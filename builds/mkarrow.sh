#!/bin/bash
DEVICE=RM6785
BINPATH=$HOME/github-repo/mybot/telegram-bot-bash/bin
CHID=-1001664444944
ROOT=/mnt/arrow
if [[ $1 == gapps ]]; then
    export ARROW_GAPPS=true
    GAPPS_INSERT="(GAPPS)"
fi
if [[ "$*" =~ "--sync" ]]; then
    NEED_SYNC=true
elif [[ "$*" =~ "--fsync" ]]; then
    NEED_FSYNC=true
fi
MSGTOEDITID=$(
    "$BINPATH/send_message.sh" \
        "$CHID" \
        "Building arrow for $DEVICE $GAPPS_INSERT\nProgress: --% (Updating device tree)" \
        | grep 'ID' \
        | cut -d] -f2 \
        | tr -d '[:space:]' \
        | sed 's/"//g'
)


progress() {
    BUILD_PROGRESS=$(
            sed -n '/ ninja/,$p' "$HOME/build_$DEVICE.log" | \
            grep -Po '\d+% \d+/\d+' | \
            tail -n1 | \
            sed -e 's/ / \(/' -e 's/$/)/'
    )
    [ "$BUILD_PROGRESS" ] && NEED_EDIT=true
    if [[ -z $(jobs -r) && ! $BUILD_PROGRESS =~ "100%" ]]; then
        fail "Build failed"
    fi
}

editmsg() {
    [[ "$*" =~ "--no-proginsert" ]] && local no_proginsert=true
    [[ "$*" =~ "--edit-prog" ]] && local edit_prog=true
    [[ "$*" =~ "--cust-prog" ]] && local cust_prog=true
    if [[ $edit_prog == true ]]; then
        if [[ $NEED_EDIT == true ]]; then
            "$BINPATH/edit_message.sh" "$CHID" \
                "$MSGTOEDITID" \
                "Building arrow for $DEVICE $GAPPS_INSERT\nProgress: $BUILD_PROGRESS"
        fi
    elif [[ $cust_prog == true ]]; then
        "$BINPATH/edit_message.sh" "$CHID" \
            "$MSGTOEDITID" \
            "Building arrow for $DEVICE $GAPPS_INSERT\nprogress: $1"
    elif [[ $no_proginsert == true ]]; then
        "$BINPATH/edit_message.sh" "$CHID" \
            "$MSGTOEDITID" \
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

editmsg "--% (Purging zips)" --cust-prog
rm -f $ROOT/out/target/product/$DEVICE/*.zip

editmsg "--% (Initialising build system)" --cust-prog
source build/envsetup.sh
build_start=$(date +%s)
lunch "arrow_$DEVICE-eng"
m bacon 2>&1 | tee "$HOME/build_$DEVICE.log" || readonly build_failed=true &


until [ -z "$(jobs -r)" ]; do
    progress
    editmsg --edit-prog
    sleep 7
done

progress
editmsg --edit-prog

build_end=$(date +%s)
build_diff=$((build_end - build_start))
build_time="$((build_diff / 3600)) hour and $(($((build_diff / 60)) % 60)) minutes"

sleep 2
editmsg "Build finished in $build_time"

MSGTOEDITID=$(
    "$BINPATH/send_message.sh" \
        "$CHID" \
        "Uploading zip" \
        | grep 'ID' \
        | cut -d] -f2 \
        | tr -d '[:space:]' \
        | sed 's/"//g'
)
link=$(transfer wet --silent $ROOT/out/target/product/$DEVICE/*.zip)
# transfer wet /home/azureuser/pbrp/pbrp/out/target/product/RMX2151/PBRP-RMX2151-3.1.0-20220207-0422-UNOFFICIAL.zip 2>&1 | grep 'we.tl' | cut -d: -f3
# //we.tl/t-UcrCXiVVnP
editmsg "Done\nDownload link: $link" --no-proginsert

# Remove the lock
unlock

exit 0
