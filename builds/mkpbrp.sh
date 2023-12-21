#!/bin/bash
# shellcheck disable=SC2153 # possible misspelling (SENT_MSG_ID is set by util.sh)
# shellcheck disable=SC1091 # Not following: not specified as input (who cares)

set -o pipefail

curl -sL https://raw.githubusercontent.com/Hakimi0804/tgbot/main/util.sh -o util.sh
source util.sh # make sure TOKEN is exported

# Constants
KSAU_UPLOAD_FOLDER=hakimi
RM6785_TESTING_GROUPID=-1001299514785
CHANNEL_CHAT_ID=-1001664444944
MANIFEST="https://github.com/PitchBlackRecoveryProject/manifest_pb.git"
MANIFEST_BRANCH="android-12.1"
DEVICE="RMX2001"
DT_LINK="https://github.com/PitchBlackRecoveryProject/android_device_realme_RMX2001-pbrp"
DT_BRANCH="android-12.1"
DT_PATH="device/realme/RMX2001"
n=$'\n' # syntax looks weird, because it's mostly unknown

# second device
DEVICER7="RMX2151"
DT_LINKR7="https://github.com/PitchBlackRecoveryProject/android_device_realme_RMX2151-pbrp"
DT_BRANCHR7="android-12.1"
DT_PATHR7="device/realme/RMX2151"

MSG_TITLE=(
    $'Building recovery for realme 6/RM6785\n'
)

git config --global user.email "hakimifirdaus944@gmail.com"
git config --global user.name "Firdaus Hakimi"

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

tg --sendmsg "$RM6785_TESTING_GROUPID" "PBRP Build started. View progress in https://t.me/Hakimi0804_SC" >/dev/null 2>&1
tg --sendmsg "$CHANNEL_CHAT_ID" "${MSG_TITLE[*]}Progress: Syncing repo" >/dev/null 2>&1

repo init --depth=1 -u "$MANIFEST" -b "$MANIFEST_BRANCH"
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

[ -d "$DT_PATH" ] || git clone "$DT_LINK" --depth=1 --single-branch -b "$DT_BRANCH" "$DT_PATH"
rm -f "build_$DEVICE.log"

MSG_TITLE+=($'\nBuilding for RMX2001\n')
. build/envsetup.sh && \
    lunch "omni_$DEVICE-eng" && \
    { make "-j$(nproc --all)" pbrp | tee -a "build_$DEVICE.log" || fail; } &

until [ -z "$(jobs -r)" ]; do
    update_progress
    edit_progress
    sleep 5
done

update_progress
edit_progress
file_link=$(ksau -r -q upload out/target/product/$DEVICE/*.zip "$KSAU_UPLOAD_FOLDER")
echo "RMX2001 link: $file_link"
MSG_TITLE+=("RMX2001 link: $file_link$n")




## REALME 7/Narzo 20 Pro/Narzo 30 4G ##

[ -d "$DT_PATHR7" ] || git clone "$DT_LINKR7" "$DT_PATHR7" --depth=1 --single-branch -b "$DT_BRANCHR7"

DEVICE=$DEVICER7
rm -f "build_$DEVICE.log"
MSG_TITLE+=($'\nBuilding for salaa\n')
. build/envsetup.sh && \
    lunch "omni_$DEVICE-eng" && \
    { make "-j$(nproc --all)" pbrp | tee -a build_$DEVICE.log || fail; } &

until [ -z "$(jobs -r)" ]; do
    update_progress
    edit_progress
    sleep 5
done

update_progress
edit_progress

file_link=$(ksau -r -q upload out/target/product/$DEVICE/*.zip "$KSAU_UPLOAD_FOLDER")
echo "salaa link: $file_link"
MSG_TITLE+=("RMX2151 link: $file_link$n")
BUILD_PROGRESS="Finished successfully"
edit_progress

nSENT_MSG_ID=$(tg --fwdmsg "$CHANNEL_CHAT_ID" "$RM6785_TESTING_GROUPID" "$SENT_MSG_ID" | jq .result.message_id)
tg --pinmsg $RM6785_TESTING_GROUPID  "$nSENT_MSG_ID" >/dev/null 2>&1
