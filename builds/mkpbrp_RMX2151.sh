#!/bin/bash

git config --global user.name "Firdaus Hakimi"
git config --global user.email "hakimifirdaus944@gmail.com"

if [ ! -f util.sh ]; then
	curl -sLo util.sh https://raw.githubusercontent.com/Hakimi0804/scripts/06909257a90046e8f933e754c2edfa3d161fd95f/builds/util.sh
fi

source util.sh

# CHAT_ID=-1001299514785
CHAT_ID=-1001155763792

tg --sendmsg "$CHAT_ID" "Script started"

MANIFEST="https://github.com/PitchBlackRecoveryProject/manifest_pb.git"
MANIFEST_BRANCH="android-11.0"
DEVICE="RMX2001"
DT_LINK="https://github.com/Hakimi0804/android_device_realme_RMX2001-pbrp"
DT_BRANCH="android-11.0"
DT_PATH="device/realme/RMX2001"
MSG_TITLE=$'Building PBRP for realme 7/n20p\n'

tg --editmsg "$CHAT_ID" "$SENT_MSG_ID" "${MSG_TITLE}Progress: --% (Repo syncing)"

repo init -u $MANIFEST -b $MANIFEST_BRANCH
repo sync -j8 --force-sync --no-clone-bundle --no-tags

tg --editmsg "$CHAT_ID" "$SENT_MSG_ID" "${MSG_TITLE}Progress: --% (Cloning device tree)"
git clone --depth=1 "$DT_LINK" -b "$DT_BRANCH" "$DT_PATH"

updateProg() {
	BUILD_PROGRESS=$(
            sed -n '/ ninja/,$p' "build_$DEVICE.log" | \
            grep -Po '\d+% \d+/\d+' | \
            tail -n1 | \
            sed -e 's/ / \(/' -e 's/$/)/'
    	)
}

editProg() {
	if [ -z "$BUILD_PROGRESS" ]; then
		return
	fi
	if [ "$BUILD_PROGRESS" = "$PREV_BUILD_PROGRESS" ]; then
		return
	fi
	tg --editmsg "$CHAT_ID" "$SENT_MSG_ID" "${MSG_TITLE}Progress: $BUILD_PROGRESS"
	PREV_BUILD_PROGRESS=$BUILD_PROGRESS
}

fail() {
	tg --editmsg "$CHAT_ID" "$SENT_MSG_ID" "${MSG_TITLE}Progress: Build failed"
	exit 1
}

tg --editmsg "$CHAT_ID" "$SENT_MSG_ID" "${MSG_TITLE}Progress: --% (Build system initialization)"

export RMX2151_BUILD=true
source build/envsetup.sh || fail
lunch "omni_$DEVICE-eng" || fail
make -j8 pbrp 2>&1 | tee "build_$DEVICE.log" || fail &

until [ -z "$(jobs -r)" ]; do
	updateProg
	editProg
	sleep 5
done

updateProg
editProg

tg --editmsg "$CHAT_ID" "$SENT_MSG_ID" "${MSG_TITLE}Progress: $BUILD_PROGRESS (Uploading recovery image)"

curl -sL https://git.io/file-transfer | sh
BUILD_LINK=$(
    ./transfer wet --silent "$(
        grep 'Flashable Zip' "build_$DEVICE.log" \
        | cut -d: -f2 \
        | tr -d '[:space:]'
    )"
)

tg --editmsg "$CHAT_ID" "$SENT_MSG_ID" "${MSG_TITLE}Progress: $BUILD_PROGRESS (Completed)"
tg --replymsg "$CHAT_ID" "$SENT_MSG_ID" "Build link: $BUILD_LINK"
echo "$BUILD_LINK"

