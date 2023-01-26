#!/bin/bash
readonly ARROW_ROOT=$HOME/arrow
readonly SCRIPT_NAME=$0
cd "$ARROW_ROOT" || exit 1

function print {
    echo "$SCRIPT_NAME: $*"
}
# frameworks/av: alps codecs stuff
cd frameworks/av
if patch -p1 --dry-run -R <(curl -sL https://github.com/ArrowOS/android_frameworks_av/commit/1fb1c48309cf01deb9e3f8253cb7fa5961c25595.patch) >/dev/null; then
    git am <(curl -sL https://github.com/ArrowOS/android_frameworks_av/commit/1fb1c48309cf01deb9e3f8253cb7fa5961c25595.patch)
else
    print "frameworks/av: alps commit already applied, skipping"
fi
cd ../..

# vendor/arrow: Do not build kernel from source if prebuilt is defined
cd vendor/arrow
if patch -p1 --dry-run -R <(curl -sL https://pastebin.com/raw/GnqV3Knb); then
    git am <(curl -sL https://pastebin.com/raw/GnqV3Knb)
else
    print "vendor/arrow: kernel patch already applied, skipping"
fi
cd ../..

# LineageOS Aperture
rm -rfv packages/apps/Camera2
test -d packages/apps/Aperture || git clone https://github.com/LineageOS/android_packages_apps_Aperture packages/apps/Aperture
cd packages/apps/Aperture
git pull
cd ../../..
