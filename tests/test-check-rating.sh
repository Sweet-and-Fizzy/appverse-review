#!/usr/bin/env bash
# Test check-rating.py: Documentation rating follows its evidence lines; Documentation signal follows the rating;
# a suggestion-class check or an MNT-02..MNT-06 good-practice signal recorded as FAIL is a mismatch, and so is
# a suggestion-class FAIL or WARN rated above info.
# Only Documentation is checked among ratings/signals (no security rating, design R4); the findings JSON is also
# read for a stub README rating (QUA-01 docs-stub) and for the suggestion/good-practice FAIL scan (rule 3).
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CHECK="$SCRIPT_DIR/references/check-rating.py"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0
check() { local name="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then echo "  PASS  $name"; pass=$((pass+1)); else echo "  FAIL  $name: expected '$expected', got '$actual'"; fail=$((fail+1)); fi; }
run() { python3 "$CHECK" "$@" > "$TMP/out" 2>&1; echo $?; }

report() { # $1 = doc rating, $2 = documentation signal, $3 = evidence block (bullet form)
cat <<EOF
# Appverse Review: x

## Repo-level gate criteria

| Rule | Result | Evidence |
|---|---|---|

## App: X (root)

### Signals

| Dimension | Level | Evidence |
|---|---|---|
| Portability | Medium | e |
| Documentation | $2 | e |

### Structure
No findings.

### Security

#### Findings

| Rule | Result | Severity | Tag | Summary | Evidence |
|---|---|---|---|---|---|

No tool-detectable issues in the checked tiers.

### Portability
- Rating: **Partially portable** — x

### Documentation
- Rating: **$1** — x
- Evidence per rung:
$3

### Code Quality
No findings.

## Review scope
x
EOF
}
FULL='  - what it launches: README.md:27
  - prerequisites: README.md:65
  - installation: README.md:84
  - configuration: README.md:99
  - known limitations: README.md:200
  - troubleshooting: README.md:159
  - screenshots: README.md:39
  - environment variables: README.md:120
  - info panel: none
  - architecture: none'
NOENV='  - what it launches: README.md:27
  - prerequisites: README.md:65
  - installation: README.md:84
  - configuration: README.md:99
  - known limitations: README.md:200
  - troubleshooting: README.md:159
  - screenshots: README.md:39
  - environment variables: none user-facing to document — N/A
  - info panel: none
  - architecture: none'
SEMI='  what it launches: README.md:27; prerequisites: README.md:65; installation: README.md:84;
  configuration: README.md:99; known limitations: none;
  troubleshooting: README.md:159; screenshots: README.md:39; environment variables: README.md:120;
  info panel: none; architecture: none'

echo "Test 1: consistent report passes"
report Strong Low "$FULL" > "$TMP/r1.md"; echo '[]' > "$TMP/f1.json"
check "exit 0" 0 "$(run "$TMP/r1.md" "$TMP/f1.json")"
check "summary" "ratings: consistent" "$(tail -1 "$TMP/out")"

echo "Test 2: Strong claimed with environment variables = none (the 2026-09-28 sonnet-1 case)"
report Strong Low "$NOENV" > "$TMP/r2.md"
check "exit 1" 1 "$(run "$TMP/r2.md" "$TMP/f1.json")"
check "mismatch names the rung" 1 "$(grep -c "MISMATCH Documentation rating (Strong claimed but 'environment variables' evidence is none; highest supported rung is Adequate)" "$TMP/out")"

echo "Test 3: rungs are cumulative (known limitations none caps at Minimal even with Strong-rung evidence)"
report Strong Low "$SEMI" > "$TMP/r3.md"
check "exit 1" 1 "$(run "$TMP/r3.md" "$TMP/f1.json")"
check "caps at Minimal" 1 "$(grep -c "highest supported rung is Minimal" "$TMP/out")"

echo "Test 4: semicolon (template) form parses when consistent"
SEMIOK='  what it launches: README.md:27; prerequisites: README.md:65; installation: README.md:84;
  configuration: README.md:99; known limitations: README.md:200;
  troubleshooting: none; screenshots: none; environment variables: none;
  info panel: none; architecture: none'
report Adequate Medium "$SEMIOK" > "$TMP/r4.md"
check "exit 0" 0 "$(run "$TMP/r4.md" "$TMP/f1.json")"

echo "Test 8: Documentation signal disagrees with the rating (Adequate must be Medium)"
report Adequate Low "$FULL" > "$TMP/r8.md"
check "exit 1" 1 "$(run "$TMP/r8.md" "$TMP/f1.json")"
check "reason" 1 "$(grep -c "MISMATCH Documentation signal (report says Low; rating Adequate maps to Medium)" "$TMP/out")"

echo "Test 9: no Documentation section is exit 2"
grep -v "^### Documentation" "$TMP/r1.md" | grep -v "Rating: \*\*Strong" > "$TMP/r9.md"
check "exit 3 (malformed report)" 3 "$(run "$TMP/r9.md" "$TMP/f1.json")"

echo "Test 10: signal() must not read a findings-table row whose first cell is Documentation"
# Signals table has no Documentation row; a findings table below it has a row starting
# "| Documentation | Low | …" that must not be misread as the Signals-table Documentation level.
sed -e '/^| Documentation | Low | e |$/d' \
    -e 's/^|---|---|---|---|---|---|$/|---|---|---|---|---|---|\n| Documentation | Low | medium | DOC-01 | s | e |/' \
    "$TMP/r1.md" > "$TMP/r10.md"
check "findings-table decoy row present" 1 "$(grep -c '^| Documentation | Low | medium | DOC-01 | s | e |$' "$TMP/r10.md")"
check "exit 3 (missing Signals row, not misread)" 3 "$(run "$TMP/r10.md" "$TMP/f1.json")"
check "error names Documentation" 1 "$(grep -c "has no Signals row for Documentation" "$TMP/out")"

echo "Test 11: missing '### Signals' section entirely is exit 2"
grep -v "^### Signals$" "$TMP/r1.md" | sed '/^| Dimension | Level | Evidence |$/d; /^|---|---|---|$/d; /^| Portability | Medium | e |$/d; /^| Documentation | Low | e |$/d' > "$TMP/r11.md"
check "exit 3 (malformed report)" 3 "$(run "$TMP/r11.md" "$TMP/f1.json")"
check "error names Signals section" 1 "$(grep -c "has no '### Signals' section" "$TMP/out")"

echo "Test 12: Signals table present but missing the Documentation row is exit 2"
grep -v "^| Documentation | Low | e |$" "$TMP/r1.md" > "$TMP/r12.md"
check "exit 3 (malformed report)" 3 "$(run "$TMP/r12.md" "$TMP/f1.json")"
check "error names Documentation" 1 "$(grep -c "has no Signals row for Documentation" "$TMP/out")"

# FULL with one line replaced: $1 = requirement, $2 = new value
full_with() { printf '%s\n' "$FULL" | sed "s|^  - $1: .*|  - $1: $2|"; }

echo "Test 14: 'No …' evidence is none"
report Strong Low "$(full_with troubleshooting 'No troubleshooting section')" > "$TMP/r14.md"
check "exit 1" 1 "$(run "$TMP/r14.md" "$TMP/f1.json")"
check "caps at Adequate" 1 "$(grep -cF "MISMATCH Documentation rating (Strong claimed but 'troubleshooting' evidence is none; highest supported rung is Adequate)" "$TMP/out")"

echo "Test 15: punctuation-only evidence is none"
report Strong Low "$(full_with 'environment variables' '—')" > "$TMP/r15.md"
check "exit 1" 1 "$(run "$TMP/r15.md" "$TMP/f1.json")"
check "caps at Adequate" 1 "$(grep -cF "MISMATCH Documentation rating (Strong claimed but 'environment variables' evidence is none; highest supported rung is Adequate)" "$TMP/out")"

echo "Test 16: bold requirement keys parse"
BOLD=$(printf '%s\n' "$FULL" | sed -E 's/^  - ([a-z ]+):/  - **\1:**/')
report Strong Low "$BOLD" > "$TMP/r16.md"
check "exit 0" 0 "$(run "$TMP/r16.md" "$TMP/f1.json")"
check "summary" "ratings: consistent" "$(tail -1 "$TMP/out")"
BOLDNOENV=$(printf '%s\n' "$BOLD" | sed 's/^  - \*\*environment variables:\*\* .*/  - **environment variables:** none/')
report Strong Low "$BOLDNOENV" > "$TMP/r16b.md"
check "bold none still caps" 1 "$(run "$TMP/r16b.md" "$TMP/f1.json")"
check "bold none reason" 1 "$(grep -cF "MISMATCH Documentation rating (Strong claimed but 'environment variables' evidence is none; highest supported rung is Adequate)" "$TMP/out")"

echo "Test 17: * and + bullets parse"
STARS=$(printf '%s\n' "$FULL" | awk '{ sub(/^  - /, NR <= 5 ? "  * " : "  + "); print }')
report Strong Low "$STARS" > "$TMP/r17.md"
check "exit 0" 0 "$(run "$TMP/r17.md" "$TMP/f1.json")"
check "five * bullets" 5 "$(grep -cE '^  \* [a-z]' "$TMP/r17.md")"
check "five + bullets" 5 "$(grep -cE '^  \+ [a-z]' "$TMP/r17.md")"

echo "Test 18: bold dimension and level cells in the Signals table"
sed -e 's/^| Documentation | Low | e |$/| Documentation | **Low** | e |/' "$TMP/r1.md" > "$TMP/r18.md"
check "exit 0" 0 "$(run "$TMP/r18.md" "$TMP/f1.json")"
check "summary" "ratings: consistent" "$(tail -1 "$TMP/out")"
sed -e 's/^| Documentation | Low | e |$/| **Documentation** | **Medium** | e |/' "$TMP/r1.md" > "$TMP/r18b.md"
check "bold dimension and level still compared" 1 "$(run "$TMP/r18b.md" "$TMP/f1.json")"
check "bold level reason" 1 "$(grep -cF "MISMATCH Documentation signal (report says Medium; rating Strong maps to Low)" "$TMP/out")"

echo "Test 19: an absent requirement line is 'missing', not 'none'"
report Strong Low "$(printf '%s\n' "$FULL" | grep -v 'screenshots:')" > "$TMP/r19.md"
check "exit 1" 1 "$(run "$TMP/r19.md" "$TMP/f1.json")"
check "reason" 1 "$(grep -cF "MISMATCH Documentation rating (Strong claimed but 'screenshots' evidence is missing; highest supported rung is Adequate)" "$TMP/out")"

echo "Test 20: Documentation is checked per app section (two apps, one mismatched)"
two_apps() { # $1/$2 = root rating/signal, $3/$4 = viewer rating/signal
  report "$1" "$2" "$FULL" | sed '/^## Review scope$/,$d' | sed 's/^## App: X (root)$/## App: SAS (root)/'
  report "$3" "$4" "$SEMIOK" | sed -n '/^## App: X (root)$/,$p' | sed 's/^## App: X (root)$/## App: Viewer (apps\/viewer)/'
}
two_apps Strong Low Adequate Medium > "$TMP/r20.md"
check "two sections" 2 "$(grep -c '^## App:' "$TMP/r20.md")"
check "consistent exit 0" 0 "$(run "$TMP/r20.md" "$TMP/f1.json")"
check "consistent summary" "ratings: consistent" "$(tail -1 "$TMP/out")"
two_apps Strong Low Adequate Low > "$TMP/r20b.md"
check "viewer mismatched exit 1" 1 "$(run "$TMP/r20b.md" "$TMP/f1.json")"
check "viewer signal reason" 1 "$(grep -cF "MISMATCH Documentation signal (report says Low; rating Adequate maps to Medium)" "$TMP/out")"
check "one mismatch only" "ratings: 1 mismatch" "$(tail -1 "$TMP/out")"

echo "Test 21: a stray Security row in the Signals table is ignored (no security rating, R4)"
sed -e 's/^| Portability | Medium | e |$/| Security | High | e |\n| Portability | Medium | e |/' "$TMP/r1.md" > "$TMP/r21.md"
check "stray row present, still exit 0" "1 0" "$(grep -c '^| Security | High | e |$' "$TMP/r21.md") $(run "$TMP/r21.md" "$TMP/f1.json")"

echo "Test 22: a stub README rating is accepted only with a QUA-01 docs-stub FAIL record for the app"
STUB='  - what it launches: none (stub README)
  - prerequisites: none'
report "Minimal — not supported (stub README; see QUA-01)" High "$STUB" > "$TMP/r22.md"
STR01='{"app_id":"root","rule":"STR-01","defect_key":"README.md:readme-not-substantive","aspect":"structure","severity":"high","result":"FAIL","summary":"title and contact line only","evidence":"README.md:1"}'
printf '[{"app_id":"root","rule":"QUA-01","defect_key":"README.md:docs-stub","aspect":"quality","severity":"high","result":"FAIL","summary":"stub","evidence":"README.md:1"},%s]' "$STR01" > "$TMP/f22.json"
check "with the docs-stub record (and, with no facts, the STR-01 record): exit 0" 0 "$(run "$TMP/r22.md" "$TMP/f22.json")"
check "summary" "ratings: consistent" "$(tail -1 "$TMP/out")"
check "without it: exit 1" 1 "$(run "$TMP/r22.md" "$TMP/f1.json")"
check "mismatch as today" 1 "$(grep -cF "MISMATCH Documentation rating (Minimal claimed but 'what it launches' evidence is none; highest supported rung is none)" "$TMP/out")"
sed 's/"app_id":"root"/"app_id":"apps\/other"/' "$TMP/f22.json" > "$TMP/f22b.json"
check "a docs-stub record for another app does not count: exit 1" 1 "$(run "$TMP/r22.md" "$TMP/f22b.json")"
sed 's/docs-stub/docs-minimal/' "$TMP/f22.json" > "$TMP/f22c.json"
check "a docs-minimal record does not count: exit 1" 1 "$(run "$TMP/r22.md" "$TMP/f22c.json")"
sed 's/"result":"FAIL"/"result":"WARN"/' "$TMP/f22.json" > "$TMP/f22d.json"
check "a WARN docs-stub record does not count: exit 1" 1 "$(run "$TMP/r22.md" "$TMP/f22d.json")"
report "Minimal — not supported (stub README; see QUA-01)" Medium "$STUB" > "$TMP/r22e.md"
check "the signal is still checked (Minimal maps to High): exit 1" 1 "$(run "$TMP/r22e.md" "$TMP/f22.json")"
check "signal reason" 1 "$(grep -cF "MISMATCH Documentation signal (report says Medium; rating Minimal maps to High)" "$TMP/out")"
report Minimal High "$STUB" > "$TMP/r22f.md"
check "plain Minimal with the record still fails rule 1: exit 1" 1 "$(run "$TMP/r22f.md" "$TMP/f22.json")"
check "unreadable findings: exit 2" 2 "$(run "$TMP/r22.md" "$TMP/nope.json")"

echo "Test 22b: the stub line is accepted only when the facts say stub"
DOCSTUB='{"app_id":"root","rule":"QUA-01","defect_key":"README.md:docs-stub","aspect":"quality","severity":"high","result":"FAIL","summary":"stub","evidence":"README.md:1"}'
printf '[%s]' "$DOCSTUB" > "$TMP/f22s.json"
mkdir -p "$TMP/pre-stub/root" "$TMP/pre-real/root" "$TMP/pre-old/root" "$TMP/pre-none" "$TMP/pre-bad/root"
printf '{"file": "README.md", "stub": true, "content_line_count": 0}' > "$TMP/pre-stub/root/readme.json"
printf '{"file": "README.md", "stub": false, "content_line_count": 184}' > "$TMP/pre-real/root/readme.json"
printf '{"file": "README.md", "rungs": {}}' > "$TMP/pre-old/root/readme.json"
printf '{"file": ' > "$TMP/pre-bad/root/readme.json"
check "stub: true facts and a docs-stub FAIL record: exit 0" 0 "$(run "$TMP/r22.md" "$TMP/f22s.json" "$TMP/pre-stub")"
check "summary" "ratings: consistent" "$(tail -1 "$TMP/out")"
check "stub: false facts: exit 1" 1 "$(run "$TMP/r22.md" "$TMP/f22.json" "$TMP/pre-real")"
check "stub: false facts: the reason (a STR-01 record does not override the fact)" "MISMATCH root documentation: stub rating but readme.json says the README is not a stub|ratings: 1 mismatch" "$(paste -sd'|' "$TMP/out")"
check "no facts: the STR-01 record decides (absent): exit 1" 1 "$(run "$TMP/r22.md" "$TMP/f22s.json")"
check "no facts, no STR-01 record: the reason" "MISMATCH root documentation: stub rating but no STR-01 readme-not-substantive FAIL record and no readme.json stub fact" "$(head -1 "$TMP/out")"
check "no facts: the STR-01 record decides (present): exit 0" 0 "$(run "$TMP/r22.md" "$TMP/f22.json")"
sed 's/"result":"FAIL","summary":"title/"result":"PASS","summary":"title/' "$TMP/f22.json" > "$TMP/f22p.json"
check "no facts: a STR-01 PASS record does not count: exit 1" 1 "$(run "$TMP/r22.md" "$TMP/f22p.json")"
check "facts written before the stub key: the STR-01 record decides: exit 0|1" "0|1" "$(run "$TMP/r22.md" "$TMP/f22.json" "$TMP/pre-old")|$(run "$TMP/r22.md" "$TMP/f22s.json" "$TMP/pre-old")"
check "a pre-review dir with no readme.json for the app: the STR-01 record decides: exit 0|1" "0|1" "$(run "$TMP/r22.md" "$TMP/f22.json" "$TMP/pre-none")|$(run "$TMP/r22.md" "$TMP/f22s.json" "$TMP/pre-none")"
check "unreadable readme.json: exit 2" 2 "$(run "$TMP/r22.md" "$TMP/f22s.json" "$TMP/pre-bad")"
sed 's/## App: X (root)/## App: X (.)/' "$TMP/r22.md" > "$TMP/r22dot.md"
printf '[%s]' "$(echo "$DOCSTUB" | sed 's/"app_id":"root"/"app_id":"."/')" > "$TMP/f22dot.json"
check "an app written as (.) reads root/readme.json: exit 0|1" "0|1" "$(run "$TMP/r22dot.md" "$TMP/f22dot.json" "$TMP/pre-stub")|$(run "$TMP/r22dot.md" "$TMP/f22dot.json" "$TMP/pre-real")"
check "stub: true facts without a docs-stub record is still rule 1: exit 1" 1 "$(run "$TMP/r22.md" "$TMP/f1.json" "$TMP/pre-stub")"
check "four arguments: exit 2" 2 "$(run "$TMP/r22.md" "$TMP/f22s.json" "$TMP/pre-stub" extra)"
report Adequate Medium "$SEMIOK" > "$TMP/r22g.md"
check "a non-stub rating ignores the facts: exit 0" 0 "$(run "$TMP/r22g.md" "$TMP/f1.json" "$TMP/pre-stub")"

echo "Test 22c: Below minimal is its own rating"
NONE='  - what it launches: README.md:3
  - prerequisites: none
  - installation: none
  - configuration: none
  - known limitations: none
  - troubleshooting: none
  - screenshots: none
  - environment variables: none
  - info panel: none
  - architecture: none'
report "Below minimal" High "$NONE" > "$TMP/r22h.md"
printf '[{"app_id":"root","rule":"QUA-01","defect_key":"README.md:docs-minimal","aspect":"quality","severity":"medium","result":"FAIL","summary":"below minimal","evidence":"README.md:3"}]' > "$TMP/f22h.json"
check "Below minimal, zero supported rungs, a docs-minimal FAIL record: exit 0" 0 "$(run "$TMP/r22h.md" "$TMP/f22h.json" "$TMP/pre-real")"
check "summary" "ratings: consistent" "$(tail -1 "$TMP/out")"
sed 's/"result":"FAIL"/"result":"WARN"/' "$TMP/f22h.json" > "$TMP/f22hw.json"
check "a docs-minimal WARN record does not count (the rubric says FAIL): exit 1" 1 "$(run "$TMP/r22h.md" "$TMP/f22hw.json" "$TMP/pre-real")"
check "without facts too: exit 0" 0 "$(run "$TMP/r22h.md" "$TMP/f22h.json")"
sed 's/"result":"WARN"/"result":"FAIL"/' "$TMP/f22h.json" > "$TMP/f22hf.json"
check "a docs-minimal FAIL record (what the skill writes, as for Minimal): exit 0" 0 "$(run "$TMP/r22h.md" "$TMP/f22hf.json" "$TMP/pre-real")"
check "without the docs-minimal record: exit 1" 1 "$(run "$TMP/r22h.md" "$TMP/f1.json")"
check "reason" "MISMATCH root documentation: Below minimal rating but no QUA-01 docs-minimal FAIL record" "$(head -1 "$TMP/out")"
sed 's/"result":"FAIL"/"result":"PASS"/' "$TMP/f22h.json" > "$TMP/f22i.json"
check "a PASS docs-minimal record does not count: exit 1" 1 "$(run "$TMP/r22h.md" "$TMP/f22i.json")"
report "Below minimal" Medium "$NONE" > "$TMP/r22j.md"
check "Below minimal maps to High: exit 1" 1 "$(run "$TMP/r22j.md" "$TMP/f22h.json")"
check "signal reason" "MISMATCH Documentation signal (report says Medium; rating Below minimal maps to High)" "$(head -1 "$TMP/out")"
report "Minimal" High "$NONE" > "$TMP/r22k.md"
check "Minimal with zero supported rungs: exit 1" 1 "$(run "$TMP/r22k.md" "$TMP/f22h.json")"
check "reason" "MISMATCH Documentation rating (Minimal claimed but 'prerequisites' evidence is none; highest supported rung is none)" "$(head -1 "$TMP/out")"
report "Below Minimal" High "$NONE" > "$TMP/r22l.md"
check "the rating word's case does not matter: exit 0" 0 "$(run "$TMP/r22l.md" "$TMP/f22h.json")"

echo "Test 22d: a rung met by cited content counts as evidence"
CONTENT='  - what it launches: "Llama.cpp WebUI" (intro), README.md:3
  - prerequisites: content: README.md:19
  - installation: none'
report Minimal High "$CONTENT" > "$TMP/r22m.md"
check "prerequisites: content: README.md:19 supports Minimal: exit 0" 0 "$(run "$TMP/r22m.md" "$TMP/f1.json" "$TMP/pre-real")"
BCONTENT='  - what it launches: "Llama.cpp WebUI" (intro), README.md:3
  - **prerequisites:** `content: README.md:19`
  - installation: none'
report Minimal High "$BCONTENT" > "$TMP/r22n.md"
check "bold key, backticked content citation: exit 0" 0 "$(run "$TMP/r22n.md" "$TMP/f1.json")"
report Adequate Medium "$CONTENT" > "$TMP/r22o.md"
check "one content rung does not lift the rating past the next none: exit 1" 1 "$(run "$TMP/r22o.md" "$TMP/f1.json")"

echo "Test 22e: legitimate reports the old rule accepted still pass rule 1 and the stub check"
# The committed corpus reports (the three pr2m ood-sas runs, the Task 6
# containerized-server sample, tillicum): no rule-1 MISMATCH, with their
# own pre-review facts.
for run in ood-sas-36678163506 ood-sas-36678169915 ood-sas-36678176175 sample-containerized-server; do
  D="$SCRIPT_DIR/tests/corpus/$run"
  run "$D/report.md" "$D/findings.json" "$D/pre-review" > /dev/null
  check "$run: no Documentation MISMATCH" 0 "$(grep -cE 'MISMATCH (Documentation|[^ ]+ documentation:)' "$TMP/out")"
done

echo "Test 23: a suggestion check or a maintenance good-practice signal recorded as FAIL is a MISMATCH"
report Strong Low "$FULL" > "$TMP/r23.md"
cat > "$TMP/f23.json" <<'EOF'
[
  {"app_id":"root","rule":"QUA-04","defect_key":"template/script.sh.erb:commented-out-code","aspect":"quality","severity":"info","result":"FAIL","summary":"dead code","evidence":"template/script.sh.erb:12"},
  {"app_id":"root","rule":"MNT-02","defect_key":"releases:no-releases","aspect":"maintenance","severity":"low","result":"FAIL","summary":"no releases","evidence":"releases"}
]
EOF
check "exit 1" 1 "$(run "$TMP/r23.md" "$TMP/f23.json")"
check "QUA-04 line" 1 "$(grep -cF 'MISMATCH root QUA-04 template/script.sh.erb:commented-out-code: suggestion (check dead-code) recorded as FAIL' "$TMP/out")"
check "MNT-02 line" 1 "$(grep -cF 'MISMATCH root MNT-02 releases:no-releases: good-practice signal recorded as FAIL' "$TMP/out")"

echo "Test 24: a target check FAIL and an MNT-01 FAIL are not mismatches"
report Strong Low "$FULL" > "$TMP/r24.md"
cat > "$TMP/f24.json" <<'EOF'
[
  {"app_id":"root","rule":"QUA-03","defect_key":"template/script.sh.erb:no-set-e","aspect":"quality","severity":"low","result":"FAIL","summary":"missing set -e","evidence":"template/script.sh.erb:1"},
  {"app_id":"root","rule":"MNT-01","defect_key":"commits:stale-repo","aspect":"maintenance","severity":"high","result":"FAIL","summary":"stale repo","evidence":"commits"}
]
EOF
check "exit 0" 0 "$(run "$TMP/r24.md" "$TMP/f24.json")"
check "summary" "ratings: consistent" "$(tail -1 "$TMP/out")"

# report() with the Security section replaced wholesale: $1 = doc rating, $2 = documentation
# signal, $3 = evidence block, $4 = the Security section body (between "### Security" and
# the next "### ").
report_sec() {
  report "$1" "$2" "$3" | python3 -c '
import re, sys
text = sys.stdin.read()
body = sys.argv[1]
text = re.sub(r"(?ms)^### Security\n.*?(?=^### )", "### Security\n\n" + body + "\n", text, count=1)
sys.stdout.write(text)
' "$4"
}

echo "Test 25: two WARN security rows under the sentence is a MISMATCH naming the count (the report:80 audit case)"
SEC_TWO_WARN='#### Findings

| Rule | Check | Result | Severity | Tag | Summary | Evidence |
|---|---|---|---|---|---|---|
| OODT-01 | `check: sec-interpolation` | WARN | low | unintentional | text_field interpolated | submit.yml.erb:6 |
| OODT-08 | `check: sec-config-flag` | WARN | info | unintentional | set -x tracing enabled | template/script.sh.erb:19 |

#### Additional observations (review)

No findings.

No tool-detectable issues in the checked tiers.'
report_sec Strong Low "$FULL" "$SEC_TWO_WARN" > "$TMP/r25.md"
check "exit 1" 1 "$(run "$TMP/r25.md" "$TMP/f1.json")"
check "reason" 1 "$(grep -cF 'MISMATCH root security: "No tool-detectable issues in the checked tiers." with 2 FAIL/WARN rows above it' "$TMP/out")"

echo "Test 26: only PASS security rows with the sentence is consistent"
SEC_PASS_ONLY='#### Findings

| Rule | Check | Result | Severity | Tag | Summary | Evidence |
|---|---|---|---|---|---|---|
| OODT-01 | `check: sec-interpolation` | PASS | info | — | quoted scheduler argument | submit.yml.erb:6 |

#### Additional observations (review)

No findings.

No tool-detectable issues in the checked tiers.'
report_sec Strong Low "$FULL" "$SEC_PASS_ONLY" > "$TMP/r26.md"
check "exit 0" 0 "$(run "$TMP/r26.md" "$TMP/f1.json")"
check "summary" "ratings: consistent" "$(tail -1 "$TMP/out")"

echo "Test 27: only PASS security rows with no sentence is consistent (no MISMATCH for missing prose)"
SEC_PASS_NO_SENTENCE='#### Findings

| Rule | Check | Result | Severity | Tag | Summary | Evidence |
|---|---|---|---|---|---|---|
| OODT-01 | `check: sec-interpolation` | PASS | info | — | quoted scheduler argument | submit.yml.erb:6 |

#### Additional observations (review)

No findings.'
report_sec Strong Low "$FULL" "$SEC_PASS_NO_SENTENCE" > "$TMP/r27.md"
check "exit 0" 0 "$(run "$TMP/r27.md" "$TMP/f1.json")"
check "summary" "ratings: consistent" "$(tail -1 "$TMP/out")"

echo "Test 28: the no-candidates form needs no sentence"
SEC_NO_CANDIDATES='security.json lists no candidates; no observations.'
report_sec Strong Low "$FULL" "$SEC_NO_CANDIDATES" > "$TMP/r28.md"
check "exit 0" 0 "$(run "$TMP/r28.md" "$TMP/f1.json")"
check "summary" "ratings: consistent" "$(tail -1 "$TMP/out")"

echo "Test 29: a FAIL row without the sentence, and a table with no Check column (rule uses the second cell), is consistent"
SEC_NO_CHECK_COL='#### Findings

| Rule | Result | Severity | Tag | Summary | Evidence |
|---|---|---|---|---|---|
| OODT-05 | FAIL | high | unintentional | CORS wildcard | template/create_nginx_conf.sh.erb:17 |

#### Additional observations (review)

No findings.'
report_sec Strong Low "$FULL" "$SEC_NO_CHECK_COL" > "$TMP/r29.md"
check "exit 0" 0 "$(run "$TMP/r29.md" "$TMP/f1.json")"
check "summary" "ratings: consistent" "$(tail -1 "$TMP/out")"

echo "Test 30: a Check column in the Findings table must not leak into the Additional observations table's own header"
SEC_MIXED_TABLES='#### Findings

| Rule | Check | Result | Severity | Tag | Summary | Evidence |
|---|---|---|---|---|---|---|
| OODT-01 | `check: sec-interpolation` | PASS | info | — | quoted scheduler argument | submit.yml.erb:6 |

#### Additional observations (review)

| Rule | Result | Severity | Tag | Summary | Evidence |
|---|---|---|---|---|---|
| OODT-06 | FAIL | high | unintentional | bad thing found on the open-ended pass | submit.yml.erb:9 |'
report_sec Strong Low "$FULL" "$SEC_MIXED_TABLES" > "$TMP/r30.md"
check "no sentence: exit 0" 0 "$(run "$TMP/r30.md" "$TMP/f1.json")"
check "no sentence: summary" "ratings: consistent" "$(tail -1 "$TMP/out")"
report_sec Strong Low "$FULL" "$SEC_MIXED_TABLES
No tool-detectable issues in the checked tiers." > "$TMP/r30b.md"
check "with sentence: exit 1" 1 "$(run "$TMP/r30b.md" "$TMP/f1.json")"
check "with sentence: reason" 1 "$(grep -cF 'MISMATCH root security: "No tool-detectable issues in the checked tiers." with 1 FAIL/WARN row above it' "$TMP/out")"

echo "Test 31: a bare '---' prose divider after an OODT row is not mistaken for a table separator"
SEC_BARE_RULE='#### Findings

| Rule | Check | Result | Severity | Tag | Summary | Evidence |
|---|---|---|---|---|---|---|
| OODT-01 | `check: sec-interpolation` | FAIL | high | unintentional | bad thing | submit.yml.erb:6 |

---

Some prose divider, not a table.

No tool-detectable issues in the checked tiers.'
report_sec Strong Low "$FULL" "$SEC_BARE_RULE" > "$TMP/r31.md"
check "exit 1" 1 "$(run "$TMP/r31.md" "$TMP/f1.json")"
check "reason" 1 "$(grep -cF 'MISMATCH root security: "No tool-detectable issues in the checked tiers." with 1 FAIL/WARN row above it' "$TMP/out")"

echo "Test 32: a tool-finding row under a QUA-xx rule, an emphasised OODT cell and the sentence without its period all count"
SEC_QUA_TOOL='#### Findings

| Rule | Check | Result | Severity | Tag | Summary | Evidence |
|---|---|---|---|---|---|---|
| QUA-03 | `check: sec-tool-finding` | WARN | low | — | SC2164: cd without an exit check | template/script.sh.erb:22 |

No tool-detectable issues in the checked tiers.'
report_sec Strong Low "$FULL" "$SEC_QUA_TOOL" > "$TMP/r32.md"
check "QUA-03 WARN tool row: exit 1" 1 "$(run "$TMP/r32.md" "$TMP/f1.json")"
check "QUA-03 WARN tool row: reason" 'MISMATCH root security: "No tool-detectable issues in the checked tiers." with 1 FAIL/WARN row above it' "$(head -1 "$TMP/out")"
SEC_BOLD_CELL='| Rule | Check | Result | Severity | Tag | Summary | Evidence |
|---|---|---|---|---|---|---|
| **OODT-01** | `check: sec-interpolation` | **FAIL** | high | unintentional | bad thing | submit.yml.erb:6 |

No tool-detectable issues in the checked tiers.'
report_sec Strong Low "$FULL" "$SEC_BOLD_CELL" > "$TMP/r32b.md"
check "**OODT-01** cell: exit 1" 1 "$(run "$TMP/r32b.md" "$TMP/f1.json")"
report_sec Strong Low "$FULL" "${SEC_TWO_WARN%.}" > "$TMP/r32c.md"
check "sentence without its period: exit 1" 1 "$(run "$TMP/r32c.md" "$TMP/f1.json")"
report_sec Strong Low "$FULL" "${SEC_TWO_WARN%No tool-detectable issues in the checked tiers.}**No tool-detectable issues in the
checked tiers.**" > "$TMP/r32d.md"
check "sentence bolded and wrapped: exit 1" 1 "$(run "$TMP/r32d.md" "$TMP/f1.json")"
SEC_QUA_PASS='| Rule | Check | Result | Severity | Tag | Summary | Evidence |
|---|---|---|---|---|---|---|
| — | `check: sec-tool-finding` | PASS | info | — | SC2148 on a sourced before.sh fragment: an artefact | template/before.sh.erb:1 |
| QUA-03 | `check: sec-tool-finding` | PASS | info | — | SC2086 reviewed: the value is an integer | template/script.sh.erb:30 |

No tool-detectable issues in the checked tiers.'
report_sec Strong Low "$FULL" "$SEC_QUA_PASS" > "$TMP/r32e.md"
check "PASS tool rows (any rule cell) with the sentence: exit 0" 0 "$(run "$TMP/r32e.md" "$TMP/f1.json")"
SEC_LOWERCASE="${SEC_TWO_WARN%No tool-detectable issues in the checked tiers.}no tool-detectable issues in the checked tiers."
report_sec Strong Low "$FULL" "$SEC_LOWERCASE" > "$TMP/r32f.md"
check "sentence in lowercase: exit 1" 1 "$(run "$TMP/r32f.md" "$TMP/f1.json")"
check "sentence in lowercase: reason" 1 "$(grep -cF 'MISMATCH root security: "No tool-detectable issues in the checked tiers." with 2 FAIL/WARN rows above it' "$TMP/out")"
SEC_NBHYPHEN="${SEC_TWO_WARN%No tool-detectable issues in the checked tiers.}No tool\xe2\x80\x91detectable issues in the checked tiers."
printf '%b' "$SEC_NBHYPHEN" > "$TMP/nbh.txt"
report_sec Strong Low "$FULL" "$(cat "$TMP/nbh.txt")" > "$TMP/r32g.md"
check "sentence with a non-breaking hyphen (U+2011): exit 1" 1 "$(run "$TMP/r32g.md" "$TMP/f1.json")"

echo "Test 33: a suggestion check matches any tag in its tags list; a tag of the same rule it does not own does not match"
report Strong Low "$FULL" > "$TMP/r33.md"
cat > "$TMP/f33.json" <<'EOF'
[
  {"app_id":"root","rule":"QUA-08","defect_key":"form.yml:undocumented-resource-limit","aspect":"quality","severity":"info","result":"FAIL","summary":"x","evidence":"form.yml:3"},
  {"app_id":"root","rule":"QUA-04","defect_key":"template/script.sh.erb:dead-branch","aspect":"quality","severity":"info","result":"FAIL","summary":"x","evidence":"template/script.sh.erb:6"},
  {"app_id":"root","rule":"QUA-06","defect_key":"form.yml:duplicate-yaml-key:x","aspect":"quality","severity":"low","result":"FAIL","summary":"x","evidence":"form.yml:6"},
  {"app_id":"root","rule":"QUA-02","defect_key":"form.yml:hardcoded-cluster","aspect":"quality","severity":"low","result":"FAIL","summary":"x","evidence":"form.yml:3"},
  {"app_id":"root","rule":"QUA-01","defect_key":"README.md:docs-minimal","aspect":"quality","severity":"low","result":"FAIL","summary":"x","evidence":"README.md:1"}
]
EOF
check "exit 1" 1 "$(run "$TMP/r33.md" "$TMP/f33.json")"
check "QUA-08 undocumented-resource-limit is in magic-numbers' tags" 1 "$(grep -cxF 'MISMATCH root QUA-08 form.yml:undocumented-resource-limit: suggestion (check magic-numbers) recorded as FAIL' "$TMP/out")"
check "QUA-04 dead-branch is in dead-code's tags" 1 "$(grep -cxF 'MISMATCH root QUA-04 template/script.sh.erb:dead-branch: suggestion (check dead-code) recorded as FAIL' "$TMP/out")"
check "QUA-06 duplicate-yaml-key (a correctness defect) is not a suggestion" 0 "$(grep -c 'duplicate-yaml-key' "$TMP/out")"
check "only those two" "ratings: 2 mismatches" "$(tail -1 "$TMP/out")"
mkdir -p "$TMP/refs2"
cp "$CHECK" "$SCRIPT_DIR/references/report_parse.py" "$SCRIPT_DIR/references/readme_lines.py" "$TMP/refs2/"
cat > "$TMP/refs2/checks.json" <<'EOF'
{"checks":[
 {"id":"magic-numbers","rule":"QUA-08","tag":"magic-number","weight":"suggestion"},
 {"id":"resource-limits","rule":"QUA-08","tag":"undocumented-resource-limit","weight":"target"}
]}
EOF
python3 "$TMP/refs2/check-rating.py" "$TMP/r33.md" "$TMP/f33.json" > "$TMP/out" 2>&1
check "checks with no tags list fall back to their single tag: the target tag is not a suggestion" "ratings: consistent" "$(tail -1 "$TMP/out")"
printf '[{"app_id":"root","rule":"QUA-08","defect_key":"form.yml:magic-number","result":"FAIL","evidence":"form.yml:4"}]' > "$TMP/f33b.json"
python3 "$TMP/refs2/check-rating.py" "$TMP/r33.md" "$TMP/f33b.json" > "$TMP/out" 2>&1
check "two QUA-08 checks: the suggestion tag still matches" 1 "$(grep -cxF 'MISMATCH root QUA-08 form.yml:magic-number: suggestion (check magic-numbers) recorded as FAIL' "$TMP/out")"

echo "Test 34: an unreadable checks.json is exit 2, never a silent pass"
rm "$TMP/refs2/checks.json"
python3 "$TMP/refs2/check-rating.py" "$TMP/r33.md" "$TMP/f33.json" > "$TMP/out" 2>&1
check "missing: exit 2" 2 "$?"
check "missing: the error line" "error: cannot load references/checks.json (No such file or directory)" "$(cat "$TMP/out")"
printf '{"checks": [' > "$TMP/refs2/checks.json"
python3 "$TMP/refs2/check-rating.py" "$TMP/r33.md" "$TMP/f33.json" > "$TMP/out" 2>&1
check "corrupt: exit 2" 2 "$?"
check "corrupt: the error line" 1 "$(grep -c '^error: cannot load references/checks.json (Expecting value: line 1 column 13 (char 12))$' "$TMP/out")"
printf '{"rules": []}' > "$TMP/refs2/checks.json"
python3 "$TMP/refs2/check-rating.py" "$TMP/r33.md" "$TMP/f33.json" > "$TMP/out" 2>&1
check "no checks list: the error line" "error: cannot load references/checks.json (no checks list)" "$(cat "$TMP/out")"

echo "Test 35: one content: line may not meet two rung requirements"
REUSE='  - what it launches: content: README.md:3
  - prerequisites: content: README.md:7
  - installation: content: README.md:7
  - configuration: README.md:99
  - known limitations: README.md:200'
report Adequate Medium "$REUSE" > "$TMP/r35.md"
check "exit 1" 1 "$(run "$TMP/r35.md" "$TMP/f1.json")"
check "reason" "MISMATCH root documentation: content line README.md:7 cited for two rungs (prerequisites, installation)|ratings: 1 mismatch" "$(paste -sd'|' "$TMP/out")"
DISTINCT='  - what it launches: content: README.md:3
  - prerequisites: content: README.md:7
  - installation: content: README.md:9
  - configuration: README.md:99
  - known limitations: README.md:200'
report Adequate Medium "$DISTINCT" > "$TMP/r35b.md"
check "distinct content lines: exit 0" 0 "$(run "$TMP/r35b.md" "$TMP/f1.json")"

echo "Test 36: Below minimal on a README the facts call a stub is a MISMATCH"
check "stub: true facts: exit 1" 1 "$(run "$TMP/r22h.md" "$TMP/f22h.json" "$TMP/pre-stub")"
check "stub: true facts: reason" "MISMATCH root documentation: Below minimal rating but readme.json says the README is a stub (the stub line applies)" "$(head -1 "$TMP/out")"

echo "Test 37: the repo-level gate table's STR-01 README row must be FAIL iff readme.json says stub"
gate_readme_row() { # $1 = report file, $2 = Result cell, writes to stdout
  awk -v result="$2" '
    { print }
    /^\| Rule \| Result \| Evidence \|$/ { header = 1; next }
    header == 1 { print "| STR-01 | " result " | README.md — present and substantive (184 content lines, 11,971 characters, no placeholder text) |"; header = 0 }
  ' "$1"
}
report Strong Low "$FULL" > "$TMP/r37base.md"
gate_readme_row "$TMP/r37base.md" FAIL > "$TMP/r37fail.md"
gate_readme_row "$TMP/r37base.md" PASS > "$TMP/r37pass.md"
check "README gate row present (FAIL variant)" 1 "$(grep -cF '| STR-01 | FAIL | README.md' "$TMP/r37fail.md")"

check "(a) FAIL with stub:false: exit 1" 1 "$(run "$TMP/r37fail.md" "$TMP/f1.json" "$TMP/pre-real")"
check "(a) FAIL with stub:false: the exact line" "MISMATCH root STR-01 README gate: FAIL but readme.json says stub: false" "$(head -1 "$TMP/out")"

check "(b) PASS with stub:false: exit 0" 0 "$(run "$TMP/r37pass.md" "$TMP/f1.json" "$TMP/pre-real")"

check "(c) FAIL with stub:true: exit 0" 0 "$(run "$TMP/r37fail.md" "$TMP/f1.json" "$TMP/pre-stub")"

check "(d) PASS with stub:true: exit 1" 1 "$(run "$TMP/r37pass.md" "$TMP/f1.json" "$TMP/pre-stub")"
check "(d) PASS with stub:true: the exact line" "MISMATCH root STR-01 README gate: PASS but readme.json says stub: true" "$(head -1 "$TMP/out")"

check "(e) no pre-review dir: exit 0 regardless (FAIL row)" 0 "$(run "$TMP/r37fail.md" "$TMP/f1.json")"
check "(e) no pre-review dir: exit 0 regardless (PASS row)" 0 "$(run "$TMP/r37pass.md" "$TMP/f1.json")"

# Must-not: a legitimate report (README PASS, no stub) is never flagged by rule 5.
check "legitimate report untouched: exit 0" 0 "$(run "$TMP/r37pass.md" "$TMP/f1.json" "$TMP/pre-real")"

# A LICENSE STR-01 row is not the README row and must not trigger rule 5.
awk '{ print } /^\| STR-01 \| PASS \| README\.md/ { print "| STR-01 | FAIL | LICENSE — no LICENSE file found in the repository root |" }' \
  "$TMP/r37pass.md" > "$TMP/r37license.md"
check "LICENSE STR-01 row present" 1 "$(grep -cF '| STR-01 | FAIL | LICENSE' "$TMP/r37license.md")"
check "LICENSE row ignored, README row consistent: exit 0" 0 "$(run "$TMP/r37license.md" "$TMP/f1.json" "$TMP/pre-real")"

# readme.json with no stub key (pre-old, from Test 22b) does nothing.
check "readme.json with no stub key: exit 0 regardless" 0 "$(run "$TMP/r37fail.md" "$TMP/f1.json" "$TMP/pre-old")"

echo "Test 38: a suggestion check FAIL or WARN rated above info is a MISMATCH; info, a target check and PASS are not"
report Strong Low "$FULL" > "$TMP/r38.md"
cat > "$TMP/f38.json" <<'EOF'
[
  {"app_id":"root","rule":"QUA-08","defect_key":"template/script.sh.erb:undocumented-hex-color","aspect":"quality","severity":"low","result":"WARN","summary":"x","evidence":"template/script.sh.erb:4"},
  {"app_id":"root","rule":"QUA-09","defect_key":"template/script.sh.erb:duplicated-block","aspect":"quality","severity":"Medium","result":"WARN","summary":"x","evidence":"template/script.sh.erb:10"},
  {"app_id":"root","rule":"QUA-04","defect_key":"template/script.sh.erb:commented-out-code","aspect":"quality","severity":"low","result":"FAIL","summary":"x","evidence":"template/script.sh.erb:12"},
  {"app_id":"root","rule":"QUA-10","defect_key":"submit.yml.erb:erb-missing-value-unhandled","aspect":"quality","severity":"info","result":"WARN","summary":"x","evidence":"submit.yml.erb:3"},
  {"app_id":"root","rule":"QUA-06","defect_key":"template/desktop.xml:icon-os-mismatch","aspect":"quality","severity":"low","result":"PASS","summary":"x","evidence":"template/desktop.xml:2"},
  {"app_id":"root","rule":"QUA-07","defect_key":"form.yml:missing-pattern","aspect":"quality","severity":"low","result":"WARN","summary":"x","evidence":"form.yml:3"},
  {"app_id":"root","rule":"QUA-06","defect_key":"form.yml:duplicate-yaml-key:x","aspect":"quality","severity":"low","result":"WARN","summary":"x","evidence":"form.yml:6"}
]
EOF
check "exit 1" 1 "$(run "$TMP/r38.md" "$TMP/f38.json")"
check "QUA-08 hex colour WARN low" 1 "$(grep -cxF 'MISMATCH root QUA-08 template/script.sh.erb:undocumented-hex-color: suggestion (check magic-numbers) rated low; suggestions are info' "$TMP/out")"
check "QUA-09 WARN Medium (case-insensitive)" 1 "$(grep -cxF 'MISMATCH root QUA-09 template/script.sh.erb:duplicated-block: suggestion (check duplicated-blocks) rated medium; suggestions are info' "$TMP/out")"
check "QUA-04 FAIL low: the severity line" 1 "$(grep -cxF 'MISMATCH root QUA-04 template/script.sh.erb:commented-out-code: suggestion (check dead-code) rated low; suggestions are info' "$TMP/out")"
check "QUA-04 FAIL low: the FAIL line too" 1 "$(grep -cxF 'MISMATCH root QUA-04 template/script.sh.erb:commented-out-code: suggestion (check dead-code) recorded as FAIL' "$TMP/out")"
check "a suggestion WARN at info is fine" 0 "$(grep -c 'erb-missing-value-unhandled' "$TMP/out")"
check "a suggestion PASS is not judged on severity" 0 "$(grep -c 'icon-os-mismatch' "$TMP/out")"
check "a target check WARN low is fine" 0 "$(grep -c missing-pattern "$TMP/out")"
check "a QUA-06 correctness tag the icon check does not own is fine" 0 "$(grep -c 'duplicate-yaml-key' "$TMP/out")"
check "only those four" "ratings: 4 mismatches" "$(tail -1 "$TMP/out")"

echo "Test 39: the rating starts from readme.json's baseline; lower only with a stated reason, never above"
# rf <dir> <rungs met, comma list> [screenshots] [env]: a readme.json whose rungs entries are headings
rf() { mkdir -p "$1/root"; python3 - "$1/root/readme.json" "$2" <<'PY'
import json, sys
all_rungs = ["what it launches", "prerequisites", "installation", "configuration", "known limitations",
             "troubleshooting", "screenshots", "environment variables", "info panel", "architecture"]
met = [r for r in sys.argv[2].split(",") if r]
rungs = {r: ({"heading": r, "line": 10 + i, "placeholder": False, "match": "heading"} if r in met else None)
         for i, r in enumerate(all_rungs)}
json.dump({"file": "README.md", "stub": False, "rungs": rungs, "screenshots": [], "env_vars": []}, open(sys.argv[1], "w"))
PY
}
STRONG_FACTS="what it launches,prerequisites,installation,configuration,known limitations,troubleshooting,screenshots,environment variables"
rf "$TMP/pre-strong" "$STRONG_FACTS"
NOTROUBLE='  - what it launches: README.md:27
  - prerequisites: README.md:65
  - installation: README.md:84
  - configuration: README.md:99
  - known limitations: README.md:200
  - troubleshooting: none (the section describes a different app)
  - screenshots: README.md:39
  - environment variables: README.md:120
  - info panel: none
  - architecture: none'
report Strong Low "$FULL" > "$TMP/r39a.md"
check "(a) rating equals the baseline: exit 0" 0 "$(run "$TMP/r39a.md" "$TMP/f1.json" "$TMP/pre-strong")"
check "(a) baseline met: consistent" "ratings: consistent" "$(tail -1 "$TMP/out")"
report "Adequate (lowered from Strong: the Troubleshooting section describes a different app)" Medium "$NOTROUBLE" > "$TMP/r39b.md"
check "(b) lowered with a reason: exit 0" 0 "$(run "$TMP/r39b.md" "$TMP/f1.json" "$TMP/pre-strong")"
report Adequate Medium "$NOTROUBLE" > "$TMP/r39c.md"
check "(c) lowered without a reason: exit 1" 1 "$(run "$TMP/r39c.md" "$TMP/f1.json" "$TMP/pre-strong")"
check "(c) the line" "MISMATCH root documentation: rated Adequate below the readme.json baseline Strong with no reason (write '(lowered from Strong: <reason>)' on the rating line)" "$(head -1 "$TMP/out")"
report "Adequate (lowered from Strong: )" Medium "$NOTROUBLE" > "$TMP/r39d.md"
check "(d) an empty reason is no reason: exit 1" 1 "$(run "$TMP/r39d.md" "$TMP/f1.json" "$TMP/pre-strong")"
report "Adequate (lowered from Exemplary: thin troubleshooting)" Medium "$NOTROUBLE" > "$TMP/r39e.md"
check "(e) naming a rung other than the baseline: exit 1" 1 "$(run "$TMP/r39e.md" "$TMP/f1.json" "$TMP/pre-strong")"
check "(e) the line" "MISMATCH root documentation: lowered from Exemplary but the readme.json baseline is Strong" "$(head -1 "$TMP/out")"
report "Strong (lowered from Strong: no reason really)" Low "$FULL" > "$TMP/r39f.md"
check "(f) a lowering clause on a rating at the baseline: exit 1" 1 "$(run "$TMP/r39f.md" "$TMP/f1.json" "$TMP/pre-strong")"
check "(f) the line" "MISMATCH root documentation: rated Strong with a lowering clause but the readme.json baseline is Strong" "$(head -1 "$TMP/out")"
rf "$TMP/pre-adequate" "what it launches,prerequisites,installation,configuration,known limitations,screenshots,environment variables"
check "(g) above the baseline on a heading citation the facts do not meet: exit 1" 1 "$(run "$TMP/r39a.md" "$TMP/f1.json" "$TMP/pre-adequate")"
check "(g) the line" "MISMATCH root documentation: rated Strong above the readme.json baseline Adequate; 'troubleshooting' is not met in readme.json and its evidence is not a content: line" "$(head -1 "$TMP/out")"
sed 's|troubleshooting: README.md:159|troubleshooting: content: README.md:159|' "$TMP/r39a.md" > "$TMP/r39h.md"
check "(h) above the baseline where a content: line delivers the missing rung: exit 0" 0 "$(run "$TMP/r39h.md" "$TMP/f1.json" "$TMP/pre-adequate")"
report Strong Low "$NOENV" > "$TMP/r39i.md"
check "(i) above the evidence ceiling is still the ceiling MISMATCH, once" "MISMATCH Documentation rating (Strong claimed but 'environment variables' evidence is none; highest supported rung is Adequate)|ratings: 1 mismatch" "$(run "$TMP/r39i.md" "$TMP/f1.json" "$TMP/pre-strong" >/dev/null; paste -sd'|' "$TMP/out")"
report "Below minimal (lowered from Strong: every section is copied from another site's app)" High "$NOTROUBLE" > "$TMP/r39j.md"
DOCMIN='[{"app_id":"root","rule":"QUA-01","defect_key":"README.md:docs-minimal","aspect":"quality","severity":"low","result":"FAIL","summary":"x","evidence":"README.md:1"}]'
echo "$DOCMIN" > "$TMP/f39j.json"
check "(j) Below minimal lowered from the baseline with a reason: exit 0" 0 "$(run "$TMP/r39j.md" "$TMP/f39j.json" "$TMP/pre-strong")"
report "Below minimal" High "$NOTROUBLE" > "$TMP/r39k.md"
check "(k) Below minimal under a Strong baseline with no reason: exit 1" 1 "$(run "$TMP/r39k.md" "$TMP/f39j.json" "$TMP/pre-strong")"
mkdir -p "$TMP/pre-lists/root"
printf '{"file":"README.md","stub":false,"rungs":{"what it launches":{"line":1,"placeholder":false},"prerequisites":{"line":2,"placeholder":false},"installation":{"line":3,"placeholder":false},"configuration":{"line":4,"placeholder":false},"known limitations":{"line":5,"placeholder":false},"troubleshooting":{"line":6,"placeholder":false},"screenshots":null,"environment variables":null},"screenshots":[{"line":39}],"env_vars":[{"line":120,"match":"assignment"}]}' > "$TMP/pre-lists/root/readme.json"
check "(l) screenshots and env_vars content entries meet their rungs: Strong baseline, exit 0" 0 "$(run "$TMP/r39a.md" "$TMP/f1.json" "$TMP/pre-lists")"
mkdir -p "$TMP/pre-lists2/root"
sed 's/"troubleshooting":{"line":6,"placeholder":false}/"troubleshooting":{"line":6,"placeholder":true}/' "$TMP/pre-lists/root/readme.json" > "$TMP/pre-lists2/root/readme.json"
check "(m) a placeholder rung is not met by the facts: Strong is above the Adequate baseline, exit 1" 1 "$(run "$TMP/r39a.md" "$TMP/f1.json" "$TMP/pre-lists2")"
check "(m) the line names troubleshooting" 1 "$(grep -c "above the readme.json baseline Adequate; 'troubleshooting'" "$TMP/out")"
check "(n) facts with no rungs (pre-real): rule 6 does nothing, exit 0" 0 "$(run "$TMP/r39c.md" "$TMP/f1.json" "$TMP/pre-real")"
check "(o) no pre-review directory: rule 6 does nothing, exit 0" 0 "$(run "$TMP/r39c.md" "$TMP/f1.json")"

echo; echo "Done: $pass passed, $fail failed."; [ "$fail" -eq 0 ]
