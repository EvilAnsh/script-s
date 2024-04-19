#!/bin/bash

curl -sLo "$(dirname "$0")/util.logging.sh" https://raw.githubusercontent.com/ksauraj/telegram-bash-bot/master/util.logging.sh
curl -sLo "$(dirname "$0")/util.sh" https://raw.githubusercontent.com/ksauraj/telegram-bash-bot/master/util.sh
curl -sLo "$(dirname "$0")/utils.sh" https://raw.githubusercontent.com/Hakimi0804/scripts/main/builds/utils.sh

source "$HOME/.token.sh" || { echo "warning: Unable to source token file"; }
source "$(dirname "$0")/util.logging.sh" || { echo "Unable to source telegram utils!" && exit 1; }
source "$(dirname "$0")/util.sh" || { echo "Unable to source telegram utils!" && exit 1; }


#########################################################
## This is the starting of the part you should care about
#########################################################

DEVICE=RM6785  # Not important for the build, but it is for Telegram message
CHID=-1001363413558
TMPDIR="$(mktemp -d)"
ROOT=$HOME/rising
TARGET="rising_RM6785"
KSAU_UPLOAD_FOLDER="EvilAnsh/risingOSS"
REPOSYNC_THREAD_COUNT="$(nproc --all)"
ROMNAME="risingOS"  # Not important for the build, but it is for Telegram message

# Arrow leftover - adapt for whatever ROM being built, or ignore
if [[ $1 == gapps ]]; then
    export WITH_GMS=true
    GAPPS_INSERT="(GAPPS)"
else
    GAPPS_INSERT="(VANILLA)"
fi

# Do not pass any of these if you don't want to repo sync
if [[ "$*" =~ "--sync" ]]; then  # Regular sync
    NEED_SYNC=false
elif [[ "$*" =~ "--fsync" ]]; then  # Sync with --force-sync
    NEED_FSYNC=false
fi

# Build flavour
if [ -z "$FLAVOUR" ]; then
  FLAVOUR=user
fi
echo " ** Using flavour $FLAVOUR, to change please export FLAVOUR"

#########################################################
## This is the ending of the part you should care about
#########################################################

tg --sendmsg \
    "$CHID" \
    "Building $ROMNAME for $DEVICE $GAPPS_INSERT
Progress: --%" >/dev/null

progress() {
    BUILD_PROGRESS=$(
            sed -n '/Starting ninja/,$p' "$HOME/build_$DEVICE.log" | \
            grep -Po '\d+% \d+/\d+' | \
            tail -n1 | \
            sed -e 's/ / \(/' -e 's/$/)/'
    )
    [ "$BUILD_PROGRESS" ] && NEED_EDIT=true
}

editmsg() {
    [[ "$*" =~ "--no-proginsert" ]] && local no_proginsert=true
    [[ "$*" =~ "--edit-prog" ]] && local edit_prog=true
    [[ "$*" =~ "--cust-prog" ]] && local cust_prog=true
    if [[ $edit_prog == true ]]; then
        if [[ $NEED_EDIT == true ]]; then
            tg --editmsg "$CHID" \
                "$SENT_MSG_ID" \
                "Building $ROMNAME for $DEVICE $GAPPS_INSERT
ro tmate session: $(tmate display -p '#{tmate_ssh_ro}')
Progress: $BUILD_PROGRESS" >/dev/null
        fi
    elif [[ $cust_prog == true ]]; then
        tg --editmsg "$CHID" \
            "$SENT_MSG_ID" \
            "Building $ROMNAME for $DEVICE $GAPPS_INSERT
ro tmate session: $(tmate display -p '#{tmate_ssh_ro}')
Progress: $1" >/dev/null
    elif [[ $no_proginsert == true ]]; then
        tg --editmsg "$CHID" \
            "$SENT_MSG_ID" \
            "$1" >/dev/null
    fi
}

fail() {
    editmsg "$1" --cust-prog
    unlock
    exit 1
}

inttrap() {
    kill -s SIGINT "$(jobs -p | tr -d '[:space:]' | tr -d '\n')"
    # Wait for the job to exit by sigint
    editmsg "Build failed, SIGINT received" --cust-prog
    wait
    unlock
    exit
}

# Check if there's a build in progress
source "$(dirname "$0")/utils.sh"
check_lock

# Prevent the script from running multiple times
lock

trap inttrap SIGINT

cd "$ROOT" || exit 1

if [[ $NEED_SYNC == true ]]; then
    editmsg "--% (Syncing with repo sync -j12 --optimized-fetch --auto-gc)" --cust-prog
    repo sync "-j$REPOSYNC_THREAD_COUNT" --optimized-fetch --auto-gc
elif [[ $NEED_FSYNC == true ]]; then
    editmsg "--% (Syncing with repo sync -j12 --optimized-fetch --force-sync --auto-gc)" --cust-prog
    repo sync "-j$REPOSYNC_THREAD_COUNT" --optimized-fetch --force-sync --auto-gc
fi

editmsg "--% (Initialising build system)" --cust-prog
source build/envsetup.sh
export ALLOW_MISSING_DEPENDENCIES=true
build_start=$(date +%s)
riseup "$DEVICE" "$FLAVOUR"
{ rise b 2>&1 | tee "$HOME/build_$DEVICE.log" || touch "$TMPDIR/build_failed_marker"; } &


until [ -z "$(jobs -r)" ]; do
    progress
    editmsg --edit-prog
    sleep 5
done

if [ -f "$TMPDIR/build_failed_marker" ]; then
    curl -s "https://api.telegram.org/bot$TOKEN/sendDocument" -F chat_id=$CHID -F document=@out/error.log
    fail "Build failed"
fi

progress
editmsg --edit-prog

if ! echo "$BUILD_PROGRESS" | grep -q "100%"; then
    curl -s "https://api.telegram.org/bot$TOKEN/sendDocument" -F chat_id=$CHID -F document=@out/error.log
    fail "Build failed"
fi

build_end=$(date +%s)
build_diff=$((build_end - build_start))
build_time="$((build_diff / 3600)) hour and $(($((build_diff / 60)) % 60)) minutes"

sleep 2
editmsg "$BUILD_PROGRESS
Build finished in $build_time" --cust-prog

tg --sendmsg \
    "$CHID" \
    "Uploading zip" >/dev/null

fname=$(find $ROOT/out/target/product/$DEVICE -maxdepth 1 -iname '*.zip' | grep -v ota-eng)

link=$(ksau -c hakimionedrive -q upload "$fname" "$KSAU_UPLOAD_FOLDER")
tg --editmsg "$CHID" "$SENT_MSG_ID" "Done
Download link: $link
SHA256SUM: $(cut -d' ' -f1 <"$fname.sha256sum")" >/dev/null

# Remove the lock
unlock

exit 0
