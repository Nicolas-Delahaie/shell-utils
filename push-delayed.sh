#!/bin/bash

# Push le prochain commit, en modifiant sa date a la prochaine journee

set -eu

# -g generate l'heure aleatoirement
random_generation=false

while getopts "g" opt; do
    case $opt in
        g)
            random_generation=true
            echo "Random date generation enabled."
            ;;
    esac
done

git switch -qc tmp-delay origin/main 
target_commit=$(git log ..main --reverse --format="%H" | head -1)
git merge $target_commit --ff-only -q

previous_commit_date=$(git log -2 --pretty=format:"%cd" --date=iso | tail -1)
next_day=$(date -d "$previous_commit_date + 1 day" +"%Y-%m-%d")

# Date edition
if $random_generation; then
    if ((RANDOM % 2 == 0)); then
        base_time="$next_day 00:00:00"
        max_seconds=$((2 * 3600))
    else
        base_time="$next_day 18:00:00"
        max_seconds=$((6 * 3600))
    fi
    random_seconds=$((RANDOM % max_seconds))
    D=$(date -d "$base_time $random_seconds seconds" --iso-8601=seconds)
else
    current_commit_date=$(git log -1 --pretty=format:"%ad" --date=iso)
    time=$(date -d "$current_commit_date" +%H:%M:%S)
    D=$(date -d "$next_day $time" --iso-8601=seconds)
fi
GIT_COMMITTER_DATE="$D" git commit --amend --no-edit --date="$D" > /dev/null
echo "New commit date : $D"

git switch main -q
git -c advice.skippedCherryPicks=false rebase tmp-delay -q
git push origin tmp-delay:main -q
git branch -qd tmp-delay

echo "Pushed delayed commit to remote main successfully"