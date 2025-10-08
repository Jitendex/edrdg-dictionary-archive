set LOCAL_REPO_DIR (dirname (status dirname))
set COMMIT_MESSAGE (date "+%B %d %Y")
set GITHUB_USERNAME stephenmk
set GITHUB_PAT (cat (status dirname)/"github_pat.txt")
set REPO_NAME edrdg-dictionary-archive
set REMOTE "https://$GITHUB_USERNAME:$GITHUB_PAT@github.com/$GITHUB_USERNAME/$REPO_NAME.git"
set BRANCH main