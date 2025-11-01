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

set THIS_SCRIPT_DIR (realpath (status dirname))
set LOCAL_REPO_DIR (dirname "$THIS_SCRIPT_DIR")
set COMMIT_MESSAGE (date '+%B %d %Y')
set REMOTE 'origin'
set BRANCH 'main'

function _get_git_config -a key
    git -C "$LOCAL_REPO_DIR" config --local "$key"
end

function _set_git_config -a key value
    git -C "$LOCAL_REPO_DIR" config --local "$key" "$value"
end

function _set_temporary_updater_git_config
    set name    (_get_git_config 'user.name')
    set email   (_get_git_config 'user.email')
    set gpgsign (_get_git_config 'commit.gpgsign')

    function _config_reset --on-event fish_exit -V name -V email -V gpgsign
        _set_git_config 'user.name'      "$name"
        _set_git_config 'user.email'     "$email"
        _set_git_config 'commit.gpgsign' "$gpgsign"
    end

    _set_git_config 'user.name'      'edrdg-dictionary-archive'
    _set_git_config 'user.email'     'edrdg-dictionary-archive@noreply.jitendex.org'
    _set_git_config 'commit.gpgsign' 'false'
end

function _git_add -a file_name
    set update_script "$THIS_SCRIPT_DIR"/'update_file.fish'
    if set new_patch (fish "$update_script" --file="$file_name")
        git -C "$LOCAL_REPO_DIR" add "$new_patch"
    end
end

function _git_list_added_files
    git -C "$LOCAL_REPO_DIR" diff --name-only --cached
end

function _added_files_are_valid
    set half_mebibyte (math 2 ^ 19)
    for added_file in (_git_list_added_files)
        set filepath "$LOCAL_REPO_DIR"/"$added_file"
        set filesize (stat -c %s -- "$filepath")
        if test $filesize -gt $half_mebibyte
            echo "New file '$added_file' is suspiciously large; manual intervention required." >&2
            return 1
        end
    end
end

function _git_commit_and_push
    if _added_files_are_valid
        _set_temporary_updater_git_config
        git -C "$LOCAL_REPO_DIR" commit -m "$COMMIT_MESSAGE"
        git -C "$LOCAL_REPO_DIR" push "$REMOTE" "$BRANCH"
    else
        return 1
    end
end

function main
    git pull "$REMOTE" "$BRANCH"
    git checkout "$BRANCH"

    set files 'JMdict' 'JMdict_e' 'JMdict_e_examp' 'JMnedict.xml' 'kanjidic2.xml' 'examples.utf'
    for file in $files
        _git_add $file
    end

    _git_commit_and_push
end

main
