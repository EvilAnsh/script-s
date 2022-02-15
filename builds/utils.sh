#!/bin/bash
BINPATH=$HOME/github-repo/mybot/telegram-bot-bash/bin
CHID=-1001664444944

lock() {
    touch "$HOME/build.lock"
}

unlock() {
    rm -f "$HOME/build.lock"
}

check_lock() {
    test -f "$HOME/build.lock" && echo "Build already in progress" && exit 1
}

if [ ! -d "$BINPATH" ]; then
    TGBOT_HOME=$HOME/github-repo/mybot/telegram-bot-bash
    git clone https://github.com/Hakimi0804/telegram-bot-bash.git "$TGBOT_HOME"
    mkdir "$TGBOT_HOME/data-bot-bash"
    "$TGBOT_HOME/bashbot.sh" init
fi
