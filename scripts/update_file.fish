# Copyright (c) 2025 Stephen Kraus
#
# Permission is hereby granted, free of charge, to any person
# obtaining a copy of this software and associated documentation files
# (the “Software”), to deal in the Software without restriction,
# including without limitation the rights to use, copy, modify, merge,
# publish, distribute, sublicense, and/or sell copies of the Software,
# and to permit persons to whom the Software is furnished to do so,
# subject to the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
# BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
# ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
# CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

source (status dirname)/'shared_functions.fish'

function _usage
    echo >&2
    echo 'Usage: update_file.fish' >&2
    echo '    -f | --file=FILE   ' >&2
    echo >&2
end

function _get_latest_file -a file_name
    fish (status dirname)/'get_file_by_date.fish' \
        --latest \
        --file="$file_name"
end

function _update_file -a file_name file_path
    set src 'ftp.edrdg.org::nihongo'/"$file_name"
    set dest "$file_path"
    rsync "$src" "$dest"
end

function _get_file_date -a file_name file_path
    set date_pattern '[0-9]{4}-[0-9]{2}-[0-9]{2}'
    switch "$file_name"
        case 'JMdict'
            grep -m 1 '^<!-- JMdict created:' "$file_path" | grep -Eo "$date_pattern"
        case 'JMnedict.xml'
            grep -m 1 '^<!-- JMnedict created:' "$file_path" | grep -Eo "$date_pattern"
        case 'kanjidic2.xml'
            grep -m 1 '^<date_of_creation>' "$file_path" | grep -Eo "$date_pattern"
        case 'examples.utf'
            date '+%Y-%m-%d'
    end
end

function _make_new_patch -a file_name
    # Exit quickly if today's patch already exists.
    begin
        set --local file_dir (get_file_dir "$file_name")
        set --local today (date '+%Y/%m/%d')
        if test -e "$file_dir"/patches/"$today".patch.br
            echo "$file_name patch for $today already exists" >&2
            return 1
        end
    end

    set old_file_compressed (_get_latest_file "$file_name")
    or begin
        echo "Error fetching latest $file_name archive" >&2
        return 1
    end

    set tmp_dir (make_tmp_dir)
    set old_file "$tmp_dir"/'old'
    set new_file "$tmp_dir"/"$file_name"

    brotli --decompress \
        --output="$old_file" \
        -- "$old_file_compressed"

    cp "$old_file" "$new_file"

    _update_file "$file_name" "$new_file"
    or begin
        echo "Error occurred during $file_name update" >&2
        return 1
    end

    if cmp --quiet "$old_file" "$new_file"
        echo "$file_name is already up-to-date" >&2
        return 1
    end

    set old_date (_get_file_date "$file_name" "$old_file")
    or begin
        echo "Cannot parse date from current $file_name file" >&2
        return 1
    end

    set new_date (_get_file_date "$file_name" "$new_file")
    or begin
        echo "Cannot parse date from updated $file_name file" >&2
        return 1
    end

    if test "$old_date" = "$new_date"
        echo "$file_name contents are different, yet files contain the same date" >&2
        return 1
    end

    # Ensure new date is greater than old date and not greater than today.
    begin
        set -l old_timestamp (date -d "$old_date" '+%s')
        set -l new_timestamp (date -d "$new_date" '+%s')
        set -l today_timestamp (date -d (date "+%Y-%m-%d") '+%s')
        if test $old_timestamp -gt $new_timestamp
            echo "Updated $file_name date '$new_date' is older than current file date '$old_date'" >&2
            return 1
        else if test $new_timestamp -gt $today_timestamp
            echo "Updated $file_name date '$new_date' is from the future" >&2
            return 1
        end
    end

    set patch_path "$tmp_dir"/'new.patch'

    diff --unified \
        --label "$old_date" \
        --label "$new_date" \
        "$old_file" "$new_file" >"$patch_path"

    begin
        set --local file_dir (get_file_dir "$file_name")
        set --local date_path (string split '-' "$new_date" | string join '/')
        set archived_patch_path "$file_dir"/patches/"$date_path".patch.br
    end

    mkdir -p (dirname "$archived_patch_path")

    echo "Compressing new patch to '$archived_patch_path'" >&2

    brotli --best \
        --output="$archived_patch_path" \
        -- "$patch_path"

    set cache_dir (get_cache_dir "$new_date")
    mkdir -p "$cache_dir"

    echo "Compressing updated $file_name to cache dir '$cache_dir'" >&2

    brotli -4 \
        --output="$cache_dir"/"$file_name".br \
        -- "$new_file"

    echo "Deleting old $file_name from cache" >&2

    rm "$old_file_compressed"

    # Remove the directory if it is now empty.
    begin
        set -l old_dir (dirname "$old_file_compressed")
        if test -z (ls -A "$old_dir")
            rm -d "$old_dir"
        end
    end

    echo "$archived_patch_path"
end

function main
    set file_name (argparse_file $argv); or return 1
    _make_new_patch "$file_name"
end

main $argv
