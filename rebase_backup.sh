#!/bin/bash
# Before executing this script, ensure you are at the merge commit.
# It is recommended to checkout local master to the version of the merge you want to backup.
set -eu

# At first, going to the project path for every "git" calls
PROJECT_PATH=$(git rev-parse --show-toplevel)
CURRENT_PROJECT_NAME=$(basename $PROJECT_PATH)
BACKUP_BRANCH='backup'
BRANCH_REGEX="[a-zA-Z0-9._/-]+"
BRANCH_SEPARATOR_REGEX=".*'($BRANCH_REGEX)' into '($BRANCH_REGEX)'.*"
COMMIT_DESC=$(git log -1 --pretty=%B) 
EXPECTED_MERGE_COMMIT="   Merge branch '<merged_branch>' into '<merge_dest>'

   <Message>

   See merge request <merge_request_name>"

# Extract branches from merge commit description
function branch_not_found() {
    MSG="Error :"
    if [[ -z "${1:-}" ]]; then
        MSG+=" No branch found"
    else
        MSG+=" Branch '$1' not found"
    fi
    MSG+=" in message of current commit ($(git rev-parse HEAD))"
    echo $MSG
    echo "Are you checked out at the merge commit ? "
    echo "Expected format : "
    echo "$EXPECTED_MERGE_COMMIT"
    exit 1
}
if [[ $COMMIT_DESC =~ $BRANCH_SEPARATOR_REGEX ]]; then
    MERGED_BRANCH="${BASH_REMATCH[1]}"
    MERGE_DEST="${BASH_REMATCH[2]}"
    if [[ -z "$MERGED_BRANCH" ]]; then
        branch_not_found "$MERGED_BRANCH"
    fi
    if [[ -z "$MERGE_DEST" ]]; then
        branch_not_found "$MERGE_DEST"
    fi
else
    branch_not_found
fi

# Automatically search for the merge request number in the merge commit
MERGE_NUMBER=$(echo "$COMMIT_DESC" | grep -oE '![0-9]+' | grep -oE '[0-9]+')
if [[ -z "$MERGE_NUMBER" ]]; then
    echo "Error : merge number not found in commit message."
    exit 1
fi

echo "Starting backup rebasing on current project \"$CURRENT_PROJECT_NAME\" of merge request number: $MERGE_NUMBER"

# Check if branches exist
git show-ref --verify refs/heads/$MERGED_BRANCH >/dev/null;
git show-ref --verify refs/heads/$MERGE_DEST >/dev/null;
git show-ref --verify refs/heads/$BACKUP_BRANCH >/dev/null;

# Starting merge backup
echo "Switching to branch $MERGED_BRANCH"
git switch -q $MERGED_BRANCH

echo "Starting rebase of '$BACKUP_BRANCH' branch into '$MERGED_BRANCH' branch."
git rebase -X theirs $BACKUP_BRANCH --committer-date-is-author-date &>/dev/null || {
    while true; do 
        git add .
        GIT_EDITOR=true git rebase --continue &>/dev/null && break
    done
}

# Creating delta commit
git diff $MERGED_BRANCH $MERGE_DEST | git apply --whitespace=nowarn >/dev/null && {
    git add .
    COMMIT_DATE=$(git log -1 --format=%cI $MERGE_DEST)
    GIT_AUTHOR_DATE="$COMMIT_DATE" GIT_COMMITTER_DATE="$COMMIT_DATE" git commit -m "Delta from $MERGE_DEST and $MERGED_BRANCH after rebase"
}

git branch -d $BACKUP_BRANCH
git branch -M $BACKUP_BRANCH
git branch --unset-upstream 
git tag MR-$MERGE_NUMBER

read -n 1 -p "Delete remote branch ? (y/n) " choice
if [[ "$choice" = "y" ]]; then
    echo "Suppression annulee."
    git push --delete origin $MERGED_BRANCH
fi

git switch $MERGE_DEST

echo "Backup completed successfully."
