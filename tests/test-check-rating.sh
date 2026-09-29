#!/usr/bin/env bash
# Test check-rating.py: Documentation rating follows its evidence lines; Security signal follows the findings.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CHECK="$SCRIPT_DIR/references/check-rating.py"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0
check() { local name="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then echo "  PASS  $name"; pass=$((pass+1)); else echo "  FAIL  $name: expected '$expected', got '$actual'"; fail=$((fail+1)); fi; }
run() { python3 "$CHECK" "$1" "$2" > "$TMP/out" 2>&1; echo $?; }

report() { # $1 = doc rating, $2 = security signal, $3 = documentation signal, $4 = evidence block (bullet form)
cat <<EOF
# Appverse Review: x

## Repo-level gate criteria

| Rule | Result | Evidence |
|---|---|---|

## App: X (root)

### Signals

| Dimension | Level | Evidence |
|---|---|---|
| Security | $2 | e |
| Portability | Medium | e |
| Documentation | $3 | e |

### Structure
No findings.

### Security

#### Findings

| Rule | Result | Severity | Tag | Summary | Evidence |
|---|---|---|---|---|---|

### Portability
- Rating: **Partially portable** — x

### Documentation
- Rating: **$1** — x
- Evidence per rung:
$4

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
sec() { printf '{"app_id":"root","rule":"OODT-01","defect_key":"submit.yml.erb:unsanitized-user-input","aspect":"security","severity":"%s","result":"%s","summary":"s","evidence":"submit.yml.erb:15"}' "$1" "$2"; }

echo "Test 1: consistent report passes"
report Strong Low Low "$FULL" > "$TMP/r1.md"; echo '[]' > "$TMP/f1.json"
check "exit 0" 0 "$(run "$TMP/r1.md" "$TMP/f1.json")"
check "summary" "ratings: consistent" "$(tail -1 "$TMP/out")"

echo "Test 2: Strong claimed with environment variables = none (the 2026-09-28 sonnet-1 case)"
report Strong Low Low "$NOENV" > "$TMP/r2.md"
check "exit 1" 1 "$(run "$TMP/r2.md" "$TMP/f1.json")"
check "mismatch names the rung" 1 "$(grep -c "MISMATCH Documentation rating (Strong claimed but 'environment variables' evidence is none; highest supported rung is Adequate)" "$TMP/out")"

echo "Test 3: rungs are cumulative (known limitations none caps at Minimal even with Strong-rung evidence)"
report Strong Low Low "$SEMI" > "$TMP/r3.md"
check "exit 1" 1 "$(run "$TMP/r3.md" "$TMP/f1.json")"
check "caps at Minimal" 1 "$(grep -c "highest supported rung is Minimal" "$TMP/out")"

echo "Test 4: semicolon (template) form parses when consistent"
SEMIOK='  what it launches: README.md:27; prerequisites: README.md:65; installation: README.md:84;
  configuration: README.md:99; known limitations: README.md:200;
  troubleshooting: none; screenshots: none; environment variables: none;
  info panel: none; architecture: none'
report Adequate Low Medium "$SEMIOK" > "$TMP/r4.md"
check "exit 0" 0 "$(run "$TMP/r4.md" "$TMP/f1.json")"

echo "Test 5: Security signal Low but a Low OODT finding exists (should be Medium)"
report Adequate Low Medium "$FULL" > "$TMP/r5.md"; printf '[%s]' "$(sec low WARN)" > "$TMP/f5.json"
check "exit 1" 1 "$(run "$TMP/r5.md" "$TMP/f5.json")"
check "reason" 1 "$(grep -c "MISMATCH Security signal (report says Low; findings derive Medium: 1 OODT finding, highest severity low)" "$TMP/out")"

echo "Test 6: Security signal Medium but a medium OODT finding exists (should be High)"
report Adequate Medium Medium "$FULL" > "$TMP/r6.md"; printf '[%s]' "$(sec medium FAIL)" > "$TMP/f6.json"
check "exit 1" 1 "$(run "$TMP/r6.md" "$TMP/f6.json")"

echo "Test 7: PASS and NOT CHECKED security records do not count"
report Adequate Low Medium "$FULL" > "$TMP/r7.md"; printf '[%s,%s]' "$(sec low PASS)" "$(sec medium 'NOT CHECKED')" > "$TMP/f7.json"
check "exit 0" 0 "$(run "$TMP/r7.md" "$TMP/f7.json")"

echo "Test 8: Documentation signal disagrees with the rating (Adequate must be Medium)"
report Adequate Low Low "$FULL" > "$TMP/r8.md"
check "exit 1" 1 "$(run "$TMP/r8.md" "$TMP/f1.json")"
check "reason" 1 "$(grep -c "MISMATCH Documentation signal (report says Low; rating Adequate maps to Medium)" "$TMP/out")"

echo "Test 9: no Documentation section is exit 2"
grep -v "^### Documentation" "$TMP/r1.md" | grep -v "Rating: \*\*Strong" > "$TMP/r9.md"
check "exit 2" 2 "$(run "$TMP/r9.md" "$TMP/f1.json")"

echo "Test 10: signal() must not read a findings-table row whose first cell is Security/Documentation"
# Signals table has no Security row (blank Level cell removed entirely); the Security findings
# table below it has a row starting "| Security | High | medium | OODT-01 | s | e |" that must
# not be misread as the Signals-table Security level.
sed -e 's/^| Security | Low | e |$//' \
    -e 's/^|---|---|---|---|---|---|$/|---|---|---|---|---|---|\n| Security | High | medium | OODT-01 | s | e |/' \
    "$TMP/r1.md" > "$TMP/r10.md"
check "exit 2 (missing Signals row, not misread)" 2 "$(run "$TMP/r10.md" "$TMP/f1.json")"
check "error names Security" 1 "$(grep -c "has no Signals row for Security" "$TMP/out")"

echo "Test 11: missing '### Signals' section entirely is exit 2"
grep -v "^### Signals$" "$TMP/r1.md" | sed '/^| Dimension | Level | Evidence |$/d; /^|---|---|---|$/d; /^| Security | Low | e |$/d; /^| Portability | Medium | e |$/d; /^| Documentation | Low | e |$/d' > "$TMP/r11.md"
check "exit 2" 2 "$(run "$TMP/r11.md" "$TMP/f1.json")"
check "error names Signals section" 1 "$(grep -c "has no '### Signals' section" "$TMP/out")"

echo "Test 12: Signals table present but missing the Documentation row is exit 2"
grep -v "^| Documentation | Low | e |$" "$TMP/r1.md" > "$TMP/r12.md"
check "exit 2" 2 "$(run "$TMP/r12.md" "$TMP/f1.json")"
check "error names Documentation" 1 "$(grep -c "has no Signals row for Documentation" "$TMP/out")"

echo "Test 13: Signals table present but missing the Security row is exit 2"
grep -v "^| Security | Low | e |$" "$TMP/r1.md" > "$TMP/r13.md"
check "exit 2" 2 "$(run "$TMP/r13.md" "$TMP/f1.json")"
check "error names Security" 1 "$(grep -c "has no Signals row for Security" "$TMP/out")"

# FULL with one line replaced: $1 = requirement, $2 = new value
full_with() { printf '%s\n' "$FULL" | sed "s|^  - $1: .*|  - $1: $2|"; }

echo "Test 14: 'No …' evidence is none"
report Strong Low Low "$(full_with troubleshooting 'No troubleshooting section')" > "$TMP/r14.md"
check "exit 1" 1 "$(run "$TMP/r14.md" "$TMP/f1.json")"
check "caps at Adequate" 1 "$(grep -cF "MISMATCH Documentation rating (Strong claimed but 'troubleshooting' evidence is none; highest supported rung is Adequate)" "$TMP/out")"

echo "Test 15: punctuation-only evidence is none"
report Strong Low Low "$(full_with 'environment variables' '—')" > "$TMP/r15.md"
check "exit 1" 1 "$(run "$TMP/r15.md" "$TMP/f1.json")"
check "caps at Adequate" 1 "$(grep -cF "MISMATCH Documentation rating (Strong claimed but 'environment variables' evidence is none; highest supported rung is Adequate)" "$TMP/out")"

echo "Test 16: bold requirement keys parse"
BOLD=$(printf '%s\n' "$FULL" | sed -E 's/^  - ([a-z ]+):/  - **\1:**/')
report Strong Low Low "$BOLD" > "$TMP/r16.md"
check "exit 0" 0 "$(run "$TMP/r16.md" "$TMP/f1.json")"
check "summary" "ratings: consistent" "$(tail -1 "$TMP/out")"
BOLDNOENV=$(printf '%s\n' "$BOLD" | sed 's/^  - \*\*environment variables:\*\* .*/  - **environment variables:** none/')
report Strong Low Low "$BOLDNOENV" > "$TMP/r16b.md"
check "bold none still caps" 1 "$(run "$TMP/r16b.md" "$TMP/f1.json")"
check "bold none reason" 1 "$(grep -cF "MISMATCH Documentation rating (Strong claimed but 'environment variables' evidence is none; highest supported rung is Adequate)" "$TMP/out")"

echo "Test 17: * and + bullets parse"
STARS=$(printf '%s\n' "$FULL" | awk '{ sub(/^  - /, NR <= 5 ? "  * " : "  + "); print }')
report Strong Low Low "$STARS" > "$TMP/r17.md"
check "exit 0" 0 "$(run "$TMP/r17.md" "$TMP/f1.json")"
check "five * bullets" 5 "$(grep -cE '^  \* [a-z]' "$TMP/r17.md")"
check "five + bullets" 5 "$(grep -cE '^  \+ [a-z]' "$TMP/r17.md")"

echo "Test 18: bold dimension and level cells in the Signals table"
sed -e 's/^| Security | Low | e |$/| **Security** | Low | e |/' -e 's/^| Documentation | Low | e |$/| Documentation | **Low** | e |/' "$TMP/r1.md" > "$TMP/r18.md"
check "exit 0" 0 "$(run "$TMP/r18.md" "$TMP/f1.json")"
check "summary" "ratings: consistent" "$(tail -1 "$TMP/out")"
sed -e 's/^| Security | Low | e |$/| **Security** | **Low** | e |/' "$TMP/r1.md" > "$TMP/r18b.md"; printf '[%s]' "$(sec medium FAIL)" > "$TMP/f18.json"
check "bold level still compared" 1 "$(run "$TMP/r18b.md" "$TMP/f18.json")"
check "bold level reason" 1 "$(grep -cF "MISMATCH Security signal (report says Low; findings derive High: 1 OODT finding, highest severity medium)" "$TMP/out")"

echo "Test 19: an absent requirement line is 'missing', not 'none'"
report Strong Low Low "$(printf '%s\n' "$FULL" | grep -v 'screenshots:')" > "$TMP/r19.md"
check "exit 1" 1 "$(run "$TMP/r19.md" "$TMP/f1.json")"
check "reason" 1 "$(grep -cF "MISMATCH Documentation rating (Strong claimed but 'screenshots' evidence is missing; highest supported rung is Adequate)" "$TMP/out")"

echo "Test 20: Security signal is derived per app_id across two app sections"
two_apps() { # $1 = root Security level, $2 = viewer Security level
  report Strong "$1" Low "$FULL" | sed '/^## Review scope$/,$d'
  report Strong "$2" Low "$FULL" | sed -n '/^## App: X (root)$/,$p' | sed 's/^## App: X (root)$/## App: Viewer (apps\/viewer)/'
}
two_apps Low High | sed 's/^## App: X (root)$/## App: SAS (root)/' > "$TMP/r20.md"
printf '[%s]' "$(sec medium WARN | sed 's/"app_id":"root"/"app_id":"apps\/viewer"/')" > "$TMP/f20.json"
check "two sections" 2 "$(grep -c '^## App:' "$TMP/r20.md")"
check "consistent exit 0" 0 "$(run "$TMP/r20.md" "$TMP/f20.json")"
check "consistent summary" "ratings: consistent" "$(tail -1 "$TMP/out")"
two_apps High Low | sed 's/^## App: X (root)$/## App: SAS (root)/' > "$TMP/r20b.md"
check "swapped exit 1" 1 "$(run "$TMP/r20b.md" "$TMP/f20.json")"
check "root mismatch derives Low" 1 "$(grep -cF "MISMATCH Security signal (report says High; findings derive Low: no OODT findings)" "$TMP/out")"
check "viewer mismatch derives High" 1 "$(grep -cF "MISMATCH Security signal (report says Low; findings derive High: 1 OODT finding, highest severity medium)" "$TMP/out")"
check "swapped summary" "ratings: 2 mismatches" "$(tail -1 "$TMP/out")"

echo; echo "Done: $pass passed, $fail failed."; [ "$fail" -eq 0 ]
