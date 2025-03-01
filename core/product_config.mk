#
# Copyright (C) 2008 The Android Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# ---------------------------------------------------------------
# Generic functions
# TODO: Move these to definitions.make once we're able to include
# definitions.make before config.make.

###########################################################
## Return non-empty if $(1) is a C identifier; i.e., if it
## matches /^[a-zA-Z_][a-zA-Z0-9_]*$/.  We do this by first
## making sure that it isn't empty and doesn't start with
## a digit, then by removing each valid character.  If the
## final result is empty, then it was a valid C identifier.
##
## $(1): word to check
###########################################################

_ici_digits := 0 1 2 3 4 5 6 7 8 9
_ici_alphaunderscore := \
    a b c d e f g h i j k l m n o p q r s t u v w x y z \
    A B C D E F G H I J K L M N O P Q R S T U V W X Y Z _
define is-c-identifier
$(strip \
  $(if $(1), \
    $(if $(filter $(addsuffix %,$(_ici_digits)),$(1)), \
     , \
      $(eval w := $(1)) \
      $(foreach c,$(_ici_digits) $(_ici_alphaunderscore), \
        $(eval w := $(subst $(c),,$(w))) \
       ) \
      $(if $(w),,TRUE) \
      $(eval w :=) \
     ) \
   ) \
 )
endef

# TODO: push this into the combo files; unfortunately, we don't even
# know HOST_OS at this point.
trysed := $(shell echo a | sed -E -e 's/a/b/' 2>/dev/null)
ifeq ($(trysed),b)
  SED_EXTENDED := sed -E
else
  trysed := $(shell echo c | sed -r -e 's/c/d/' 2>/dev/null)
  ifeq ($(trysed),d)
    SED_EXTENDED := sed -r
  else
    $(error Unknown sed version)
  endif
endif

###########################################################
## List all of the files in a subdirectory in a format
## suitable for PRODUCT_COPY_FILES and
## PRODUCT_SDK_ADDON_COPY_FILES
##
## $(1): Glob to match file name
## $(2): Source directory
## $(3): Target base directory
###########################################################

define find-copy-subdir-files
$(shell find $(2) -name "$(1)" | $(SED_EXTENDED) "s:($(2)/?(.*)):\\1\\:$(3)/\\2:" | sed "s://:/:g")
endef

# ---------------------------------------------------------------

# These are the valid values of TARGET_BUILD_VARIANT.  Also, if anything else is passed
# as the variant in the PRODUCT-$TARGET_BUILD_PRODUCT-$TARGET_BUILD_VARIANT form,
# it will be treated as a goal, and the eng variant will be used.
INTERNAL_VALID_VARIANTS := user userdebug eng tests

# ---------------------------------------------------------------
# Provide "PRODUCT-<prodname>-<goal>" targets, which lets you build
# a particular configuration without needing to set up the environment.
#
product_goals := $(strip $(filter PRODUCT-%,$(MAKECMDGOALS)))
ifdef product_goals
  # Scrape the product and build names out of the goal,
  # which should be of the form PRODUCT-<productname>-<buildname>.
  #
  ifneq ($(words $(product_goals)),1)
    $(error Only one PRODUCT-* goal may be specified; saw "$(product_goals)")
  endif
  goal_name := $(product_goals)
  product_goals := $(patsubst PRODUCT-%,%,$(product_goals))
  product_goals := $(subst -, ,$(product_goals))
  ifneq ($(words $(product_goals)),2)
    $(error Bad PRODUCT-* goal "$(goal_name)")
  endif

  # The product they want
  TARGET_PRODUCT := $(word 1,$(product_goals))

  # The variant they want
  TARGET_BUILD_VARIANT := $(word 2,$(product_goals))

  # The build server wants to do make PRODUCT-dream-installclean
  # which really means TARGET_PRODUCT=dream make installclean.
  ifneq ($(filter-out $(INTERNAL_VALID_VARIANTS),$(TARGET_BUILD_VARIANT)),)
	MAKECMDGOALS := $(MAKECMDGOALS) $(TARGET_BUILD_VARIANT)
	TARGET_BUILD_VARIANT := eng
    default_goal_substitution :=
  else
    default_goal_substitution := $(DEFAULT_GOAL)
  endif

  # For tests build, only build tests-build-target
  ifeq (tests,$(TARGET_BUILD_VARIANT))
    default_goal_substitution := tests-build-target
  endif

  # Hack to make the linux build servers use dexpreopt (emulator-based
  # preoptimization). Most engineers don't use this type of target
  # ("make PRODUCT-blah-user"), so this should only tend to happen when
  # using buildbot.
  # TODO: Remove this once host Dalvik preoptimization is working.
  ifeq ($(TARGET_BUILD_VARIANT),user)
    WITH_DEXPREOPT_buildbot := true
  endif

  # Replace the PRODUCT-* goal with the build goal that it refers to.
  # Note that this will ensure that it appears in the same relative
  # position, in case it matters.
  #
  # Note that modifying this will not affect the goals that make will
  # attempt to build, but it's important because we inspect this value
  # in certain situations (like for "make sdk").
  #
  MAKECMDGOALS := $(patsubst $(goal_name),$(default_goal_substitution),$(MAKECMDGOALS))

  # Define a rule for the PRODUCT-* goal, and make it depend on the
  # patched-up command-line goals as well as any other goals that we
  # want to force.
  #
.PHONY: $(goal_name)
$(goal_name): $(MAKECMDGOALS)
endif
# else: Use the value set in the environment or buildspec.mk.

# ---------------------------------------------------------------
# Provide "APP-<appname>" targets, which lets you build
# an unbundled app.
#
unbundled_goals := $(strip $(filter APP-%,$(MAKECMDGOALS)))
ifdef unbundled_goals
  ifneq ($(words $(unbundled_goals)),1)
    $(error Only one APP-* goal may be specified; saw "$(unbundled_goals)"))
  endif
  TARGET_BUILD_APPS := $(strip $(subst -, ,$(patsubst APP-%,%,$(unbundled_goals))))
  ifneq ($(filter $(DEFAULT_GOAL),$(MAKECMDGOALS)),)
    MAKECMDGOALS := $(patsubst $(unbundled_goals),,$(MAKECMDGOALS))
  else
    MAKECMDGOALS := $(patsubst $(unbundled_goals),$(DEFAULT_GOAL),$(MAKECMDGOALS))
  endif

.PHONY: $(unbundled_goals)
$(unbundled_goals): $(MAKECMDGOALS)
endif # unbundled_goals

# ---------------------------------------------------------------
# Include the product definitions.
# We need to do this to translate TARGET_PRODUCT into its
# underlying TARGET_DEVICE before we start defining any rules.
#
include $(BUILD_SYSTEM)/node_fns.mk
include $(BUILD_SYSTEM)/product.mk
include $(BUILD_SYSTEM)/device.mk

ifneq ($(strip $(TARGET_BUILD_APPS)),)
  # An unbundled app build needs only the core product makefiles.
  $(call import-products,$(call get-product-makefiles,\
      $(SRC_TARGET_DIR)/product/AndroidProducts.mk))
else
  # Read in all of the product definitions specified by the AndroidProducts.mk
  # files in the tree.
  #
  #TODO: when we start allowing direct pointers to product files,
  #    guarantee that they're in this list.
  $(call import-products, $(get-all-product-makefiles))
endif # TARGET_BUILD_APPS
$(check-all-products)
#$(dump-products)
#$(error done)

# Convert a short name like "sooner" into the path to the product
# file defining that product.
#
INTERNAL_PRODUCT := $(call resolve-short-product-name, $(TARGET_PRODUCT))
#$(error TARGET_PRODUCT $(TARGET_PRODUCT) --> $(INTERNAL_PRODUCT))

# Find the device that this product maps to.
TARGET_DEVICE := $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_DEVICE)

# Figure out which resoure configuration options to use for this
# product.
PRODUCT_LOCALES := $(strip $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_LOCALES))
# TODO: also keep track of things like "port", "land" in product files.

# If CUSTOM_LOCALES contains any locales not already included
# in PRODUCT_LOCALES, add them to PRODUCT_LOCALES.
extra_locales := $(filter-out $(PRODUCT_LOCALES),$(CUSTOM_LOCALES))
ifneq (,$(extra_locales))
  ifneq ($(CALLED_FROM_SETUP),true)
    # Don't spam stdout, because envsetup.sh may be scraping values from it.
    $(info Adding CUSTOM_LOCALES [$(extra_locales)] to PRODUCT_LOCALES [$(PRODUCT_LOCALES)])
  endif
  PRODUCT_LOCALES += $(extra_locales)
  extra_locales :=
endif

# Default to medium-density assets.
# (Can be overridden in the device config, e.g.: PRODUCT_LOCALES += hdpi)
PRODUCT_LOCALES := $(strip \
	$(PRODUCT_LOCALES) \
	$(if $(filter %dpi,$(PRODUCT_LOCALES)),,mdpi))

# Everyone gets nodpi assets which are density-independent.
PRODUCT_LOCALES += nodpi

# Assemble the list of options.
PRODUCT_AAPT_CONFIG := $(PRODUCT_LOCALES)

# Convert spaces to commas.
comma := ,
PRODUCT_AAPT_CONFIG := \
	$(subst $(space),$(comma),$(strip $(PRODUCT_AAPT_CONFIG)))

PRODUCT_BRAND := $(strip $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_BRAND))

PRODUCT_MODEL := $(strip $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_MODEL))
ifndef PRODUCT_MODEL
  PRODUCT_MODEL := $(strip $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_NAME))
endif

PRODUCT_MANUFACTURER := \
	$(strip $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_MANUFACTURER))
ifndef PRODUCT_MANUFACTURER
  PRODUCT_MANUFACTURER := unknown
endif

ifeq ($(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_CHARACTERISTICS),)
  TARGET_AAPT_CHARACTERISTICS := default
else
  TARGET_AAPT_CHARACTERISTICS := $(strip $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_CHARACTERISTICS))
endif

PRODUCT_SPECIFIC_DEFINES := \
	$(strip $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_SPECIFIC_DEFINES))

PRODUCT_DEFAULT_WIFI_CHANNELS := \
	$(strip $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_DEFAULT_WIFI_CHANNELS))

# A list of words like <source path>:<destination path>.  The file at
# the source path should be copied to the destination path when building
# this product.  <destination path> is relative to $(PRODUCT_OUT), so
# it should look like, e.g., "system/etc/file.xml".  The rules
# for these copy steps are defined in config/Makefile.
PRODUCT_COPY_FILES := \
	$(strip $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_COPY_FILES))

# The HTML file containing the contributors to the project.
PRODUCT_CONTRIBUTORS_FILE := \
	$(strip $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_CONTRIBUTORS_FILE))

# A list of property assignments, like "key = value", with zero or more
# whitespace characters on either side of the '='.
PRODUCT_PROPERTY_OVERRIDES := \
	$(strip $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_PROPERTY_OVERRIDES))

PRODUCT_BUILD_PROP_OVERRIDES := \
        $(strip $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_BUILD_PROP_OVERRIDES))

# Should we use the default resources or add any product specific overlays
PRODUCT_PACKAGE_OVERLAYS := \
	$(strip $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_PACKAGE_OVERLAYS))
DEVICE_PACKAGE_OVERLAYS := \
        $(strip $(PRODUCTS.$(INTERNAL_PRODUCT).DEVICE_PACKAGE_OVERLAYS))

# An list of whitespace-separated words.
PRODUCT_TAGS := $(strip $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_TAGS))

# Add the product-defined properties to the build properties.
ADDITIONAL_BUILD_PROPERTIES := \
	$(ADDITIONAL_BUILD_PROPERTIES) \
	$(PRODUCT_PROPERTY_OVERRIDES)

# The OTA key(s) specified by the product config, if any.  The names
# of these keys are stored in the target-files zip so that post-build
# signing tools can substitute them for the test key embedded by
# default.
PRODUCT_OTA_PUBLIC_KEYS := $(sort \
    $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_OTA_PUBLIC_KEYS))

# ---------------------------------------------------------------
# Simulator overrides
ifeq ($(TARGET_PRODUCT),sim)
  # Tell the build system to turn on some special cases
  # to deal with the simulator product.
  TARGET_SIMULATOR := true
  # dexpreopt doesn't work when building the simulator
  DISABLE_DEXPREOPT := true
endif
