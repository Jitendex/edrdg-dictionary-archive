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

source (status dirname)/"github_bot_config.fish"

function _git_config_gpgsign -a value
    git -C "$LOCAL_REPO_DIR" config --local commit.gpgsign "$value"
end

function _git_add -a file_name
    set update_script (status dirname)/"update_file.fish"
    if set new_patch (fish "$update_script" --file="$file_name")
        git -C "$LOCAL_REPO_DIR" add "$new_patch"
    end
end

function _git_commit_and_push
    for filename in (git -C "$LOCAL_REPO_DIR" diff --name-only --cached)
        set -l filepath "$LOCAL_REPO_DIR"/"$filename"
        set -l filesize (stat -c %s -- "$filepath")
        set -l megabyte (math 2 ^ 20)
        if test $filesize -gt $megabyte
            echo "New file '$filename' is suspiciously large; manual intervention required." >&2
            return 1
        end
    end

    git -C "$LOCAL_REPO_DIR" commit -m "$COMMIT_MESSAGE"
    git -C "$LOCAL_REPO_DIR" push "$REMOTE" "$BRANCH"
end

function main
    set files JMdict "JMnedict.xml" "kanjidic2.xml" "examples.utf"

    for file in $files
        _git_add $file
    end

    _git_config_gpgsign false
    _git_commit_and_push
    _git_config_gpgsign true
end

main