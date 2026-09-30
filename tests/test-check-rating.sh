#!/usr/bin/env bash
# Test check-rating.py: Documentation rating follows its evidence lines; Documentation signal follows the rating;
# a suggestion-class check or an MNT-02..MNT-06 good-practice signal recorded as FAIL is a mismatch.
# Only Documentation is checked among ratings/signals (no security rating, design R4); the findings JSON is also
# read for a stub README rating (QUA-01 docs-stub) and for the suggestion/good-practice FAIL scan (rule 3).
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CHECK="$SCRIPT_DIR/references/check-rating.py"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0
check() { local name="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then echo "  PASS  $name"; pass=$((pass+1)); else echo "  FAIL  $name: expected '$expected', got '$actual'"; fail=$((fail+1)); fi; }
run() { python3 "$CHECK" "$1" "$2" > "$TMP/out" 2>&1; echo $?; }

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
check "exit 2" 2 "$(run "$TMP/r9.md" "$TMP/f1.json")"

echo "Test 10: signal() must not read a findings-table row whose first cell is Documentation"
# Signals table has no Documentation row; a findings table below it has a row starting
# "| Documentation | Low | …" that must not be misread as the Signals-table Documentation level.
sed -e '/^| Documentation | Low | e |$/d' \
    -e 's/^|---|---|---|---|---|---|$/|---|---|---|---|---|---|\n| Documentation | Low | medium | DOC-01 | s | e |/' \
    "$TMP/r1.md" > "$TMP/r10.md"
check "findings-table decoy row present" 1 "$(grep -c '^| Documentation | Low | medium | DOC-01 | s | e |$' "$TMP/r10.md")"
check "exit 2 (missing Signals row, not misread)" 2 "$(run "$TMP/r10.md" "$TMP/f1.json")"
check "error names Documentation" 1 "$(grep -c "has no Signals row for Documentation" "$TMP/out")"

echo "Test 11: missing '### Signals' section entirely is exit 2"
grep -v "^### Signals$" "$TMP/r1.md" | sed '/^| Dimension | Level | Evidence |$/d; /^|---|---|---|$/d; /^| Portability | Medium | e |$/d; /^| Documentation | Low | e |$/d' > "$TMP/r11.md"
check "exit 2" 2 "$(run "$TMP/r11.md" "$TMP/f1.json")"
check "error names Signals section" 1 "$(grep -c "has no '### Signals' section" "$TMP/out")"

echo "Test 12: Signals table present but missing the Documentation row is exit 2"
grep -v "^| Documentation | Low | e |$" "$TMP/r1.md" > "$TMP/r12.md"
check "exit 2" 2 "$(run "$TMP/r12.md" "$TMP/f1.json")"
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
printf '[{"app_id":"root","rule":"QUA-01","defect_key":"README.md:docs-stub","aspect":"quality","severity":"high","result":"FAIL","summary":"stub","evidence":"README.md:1"}]' > "$TMP/f22.json"
check "with the docs-stub record: exit 0" 0 "$(run "$TMP/r22.md" "$TMP/f22.json")"
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

echo "Test 23: a suggestion check or a maintenance good-practice signal recorded as FAIL is a MISMATCH"
report Strong Low "$FULL" > "$TMP/r23.md"
cat > "$TMP/f23.json" <<'EOF'
[
  {"app_id":"root","rule":"QUA-04","defect_key":"template/script.sh.erb:commented-out-code","aspect":"quality","severity":"low","result":"FAIL","summary":"dead code","evidence":"template/script.sh.erb:12"},
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

echo "Test 27: only PASS security rows with no sentence is a MISMATCH"
SEC_PASS_NO_SENTENCE='#### Findings

| Rule | Check | Result | Severity | Tag | Summary | Evidence |
|---|---|---|---|---|---|---|
| OODT-01 | `check: sec-interpolation` | PASS | info | — | quoted scheduler argument | submit.yml.erb:6 |

#### Additional observations (review)

No findings.'
report_sec Strong Low "$FULL" "$SEC_PASS_NO_SENTENCE" > "$TMP/r27.md"
check "exit 1" 1 "$(run "$TMP/r27.md" "$TMP/f1.json")"
check "reason" 1 "$(grep -cF 'MISMATCH root security: no FAIL/WARN rows but the sentence "No tool-detectable issues in the checked tiers." is missing' "$TMP/out")"

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

echo; echo "Done: $pass passed, $fail failed."; [ "$fail" -eq 0 ]
