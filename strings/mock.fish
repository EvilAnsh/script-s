#!/bin/fish

set -g filename $argv[1]
if test (count $argv) -eq 0
    echo "No filename passed" 2>&1
    exit 1
end
if not test -f $filename
    echo "File does not exist" 2>&1
    exit 1
end

set -g content (cat $filename)
set -g split_content (string split '' $content)
set -g split_content_count (count $split_content)
set -g count 1

for char in $split_content
    if test -z "$current_type"
        set -g current_type lower
    end

    set -g new_split_content $new_split_content (string $current_type $char)

    if test "$current_type" = "lower"
        set -g current_type "upper"
    else if test "$current_type" = "upper"
        set -g current_type "lower"
    end
end

for char in $new_split_content
    echo -n $char >> $filename.mocked
end
