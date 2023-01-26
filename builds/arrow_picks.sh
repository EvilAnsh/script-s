#!/bin/bash
readonly ARROW_ROOT=$HOME/arrow
cd "$ARROW_ROOT" || exit 1

# frameworks/av: alps codecs stuff
cd frameworks/av
git fetch https://review.arrowos.net/ArrowOS/android_frameworks_av refs/changes/57/18657/6 && git cherry-pick FETCH_HEAD
cd ../..

# vendor/arrow: Do not build kernel from source if prebuilt is defined
cd vendor/arrow
git am <(https://pastebin.com/raw/GnqV3Knb)
cd ../..

# LineageOS Aperture
rm -rfv packages/apps/Camera2
test -d packages/apps/Aperture || git clone https://github.com/LineageOS/android_packages_apps_Aperture packages/apps/Aperture
cd packages/apps/Aperture
git pull
cd ../../..
