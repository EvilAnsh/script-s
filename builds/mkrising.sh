#!/bin/bash
# shellcheck disable=SC2153 # possible misspelling (SENT_MSG_ID is set by util.sh)
# shellcheck disable=SC1091 # Not following: not specified as input (who cares)

set -o pipefail

curl -sL https://raw.githubusercontent.com/Hakimi0804/tgbot/main/util.sh -o util.sh
source util.sh # make sure TOKEN is exported

# Constants
KSAU_UPLOAD_FOLDER=hakimi
CHANNEL_CHAT_ID=-1001363413558
MANIFEST="https://github.com/RisingTechOSS/android"
MANIFEST_BRANCH="fourteen"
DEVICE="RM6785"
LM_LINK="https://github.com/EvilAnsh/Local-Manifest"
LM_BRANCH="rising"
LM_PATH=".repo/local_manifests"
n=$'\n' # syntax looks weird, because it's mostly unknown

MSG_TITLE=(
    $'Building ROM for RM6785\n'
)

git config --global user.email "singhansh64321@gmail.com"
git config --global user.name "Ansh"

command -v ksau >/dev/null 2>&1 || curl -s https://raw.githubusercontent.com/ksauraj/global_index_source/master/setup | bash

duf || df -h
#mkdir work
#cd work

update_progress() {
    BUILD_PROGRESS=$(
            sed -n '/ ninja/,$p' "build_$DEVICE.log" | \
            grep -Po '\d+% \d+/\d+' | \
            tail -n1 | \
            sed -e 's/ / \(/' -e 's/$/)/'
        )
}

edit_progress() {
    if [ -z "$BUILD_PROGRESS" ]; then
        return
    fi
    if [ "$BUILD_PROGRESS" = "$PREV_BUILD_PROGRESS" ]; then
        return
    fi
    tg --editmsg "$CHANNEL_CHAT_ID" "$SENT_MSG_ID" "${MSG_TITLE[*]}Progress: $BUILD_PROGRESS" >/dev/null 2>&1
    PREV_BUILD_PROGRESS=$BUILD_PROGRESS
}

fail() {
    BUILD_PROGRESS=failed
    edit_progress
    exit 1
}

tg --sendmsg "$CHANNEL_CHAT_ID" "${MSG_TITLE[*]}Progress: Syncing repo" >/dev/null 2>&1

repo init --depth=1 -u "$MANIFEST" -b "$MANIFEST_BRANCH"
[ -d "$LM_PATH" ] || git clone "$LM_LINK" --depth=1 --single-branch -b "$LM_BRANCH" "$LM_PATH"
repo sync -c --no-clone-bundle --no-tags --optimized-fetch --prune --force-sync "-j$(nproc --all)" &
repo_sync_start=$(date +%s)
until [ -z "$(jobs -r)" ]; do
    tempdiff=$(($(date +%s) - repo_sync_start))
    BUILD_PROGRESS="Repo syncing. Time elapsed: $((tempdiff / 60)) min $((tempdiff % 60)) sec"
    edit_progress
    sleep 5
done
repo_sync_end=$(date +%s)
repo_sync_diff=$((repo_sync_end - repo_sync_start))
repo_sync_time="$((repo_sync_diff / 3600)) hour and $(($((repo_sync_diff / 60)) % 60)) minute(s)"
BUILD_PROGRESS=""
edit_progress
unset BUILD_PROGRESS
MSG_TITLE+=("Repo sync took $repo_sync_time$n")

rm -f "build_$DEVICE.log"

MSG_TITLE+=($'\nBuilding for RM6785\n')
. build/envsetup.sh && \
    opt_patch && \
    cd device/lineage/sepolicy && \
    wget https://github.com/realme-mt6785-devs/android_device_lineage_sepolicy/commit/63529a7f2a7992cd50581d89489dd0a67be13c9c.patch && git am *.patch && \
    cd - && \
    cd packages/modules/Bluetooth && \
    git fetch https://github.com/realme-mt6785-devs/android_packages_modules_Bluetooth && \
    git cherry-pick be5b9270bcbc85b1caa2cf5421c712f048a37ec6 && \
    lunch "rising_$DEVICE-user" && \
    { ascend | tee -a "build_$DEVICE.log" || fail; } &

until [ -z "$(jobs -r)" ]; do
    update_progress
    edit_progress
    sleep 5
done

update_progress
edit_progress
file_link=$(ksau -r -q upload out/target/product/$DEVICE/*.zip "$KSAU_UPLOAD_FOLDER")
echo "RM6785 link: $file_link"
MSG_TITLE+=("RM6785 link: $file_link$n")

until [ -z "$(jobs -r)" ]; do
    update_progress
    edit_progress
    sleep 5
done
