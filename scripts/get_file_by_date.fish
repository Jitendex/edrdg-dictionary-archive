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
    echo 'Usage: get_file_by_date.fish' >&2
    echo '    -h | --help             ' >&2
    echo '    -f | --file=FILE        ' >&2
    echo '    -d | --date=YYYY-MM-DD  ' >&2
    echo '    -l | --latest           ' >&2
    echo >&2
end

function _argparse_help
    argparse --ignore-unknown \
        'h/help' \
        -- $argv

    if set -q _flag_help
        _usage
        return 1
    end
end

function _argparse_date
    argparse --ignore-unknown \
        'd/date=!string match -rq \'^[0-9]{4}-[0-1][0-9]-[0-3][0-9]$\' "$_flag_value"' \
        'l/latest' \
        -- $argv

    if set -q _flag_date
        echo "$_flag_date"
    else if not set -q _flag_latest
        echo 'Either DATE or --latest flag must be specified' >&2
        _usage
        return 1
    end
end

function _patchfile_to_date -a patchfile
    string match --regex --groups-only \
        '(\d{4}/\d{2}/\d{2}).patch.br$' "$patchfile" | tr '/' '-'
end

function _get_latest_date -a file_name
    set file_dir (get_file_dir "$file_name")

    for patchfile in "$file_dir"/patches/**.patch.br
        set latest_patchfile "$patchfile"
    end

    if not set -q latest_patchfile
        echo "No patches found in directory '$file_dir/patches/'" >&2
        return 1
    end

    set latest_date (_patchfile_to_date "$latest_patchfile")

    echo "$latest_date"
end

function _get_zeroth_patchfile -a file_name final_patchfile tmp_dir
    set file_dir (get_file_dir "$file_name")

    for patchfile in "$file_dir"/patches/**.patch.br
        set --local patchfile_date (_patchfile_to_date "$patchfile")
        set --local cache_dir (get_cache_dir "$patchfile_date")
        set --local cached_file "$cache_dir"/"$file_name".br

        if test -e "$cached_file"
            set zeroth_patchfile "$patchfile"
            set zeroth_file "$cached_file"
        end

        if test "$patchfile" = "$final_patchfile"
            break
        end
    end

    if set -q zeroth_patchfile; and test "$zeroth_patchfile" = "$final_patchfile"
        set --local file_date (_patchfile_to_date "$zeroth_patchfile")
        echo "Patched $file_name already exists in cache for date $file_date" >&2
        return 1
    end

    if not set -q zeroth_file
        set zeroth_file "$file_dir"/"$file_name".br
        if not test -e "$zeroth_file"
            echo "Base file '$zeroth_file' is missing" >&2
            return 1
        end
    end

    echo "Decompressing cached file '$zeroth_file' to '$tmp_dir'" >&2

    brotli --decompress \
        --output="$tmp_dir"/"$file_name" \
        -- "$zeroth_file"

    if set -q zeroth_patchfile
        echo "$zeroth_patchfile"
    end
end

function _get_existing_patchfile -a file_name file_date
    set file_dir (get_file_dir "$file_name")
    set patch_path (string replace -a '-' '/' "$file_date")
    set patchfile "$file_dir"/patches/"$patch_path".patch.br

    if test -e "$patchfile"
        echo "$patchfile"
    else
        echo "No patch exists for file '$file_name' date '$file_date'" >&2
        return 1
    end
end

function _make_patched_file -a file_name file_date
    set output_dir (get_cache_dir "$file_date")
    set output_file "$output_dir"/"$file_name".br

    # Exit quickly if cached file already exists.
    if test -e "$output_file"
        echo "$output_file"
        return 0
    end

    set final_patchfile (_get_existing_patchfile "$file_name" "$file_date")
    or return 1

    set tmp_dir (make_tmp_dir)
    or return 1

    set zeroth_patchfile (_get_zeroth_patchfile "$file_name" "$final_patchfile" "$tmp_dir")
    or return 1

    if test -z "$zeroth_patchfile"
        set begin_patching
    end

    for patchfile in (get_file_dir "$file_name")/patches/**.patch.br
        if not set -q begin_patching
            if test "$patchfile" = "$zeroth_patchfile"
                set begin_patching
            end
            continue
        end

        set -l decompressed_patchfile "$tmp_dir"/'next.patch'

        brotli --decompress --force \
            --output="$decompressed_patchfile" \
            -- "$patchfile"

        set -l patch_date (_patchfile_to_date $patchfile)
        echo "Patching $file_name to version $patch_date" >&2

        patch --quiet \
            "$tmp_dir"/"$file_name" <"$decompressed_patchfile"

        if test "$patchfile" = "$final_patchfile"
            break
        end
    end

    mkdir -p "$output_dir"

    brotli -4 \
        --output="$output_file" \
        -- "$tmp_dir"/"$file_name"

    echo "$output_file"
end

function main
    _argparse_help $argv
    or return 0

    set file_name (argparse_file $argv)
    or return 1

    set file_date (_argparse_date $argv)
    or return 1

    if test -z "$file_date"
        set file_date (_get_latest_date "$file_name")
        or return 1
    end

    _make_patched_file "$file_name" "$file_date"
end

main $argv
