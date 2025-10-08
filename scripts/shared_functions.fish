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

function argparse_file
    argparse --ignore-unknown \
        'f/file=!string match -rq \'^JMdict|JMnedict.xml|kanjidic2.xml|examples.utf$\' "$_flag_value"' \
        -- $argv

    if set -q _flag_file
        echo "$_flag_file"
    else
        echo 'FILE must be one of JMdict JMnedict.xml kanjidic2.xml examples.utf' >&2
        _usage
        return 1
    end
end

function get_file_dir -a file_name
    set file_dir_name (string replace -a '.' '_' "$file_name")
    echo (dirname (status dirname))/"$file_dir_name"
end

function get_cache_dir -a file_date
    set cache_dir 'edrdg-dictionary-archive'
    if set -q XDG_CACHE_HOME
        echo "$XDG_CACHE_HOME"/"$cache_dir"/"$file_date"
    else
        echo "$HOME"/'.cache'/"$cache_dir"/"$file_date"
    end
end

function make_tmp_dir
    set tmp_dir '/tmp/edrdg-dictionary-archive-'(uuidgen | cut -c1-8)
    mkdir -p -m 700 "$tmp_dir"

    function tmp_dir_cleanup --inherit-variable tmp_dir --on-event fish_exit
        if test -d "$tmp_dir"
            rm -r "$tmp_dir"
        end
    end

    echo "$tmp_dir"
end
