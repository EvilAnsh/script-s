#!/bin/fish

test -f .token.fish
or echo (set_color brred)".token.fish not found."(set_color normal) && exit 1

test -f util.fish
or echo (set_color brred)"util.fish not found."(set_color normal) && exit 1

source util.fish
source komaru-id.fish 2>/dev/null
set -g max_num
set -g cur_num

function update_progress
    set -g prog_prev_arg $argv[1]
    echo -ne (set_color magenta)"Processing $prog_prev_arg[1] ($cur_num/$max_num)\r"(set_color normal)
end

function finish_progress
    string repeat -n(math $COLUMNS - 1) -N ' '
    echo -ne '\r'

    set -q argv[1]
    and set prog_prev_arg $argv[1]
    echo (set_color magenta)"Processing $prog_prev_arg ($cur_num/$max_num) - Complete!"(set_color normal)
end

function write_file
    echo "set -g komaru_id $komaru_id" > komaru-id.fish
    echo "set -g komaru_unique_id $komaru_unique_id" >> komaru-id.fish
end

function update_gist
    gh gist edit https://gist.github.com/ce08621726a75310e8be7f34e9cdb1ee - < komaru-id.fish >/dev/null
end

function drop_update
    set -lx UPDATE_ID_TODROP $argv
    set -lx API $API
    python3 helper.py
end

function erase
    set -l index 1
    set -l found false
    for id in $komaru_id
        if test "$id" = "$argv[1]"
            set found true
            break
        end
        set index (math $index + 1)
    end
    if test "$found" = true
        set -ge komaru_id[$index]
        set -ge komaru_unique_id[$index]
        echo "Writing"
        write_file
        echo "Updating gist"
        update_gist
        exit 0
    else
        echo (set_color brred)"Cannot find GIF with ID $argv[1]"(set_color normal)
        exit 1
    end
end

argparse 'd/delete=' -- $argv
or exit 1
test -n "$_flag_delete"
and erase $_flag_delete

echo "Dropping updates... "
while true
    set -g update_ids (curl -s $API/getUpdates | jq .result[].update_id)
    set -g id_count (count $update_ids)
    set -g last_update_id $update_ids[$id_count]

    if test "$last_update_id" = "$prev_update_id"
        break
    end
    set -g prev_update_id $last_update_id

    echo "Dropping IDs: $update_ids"
    set -g max_num (count $update_ids)
    set -g cur_num 0
    for id in $update_ids
        update_progress "update ID"
        curl -s $API/getUpdates -d offset=$id >/dev/null &
        set -g cur_num (math $cur_num + 1)
    end
    finish_progress
    # drop_update $update_ids
end
echo (set_color brblack)"Finishing up ID dropping..."(set_color normal)
wait # Wait for bg jobs

echo (set_color green)"Now forward/send all of the gifs and press any keys to continue..."(set_color normal)
read -n1 -p "echo"

echo
while true
    set -g fetch "$(curl -s $API/getUpdates | jq .result[])"
    set -g komaru_gif_ids (echo "$fetch" | jq -r .message.document.file_id)
    set -g komaru_gif_unique_ids (echo "$fetch" | jq -r .message.document.file_unique_id)
    set -g all_update_id (echo "$fetch" | jq .update_id)
    set -g id_count (count $all_update_id)
    set -g last_update_id $all_update_id[$id_count]

    # komaru_id
    # komaru_unique_id

    if test "$last_update_id" = "$prev_update_id"
        break
    end
    set -g prev_update_id $last_update_id
    set -g max_num (count $komaru_gif_ids)

    set -l index 1
    set -l skip false
    for id in $komaru_gif_ids
        set -g cur_num $index
        update_progress GIFs
        for idu in $komaru_unique_id
            if test "$komaru_gif_unique_ids[$index]" = "$idu" -o "$komaru_gif_unique_ids[$index]" = null
                set skip true
            end
        end

        if test "$skip" = true
            set index (math $index + 1)
            set skip false
            continue
        end

        set -ga komaru_id $id
        set -ga komaru_unique_id $komaru_gif_unique_ids[$index]
        set -ga komaru_count $komaru_gif_unique_ids[$index] # Tho only will be used for count

        set index (math $index + 1)
    end
    finish_progress

    set -g max_num (count $all_update_id)
    set -l prog 1
    for id in $all_update_id
        set cur_num $prog
        update_progress "Update IDs"
        curl -s $API/getUpdates -d offset=$id >/dev/null &
        set prog (math $prog + 1)
    end
    finish_progress
    # drop_update $all_update_id
end

set_color brwhite
string repeat -n$COLUMNS '-'
set_color normal
echo "Total komaru GIFs after deduplication: $(count $komaru_count)"
echo "Grand total of komaru GIFs now: $(count $komaru_id)"
echo "Writing these to file..."
write_file
echo "Updating gist"
update_gist
echo "Finishing update id processing, this may take a while"
wait
