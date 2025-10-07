#!/usr/bin/env fish

######################################################################
#
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
#
######################################################################

source "shared_functions.fish"

function _usage
    echo >&2
    echo "Usage: make_new_patch.fish" >&2
    echo "    -f | --file=FILE      " >&2
    echo >&2
end

function _get_old_file_archive -a file_name
    fish "make_patched_file.fish" --latest --file="$file_name"
end

function _rsync_file -a file_name file_path
    rsync "ftp.edrdg.org::nihongo"/"$file_name" "$file_path"
end

function _get_file_date -a file_name file_path
    set date_pattern "[0-9]{4}-[0-9]{2}-[0-9]{2}"
    switch "$file_name"
        case JMdict
            grep "^<!-- JMdict created:" "$file_path" | grep -Eo "$date_pattern"
        case "JMnedict.xml"
            grep "^<!-- JMnedict created:" "$file_path" | grep -Eo "$date_pattern"
        case "kanjidic2.xml"
            grep "^<date_of_creation>" "$file_path" | grep -Eo "$date_pattern"
        case "examples.utf"
            date "+%Y-%m-%d"
    end
end

function _make_new_patch -a file_name
    set old_archive (_get_old_file_archive "$file_name")
    set tmp_dir (make_tmp_dir)
    set old_file "$tmp_dir"/"old"
    set new_file "$tmp_dir"/"$file_name"

    brotli --decompress "$old_archive" \
        --output="$old_file"

    cp "$old_file" "$new_file"
    _rsync_file "$file_name" "$new_file"

    if cmp --quiet "$old_file" "$new_file"
        echo "$file_name is already up-to-date" >&2
        rm -r "$tmp_dir"
        return
    end

    set old_date (_get_file_date "$file_name" "$old_file")
    set new_date (_get_file_date "$file_name" "$new_file")

    if test "$old_date" = "$new_date"
        echo "$file_name contents are different, yet files contain the same date" >&2
        rm -r "$tmp_dir"
        return
    end

    set temporary_patch "$tmp_dir"/"new.patch"

    diff -u \
        --label "$old_date" \
        --label "$new_date" \
        "$old_file" "$new_file" >"$temporary_patch"

    set file_dir (get_file_dir "$file_name")
    set new_patch_path "$file_dir"/patches/(string split "-" "$new_date" | string join "/").patch.br
    set patch_dir (dirname "$new_patch_path")

    mkdir -p "$patch_dir"

    echo "Writing new patch to '$new_patch_path'" >&2

    brotli -Z "$temporary_patch" \
        --output="$new_patch_path"

    set cache_dir (get_cache_dir "$new_date")
    mkdir -p cache_dir

    echo "Archiving updated $file_name to '$cache_dir'" >&2

    brotli -4 "$new_file" \
        --output="$cache_dir"/"$file_name"

    echo "Deleting old $file_name from cache" >&2

    rm "$old_archive"
    rm -r "$tmp_dir"

    echo "$new_patch_path"
end

function main
    set file_name (argparse_file $argv; or return 1)
    _make_new_patch "$file_name"
end

main $argv
