#!/usr/bin/env bash
# Test stamp-meta.py and check-meta.py: the run facts are stamped into meta.json, and an incomplete meta.json fails.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
STAMP="$SCRIPT_DIR/references/stamp-meta.py"; CHK="$SCRIPT_DIR/references/check-meta.py"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0
check() { local name="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then echo "  PASS  $name"; pass=$((pass+1)); else echo "  FAIL  $name: expected '$expected', got '$actual'"; fail=$((fail+1)); fi; }
j() { python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(eval(sys.argv[2]))' "$1" "$2" 2>&1; }
stamp() { python3 "$STAMP" "$@" > "$TMP/out" 2>&1; echo $?; }
chk() { python3 "$CHK" "$@" > "$TMP/out" 2>&1; echo $?; }

T="$TMP/target"; mkdir -p "$T"; git -C "$T" init -q -b appverse; echo x > "$T/f"; git -C "$T" add f
git -C "$T" -c user.email=t@t -c user.name=t commit -q -m one; SHA=$(git -C "$T" rev-parse HEAD)
GOOD='{"recommendation":{"decision":"Accept with suggestions","note":"Fine."},"not_archived":"pass","public":"pass","apps":[{"app_id":"root"}],"repo_shape":"declared_single"}'

echo "Test 1: a meta.json the model got wrong is stamped with the run's facts"
printf '{"apps":[{"app_id":"root"}],"maintenance_assessment":{},"run_meta":{}}' > "$TMP/m1.json"
check "exit 0" 0 "$(stamp "$TMP/m1.json" "$T" "Org/Repo" "claude-sonnet-4-6")"
check "sha" "$SHA" "$(j "$TMP/m1.json" "d['sha']")"
check "ref is the branch" "appverse" "$(j "$TMP/m1.json" "d['ref']")"
check "repo_url" "https://github.com/Org/Repo" "$(j "$TMP/m1.json" "d['repo_url']")"
check "model" "claude-sonnet-4-6" "$(j "$TMP/m1.json" "d['model']")"
check "missing shape filled from the target" "inferred_single" "$(j "$TMP/m1.json" "d['repo_shape']")"
check "other fields kept" "True" "$(j "$TMP/m1.json" "'maintenance_assessment' in d")"

echo "Test 2: wrong values are overwritten; a valid shape is kept; detached HEAD gives the sha as ref"
git -C "$T" checkout -q --detach
printf '{"sha":"deadbeef","repo_url":"x","model":"Claude","repo_shape":"declared_monorepo"}' > "$TMP/m2.json"
stamp "$TMP/m2.json" "$T" "Org/Repo" "m" >/dev/null
check "sha overwritten" "$SHA" "$(j "$TMP/m2.json" "d['sha']")"
check "ref is the sha" "$SHA" "$(j "$TMP/m2.json" "d['ref']")"
check "valid shape kept" "declared_monorepo" "$(j "$TMP/m2.json" "d['repo_shape']")"
printf 'apps:\n  - path: a\n' > "$T/appverse.yml"; printf '{"repo_shape":"Single"}' > "$TMP/m2b.json"
stamp "$TMP/m2b.json" "$T" "Org/Repo" "m" >/dev/null
check "invalid shape replaced from the target" "declared_monorepo" "$(j "$TMP/m2b.json" "d['repo_shape']")"

echo "Test 3: an unreadable or non-object meta.json is not stamped"
printf 'not json' > "$TMP/m3.json"; check "bad JSON: exit 1" 1 "$(stamp "$TMP/m3.json" "$T" "Org/Repo" "m")"
printf '[]' > "$TMP/m3b.json"; check "a list: exit 1" 1 "$(stamp "$TMP/m3b.json" "$T" "Org/Repo" "m")"
check "missing file: exit 1" 1 "$(stamp "$TMP/none.json" "$T" "Org/Repo" "m")"
check "bad arguments: exit 2" 2 "$(stamp "$TMP/m1.json")"

echo "Test 4: check-meta passes a complete, stamped meta.json"
printf '%s' "$GOOD" > "$TMP/c1.json"; stamp "$TMP/c1.json" "$T" "Org/Repo" "m" >/dev/null
check "exit 0" 0 "$(chk "$TMP/c1.json")"
check "summary" "meta: complete" "$(tail -1 "$TMP/out")"

echo "Test 5: check-meta fails the portal run's meta.json (no recommendation, gates or sha)"
printf '{"apps":[{"app_id":"root"}],"run_meta":{}}' > "$TMP/c2.json"
check "exit 1" 1 "$(chk "$TMP/c2.json")"
check "names the recommendation" 1 "$(grep -c '^MISSING meta field: recommendation (an object' "$TMP/out")"
check "names the gates" 2 "$(grep -c '^MISSING meta field: \(not_archived\|public\)' "$TMP/out")"
check "names the sha" 1 "$(grep -c '^MISSING meta field: sha' "$TMP/out")"

echo "Test 6: check-meta field rules"
python3 -c "import json,sys; d=json.loads(sys.argv[1]); d.update(sha='a',repo_url='u'); d['recommendation']['decision']='Approve'; json.dump(d,open(sys.argv[2],'w'))" "$GOOD" "$TMP/c3.json"
check "an unknown decision: exit 1" 1 "$(chk "$TMP/c3.json")"
check "names it" 1 "$(grep -c "INVALID meta field: recommendation.decision 'Approve'" "$TMP/out")"
python3 -c "import json,sys; d=json.loads(sys.argv[1]); d.update(sha='a',repo_url='u',public='NOT CHECKED'); d['recommendation']['note']=' '; json.dump(d,open(sys.argv[2],'w'))" "$GOOD" "$TMP/c4.json"
check "a blank note: exit 1" 1 "$(chk "$TMP/c4.json")"
check "NOT CHECKED is an accepted gate value" 0 "$(grep -c 'public' "$TMP/out")"
python3 -c "import json,sys; d=json.loads(sys.argv[1]); d.update(sha='a',repo_url='u',apps=[{'name':'x'}]); json.dump(d,open(sys.argv[2],'w'))" "$GOOD" "$TMP/c5.json"
check "an app without app_id: exit 1" 1 "$(chk "$TMP/c5.json")"
check "unreadable: exit 2" 2 "$(chk "$TMP/none.json")"
printf '[]' > "$TMP/c6.json"; check "not an object: exit 2" 2 "$(chk "$TMP/c6.json")"

echo; echo "Done: $pass passed, $fail failed."; [ "$fail" -eq 0 ]
