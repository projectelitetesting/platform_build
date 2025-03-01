#
# Copyright (C) 2009 The Android Open Source Project
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

# This is a build configuration for a full-featured build of the
# Open-Source part of the tree. This is a base configuration to
# bes used for AOSP builds on various target devices.

PRODUCT_PACKAGES := \
    VoiceDialer

# Additional settings used in all AOSP builds
PRODUCT_PROPERTY_OVERRIDES := \
    keyguard.no_require_sim=true \
    ro.com.android.dateformat=MM-dd-yyyy \
    ro.com.android.dataroaming=false \
    ro.config.ringtone=Ring_Synth_04.ogg 
    ro.config.notification_sound=pixiedust.ogg
 

# Put en_US first in the list, to make it default.
PRODUCT_LOCALES := en_US

# Pick up some sounds - stick with the short list to save space
# on smaller devices.
$(call inherit-product-if-exists, frameworks/base/data/sounds/OriginalAudio.mk)
$(call inherit-product, frameworks/base/data/sounds/AudioPackage5.mk)

# Get the list of languages.
$(call inherit-product, $(SRC_TARGET_DIR)/product/languages_small.mk)

$(call inherit-product, $(SRC_TARGET_DIR)/product/generic.mk)
