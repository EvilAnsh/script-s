#!/bin/bash
binpath=$HOME/github-repo/mybot/telegram-bot-bash/bin
chid=-1001664444944
pbrp_root=$HOME/pbrp/pbrp
if [[ $1 == RMX2151 || $1 == RMX2001 ]]; then
    DEVICE=$1
else
    echo "Invalid device"
    exit 1
fi
if [[ "$*" =~ "--sync" ]]; then
    NEED_SYNC=true
elif [[ "$*" =~ "--fsync" ]]; then
    NEED_FSYNC=true
fi
msgtoeditid=$(
    "$binpath/send_message.sh" \
        "$chid" \
        "Building PBRP for $DEVICE\nProgress: --% (Build system initialization in progress)" \
        | grep 'ID' \
        | cut -d] -f2 \
        | tr -d '[:space:]' \
        | sed 's/"//g'
)

cd "$pbrp_root" || exit 1
source build/envsetup.sh
lunch "omni_$DEVICE-eng"
mka pbrp 2>&1 | tee "$HOME/build_$DEVICE.log" &

progress() {
    BUILD_PROGRESS=$(
            sed -n '/ ninja/,$p' "$HOME/build_$DEVICE.log" | \
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
            "$BINPATH/edit_message.sh" "$CHID" \
                "$MSGTOEDITID" \
                "Building PBRP for $DEVICE\nProgress: $BUILD_PROGRESS"
        fi
    elif [[ $cust_prog == true ]]; then
        "$BINPATH/edit_message.sh" "$CHID" \
            "$MSGTOEDITID" \
            "Building PBRP for $DEVICE\nprogress: $1"
    elif [[ $no_proginsert == true ]]; then
        "$BINPATH/edit_message.sh" "$CHID" \
            "$MSGTOEDITID" \
            "$1"
    fi
}

fail() {
    editmsg "$1" --cust-prog
    exit 1
}

inttrap() {
    kill -s SIGINT "$(jobs -p | tr -d '[:space:]' | tr -d '\n')"
    # Wait for the job to exit by sigint
    editmsg "Build failed, SIGINT received" --cust-prog
    wait
    exit
}

trap inttrap SIGINT

editmsg "--% (Updating device tree)" --cust-prog
cd device/realme/$DEVICE || exit 1
git pull || git pull --rebase || git rebase --abort; git reset --hard HEAD~5; git pull || fail "Failed to update device tree"

cd "$pbrp_root" || exit 1

if [[ $NEED_SYNC == true ]]; then
    editmsg "--% (Syncing with repo sync)" --cust-prog
    repo sync
elif [[ $NEED_FSYNC == true ]]; then
    editmsg "--% (Syncing with repo sync --force-sync)" --cust-prog
    repo sync --force-sync
fi

until [ -z "$(jobs -r)" ]; do
    progress
    editmsg --edit-prog
    sleep 5
done

progress
editmsg --edit-prog


msgtoeditid=$(
    "$binpath/send_message.sh" \
        "$chid" \
        "Uploading recovery image" \
        | grep 'ID' \
        | cut -d] -f2 \
        | tr -d '[:space:]' \
        | sed 's/"//g'
)
link=$(
    transfer wet --silent "$(
        grep 'Flashable Zip' "$HOME/build_$DEVICE.log" \
        | cut -d: -f2 \
        | tr -d '[:space:]'
    )"
)
# transfer wet /home/azureuser/pbrp/pbrp/out/target/product/RMX2151/PBRP-RMX2151-3.1.0-20220207-0422-UNOFFICIAL.zip 2>&1 | grep 'we.tl' | cut -d: -f3
# //we.tl/t-UcrCXiVVnP
editmsg "Done\nDownload link: $link" --no-proginsert
exit 0
