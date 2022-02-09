#!/bin/bash
if [[ $1 == RMX2151 || $1 == RMX2001 ]]; then
    DEVICE=$1
else
    echo "Invalid device"
    exit 1
fi
binpath=$HOME/github-repo/mybot/telegram-bot-bash/bin
chid=-1001664444944
pbrp_root=$HOME/pbrp/pbrp
msgtoeditid=$(
    "$binpath/send_message.sh" \
        "$chid" \
        "Building PBRP for $DEVICE\nProgress: Build system initialization in progress" \
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
    if [[ $NEED_EDIT == true ]]; then
        if [ -z "$1" ]; then
            "$binpath/edit_message.sh" "$chid" \
                "$msgtoeditid" \
                "Building PBRP for $DEVICE\nProgress: $BUILD_PROGRESS"
        else
            if [[ $no_proginsert == true ]]; then
                "$binpath/edit_message.sh" "$chid" \
                    "$msgtoeditid" \
                    "$1"
            else
                "$binpath/edit_message.sh" "$chid" \
                    "$msgtoeditid" \
                    "$1\nProgress: $BUILD_PROGRESS"
            fi
        fi
    fi
}

fail() {
    editmsg "$1"
    exit 1
}

editmsg "Updating device tree"
cd device/realme/$DEVICE || exit 1
git pull || git pull --rebase || git reset --hard HEAD~5; git pull || fail "Failed to update device tree"
cd "$pbrp_root" || exit 1

until [ -z "$(jobs -r)" ]; do
    progress
    editmsg
    sleep 5
done

progress
editmsg


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
