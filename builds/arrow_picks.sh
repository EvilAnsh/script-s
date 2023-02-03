#!/bin/bash
readonly ARROW_ROOT=$HOME/arrow
readonly SCRIPT_NAME=$0
cd "$ARROW_ROOT" || exit 1

function print {
    echo "$SCRIPT_NAME: $*"
}

function apply_patch {
    if patch -d "$1" -p1 --dry-run <<<"$(curl -sL "$2")" >/dev/null; then
        if ! [ "$3" = use_patch ]; then
            git -C "$1" am <<<"$(curl -sL "$2")"
        else
            patch -d "$1" -p1 <<<"$(curl -sL $2)"
        fi
    fi
}

# media: Import codecs/omx changes from t-alps-q0.mp1-V9.122.1
apply_patch frameworks/av https://github.com/ArrowOS/android_frameworks_av/commit/1fb1c48309cf01deb9e3f8253cb7fa5961c25595.patch

# kernel: Add option to disable inline kernel building
apply_patch vendor/arrow https://pastebin.com/raw/GnqV3Knb

# Fix brightness slider curve for some devices
apply_patch frameworks/base https://github.com/realme-mt6785-devs/android_frameworks_base/commit/7d626a51c37bf40dcceeae0c52afc4b5fbf5203a.patch

# Add bluetooth and sdk_sandbox to default key map
apply_patch build https://github.com/LineageOS/android_build/commit/483f3cf277485c9eaeaf5e025836ea0271574a63.patch use_patch


# LineageOS Aperture (added to local manifest)
#rm -rfv packages/apps/Camera2
#test -d packages/apps/Aperture || git clone https://github.com/LineageOS/android_packages_apps_Aperture packages/apps/Aperture
#git -C packages/apps/Aperture pull
