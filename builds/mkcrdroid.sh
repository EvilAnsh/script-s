#!/bin/bash
DEVICE=chan
source "$HOME/.token.sh" || { echo "Unable to get token!" && exit 1; }
source "$HOME/github-repo/telegram-bash-bot/util.logging.sh" || { echo "Unable to source telegram utils!" && exit 1; }
source "$HOME/github-repo/telegram-bash-bot/util.sh" || { echo "Unable to source telegram utils!" && exit 1; }
CHID=-1001664444944
TMPDIR="$(mktemp -d)"

sudo apt-get -y install rclone jq

ROOT=$HOME/builds/crdroid
if [[ $1 == gapps ]]; then
    export ARROW_GAPPS=true
    GAPPS_INSERT="(GAPPS)"
else
    GAPPS_INSERT="(VANILLA)"
fi
if [[ "$*" =~ "--sync" ]]; then
    NEED_SYNC=true
elif [[ "$*" =~ "--fsync" ]]; then
    NEED_FSYNC=true
fi

if [ -z "$FLAVOUR" ]; then
  FLAVOUR=eng
fi

tg --sendmsg \
    "$CHID" \
    "Building crdroid for $DEVICE $GAPPS_INSERT
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
                "Building crdroid for $DEVICE $GAPPS_INSERT
ro tmate session: $(tmate display -p '#{tmate_ssh_ro}')
Progress: $BUILD_PROGRESS" >/dev/null
        fi
    elif [[ $cust_prog == true ]]; then
        tg --editmsg "$CHID" \
            "$SENT_MSG_ID" \
            "Building crdroid for $DEVICE $GAPPS_INSERT
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
#cd "device/realme/$DEVICE" || exit 1
#git pull --rebase || git rebase --abort; git pull || git reset --hard HEAD~5; git pull || fail "Failed to update device tree"

#cd "$ROOT" || exit 1

if [[ $NEED_SYNC == true ]]; then
    editmsg "--% (Syncing with repo sync -j12 --optimized-fetch --auto-gc)" --cust-prog
    repo sync -j12 --optimized-fetch --auto-gc
elif [[ $NEED_FSYNC == true ]]; then
    editmsg "--% (Syncing with repo sync -j12 --optimized-fetch --force-sync --auto-gc)" --cust-prog
    repo sync -j12 --optimized-fetch --force-sync --auto-gc
fi

editmsg "--% (Initialising build system)" --cust-prog
source build/envsetup.sh
build_start=$(date +%s)
lunch "lineage_$DEVICE-$FLAVOUR"
{ m bacon 2>&1 | tee "$HOME/build_$DEVICE.log" || touch "$TMPDIR/build_failed_marker"; } &


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

build_end=$(date +%s)
build_diff=$((build_end - build_start))
build_time="$((build_diff / 3600)) hour and $(($((build_diff / 60)) % 60)) minutes"

sleep 2
editmsg "$BUILD_PROGRESS
Build finished in $build_time" --cust-prog

tg --sendmsg \
    "$CHID" \
    "Uploading zip" >/dev/null

fname=$(find $ROOT/out/target/product/$DEVICE -iname '*.zip')

link=$(ksau -c hakimionedrive -q upload "$fname" hakimi/crdroid_x3)
# transfer wet /home/azureuser/pbrp/pbrp/out/target/product/RMX2151/PBRP-RMX2151-3.1.0-20220207-0422-UNOFFICIAL.zip 2>&1 | grep 'we.tl' | cut -d: -f3
# //we.tl/t-UcrCXiVVnP
tg --editmsg "$CHID" "$SENT_MSG_ID" "Done
Download link: $link
MD5: $(cat "$fname.md5sum" | cut -d' ' -f1)" >/dev/null

# Remove the lock
unlock

exit 0
