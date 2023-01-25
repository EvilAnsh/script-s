#!/bin/bash
DEVICE=RM6785
source "$HOME/.token.sh"
source "$HOME/github-repo/telegram-bash-bot/util.sh"
CHID=-1001664444944
ROOT=$HOME/arrow
if [[ $1 == gapps ]]; then
    export ARROW_GAPPS=true
    GAPPS_INSERT="(GAPPS)"
fi
if [[ "$*" =~ "--sync" ]]; then
    NEED_SYNC=true
elif [[ "$*" =~ "--fsync" ]]; then
    NEED_FSYNC=true
fi

tg --sendmsg \
    "$CHID" \
    "Building arrow for $DEVICE $GAPPS_INSERT
Progress: --% (Updating device tree)"

progress() {
    BUILD_PROGRESS=$(
            sed -n '/Starting ninja/,$p' "$HOME/build_$DEVICE.log" | \
            grep -Po '\d+% \d+/\d+' | \
            tail -n1 | \
            sed -e 's/ / \(/' -e 's/$/)/'
    )
    [ "$BUILD_PROGRESS" ] && NEED_EDIT=true
    if [[ -z $(jobs -r) && ! $BUILD_PROGRESS =~ "100%" ]]; then
        fail "Build failed, error log: $(cat "$ROOT/out/error.log" | nc termbin.com 9999)"
    fi
}

editmsg() {
    [[ "$*" =~ "--no-proginsert" ]] && local no_proginsert=true
    [[ "$*" =~ "--edit-prog" ]] && local edit_prog=true
    [[ "$*" =~ "--cust-prog" ]] && local cust_prog=true
    if [[ $edit_prog == true ]]; then
        if [[ $NEED_EDIT == true ]]; then
            tg --editmsg "$CHID" \
                "$SENT_MSG_ID" \
                "Building arrow for $DEVICE $GAPPS_INSERT
Progress: $BUILD_PROGRESS"
        fi
    elif [[ $cust_prog == true ]]; then
        tg --editmsg "$CHID" \
            "$SENT_MSG_ID" \
            "Building arrow for $DEVICE $GAPPS_INSERT
progress: $1"
    elif [[ $no_proginsert == true ]]; then
        tg --editmsg "$CHID" \
            "$SENT_MSG_ID" \
            "$1"
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
source utils.sh
check_lock

# Prevent the script from running multiple times
lock

trap inttrap SIGINT

cd "$ROOT" || exit 1
cd "device/realme/$DEVICE" || exit 1
git pull --rebase || git rebase --abort; git pull || git reset --hard HEAD~5; git pull || fail "Failed to update device tree"

cd "$ROOT" || exit 1

if [[ $NEED_SYNC == true ]]; then
    editmsg "--% (Syncing with repo sync)" --cust-prog
    repo sync
elif [[ $NEED_FSYNC == true ]]; then
    editmsg "--% (Syncing with repo sync --force-sync)" --cust-prog
    repo sync --force-sync
fi

#editmsg "--% (Purging zips)" --cust-prog
#rm -f $ROOT/out/target/product/$DEVICE/*.zip

editmsg "--% (Initialising build system)" --cust-prog
source build/envsetup.sh
build_start=$(date +%s)
lunch "arrow_$DEVICE-userdebug"
m bacon 2>&1 | tee "$HOME/build_$DEVICE.log" || readonly build_failed=true &


until [ -z "$(jobs -r)" ]; do
    progress
    editmsg --edit-prog
    sleep 5
done

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
    "Uploading zip"

if [ "$ARROW_GAPPS" = true ]; then
    fname=$(find $ROOT/out/target/product/$DEVICE -iname '*.zip' | grep -v eng | grep GAPPS)
else
    fname=$(find $ROOT/out/target/product/$DEVICE -iname '*.zip' | grep -v eng | grep VANILLA)
fi

link=$(transfer wet --silent "$fname")
# transfer wet /home/azureuser/pbrp/pbrp/out/target/product/RMX2151/PBRP-RMX2151-3.1.0-20220207-0422-UNOFFICIAL.zip 2>&1 | grep 'we.tl' | cut -d: -f3
# //we.tl/t-UcrCXiVVnP
tg --editmsg "$CHID" "$SENT_MSG_ID" "Done
Download link: $link
MD5: $(cat "$fname.md5sum")"

# Remove the lock
unlock

exit 0
