#!/usr/bin/env bash
# Test run-corpus.sh: the recall table (keys, lines, reviewed OK, the
# off-candidate column and group means), the recall-floor gate, and
# --update keeping an expected file's leading comment lines. Runs against a
# synthetic corpus (RUN_CORPUS_DIR / RUN_CORPUS_RECALL_DIR).
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RUNC="$SCRIPT_DIR/tests/run-corpus.sh"
FIX="$SCRIPT_DIR/tests/fixtures"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0
check() { local name="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then echo "  PASS  $name"; pass=$((pass+1)); else echo "  FAIL  $name: expected '$expected', got '$actual'"; fail=$((fail+1)); fi; }

C="$TMP/corpus"; R="$TMP/recall"
mkdir -p "$C/demo-1" "$C/demo-2" "$R"
# rc_run [--update]: run-corpus over the synthetic corpus; output in $TMP/out, exit status echoed
rc_run() { RUN_CORPUS_DIR="$C" RUN_CORPUS_RECALL_DIR="$R" bash "$RUNC" "$@" > "$TMP/out" 2>&1; echo $?; }
for d in demo-1 demo-2; do
  printf '# Review\n' > "$C/$d/report.md"
  printf '%s\n' "$FIX/broken-app" > "$C/$d/target.txt"
done
printf '{"model": "model-a"}' > "$C/demo-1/meta.json"
printf '{"model": "model-b"}' > "$C/demo-2/meta.json"
cat > "$C/demo-1/findings.json" <<'JSON'
[{"rule": "QUA-02", "defect_key": "form.yml:hardcoded-cluster", "result": "WARN", "evidence": "form.yml:3"},
 {"rule": "QUA-06", "defect_key": "README.md:readme-typo", "result": "WARN", "evidence": "README.md:9-12"},
 {"rule": "QUA-07", "defect_key": "form.yml:missing-pattern", "result": "WARN", "evidence": "form.yml:15 (a), :21 (b); reviewed OK: form.yml:30"},
 {"rule": "QUA-08", "defect_key": "template/script.sh.erb:magic-number", "result": "PASS", "evidence": "template/script.sh.erb:40"}]
JSON
cat > "$C/demo-2/findings.json" <<'JSON'
[{"rule": "QUA-02", "defect_key": "form.yml:hardcoded-cluster", "result": "WARN", "evidence": "form.yml:3"}]
JSON
cat > "$R/demo.json" <<'JSON'
{"groups": {"early": ["demo-1"], "late": ["demo-2"]},
 "items": [
  {"defect": "cluster in form.yml", "rule": "QUA-02", "candidate": true, "keys": ["form.yml:hardcoded-cluster"]},
  {"defect": "typo at README :11", "rule": "QUA-06", "candidate": false, "keys": [], "lines": {"README.md": [11]}},
  {"defect": "field at form.yml:21 (bare :N)", "rule": "QUA-07", "candidate": false, "keys": [], "lines": {"form.yml": [21]}},
  {"defect": "reviewed-OK line only", "rule": "QUA-07", "candidate": false, "keys": [], "lines": {"form.yml": [30]}},
  {"defect": "a PASS record never counts", "rule": "QUA-08", "candidate": false, "keys": ["template/script.sh.erb:magic-number"]},
  {"defect": "rule-prefixed key (the old form)", "rule": "QUA-02", "candidate": false, "keys": ["QUA-02:form.yml:hardcoded-cluster"]}
 ]}
JSON

echo "Test 1: --update writes expected files, then a plain run passes"
check "--update exit 0" 0 "$(rc_run --update)"
check "plain run exit 0" 0 "$(rc_run)"
check "both runs PASS" "2" "$(grep -c '^PASS  demo-' "$TMP/out")"

echo "Test 2: the recall table, per item and per run"
check "demo-1 items" "$(printf '%s\n' \
  '    HIT  candidate     QUA-02   cluster in form.yml' \
  '    HIT  off-candidate QUA-06   typo at README :11' \
  '    HIT  off-candidate QUA-07   field at form.yml:21 (bare :N)' \
  '    MISS off-candidate QUA-07   reviewed-OK line only' \
  '    MISS off-candidate QUA-08   a PASS record never counts' \
  '    HIT  off-candidate QUA-02   rule-prefixed key (the old form)' \
  '  recall: candidate 1/1, off-candidate 3/5 (group early, model-a)')" \
  "$(sed -n '/^PASS  demo-1/,/^  recall:/p' "$TMP/out" | sed '1,2d')"
check "demo-2 run line" "  recall: candidate 1/1, off-candidate 1/5 (group late, model-b)" "$(sed -n '/^PASS  demo-2/,/^  recall:/p' "$TMP/out" | tail -1)"
check "summary: the off-candidate column per run and a mean per group" "$(printf '%s\n' \
  'off-candidate recall (hits/items per run):' \
  "  $R/demo.json" \
  '    early      demo-1                     3/5  model-a' \
  '    late       demo-2                     1/5  model-b' \
  '    early mean: 3.00 off-candidate hits per run over 1 run(s)' \
  '    late mean: 1.00 off-candidate hits per run over 1 run(s)')" \
  "$(sed -n '/^off-candidate recall/,/^$/p' "$TMP/out" | sed '/^$/d')"

echo "Test 3: a group with two models prints the split"
python3 -c 'import json,sys; p=sys.argv[1]; d=json.load(open(p)); d["groups"]={"all": ["demo-1", "demo-2"]}; json.dump(d, open(p, "w"))' "$R/demo.json"
rc_run > /dev/null
check "group mean with a per-model split" "    all mean: 2.00 off-candidate hits per run over 2 run(s) (model-a 3.00 over 1; model-b 1.00 over 1)" "$(grep 'all mean:' "$TMP/out")"

echo "Test 4: --update keeps leading comment lines"
{ printf '# known-wrong: a note\n# recall-floor: 3/5\n'; cat "$C/expected/demo-1.txt"; } > "$TMP/e1"; mv "$TMP/e1" "$C/expected/demo-1.txt"
check "--update exit 0" 0 "$(rc_run --update)"
check "the comment lines survive, first" "# known-wrong: a note|# recall-floor: 3/5" "$(head -2 "$C/expected/demo-1.txt" | paste -sd '|' -)"
check "and the checker output follows them once" "1" "$(grep -c '^exit: ' "$C/expected/demo-1.txt")"

echo "Test 5: the recall-floor gate"
check "floor met: exit 0" 0 "$(rc_run)"
check "floor met line" "  recall-floor 3/5: met (3/5)" "$(grep 'recall-floor' "$TMP/out")"
sed 's|^# recall-floor: 3/5$|# recall-floor: 4/5|' "$C/expected/demo-1.txt" > "$TMP/e1"; mv "$TMP/e1" "$C/expected/demo-1.txt"
check "floor above the hits: exit 1" 1 "$(rc_run)"
check "below-floor line and a DIFF" "  recall-floor 4/5: below the floor (3/5)|DIFF  demo-1 (recall floor)" "$(grep -e 'recall-floor' -e '^DIFF' "$TMP/out" | paste -sd '|' -)"
sed 's|^# recall-floor: 4/5$|# recall-floor: 3/6|' "$C/expected/demo-1.txt" > "$TMP/e1"; mv "$TMP/e1" "$C/expected/demo-1.txt"
check "floor over a different set size: exit 1" 1 "$(rc_run)"
check "set-size line" "  recall-floor 3/6: the set has 5 off-candidate items, not 6" "$(grep 'recall-floor' "$TMP/out")"

echo "Test 6: a run with no recall set gets no table; a corpus diff is still a diff"
mkdir -p "$C/other-1"; cp "$C/demo-2/report.md" "$C/demo-2/findings.json" "$C/demo-2/target.txt" "$C/other-1/"
sed 's|^# recall-floor: 3/6$|# recall-floor: 3/5|' "$C/expected/demo-1.txt" > "$TMP/e1"; mv "$TMP/e1" "$C/expected/demo-1.txt"
check "no expected file: exit 1" 1 "$(rc_run)"
check "other-1 is a DIFF with no recall lines" "DIFF  other-1 (no expected/other-1.txt; run with --update to create it)|0" "$(grep '^DIFF' "$TMP/out")|$(sed -n '/^DIFF  other-1/,/^[A-Z]/p' "$TMP/out" | grep -c 'recall against')"

echo; echo "Done: $pass passed, $fail failed."; [ "$fail" -eq 0 ]
