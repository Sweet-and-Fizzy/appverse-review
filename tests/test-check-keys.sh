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
mkdir -p "$TMP/t/template" "$TMP/t/.github/workflows"; touch "$TMP/t/form.yml" "$TMP/t/template/script.sh.erb" "$TMP/t/README.md" "$TMP/t/manifest.yml"

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

echo "Test 11: STR-02's qualifier requirement is sticky across the base tag and its bracketed examples"
printf '[%s]' "$(rec STR-02 manifest.yml:missing-field)" > "$TMP/i.json"
check "exit 1" 1 "$(run "$TMP/i.json")"
check "reason" 1 "$(grep -c "INVALID STR-02 manifest.yml:missing-field (tag 'missing-field' requires a qualifier)" "$TMP/out")"
printf '[%s]' "$(rec STR-02 manifest.yml:missing-field:software)" > "$TMP/j.json"
check "exit 0" 0 "$(run "$TMP/j.json")"
check "summary" "finding keys: 1/1 valid" "$(tail -1 "$TMP/out")"

echo "Test 12: absolute and traversal anchors are rejected, not checked against the real filesystem"
printf '[%s]' "$(rec QUA-02 /etc/passwd:hardcoded-path)" > "$TMP/k.json"
check "exit 1 with target" 1 "$(run "$TMP/k.json" --target "$TMP/t")"
check "reason with target" 1 "$(grep -c "INVALID QUA-02 /etc/passwd:hardcoded-path (anchor must be a repo-relative path)" "$TMP/out")"
check "exit 1 without target" 1 "$(run "$TMP/k.json")"
check "reason without target" 1 "$(grep -c "INVALID QUA-02 /etc/passwd:hardcoded-path (anchor must be a repo-relative path)" "$TMP/out")"
printf '[%s]' "$(rec QUA-02 ../form.yml:hardcoded-path)" > "$TMP/l.json"
check "exit 1 traversal with target" 1 "$(run "$TMP/l.json" --target "$TMP/t")"
check "reason traversal with target" 1 "$(grep -c "INVALID QUA-02 \.\./form.yml:hardcoded-path (anchor must be a repo-relative path)" "$TMP/out")"
check "exit 1 traversal without target" 1 "$(run "$TMP/l.json")"

recapp() { # app_id rule defect_key
  printf '{"app_id":"%s","rule":"%s","defect_key":"%s","aspect":"x","severity":"low","result":"WARN","summary":"s","evidence":"e"}' "$1" "$2" "$3"; }
mkdir -p "$TMP/empty"

echo "Test 13: --target that is empty or not a directory is exit 2, not a silent cwd"
printf '[%s]' "$(rec QUA-07 form.yml:missing-min-max)" > "$TMP/m.json"
check "empty target exit 2" 2 "$(run "$TMP/m.json" --target "")"
check "empty target message" 1 "$(grep -c "^error: --target is not a directory: ''$" "$TMP/out")"
check "nonexistent target exit 2" 2 "$(run "$TMP/m.json" --target /nonexistent)"
check "nonexistent target message" 1 "$(grep -c "^error: --target is not a directory: '/nonexistent'$" "$TMP/out")"

echo "Test 14: absent-file tags take their fixed expected anchor; existence is not required"
printf '[%s,%s]' "$(rec STR-01 form.yml:missing-form)" "$(rec STR-01 manifest.yml:missing-manifest)" > "$TMP/n.json"
check "exit 0 against a tree without the files" 0 "$(run "$TMP/n.json" --target "$TMP/empty")"
check "summary" "finding keys: 2/2 valid" "$(tail -1 "$TMP/out")"
printf '[%s]' "$(recapp apps/bad-app STR-01 apps/bad-app/form.yml:missing-form)" > "$TMP/o.json"
check "monorepo app_id/anchor exit 0" 0 "$(run "$TMP/o.json" --target "$TMP/empty")"
printf '[%s]' "$(rec STR-01 root:missing-form)" > "$TMP/p.json"
check "root anchor exit 1" 1 "$(run "$TMP/p.json" --target "$TMP/empty")"
check "root anchor reason" 1 "$(grep -cF "INVALID STR-01 root:missing-form (absent-file tag 'missing-form' must use anchor 'form.yml' (or '<app_id>/form.yml' in a monorepo))" "$TMP/out")"
printf '[%s]' "$(rec STR-01 apps/bad-app/form.yml:missing-form)" > "$TMP/p2.json"
check "app-prefixed anchor with app_id root exit 1" 1 "$(run "$TMP/p2.json" --target "$TMP/empty")"
# The tag vocabulary is still per rule: missing-form belongs to STR-01, so under
# STR-07 the anchor passes but the tag does not (run 36477735864 keeps this INVALID).
printf '[%s]' "$(rec STR-07 form.yml:missing-form)" > "$TMP/q.json"
check "STR-07 missing-form exit 1" 1 "$(run "$TMP/q.json" --target "$TMP/empty")"
check "STR-07 missing-form reason is the vocabulary" 1 "$(grep -cF "INVALID STR-07 form.yml:missing-form (tag 'missing-form' not in STR-07 vocabulary; use other:<slug> for a novel defect)" "$TMP/out")"

echo "Test 15: monorepo anchors are repo-root-relative and include the app subpath"
mkdir -p "$TMP/mono/apps/good-app"; touch "$TMP/mono/apps/good-app/form.yml"
printf '[%s]' "$(recapp apps/good-app QUA-07 apps/good-app/form.yml:missing-min-max)" > "$TMP/r.json"
check "full path exit 0" 0 "$(run "$TMP/r.json" --target "$TMP/mono")"
printf '[%s]' "$(recapp apps/good-app QUA-07 form.yml:missing-min-max)" > "$TMP/s.json"
check "app-relative path exit 1" 1 "$(run "$TMP/s.json" --target "$TMP/mono")"
check "app-relative path reason" 1 "$(grep -cF "INVALID QUA-07 form.yml:missing-min-max (anchor is not a repo path or allowed pseudo-anchor)" "$TMP/out")"

echo "Test 16: empty tag, unknown rule, and non-list input"
printf '[%s]' "$(rec QUA-07 form.yml:)" > "$TMP/u.json"
check "empty tag exit 1" 1 "$(run "$TMP/u.json")"
check "empty tag reason" 1 "$(grep -cF "INVALID QUA-07 form.yml: (empty tag)" "$TMP/out")"
printf '[%s]' "$(rec OAT-01 form.yml:eval-exec)" > "$TMP/v.json"
check "unknown rule exit 1" 1 "$(run "$TMP/v.json")"
check "unknown rule reason" 1 "$(grep -cF "INVALID OAT-01 form.yml:eval-exec (unknown rule 'OAT-01')" "$TMP/out")"
echo '{"findings":[]}' > "$TMP/w.json"
check "object top level exit 2" 2 "$(run "$TMP/w.json")"
check "object top level message" 1 "$(grep -cxF "error: findings must be a JSON list of objects" "$TMP/out")"
check "no traceback" 0 "$(grep -c Traceback "$TMP/out")"
echo '["form.yml:missing-min-max"]' > "$TMP/x.json"
check "non-object element exit 2" 2 "$(run "$TMP/x.json")"
check "non-object element message" 1 "$(grep -cxF "error: findings must be a JSON list of objects" "$TMP/out")"

echo "Test 17: missing-entry-point has one anchor: root, or the app subpath in a monorepo"
printf '[%s,%s]' "$(rec STR-07 root:missing-entry-point)" "$(recapp apps/web STR-07 apps/web:missing-entry-point)" > "$TMP/y.json"
check "exit 0 against a tree without the files" 0 "$(run "$TMP/y.json" --target "$TMP/empty")"
check "summary" "finding keys: 2/2 valid" "$(tail -1 "$TMP/out")"
printf '[%s,%s,%s,%s]' "$(rec STR-07 config.ru:missing-entry-point)" "$(rec STR-07 template/script.sh.erb:missing-entry-point)" "$(recapp apps/web STR-07 apps/web/config.ru:missing-entry-point)" "$(recapp apps/web STR-07 root:missing-entry-point)" > "$TMP/z.json"
check "file anchors exit 1" 1 "$(run "$TMP/z.json" --target "$TMP/empty")"
check "config.ru reason" 1 "$(grep -cxF "INVALID STR-07 config.ru:missing-entry-point (absent-file tag 'missing-entry-point' must use anchor 'root' (or the app subpath in a monorepo))" "$TMP/out")"
check "all four rejected" 4 "$(grep -cF "(absent-file tag 'missing-entry-point' must use anchor 'root' (or the app subpath in a monorepo))" "$TMP/out")"

echo "Test 18: an other: slug that extends a vocabulary tag is invalid"
printf '[%s,%s]' "$(rec QUA-07 form.yml:other:missing-pattern-constraint)" "$(rec QUA-07 form.yml:other:Missing_Pattern_check)" > "$TMP/e1.json"
check "exit 1" 1 "$(run "$TMP/e1.json" --target "$TMP/t")"
check "hyphen reason" 1 "$(grep -cF "INVALID QUA-07 form.yml:other:missing-pattern-constraint (other:missing-pattern-constraint extends the vocabulary tag 'missing-pattern'; use 'missing-pattern' or a distinct slug)" "$TMP/out")"
check "underscore/case reason" 1 "$(grep -cF "INVALID QUA-07 form.yml:other:Missing_Pattern_check (other:Missing_Pattern_check extends the vocabulary tag 'missing-pattern'; use 'missing-pattern' or a distinct slug)" "$TMP/out")"
printf '[%s]' "$(rec QUA-07 form.yml:other:missingpatterns)" > "$TMP/e2.json"
check "no separator after the tag is a distinct slug" 0 "$(run "$TMP/e2.json" --target "$TMP/t")"

echo "Test 19: CHANGELOG.md is the one MNT-03 anchor, whether or not the file exists"
printf '[%s]' "$(rec MNT-03 CHANGELOG.md:no-changelog)" > "$TMP/g1.json"
check "CHANGELOG.md:no-changelog exit 0 without the file" 0 "$(run "$TMP/g1.json" --target "$TMP/empty")"
check "summary" "finding keys: 1/1 valid" "$(tail -1 "$TMP/out")"
printf '[%s]' "$(rec MNT-03 CHANGELOG:no-changelog)" > "$TMP/g2.json"
check "CHANGELOG:no-changelog exit 1" 1 "$(run "$TMP/g2.json" --target "$TMP/empty")"
check "CHANGELOG:no-changelog reason" 1 "$(grep -cF "INVALID MNT-03 CHANGELOG:no-changelog (absent-file tag 'no-changelog' must use anchor 'CHANGELOG.md' (or '<app_id>/CHANGELOG.md' in a monorepo))" "$TMP/out")"

echo "Test 20: in a monorepo an absent-file anchor must carry the app prefix"
printf '[%s]' "$(recapp apps/bad-app STR-01 apps/bad-app/form.yml:missing-form)" > "$TMP/h1.json"
check "prefixed exit 0" 0 "$(run "$TMP/h1.json" --target "$TMP/empty")"
printf '[%s]' "$(recapp apps/bad-app STR-01 form.yml:missing-form)" > "$TMP/h2.json"
check "bare exit 1" 1 "$(run "$TMP/h2.json" --target "$TMP/empty")"
check "bare reason" 1 "$(grep -cF "INVALID STR-01 form.yml:missing-form (absent-file anchor must be 'apps/bad-app/form.yml' in a monorepo)" "$TMP/out")"

echo "Test 21: format checks run before the absent-file branch; app_id is checked"
printf '[%s]' "$(rec STR-01 ../../etc/form.yml:missing-form)" > "$TMP/i1.json"
check "dotdot absent-file anchor exit 1" 1 "$(run "$TMP/i1.json" --target "$TMP/empty")"
check "dotdot absent-file anchor reason" 1 "$(grep -cF "INVALID STR-01 ../../etc/form.yml:missing-form (anchor must be a repo-relative path)" "$TMP/out")"
printf '[%s]' "$(recapp /abs STR-01 /abs/form.yml:missing-form)" > "$TMP/i2.json"
check "absolute app_id exit 1" 1 "$(run "$TMP/i2.json" --target "$TMP/empty")"
check "absolute app_id reason" 1 "$(grep -cF "INVALID STR-01 /abs/form.yml:missing-form (app_id must be a repo-relative path)" "$TMP/out")"
printf '[%s]' "$(recapp apps/x STR-01 apps/x/form.yml:missing-form)" > "$TMP/i3.json"
check "apps/x prefixed still valid" 0 "$(run "$TMP/i3.json" --target "$TMP/empty")"

echo; echo "Done: $pass passed, $fail failed."; [ "$fail" -eq 0 ]
