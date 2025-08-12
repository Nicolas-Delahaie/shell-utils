#!/bin/bash
set -eu

# ---------------------------------------------------------------------------- #
#                                   CONSTANTS                                  #
# ---------------------------------------------------------------------------- #
BACKUP_BRANCH='backup'
BRANCH_REGEX="[a-zA-Z0-9._/-]+"
BRANCH_SEPARATOR_REGEX=".*'($BRANCH_REGEX)' into '$BRANCH_REGEX'.*"
EXPECTED_MERGE_COMMIT="   Merge branch '<MERGED_BRANCH>' into '<MERGE_DEST>'

   <Message>

   See merge request <merge_request_name>"

# ---------------------------------------------------------------------------- #
#                                    CHECKS                                    #
# ---------------------------------------------------------------------------- #
INITIAL_COMMIT=$(git rev-parse HEAD)
MERGE_DEST=${1:-$INITIAL_COMMIT}
PROJECT_PATH=$(git rev-parse --show-toplevel)
CURRENT_PROJECT_NAME=$(basename $PROJECT_PATH)

# Checking out the merge destination commit
if [[ "$MERGE_DEST" != "$INITIAL_COMMIT" ]]; then
    echo "Switching to merge destination commit."
    git checkout -q $MERGE_DEST
else
    echo "Using current HEAD as merge destination commit."
fi
COMMIT_DESC=$(git log -1 --pretty=%B) 

# TODO check the merge dest of the commit is the real merge dest 

# Check if branches exist
git cat-file -e $MERGE_DEST >/dev/null || {
    echo "Error: merge destination commit '$MERGE_DEST' does not exist."
    exit 1
}

# Extract destination branch from merge commit description
function branch_not_found() {
    msg="Error :"
    if [[ -z "${1:-}" ]]; then
        msg+=" No branch found"
    else
        msg+=" $1 not found"
    fi
    msg+=" in message of target commit ($(git rev-parse HEAD))"
    echo $msg
    echo "Are you checked out at the merge commit ? "
    echo "Expected format : "
    echo "$EXPECTED_MERGE_COMMIT"
    exit 1
}
if [[ $COMMIT_DESC =~ $BRANCH_SEPARATOR_REGEX ]]; then
    MERGED_BRANCH="${BASH_REMATCH[1]}"
    if [[ -z "MERGED_BRANCH" ]]; then
        branch_not_found "merged branch"
    fi
else
    branch_not_found
fi

# Check if branches exist
git show-ref --verify refs/heads/$BACKUP_BRANCH >/dev/null;
git show-ref --verify refs/heads/$MERGED_BRANCH &>/dev/null || {
    git show-ref --verify refs/remotes/origin/$MERGED_BRANCH >/dev/null
    # Creates local branch from remote
    git branch $MERGED_BRANCH origin/$MERGED_BRANCH
}

# Automatically search for the merge request number in the merge commit
MERGE_NUMBER=$(echo "$COMMIT_DESC" | grep -oE '![0-9]+' | grep -oE '[0-9]+')
if [[ -z "$MERGE_NUMBER" ]]; then
    echo "Error : merge number not found in commit message."
    exit 1
fi

# ---------------------------------------------------------------------------- #
#                                   EXECUTION                                  #
# ---------------------------------------------------------------------------- #
echo "Starting backup rebasing on current project \"$CURRENT_PROJECT_NAME\" of MR $MERGE_NUMBER..."

# Starting merge backup
echo "Switching to branch $MERGED_BRANCH"...
git switch -q $MERGED_BRANCH

echo "Starting rebase of '$BACKUP_BRANCH' branch into '$MERGED_BRANCH' branch..."
git rebase -X theirs $BACKUP_BRANCH --committer-date-is-author-date &>/dev/null || {
    while true; do 
        git add .
        GIT_EDITOR=true git rebase --continue &>/dev/null && break
    done
}

# Creating delta commit
echo "Creating delta commit between merge destination and merged branch..."
git diff $MERGED_BRANCH $MERGE_DEST | git apply --whitespace=nowarn >/dev/null && {
    git add .
    COMMIT_DATE=$(git log -1 --format=%cI $MERGE_DEST)
    GIT_AUTHOR_DATE="$COMMIT_DATE" GIT_COMMITTER_DATE="$COMMIT_DATE" git commit -m "Delta from merge destination and $MERGED_BRANCH after rebase" >/dev/null
}

echo "Renaming merged branch into backup..."
git branch -Dq $BACKUP_BRANCH
git branch -M $BACKUP_BRANCH
git branch --unset-upstream 
git tag MR-$MERGE_NUMBER

read -n 1 -p "Delete remote branch ? (y/n) " choice
echo
if [[ "$choice" = "y" ]]; then
    echo "Suppression en cours..."
    git push --delete origin $MERGED_BRANCH
fi

git checkout -q $INITIAL_COMMIT

echo "Backup completed successfully."
