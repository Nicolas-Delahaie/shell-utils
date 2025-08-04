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

if [ $BRANCH_NOT_FOUND -eq 1 ]; then
    echo "Erreur : Impossible de trouver les branches dans le message de commit."
    echo "Format attendu : 'Merge branch '<merged_branch>' into '<merge_dest>''"
    exit 1
fi

echo "Starting backup rebasing on current project \"$CURRENT_PROJECT_NAME\" of merge request number: $MERGE_NUMBER"

# Check if branches exist
git show-ref --verify refs/heads/$MERGED_BRANCH >/dev/null;
git show-ref --verify refs/heads/$MERGE_DEST >/dev/null;
git show-ref --verify refs/heads/$BACKUP_BRANCH >/dev/null;
exit 1;


git switch $MERGED_BRANCH
git rebase -X theirs $BACKUP_BRANCH --committer-date-is-author-date

read -p "Continue the rebase ? (o/n) " choice
if [[ "$choice" != "o" ]]; then
    echo "Rebase annulé."
    exit 0
fi
git add .
git rebase --continue
# Gerer la validation du fichier de messages de commit
git diff $MERGED_BRANCH $MERGE_DEST # Checker que le resultat sois vide
git branch -d $BACKUP_BRANCH
git branch -M $BACKUP_BRANCH
git branch --unset-upstream # Ameliorer cette partie de remplacement moche
git tag MR-$MERGE_NUMBER

read -p "Delete remote branch ? (o/n) " choice
if [[ "$choice" != "o" ]]; then
    echo "Suppression annulee."
    exit 0
fi
git push --delete origin $MERGED_BRANCH
