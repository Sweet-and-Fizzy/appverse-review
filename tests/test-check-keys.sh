#!/usr/bin/env bash
# Test check-keys.py: every defect_key is {anchor}:{tag} with a real or allowed anchor and a known tag.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CHECK="$SCRIPT_DIR/references/check-keys.py"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0
check() { local name="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then echo "  PASS  $name"; pass=$((pass+1)); else echo "  FAIL  $name: expected '$expected', got '$actual'"; fail=$((fail+1)); fi; }
run() { python3 "$CHECK" "$@" > "$TMP/out" 2>&1; echo $?; }
rec() { # rule defect_key
  printf '{"app_id":"root","rule":"%s","defect_key":"%s","aspect":"x","severity":"low","result":"WARN","summary":"s","evidence":"e"}' "$1" "$2"; }

# a fake target tree
mkdir -p "$TMP/t/template" "$TMP/t/.github/workflows"; touch "$TMP/t/form.yml" "$TMP/t/template/script.sh.erb" "$TMP/t/README.md"

echo "Test 1: valid keys pass (path anchors, pseudo-anchors, qualified tag, other: slug)"
printf '[%s,%s,%s,%s,%s]' "$(rec QUA-02 template/script.sh.erb:hardcoded-path)" "$(rec MNT-02 releases:no-releases)" "$(rec QUA-06 form.yml:duplicate-yaml-key:custom_num_cores.help)" "$(rec STR-01 LICENSE:missing-license)" "$(rec QUA-07 form.yml:other:unbounded-walltime)" > "$TMP/ok.json"
check "exit 0" 0 "$(run "$TMP/ok.json" --target "$TMP/t")"
check "summary" "finding keys: 5/5 valid" "$(tail -1 "$TMP/out")"

echo "Test 2: no colon"
printf '[%s]' "$(rec QUA-02 hardcoded-cluster)" > "$TMP/a.json"
check "exit 1" 1 "$(run "$TMP/a.json")"
check "reason" 1 "$(grep -c 'INVALID QUA-02 hardcoded-cluster (no anchor)' "$TMP/out")"

echo "Test 3: invented pseudo-anchor"
printf '[%s,%s]' "$(rec MNT-02 RELEASES:no-releases)" "$(rec MNT-01 github/commits:stale)" > "$TMP/b.json"
check "exit 1" 1 "$(run "$TMP/b.json" --target "$TMP/t")"
check "RELEASES rejected" 1 "$(grep -c 'INVALID MNT-02 RELEASES:no-releases (anchor is not a repo path or allowed pseudo-anchor)' "$TMP/out")"
check "github/commits rejected" 1 "$(grep -c 'INVALID MNT-01 github/commits:stale' "$TMP/out")"

echo "Test 4: path anchor that does not exist in the target"
printf '[%s]' "$(rec QUA-03 template/run.sh:no-set-e)" > "$TMP/c.json"
check "exit 1 with target" 1 "$(run "$TMP/c.json" --target "$TMP/t")"
check "exit 0 without target (format only)" 0 "$(run "$TMP/c.json")"

echo "Test 5: mangled anchor (not a path, not allowed)"
printf '[%s]' "$(rec OODT-01 script-sh-erb-eval:eval-exec)" > "$TMP/d.json"
check "exit 1" 1 "$(run "$TMP/d.json" --target "$TMP/t")"

echo "Test 6: tag not in the rule's vocabulary and not other:"
printf '[%s]' "$(rec QUA-07 form.yml:no-bounds)" > "$TMP/e.json"
check "exit 1" 1 "$(run "$TMP/e.json")"
check "reason" 1 "$(grep -c "INVALID QUA-07 form.yml:no-bounds (tag 'no-bounds' not in QUA-07 vocabulary; use other:<slug> for a novel defect)" "$TMP/out")"

echo "Test 7: qualified tag missing its qualifier"
printf '[%s]' "$(rec QUA-06 form.yml:duplicate-yaml-key)" > "$TMP/f.json"
check "exit 1" 1 "$(run "$TMP/f.json")"
check "reason" 1 "$(grep -c "INVALID QUA-06 form.yml:duplicate-yaml-key (tag 'duplicate-yaml-key' requires a qualifier)" "$TMP/out")"

echo "Test 8: other: slug that is a vocabulary tag in disguise"
printf '[%s]' "$(rec QUA-07 form.yml:other:missing_min_max)" > "$TMP/g.json"
check "exit 1" 1 "$(run "$TMP/g.json")"
check "reason" 1 "$(grep -c "INVALID QUA-07 form.yml:other:missing_min_max (other:missing_min_max is the vocabulary tag 'missing-min-max')" "$TMP/out")"

echo "Test 9: record without defect_key or rule"
printf '[{"app_id":"root","rule":"QUA-02","summary":"x"}]' > "$TMP/h.json"
check "exit 1" 1 "$(run "$TMP/h.json")"
check "reason" 1 "$(grep -c 'INVALID QUA-02 <missing> (no defect_key)' "$TMP/out")"

echo "Test 10: unreadable input is exit 2"
check "exit 2" 2 "$(run "$TMP/nope.json")"

echo; echo "Done: $pass passed, $fail failed."; [ "$fail" -eq 0 ]
