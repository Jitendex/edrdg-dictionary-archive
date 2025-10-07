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

function _rsync_file -a file_name file_path
    rsync "ftp.edrdg.org::nihongo"/"$file_name" "$file_path"
end

function _argparse_file
    argparse -i \
        'f/file=!string match -rq \'^JMdict|JMnedict.xml|kanjidic2.xml|examples.utf$\' "$_flag_value"' \
        -- $argv

    if set -q _flag_file
        echo $_flag_file
    else
        echo -e "\nFILE must be one of JMdict JMnedict.xml kanjidic2.xml examples.utf" >&2
        return 1
    end
end

function _make_tmp_dir
    set tmp_dir /tmp/(uuidgen)
    mkdir -p "$tmp_dir"
    echo "$tmp_dir"
end

function _get_file_dir -a file_name
    echo "$file_name" | tr '.' _
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

function _get_old_file_archive -a file_name
    fish "make_patched_file.fish" --latest --file="$file_name"
end

function _make_new_patch -a file_name
    set file_dir (_get_file_dir "$file_name")

    set old_archive (_get_old_file_archive "$file_name")

    set tmp_dir (_make_tmp_dir)
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
        echo "$file_name is different, yet contains the same date" >&2
        rm -r "$tmp_dir"
        return
    end

    diff -u \
        --label "$old_date" \
        --label "$new_date" \
        "$old_file" "$new_file" >"$tmp_dir"/"new.patch"

    set patch_dir "$file_dir"/patches/(string split "-" "$new_date" | head -n 2 | string join "/")
    set patch_filename (string split "-" "$new_date" | tail -n 1).patch.br
    set new_patch_path = "$patch_dir"/"$patch_filename"

    mkdir -p "$patch_dir"

    echo "Writing new patch to '$new_patch_path'" >&2

    brotli -Z "$tmp_dir"/"new.patch" \
        --output="$new_patch_path"

    rm -r "$tmp_dir"

    echo "$new_patch_path"
end

function main
    set file_name (_argparse_file $argv; or return 1)
    _make_new_patch "$file_name"
end

main $argv
