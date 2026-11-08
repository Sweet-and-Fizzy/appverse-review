#!/usr/bin/env bash
# Test tree-digest.sh: the workflow's guard on pre-review/ and target-repo/ sees an edited, added, removed or
# renamed file and a new commit, and not a permission change, .git internals or a __pycache__ directory.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIGEST="$SCRIPT_DIR/references/tree-digest.sh"
TMP=$(mktemp -d); trap 'chmod -R u+w "$TMP"; rm -rf "$TMP"' EXIT
pass=0; fail=0
check() { local name="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then echo "  PASS  $name"; pass=$((pass+1)); else echo "  FAIL  $name: expected '$expected', got '$actual'"; fail=$((fail+1)); fi; }
d() { bash "$DIGEST" "$@"; }
same() { [ "$1" = "$2" ] && echo same || echo differs; }

echo "Test 1: a facts directory"
P="$TMP/pre"; mkdir -p "$P/app"; echo '[{"app_id":"app"}]' > "$P/apps.json"; echo '{"stub":false}' > "$P/app/readme.json"
A=$(d "$P")
check "64 hex characters" 64 "${#A}"
check "stable" same "$(same "$A" "$(d "$P")")"
echo '[{"app_id":"app","dir_missing":true}]' > "$P/apps.json"
check "an edited fact changes it" differs "$(same "$A" "$(d "$P")")"
echo '[{"app_id":"app"}]' > "$P/apps.json"
check "the same content again restores it" same "$(same "$A" "$(d "$P")")"
touch "$P/new.json"; check "an added file changes it" differs "$(same "$A" "$(d "$P")")"; rm "$P/new.json"
mv "$P/app/readme.json" "$P/app/readme2.json"; check "a renamed file changes it" differs "$(same "$A" "$(d "$P")")"
mv "$P/app/readme2.json" "$P/app/readme.json"
rm "$P/app/readme.json"; check "a removed file changes it" differs "$(same "$A" "$(d "$P")")"; echo '{"stub":false}' > "$P/app/readme.json"
chmod -R a-w "$P"; check "a permission change does not" same "$(same "$A" "$(d "$P")")"; chmod -R u+w "$P"
ln -s /nonexistent "$P/dangling"; check "a dangling link changes it" differs "$(same "$A" "$(d "$P")")"; rm "$P/dangling"
check "a missing directory" missing "$(d "$TMP/nope")"
mkdir "$TMP/empty"; check "an empty directory is a digest, not missing" 64 "$(d "$TMP/empty" | tr -d '\n' | wc -c | tr -d ' ')"

echo "Test 2: a git checkout with --git"
T="$TMP/target"; mkdir -p "$T"; git -C "$T" init -q; echo 'x' > "$T/README.md"; git -C "$T" add README.md
git -C "$T" -c user.email=t@t -c user.name=t commit -q -m one
B=$(d "$T" --git)
echo 'quoted evidence' >> "$T/README.md"; check "an edited target file changes it" differs "$(same "$B" "$(d "$T" --git)")"
git -C "$T" checkout -q README.md; check "restored" same "$(same "$B" "$(d "$T" --git)")"
touch "$T/.git/scratch"; check ".git internals do not" same "$(same "$B" "$(d "$T" --git)")"
mkdir -p "$T/src/__pycache__"; echo bytes > "$T/src/__pycache__/m.pyc"; check "a __pycache__ directory does not" same "$(same "$B" "$(d "$T" --git)")"
git -C "$T" -c user.email=t@t -c user.name=t commit -q --allow-empty -m two
check "a new commit changes it" differs "$(same "$B" "$(d "$T" --git)")"

echo; echo "Done: $pass passed, $fail failed."; [ "$fail" -eq 0 ]
