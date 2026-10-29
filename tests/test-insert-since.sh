#!/usr/bin/env bash
# Test insert-since.py: the "Since the last review" section built from the baseline.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
INS="$SCRIPT_DIR/references/insert-since.py"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0
check() { local name="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then echo "  PASS  $name"; pass=$((pass+1)); else echo "  FAIL  $name: expected '$expected', got '$actual'"; fail=$((fail+1)); fi; }

# Baseline: A (still open, WARN, dismissed), B (still open, FAIL), C (dismissed, absent now),
# F then D (absent now, non-alphabetical; D's key also appears in a current PASS row).
# Current, in a different order from the baseline: B (empty summary), A (new summary), G and E (new, G first), PASS row on D's key.
python3 - "$TMP" <<'PYEOF'
import json, sys, hashlib
tmp = sys.argv[1]
def mk(rule, key, result, sev, summary=""):
    return dict(app_id="root", rule=rule, defect_key=key, result=result, severity=sev, summary=summary)
def sid(f):
    return hashlib.sha256("{}\0{}\0{}".format(f["app_id"], f["rule"], f["defect_key"]).encode()).hexdigest()[:16]
A = mk("QUA-07", "a", "WARN", "low", "A before"); B = mk("OODT-01", "b", "FAIL", "high", "B before")
C = mk("QUA-02", "c", "WARN", "low"); D = mk(None, "d", "WARN", "low", "D before"); F = mk("QUA-05", "f", "WARN", "low", "F before")
E = mk("QUA-04", "e", "WARN", "low", "E summary"); G = mk("QUA-08", "g", "WARN", "low", "G summary")
def entry(f, dismissed=False):
    return dict(f, id=sid(f), dismissed=dismissed)
def base(**kw):
    d = dict(sha="abc1234def0", sent_at=1700000000, recommendation="accept", apps=dict(root="accept"),
             same_commit=False, comparable=True,
             findings=[entry(A, True), entry(B), entry(C, True), entry(F), entry(D)])
    d.update(kw)
    return d
json.dump([dict(B, summary=""), dict(A, summary="A now"), G, E, dict(D, result="PASS", summary="fine")],
          open(tmp + "/findings.json", "w"))
json.dump([B, A], open(tmp + "/findings-none-new.json", "w"))
json.dump(base(), open(tmp + "/base.json", "w"))
json.dump(base(same_commit=True), open(tmp + "/same.json", "w"))
nc = base(comparable=False); del nc["findings"]
json.dump(nc, open(tmp + "/nocmp.json", "w"))
PYEOF
REPORT=$'# Review\n\n## App: X (root)\n\nbody\n\n## Overall recommendation\n\nAccept.\n\n## Draft feedback\n\nHi.\n'
run() { printf '%s' "$REPORT" > "$TMP/r.md"; python3 "$INS" "$TMP/r.md" "$TMP/findings.json" --baseline "$1" >/dev/null; echo $?; }

echo "Test 1: section content and placement"
check "exit 0" "0" "$(run "$TMP/base.json")"
check "heading" "1" "$(grep -cxF '## Since the last review (sent 2023-11-14, commit abc1234)' "$TMP/r.md")"
check "New count" "1" "$(grep -cxF '**New** (2)' "$TMP/r.md")"
check "Still open count" "1" "$(grep -cxF '**Still open** (2)' "$TMP/r.md")"
check "Not found count" "1" "$(grep -cxF '**Not found this time** (2)' "$TMP/r.md")"
check "null rule prints a dash" "1" "$(grep -cxF -- '- — `d`' "$TMP/r.md")"
check "no dismissal mark in the published section" "0" "$(grep -c 'dismissed last time' "$TMP/r.md")"
check "dismissed absent finding left out" "0" "$(grep -c '`c`' "$TMP/r.md")"
check "PASS row on a baseline key is not listed as current" "1" "$(grep -c '`d`' "$TMP/r.md")"
check "note" "1" "$(grep -c '^_Not found this time means this run did not record the finding' "$TMP/r.md")"
check "directly above Overall recommendation" "## Overall recommendation" "$(grep -A2 -F '_Not found this time means' "$TMP/r.md" | tail -1)"
check "after the app section" "body" "$(grep -B2 -F '## Since the last review' "$TMP/r.md" | head -1)"

echo "Test 1b: the whole section, exactly (order, summaries, blank lines)"
section() { awk -v h="## Since the last review" 'index($0,h)==1{p=1;print;next} p&&/^## /{exit} p' "$1"; }
EXPECTED='## Since the last review (sent 2023-11-14, commit abc1234)

**New** (2)
- QUA-08 `g` — G summary
- QUA-04 `e` — E summary

**Still open** (2)
- OODT-01 `b`
- QUA-07 `a` — A now

**Not found this time** (2)
- QUA-05 `f`
- — `d`

_Not found this time means this run did not record the finding: it may have been fixed, or the review may have varied._'
check "exact section" "$EXPECTED" "$(section "$TMP/r.md")"
printf '%s' "$REPORT" > "$TMP/r0.md"
python3 "$INS" "$TMP/r0.md" "$TMP/findings-none-new.json" --baseline "$TMP/base.json" >/dev/null
EXPECTED0='## Since the last review (sent 2023-11-14, commit abc1234)

**New** (0)

**Still open** (2)
- OODT-01 `b` — B before
- QUA-07 `a` — A before

**Not found this time** (2)
- QUA-05 `f`
- — `d`

_Not found this time means this run did not record the finding: it may have been fixed, or the review may have varied._'
check "empty group is its label and (0)" "$EXPECTED0" "$(section "$TMP/r0.md")"

echo "Test 2: a second run replaces the section"
python3 "$INS" "$TMP/r.md" "$TMP/findings.json" --baseline "$TMP/base.json" >/dev/null
check "one section" "1" "$(grep -c '^## Since the last review' "$TMP/r.md")"
check "one note" "1" "$(grep -c '^_Not found this time' "$TMP/r.md")"

echo "Test 3: same commit heading"
run "$TMP/same.json" >/dev/null
check "same-commit heading" "1" "$(grep -cxF '## Since the last review (same commit abc1234, sent 2023-11-14)' "$TMP/r.md")"

echo "Test 4: no comparison removes the section"
run "$TMP/base.json" >/dev/null
python3 "$INS" "$TMP/r.md" "$TMP/findings.json" --baseline "$TMP/nocmp.json" >/dev/null
printf '%s' "$REPORT" > "$TMP/orig.md"
check "not comparable: same as original" "0" "$(cmp -s "$TMP/r.md" "$TMP/orig.md"; echo $?)"
run "$TMP/base.json" >/dev/null
python3 "$INS" "$TMP/r.md" "$TMP/findings.json" >/dev/null
check "no baseline: same as original" "0" "$(cmp -s "$TMP/r.md" "$TMP/orig.md"; echo $?)"
python3 "$INS" "$TMP/r.md" "$TMP/findings.json" --baseline "$TMP/none.json" >/dev/null 2>&1
check "absent baseline file: untouched" "0" "$(cmp -s "$TMP/r.md" "$TMP/orig.md"; echo $?)"

echo "Test 5: other anchors"
printf '# R\n\n## Draft feedback\n\nHi.\n' > "$TMP/r.md"
python3 "$INS" "$TMP/r.md" "$TMP/findings.json" --baseline "$TMP/base.json" >/dev/null
check "before Draft feedback" "## Draft feedback" "$(grep -A2 -F '_Not found this time means' "$TMP/r.md" | tail -1)"
printf '# R\n\ntext\n' > "$TMP/r.md"
python3 "$INS" "$TMP/r.md" "$TMP/findings.json" --baseline "$TMP/base.json" >/dev/null
check "appended" "_Not found this time means this run did not record the finding: it may have been fixed, or the review may have varied._" "$(tail -1 "$TMP/r.md")"
printf '# R\n\n## Since the last review (old)\n\nstale\n' > "$TMP/r.md"
python3 "$INS" "$TMP/r.md" "$TMP/findings.json" --baseline "$TMP/base.json" >/dev/null
check "replaced at end of file" "0" "$(grep -c stale "$TMP/r.md")"

echo "Test 6: unreadable report"
python3 "$INS" "$TMP/missing.md" "$TMP/findings.json" --baseline "$TMP/base.json" >/dev/null 2>&1
check "exit 2" "2" "$?"

echo "Test 7: the checkers give the same output with and without the section"
RUN="$SCRIPT_DIR/tests/corpus/ood-sas-36773061549"
cp "$RUN/report.md" "$TMP/real.md"; cp "$RUN/report.md" "$TMP/real-orig.md"
python3 "$INS" "$TMP/real.md" "$RUN/findings.json" --baseline "$TMP/base.json" >/dev/null
check "section was inserted" "1" "$(grep -c '^## Since the last review' "$TMP/real.md")"
checkers() { # report
  python3 "$SCRIPT_DIR/references/check-sections.py" "$1" 2>&1
  python3 "$SCRIPT_DIR/references/check-rows.py" "$1" "$RUN/findings.json" "$SCRIPT_DIR/references/checks.json" "$RUN/pre-review" 2>&1
  python3 "$SCRIPT_DIR/references/check-feedback-floor.py" "$RUN/findings.json" "$1" 2>&1
}
check "same checker output" "$(checkers "$TMP/real-orig.md")" "$(checkers "$TMP/real.md")"

echo "Test 8: an unreadable or non-list findings file never fails the run"
SECTION_REPORT=$'# Review\n\n## Since the last review (sent 2023-11-14, commit abc1234)\n\nold\n\n## Overall recommendation\n\nAccept.\n'
echo '{"not":"a list"}' > "$TMP/findings-obj.json"; echo '{' > "$TMP/findings-bad.json"
try() { # report-text findings baseline-args...: exit code, then whether a section remains
  local text="$1" fpath="$2"; shift 2
  printf '%s' "$text" > "$TMP/r.md"
  python3 "$INS" "$TMP/r.md" "$fpath" "$@" >/dev/null 2>&1; local rc=$?
  echo "$rc $(grep -c '^## Since the last review' "$TMP/r.md")"; }
check "no baseline, unreadable findings, no section" "0 0" "$(try "$REPORT" "$TMP/missing-findings.json")"
check "no baseline, malformed findings, no section" "0 0" "$(try "$REPORT" "$TMP/findings-bad.json")"
check "no baseline, non-list findings, no section" "0 0" "$(try "$REPORT" "$TMP/findings-obj.json")"
check "no baseline, bad findings: existing section removed" "0 0" "$(try "$SECTION_REPORT" "$TMP/findings-bad.json")"
check "comparison, unreadable findings: section removed" "0 0" "$(try "$SECTION_REPORT" "$TMP/missing-findings.json" --baseline "$TMP/base.json")"
check "comparison, malformed findings: section removed" "0 0" "$(try "$SECTION_REPORT" "$TMP/findings-bad.json" --baseline "$TMP/base.json")"
check "comparison, non-list findings: section removed" "0 0" "$(try "$SECTION_REPORT" "$TMP/findings-obj.json" --baseline "$TMP/base.json")"
printf '%s' "$REPORT" > "$TMP/r.md"
check "comparison, bad findings: one warning" "1" "$(python3 "$INS" "$TMP/r.md" "$TMP/findings-obj.json" --baseline "$TMP/base.json" 2>&1 | grep -c '^warning:')"
python3 - "$TMP" <<'PYEOF2'
import json, sys
tmp = sys.argv[1]
json.dump([{"app_id": "root", "rule": "QUA-04", "result": "WARN", "severity": "low"}], open(tmp + "/findings-nokey.json", "w"))
PYEOF2
check "finding without defect_key: no traceback" "0" "$(try "$REPORT" "$TMP/findings-nokey.json" --baseline "$TMP/base.json" | cut -d' ' -f1)"

echo; echo "Done: $pass passed, $fail failed."; [ "$fail" -eq 0 ]
