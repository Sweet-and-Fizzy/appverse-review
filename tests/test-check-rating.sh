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

echo; echo "Done: $pass passed, $fail failed."; [ "$fail" -eq 0 ]
