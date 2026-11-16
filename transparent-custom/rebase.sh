#!/usr/bin/env bash
# The source to build: this branch's own commits (those after the Zed release tag it sits on),
# cherry-picked onto the requested Zed release tag. A conflict stops the build; the branch then needs rebasing by hand.
#
#   transparent-custom/rebase.sh <zed tag> <fork url> <branch commit> <dir>
#
# Prints one Markdown line per applied commit, for the release notes.
set -euo pipefail
tag=$1 fork=$2 head=$3 dir=$4

# Commits and tags without their trees; checkout and cherry-pick fetch the trees they need.
git clone -q --filter=tree:0 --no-checkout https://github.com/zed-industries/zed "$dir"
cd "$dir"
git fetch -q "$fork" "$head"
base=$(git describe --tags --abbrev=0 --match 'v[0-9]*' --exclude '*-pre' "$head")
git -c advice.detachedHead=false checkout -q "refs/tags/$tag"
export GIT_AUTHOR_NAME=zed-transparent-custom GIT_AUTHOR_EMAIL=ci@invalid
export GIT_COMMITTER_NAME=zed-transparent-custom GIT_COMMITTER_EMAIL=ci@invalid

for commit in $(git rev-list --reverse "$base..$head"); do
  if ! git cherry-pick --allow-empty -x "$commit" >/dev/null; then
    git cherry-pick --abort || true
    echo "::error::$(git log -1 --format='%h %s' "$commit") doesn't apply to $tag; rebase zed-transparent-custom onto $tag and push it" >&2
    exit 1
  fi
  echo "- $(git log -1 --format='%h %s' "$commit") (from $base)"
done
