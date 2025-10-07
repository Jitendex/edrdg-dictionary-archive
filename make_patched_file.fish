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

function _usage
    echo >&2
    echo "Usage: make_patched_file.fish" >&2
    echo "    -h | --help              " >&2
    echo "    -f | --file=FILE         " >&2
    echo "    -d | --date=YYYY-MM-DD   " >&2
    echo "    -l | --latest            " >&2
    echo >&2
end

function _argparse_help
    argparse -i h/help -- $argv

    if set -q _flag_help
        _usage
        return 1
    end
end

function _argparse_file
    argparse -i \
        'f/file=!string match -rq \'^JMdict|JMnedict.xml|kanjidic2.xml|examples.utf$\' "$_flag_value"' \
        -- $argv

    if set -q _flag_file
        echo $_flag_file
    else
        echo -e "\nFILE must be one of JMdict JMnedict.xml kanjidic2.xml examples.utf" >&2
        _usage
        return 1
    end
end

function _argparse_date
    argparse -i \
        'd/date=!string match -rq \'^[0-9]{4}-[0-1][0-9]-[0-3][0-9]$\' "$_flag_value"' \
        l/latest \
        -- $argv

    if set -q _flag_date
        echo "$_flag_date"
    else if not set -q _flag_latest
        echo -e "\nEither DATE or --latest flag must be specified" >&2
        _usage
        return 1
    end
end

function _get_file_dir -a file_name
    echo "$file_name" | tr '.' _
end

function _patchfile_to_date -a patchfile
    echo "$patchfile" | grep -Eo "[0-9]{4}/[0-9]{2}/[0-9]{2}" | tr / -
end

function _get_latest_date -a file_name
    set file_dir (_get_file_dir "$file_name")

    for patchfile in "$file_dir"/patches/**.patch.br
        set latest_patchfile "$patchfile"
    end

    if not set -q latest_patchfile
        echo -e "\nNo patches found in directory '$file_dir/patches/'\n" >&2
        return 1
    end

    set latest_date (_patchfile_to_date "$latest_patchfile")

    echo "$latest_date"
end

function _get_output_dir -a file_date
    set cache_dir "edrdg-dictionary-archive"
    if set -q XDG_CACHE_HOME
        echo "$XDG_CACHE_HOME"/"$cache_dir"/"$file_date"
    else
        echo "$HOME"/.cache/"$cache_dir"/"$file_date"
    end
end

function _get_zeroth_patchfile -a file_name final_patchfile tmp_dir
    set file_dir (_get_file_dir "$file_name")

    for patchfile in "$file_dir"/patches/**.patch.br
        set -l date (_patchfile_to_date "$patchfile")
        set -l output_dir (_get_output_dir "$date")
        set -l patched_file "$output_dir"/"$file_name".br

        if test -e "$patched_file"
            set zeroth_patchfile "$patchfile"
            set cached_patched_file "$patched_file"
        end

        if test "$patchfile" = "$final_patchfile"
            break
        end
    end

    if not set -q cached_patched_file
        set cached_patched_file "$file_dir"/"$file_name".br
        if not test -e "$cached_patched_file"
            echo -e "\nBase file '$cached_patched_file' is missing\n" >&2
            return 1
        end
    end

    if not set -q zeroth_patchfile; or test "$zeroth_patchfile" != "$final_patchfile"
        echo -e "Decompressing cached patched file '$cached_patched_file' to '$tmp_dir" >&2
        brotli --decompress "$cached_patched_file" \
            --output="$tmp_dir"/"$file_name"
    end

    if set -q zeroth_patchfile
        echo "$zeroth_patchfile"
    end
end

function _get_patchfile -a file_name file_date
    set file_dir (_get_file_dir "$file_name")
    set patchfile "$file_dir"/patches/(echo "$file_date" | tr '-' '/').patch.br

    if test -e "$patchfile"
        echo "$patchfile"
    else
        echo -e "\nNo patch exists for file '$file_name' date '$file_date'\n" >&2
        return 1
    end
end

function _make_tmp_dir
    set tmp_dir /tmp/(uuidgen)
    mkdir -p "$tmp_dir"
    echo "$tmp_dir"
end

function _make_patched_file -a file_name file_date
    set final_patchfile (
        _get_patchfile "$file_name" "$file_date"
        or return 1
    )

    set tmp_dir (_make_tmp_dir; or return 1)

    set zeroth_patchfile (
        _get_zeroth_patchfile "$file_name" "$final_patchfile" "$tmp_dir"
        or begin
            rm -r "$tmp_dir"
            return 1
        end
    )

    set output_dir (_get_output_dir "$file_date")
    set output_file "$output_dir"/"$file_name".br

    if test -z "$zeroth_patchfile"
        set begin_patching
    else if test "$zeroth_patchfile" = "$final_patchfile"
        echo "Patched $file_name already written for date $file_date" >&2
        rm -r "$tmp_dir"
        echo "$output_file"
        return 0
    end

    set file_dir (_get_file_dir "$file_name")

    for patchfile in "$file_dir"/patches/**.patch.br
        if set -q begin_patching
            # OK
        else if test "$patchfile" = "$zeroth_patchfile"
            set begin_patching
            continue
        else
            continue
        end

        brotli --force \
            --decompress "$patchfile" \
            --output="$tmp_dir"/next.patch

        set -l patch_date (_patchfile_to_date $patchfile)

        echo "Patching $file_name to version $patch_date" >&2

        patch --quiet \
            "$tmp_dir"/"$file_name" <"$tmp_dir"/next.patch

        if test "$patchfile" = "$final_patchfile"
            break
        end
    end

    mkdir -p "$output_dir"

    brotli -4f "$tmp_dir"/"$file_name" \
        --output="$output_file"

    rm -r "$tmp_dir"

    echo "$output_file"
end

function main
    _argparse_help $argv; or return 0

    set file_name (_argparse_file $argv; or return 1)
    set file_date (_argparse_date $argv; or return 1)

    if test -z "$file_date"
        set file_date (_get_latest_date "$file_name"; or return 1)
    end

    _make_patched_file "$file_name" "$file_date"; or return 1
end

main $argv
