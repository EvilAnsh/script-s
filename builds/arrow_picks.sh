#!/bin/bash
readonly ARROW_ROOT=$HOME/arrow
readonly SCRIPT_NAME=$0
cd "$ARROW_ROOT" || exit 1

function print {
    echo "$SCRIPT_NAME: $*"
}

function apply_patch {
    if patch -d "$1" -p1 --dry-run -R <(curl -sL "$2") >/dev/null; then
        git -C "$1" am <(curl -sL "$1")
    fi
}

# media: Import codecs/omx changes from t-alps-q0.mp1-V9.122.1
apply_patch frameworks/av https://github.com/ArrowOS/android_frameworks_av/commit/1fb1c48309cf01deb9e3f8253cb7fa5961c25595.patch
# kernel: Add option to disable inline kernel building
apply_patch vendor/arrow https://pastebin.com/raw/GnqV3Knb

# LineageOS Aperture
rm -rfv packages/apps/Camera2
test -d packages/apps/Aperture || git clone https://github.com/LineageOS/android_packages_apps_Aperture packages/apps/Aperture
git -C packages/apps/Aperture pull
