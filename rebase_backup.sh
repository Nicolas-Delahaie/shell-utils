#!/bin/bash
# Bash is necessar for regex tables
BACKUP_BRANCH={1:-'backup'}
set -eu

BRANCH_REGEX="[a-zA-Z0-9._/-]+"
BRANCH_SEPARATOR_REGEX="'($BRANCH_REGEX)' into '($BRANCH_REGEX)'"
COMMIT_DESC=$(git log -1 --pretty=%B) 

# Extract branches from merge commit description
BRANCH_NOT_FOUND=0
if [[ $COMMIT_DESC =~ $BRANCH_SEPARATOR_REGEX ]]; then
    MERGED_BRANCH="${BASH_REMATCH[1]}"
    MERGE_DEST="${BASH_REMATCH[2]}"
    if [[ -z "$MERGED_BRANCH" ]]; then
        BRANCH_NOT_FOUND=1
    fi
    if [[ -z "$MERGE_DEST" ]]; then
        BRANCH_NOT_FOUND=1
    fi
else
    BRANCH_NOT_FOUND=1
fi

if [ $BRANCH_NOT_FOUND -eq 1 ]; then
    echo "Erreur : Impossible de trouver les branches dans le message de commit."
    echo "Format attendu : 'Merge branch '<merged_branch>' into '<merge_dest>''"
    exit 1
fi

# Check if branches exist
git show-ref --verify refs/heads/$MERGED_BRANCH >/dev/null;
git show-ref --verify refs/heads/$MERGE_DEST >/dev/null;
git show-ref --verify refs/heads/$BACKUP_BRANCH >/dev/null;

echo $BACKUP_BRANCH, 
echo $MERGED_BRANCH 
echo $MERGE_DEST
echo $COMMIT_DESC

exit 1

# Recherche auto du numero de merge request dans le commit de merge
MERGE_NUMBER=$($COMMIT_DESC | grep -oE '![0-9]+' | grep -oE '[0-9]+')
if [[ -z "$MERGE_NUMBER" ]]; then
    echo "Erreur : numero de merge request introuvable dans le commit."
    exit 1
fi

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
