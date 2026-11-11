#!/usr/bin/env bash
# Print a sha256 over a directory's files, for the workflow's guard on the
# inputs the checkers trust (pre-review/ and target-repo/).
#
#   bash references/tree-digest.sh <dir> [--git]
#
# The digest covers the sorted list of every non-directory path under <dir>
# and each one's content (sha256sum follows a symlink to its target), so an
# edited, added, removed or renamed file changes it, and so does a link that
# does not resolve, since its path is in the list; a permission change does
# not. With --git, .git is left out and the HEAD commit is added, so a new
# commit changes it too; so are __pycache__ directories, which a session
# that byte-compiles a target script to check its syntax creates and no
# checker reads. Prints "missing" when <dir> is not a readable directory.
set -u
cd "$1" 2>/dev/null || { echo missing; exit 0; }
git_mode="${2:-}"
paths() {
  if [ "$git_mode" = "--git" ]; then
    find . \( -path ./.git -o -name __pycache__ \) -prune -o ! -type d -print0
  else
    find . ! -type d -print0
  fi | sort -z
}
{
  [ "$git_mode" = "--git" ] && echo "HEAD $(git rev-parse HEAD 2>/dev/null || echo none)"
  paths | tr '\0' '\n'
  paths | xargs -0 -r sha256sum 2>/dev/null
} | sha256sum | cut -c1-64
