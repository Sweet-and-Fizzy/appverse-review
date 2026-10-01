#!/usr/bin/env bash
# Test check-rows.py (R1): every manifest check that applies to an app has a
# row in that app's report section, and a check whose facts list candidates
# is answered: a FAIL/WARN row, or PASS rows whose Evidence cites every
# candidate's file:line.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CHECK="$SCRIPT_DIR/references/check-rows.py"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0
check() { local name="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then echo "  PASS  $name"; pass=$((pass+1)); else echo "  FAIL  $name: expected '$expected', got '$actual'"; fail=$((fail+1)); cat "$TMP/out"; fi; }
run() { python3 "$CHECK" "$@" > "$TMP/out" 2>&1; echo $?; }
count() { grep -cxF -- "$1" "$TMP/out"; }
echo '[]' > "$TMP/findings.json"

# A small manifest, so the cases do not move when the real one grows.
cat > "$TMP/checks.json" <<'EOF'
{"checks": [
 {"id": "str-06-syntax", "section": "Validity", "app_types": ["batch_connect"], "fact_source": "syntax.json", "rule": "STR-06", "row_required": "always", "dimension": "structure"},
 {"id": "entry-point-parses", "section": "Batch Connect layout", "app_types": ["passenger"], "fact_source": "entry_point.json", "rule": "STR-07", "row_required": "always", "dimension": "structure"},
 {"id": "sec-interpolation", "section": "Pattern checks (all app types)", "app_types": ["batch_connect", "passenger", "companion", "widget"], "fact_source": "security.json", "rule": "OODT-01", "row_required": "when_candidates", "dimension": "security"},
 {"id": "sec-eval-exec", "section": "Pattern checks (all app types)", "app_types": ["batch_connect", "passenger", "companion", "widget"], "fact_source": "security.json", "rule": "OODT-01", "row_required": "when_candidates", "dimension": "security"},
 {"id": "documentation-rating", "section": "Documentation", "app_types": ["batch_connect", "passenger", "companion", "widget"], "fact_source": "readme.json", "rule": "QUA-01", "row_required": "always", "dimension": "documentation"},
 {"id": "numeric-field-bounds", "section": "Code Quality", "app_types": ["batch_connect"], "fact_source": "form.json", "rule": "QUA-07", "row_required": "always", "dimension": "code_quality"},
 {"id": "magic-numbers", "section": "Code Quality", "app_types": ["batch_connect"], "fact_source": "template.json", "rule": "QUA-08", "row_required": "always", "dimension": "code_quality"},
 {"id": "erb-missing-value", "section": "Code Quality", "app_types": ["batch_connect"], "fact_source": "form.json", "rule": "QUA-10", "row_required": "always", "dimension": "code_quality"}
]}
EOF

# Facts for a single Batch Connect app.
O="$TMP/out-bc"; mkdir -p "$O/root"
echo '[{"app_id": "root", "path": ".", "app_type": "batch_connect", "readme": "README.md"}]' > "$O/apps.json"
cat > "$O/syntax.json" <<'EOF'
[{"path": "template/script.sh.erb", "stripped": true, "ok": true, "stderr": ""},
 {"path": "template/after.sh", "stripped": false, "ok": false, "stderr": "template/after.sh: line 3: syntax error"}]
EOF
cat > "$O/root/form.json" <<'EOF'
{"file": "form.yml", "submit_file": "submit.yml.erb", "erb_sentinel": "ERBVALUE", "error": null, "attributes": [
 {"name": "bc_num_slots", "widget": "number_field", "min": 1, "max": null, "pattern": null, "required": true, "line": 6, "defined": true, "in_form": true, "interpolated_in_submit": true, "submit_lines": [4], "reaches_scheduler": true},
 {"name": "cores", "widget": "number_field", "min": 1, "max": "ERBVALUE", "pattern": null, "required": true, "line": 9, "defined": true, "in_form": true, "interpolated_in_submit": false, "submit_lines": [], "reaches_scheduler": true},
 {"name": "version", "widget": "select", "min": null, "max": null, "pattern": null, "required": false, "line": 12, "defined": true, "in_form": true, "interpolated_in_submit": false, "submit_lines": [], "reaches_scheduler": true},
 {"name": "extra", "widget": "text_field", "min": null, "max": null, "pattern": "[a-z]+", "required": false, "line": 15, "defined": true, "in_form": true, "interpolated_in_submit": false, "submit_lines": [], "reaches_scheduler": true},
 {"name": "bc_num_hours", "widget": null, "min": null, "max": null, "pattern": null, "required": false, "line": 3, "defined": false, "in_form": true, "interpolated_in_submit": true, "submit_lines": [8], "reaches_scheduler": true}
]}
EOF
cat > "$O/root/security.json" <<'EOF'
{"counts": {"interpolation": 2},
 "candidates": [
  {"kind": "interpolation", "file": "submit.yml.erb", "line": 4, "text": "<%= bc_num_slots %>", "rule": "OODT-01", "note": "", "guarded": false, "quoted": false},
  {"kind": "interpolation", "file": "template/script.sh.erb", "line": 12, "text": "<%= extra %>", "rule": "OODT-01", "note": "", "guarded": false, "quoted": true}
 ]}
EOF
cat > "$O/root/template.json" <<'EOF'
{"dir": "template", "files": [], "icons": [], "absolute_paths": [],
 "numeric_literals": [{"file": "template/script.sh.erb", "line": 20, "value": "300"}],
 "hex_colors": [], "commented_code": [], "skipped_files": []}
EOF

cat > "$TMP/report.md" <<'EOF'
# Appverse Review: demo

## App: Demo (root)

### Structure
| Check | Rule | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| Template syntax (`check: str-06-syntax`) | STR-06 | FAIL | high | after.sh does not parse | template/after.sh (bash -n: line 3) |

### Security

#### Findings

| Rule | Check | Result | Severity | Tag | Summary | Evidence |
|---|---|---|---|---|---|---|
| OODT-01 | `check: sec-interpolation` | PASS | — | — | integer widget, bounded by OOD | submit.yml.erb:4 |
| OODT-01 | `check: sec-interpolation` | PASS | — | — | quoted | template/script.sh.erb:10-14 |

### Documentation
| Check | Result | Evidence |
|---|---|---|
| `check: documentation-rating` | PASS | Adequate |

### Code Quality
| Check | Rule | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| Input validation (`check: numeric-field-bounds`) | QUA-07 | FAIL | medium | no max | form.yml:6 |
| Magic numbers (`check: magic-numbers`) | QUA-08 | PASS | — | documented timeout | template/script.sh.erb:20 |
| ERB missing values (`check: erb-missing-value`) | QUA-10 | PASS | — | has a default | submit.yml.erb:4 |
EOF

echo "Test 1: a complete, answered report exits 0"
check "exit 0" 0 "$(run "$TMP/report.md" "$TMP/findings.json" "$TMP/checks.json" "$O")"
check "no problem lines" 0 "$(grep -cE '^(MISSING|UNCITED) ' "$TMP/out")"
check "summary" 1 "$(count "check-rows: 1 app, 6 required rows, 0 problems")"

echo "Test 2: a missing numeric-field-bounds row is MISSING"
grep -vF 'check: numeric-field-bounds' "$TMP/report.md" > "$TMP/r2.md"
check "exit 1" 1 "$(run "$TMP/r2.md" "$TMP/findings.json" "$TMP/checks.json" "$O")"
check "message" 1 "$(count "MISSING root numeric-field-bounds")"
check "summary" 1 "$(count "check-rows: 1 app, 6 required rows, 1 problem")"

echo "Test 3: PASS on sec-interpolation citing one of two candidates is UNCITED"
grep -vF 'template/script.sh.erb:10-14' "$TMP/report.md" > "$TMP/r3.md"
check "exit 1" 1 "$(run "$TMP/r3.md" "$TMP/findings.json" "$TMP/checks.json" "$O")"
check "message" 1 "$(count "UNCITED root sec-interpolation template/script.sh.erb:12")"
check "cited one not reported" 0 "$(grep -cF 'submit.yml.erb:4' "$TMP/out")"

echo "Test 4: a row answers only the candidates it cites, whatever its Result"
O4="$TMP/out-bc4"; cp -R "$O" "$O4"
cat > "$O4/root/security.json" <<'EOF'
{"counts": {"interpolation": 3},
 "candidates": [
  {"kind": "interpolation", "file": "submit.yml.erb", "line": 4, "text": "<%= bc_num_slots %>", "rule": "OODT-01", "note": "", "guarded": false, "quoted": false},
  {"kind": "interpolation", "file": "template/script.sh.erb", "line": 12, "text": "<%= extra %>", "rule": "OODT-01", "note": "", "guarded": false, "quoted": true},
  {"kind": "unquoted_expansion", "file": "template/script.sh.erb", "line": 30, "text": "$extra", "rule": "OODT-01", "note": "", "guarded": false, "quoted": false}
 ]}
EOF
grep -vF 'template/script.sh.erb:10-14' "$TMP/report.md" \
  | sed 's/| OODT-01 | `check: sec-interpolation` | PASS | — | — | integer widget, bounded by OOD | submit.yml.erb:4 |/| OODT-01 | `check: sec-interpolation` | FAIL | high | unintentional | unquoted | submit.yml.erb:4 |/' > "$TMP/r4.md"
check "FAIL citing one of three: exit 1" 1 "$(run "$TMP/r4.md" "$TMP/findings.json" "$TMP/checks.json" "$O4")"
check "second site UNCITED" 1 "$(count "UNCITED root sec-interpolation template/script.sh.erb:12")"
check "third site UNCITED" 1 "$(count "UNCITED root sec-interpolation template/script.sh.erb:30")"
check "the fixture has the FAIL row" 1 "$(grep -cF '| FAIL | high | unintentional |' "$TMP/r4.md")"
check "cited site answered" 0 "$(grep -cF 'submit.yml.erb:4' "$TMP/out")"
printf '%s\n' '| OODT-01 | `check: sec-interpolation` | NOT CHECKED | — | — | ERB too dynamic | template/script.sh.erb:12, 30 |' > "$TMP/r4row"
sed "/check: sec-interpolation.*FAIL/r $TMP/r4row" "$TMP/r4.md" > "$TMP/r4b.md"
check "a NOT CHECKED row citing the rest answers none of them: exit 1" 1 "$(run "$TMP/r4b.md" "$TMP/findings.json" "$TMP/checks.json" "$O4")"
check "NOT CHECKED leaves line 12 UNCITED" 1 "$(count "UNCITED root sec-interpolation template/script.sh.erb:12")"
check "NOT CHECKED leaves line 30 UNCITED" 1 "$(count "UNCITED root sec-interpolation template/script.sh.erb:30")"
check "summary" 1 "$(count "check-rows: 1 app, 6 required rows, 2 problems")"

echo "Test 5: citations match exactly: a longer line number or a longer path does not count"
sed 's/template\/script.sh.erb:10-14/template\/script.sh.erb:120; other\/template\/script.sh.erb:12/' "$TMP/report.md" > "$TMP/r5.md"
check "exit 1" 1 "$(run "$TMP/r5.md" "$TMP/findings.json" "$TMP/checks.json" "$O")"
check "message" 1 "$(count "UNCITED root sec-interpolation template/script.sh.erb:12")"
sed 's/template\/script.sh.erb:10-14/`template\/script.sh.erb:12`/' "$TMP/report.md" > "$TMP/r5b.md"
check "backticked exact cite exit 0" 0 "$(run "$TMP/r5b.md" "$TMP/findings.json" "$TMP/checks.json" "$O")"

echo "Test 5b: citation grammar: en-dash ranges, comma lists and a leading ./ cite; prose does not"
for ev in 'template/script.sh.erb:11–13' 'template/script.sh.erb:10,12' 'template/script.sh.erb:3, 12' './template/script.sh.erb:12' 'template/script.sh.erb:1-2,11 – 12'; do
  sed "s|template/script.sh.erb:10-14|$ev|" "$TMP/report.md" > "$TMP/r5c.md"
  check "cites: $ev" 0 "$(run "$TMP/r5c.md" "$TMP/findings.json" "$TMP/checks.json" "$O")"
done
for ev in 'template/script.sh.erb: line 12' 'template/script.sh.erb line 12' 'template/script.sh.erb:10,11' 'template/script.sh.erb:13–14'; do
  sed "s|template/script.sh.erb:10-14|$ev|" "$TMP/report.md" > "$TMP/r5c.md"
  check "does not cite: $ev" 1 "$(run "$TMP/r5c.md" "$TMP/findings.json" "$TMP/checks.json" "$O")"
done

echo "Test 5b2: backticks, emphasis and ./ around the path are stripped"
for ev in '`./template/script.sh.erb:12`' '`template/script.sh.erb`:12' '**template/script.sh.erb**:12' 'x; reviewed OK: ./template/script.sh.erb:9,12' 'x; reviewed OK:./template/script.sh.erb:9,12'; do
  sed "s|template/script.sh.erb:10-14|$ev|" "$TMP/report.md" > "$TMP/r5c.md"
  check "cites: $ev" 0 "$(run "$TMP/r5c.md" "$TMP/findings.json" "$TMP/checks.json" "$O")"
done

echo "Test 5c: Result is read from its leading token after markdown and emoji"
sed 's/| QUA-08 | PASS | — | documented timeout |/| QUA-08 | **WARN** (low) | low | undocumented |/' "$TMP/report.md" > "$TMP/r5d.md"
check "**WARN** (low) is a result: exit 0" 0 "$(run "$TMP/r5d.md" "$TMP/findings.json" "$TMP/checks.json" "$O")"
sed 's/| QUA-08 | PASS | — | documented timeout |/| QUA-08 | ✅ Pass | — | documented |/' "$TMP/report.md" > "$TMP/r5e.md"
check "emoji then Pass is a result: exit 0" 0 "$(run "$TMP/r5e.md" "$TMP/findings.json" "$TMP/checks.json" "$O")"
sed 's/| QUA-08 | PASS | — | documented timeout |/| QUA-08 | TBD | — | later |/' "$TMP/report.md" > "$TMP/r5f.md"
check "a row with no result is not a row: exit 1" 1 "$(run "$TMP/r5f.md" "$TMP/findings.json" "$TMP/checks.json" "$O")"
check "message" 1 "$(count "MISSING root magic-numbers")"

echo "Test 6: numeric-field-bounds PASS without the candidate is UNCITED; bounded, ERBVALUE and select fields are not candidates"
sed 's/| QUA-07 | FAIL | medium | no max | form.yml:6 |/| QUA-07 | PASS | — | all bounded | form.yml:9, form.yml:12 |/' "$TMP/report.md" > "$TMP/r6.md"
check "exit 1" 1 "$(run "$TMP/r6.md" "$TMP/findings.json" "$TMP/checks.json" "$O")"
check "message" 1 "$(count "UNCITED root numeric-field-bounds form.yml:6")"
check "only one problem" 1 "$(grep -cE '^(MISSING|UNCITED) ' "$TMP/out")"
check "a defined: false built-in is not a candidate" 0 "$(grep -cF 'form.yml:3' "$TMP/out")"

echo "Test 7: a when_candidates check with no candidates needs no row; with candidates it does"
check "sec-eval-exec absent, exit 0 (Test 1)" 0 "$(run "$TMP/report.md" "$TMP/findings.json" "$TMP/checks.json" "$O")"
grep -vF 'check: sec-interpolation' "$TMP/report.md" > "$TMP/r7.md"
check "exit 1" 1 "$(run "$TMP/r7.md" "$TMP/findings.json" "$TMP/checks.json" "$O")"
check "message" 1 "$(count "MISSING root sec-interpolation")"

echo "Test 8: a marker outside the Check column does not make a row"
sed 's/| Magic numbers (`check: magic-numbers`) | QUA-08 | PASS | — | documented timeout |/| Magic numbers | QUA-08 | PASS | — | `check: magic-numbers` |/' "$TMP/report.md" > "$TMP/r8.md"
check "exit 1" 1 "$(run "$TMP/r8.md" "$TMP/findings.json" "$TMP/checks.json" "$O")"
check "message" 1 "$(count "MISSING root magic-numbers")"

echo "Test 9: a failing syntax.json entry is cited by path; a NOT CHECKED row citing nothing does not answer it"
sed 's/| STR-06 | FAIL | high | after.sh does not parse | template\/after.sh (bash -n: line 3) |/| STR-06 | NOT CHECKED | — | bash missing | — |/' "$TMP/report.md" > "$TMP/r9.md"
check "exit 1" 1 "$(run "$TMP/r9.md" "$TMP/findings.json" "$TMP/checks.json" "$O")"
check "message" 1 "$(count "UNCITED root str-06-syntax template/after.sh")"
sed 's/| STR-06 | FAIL | high | after.sh does not parse | template\/after.sh (bash -n: line 3) |/| STR-06 | PASS | — | false positive | template\/after.sh:3 is a heredoc |/' "$TMP/report.md" > "$TMP/r9b.md"
check "PASS citing the path exit 0" 0 "$(run "$TMP/r9b.md" "$TMP/findings.json" "$TMP/checks.json" "$O")"

echo "Test 10: erb-missing-value candidates are the attributes interpolated in submit"
sed 's/| QUA-10 | PASS | — | has a default | submit.yml.erb:4 |/| QUA-10 | PASS | — | fine | — |/' "$TMP/report.md" > "$TMP/r10.md"
check "exit 1" 1 "$(run "$TMP/r10.md" "$TMP/findings.json" "$TMP/checks.json" "$O")"
check "message" 1 "$(count "UNCITED root erb-missing-value submit.yml.erb:4")"
check "a defined: false built-in is not a candidate" 0 "$(grep -cE 'submit.yml.erb:8|form.yml:3' "$TMP/out")"
sed 's/| QUA-10 | PASS | — | has a default | submit.yml.erb:4 |/| QUA-10 | PASS | — | has a default | form.yml:6 |/' "$TMP/report.md" > "$TMP/r10b.md"
check "the form line also cites it, exit 0" 0 "$(run "$TMP/r10b.md" "$TMP/findings.json" "$TMP/checks.json" "$O")"

echo "Test 11: a Passenger app is exempt from the Batch Connect checks and needs entry-point-parses"
P="$TMP/out-p"; mkdir -p "$P/root"
echo '[{"app_id": "root", "path": ".", "app_type": "passenger", "readme": "README.md"}]' > "$P/apps.json"
echo '{"file": "passenger_wsgi.py", "language": "python", "parses": false, "error": "SyntaxError", "dependency_manifest": "requirements.txt", "consistent": true, "note": ""}' > "$P/root/entry_point.json"
cat > "$TMP/rp.md" <<'EOF'
## App: Portal (root)

| Check | Rule | Result | Evidence |
|---|---|---|---|
| `check: entry-point-parses` | STR-07 | FAIL | passenger_wsgi.py:3 |
| `check: documentation-rating` | QUA-01 | PASS | Minimal |
EOF
check "exit 0" 0 "$(run "$TMP/rp.md" "$TMP/findings.json" "$TMP/checks.json" "$P")"
grep -vF 'check: entry-point-parses' "$TMP/rp.md" > "$TMP/rp2.md"
check "exit 1" 1 "$(run "$TMP/rp2.md" "$TMP/findings.json" "$TMP/checks.json" "$P")"
check "entry point MISSING" 1 "$(count "MISSING root entry-point-parses")"
check "no Batch Connect check reported" 0 "$(grep -cE 'numeric-field-bounds|magic-numbers|erb-missing-value|str-06-syntax' "$TMP/out")"
sed 's/| STR-07 | FAIL | passenger_wsgi.py:3 |/| STR-07 | PASS | parses |/' "$TMP/rp.md" > "$TMP/rp3.md"
check "PASS over a parse failure is UNCITED" 1 "$(run "$TMP/rp3.md" "$TMP/findings.json" "$TMP/checks.json" "$P")"
check "message" 1 "$(count "UNCITED root entry-point-parses passenger_wsgi.py")"

echo "Test 12: monorepo: sections match by app id; candidates carry the app path; a missing section is MISSING per check"
M="$TMP/out-m"; mkdir -p "$M/a" "$M/b"
echo '[{"app_id": "a", "path": "apps/a", "app_type": "batch_connect", "readme": "apps/a/README.md"}, {"app_id": "b", "path": "apps/b", "app_type": "passenger", "readme": "README.md"}]' > "$M/apps.json"
echo '[]' > "$M/syntax.json"
echo '{"file": "form.yml", "submit_file": "submit.yml.erb", "error": null, "attributes": [{"name": "n", "widget": "number_field", "min": null, "max": null, "pattern": null, "required": true, "line": 3, "defined": true, "in_form": true, "interpolated_in_submit": false, "submit_lines": [], "reaches_scheduler": true}]}' > "$M/a/form.json"
cat > "$TMP/rm.md" <<'EOF'
## App: A (a)

| Check | Result | Evidence |
|---|---|---|
| `check: str-06-syntax` | PASS | 2 files pass |
| `check: documentation-rating` | PASS | Adequate |
| `check: numeric-field-bounds` | PASS | apps/a/form.yml:3 has OOD's default bounds |
| `check: magic-numbers` | PASS | none |
| `check: erb-missing-value` | PASS | none |
EOF
check "exit 1" 1 "$(run "$TMP/rm.md" "$TMP/findings.json" "$TMP/checks.json" "$M")"
check "b entry point MISSING" 1 "$(count "MISSING b entry-point-parses")"
check "b docs MISSING" 1 "$(count "MISSING b documentation-rating")"
check "a clean" 0 "$(grep -c ' a ' "$TMP/out")"
sed 's/apps\/a\/form.yml:3/form.yml:9/' "$TMP/rm.md" > "$TMP/rm2.md"
run "$TMP/rm2.md" "$TMP/findings.json" "$TMP/checks.json" "$M" > /dev/null
check "prefixed candidate label" 1 "$(count "UNCITED a numeric-field-bounds apps/a/form.yml:3")"

echo "Test 12b: a MISSING check lists its candidates on the following lines"
grep -vF 'check: sec-interpolation' "$TMP/report.md" > "$TMP/r12b.md"
check "exit 1" 1 "$(run "$TMP/r12b.md" "$TMP/findings.json" "$TMP/checks.json" "$O")"
check "MISSING then its candidates" "MISSING root sec-interpolation
  candidate submit.yml.erb:4
  candidate template/script.sh.erb:12" "$(grep -A2 -xF 'MISSING root sec-interpolation' "$TMP/out")"
check "summary counts the check once" 1 "$(count "check-rows: 1 app, 6 required rows, 1 problem")"

echo "Test 12c: a '|' in the Summary does not shift the Evidence cell"
O12="$TMP/out-bc12"; cp -R "$O" "$O12"
cat > "$O12/root/security.json" <<'JSON'
{"candidates": [
  {"kind": "interpolation", "file": "submit.yml.erb", "line": 4, "text": "x", "rule": "OODT-01", "note": ""},
  {"kind": "interpolation", "file": "template/script.sh.erb", "line": 12, "text": "x", "rule": "OODT-01", "note": ""},
  {"kind": "eval_exec", "file": "template/before.sh.erb", "line": 3, "text": "curl -s x | bash", "rule": "OODT-01", "note": ""},
  {"kind": "eval_exec", "file": "template/before.sh.erb", "line": 7, "text": "curl -s y | bash", "rule": "OODT-01", "note": ""}
]}
JSON
printf '%s\n' '| OODT-01 | `check: sec-eval-exec` | FAIL | high | unintentional | `curl -s x | bash` runs remote code | template/before.sh.erb:3 |' > "$TMP/r12row"
printf '%s\n' '| OODT-01 | `check: sec-eval-exec` | FAIL | high | unintentional | curl -s y | bash runs remote code | template/before.sh.erb:7 |' >> "$TMP/r12row"
sed "/check: sec-interpolation.*template\/script.sh.erb:10-14/r $TMP/r12row" "$TMP/report.md" > "$TMP/r12c.md"
check "backticked and bare pipes in Summary: exit 0" 0 "$(run "$TMP/r12c.md" "$TMP/findings.json" "$TMP/checks.json" "$O12")"
check "no UNCITED" 0 "$(grep -c '^UNCITED' "$TMP/out")"

echo "Test 12b: sec-tool-finding candidates -- one per (tool, code, file), answered only by a row citing the site and naming the code"
cat > "$TMP/checks-tf.json" <<'EOF'
{"checks": [
 {"id": "sec-interpolation", "section": "Pattern checks (all app types)", "app_types": ["batch_connect"], "fact_source": "security.json", "rule": "OODT-01", "row_required": "when_candidates", "dimension": "security"},
 {"id": "sec-tool-finding", "section": "Tier 2 — Tooling", "app_types": ["batch_connect"], "fact_source": "security.json", "rule": null, "tag": null, "row_required": "when_candidates", "dimension": "security"}
]}
EOF
OTF="$TMP/out-tf"; mkdir -p "$OTF/root"
echo '[{"app_id": "root", "path": ".", "app_type": "batch_connect"}]' > "$OTF/apps.json"
cat > "$OTF/root/security.json" <<'EOF'
{"counts": {"tool_finding": 2}, "candidates": [
 {"kind": "interpolation", "check": "sec-interpolation", "rule": "OODT-01", "tag": "unsanitized-user-input", "file": "template/script.sh.erb", "line": 2, "text": "<%= x %>"},
 {"kind": "tool_finding", "check": "sec-tool-finding", "rule": null, "tag": null, "tool": "shellcheck", "code": "SC2164", "file": "template/script.sh.erb", "lines": [2], "level": "warning", "text": "cd without exit"},
 {"kind": "tool_finding", "check": "sec-tool-finding", "rule": null, "tag": null, "tool": "shellcheck", "code": "SC2148", "file": "template/before.sh.erb", "lines": [1], "level": "error", "text": "missing shebang"}
]}
EOF

cat > "$TMP/tf-not-answered.md" <<'EOF'
# Appverse Review: demo

## App: Demo (root)

### Security

#### Findings

| Rule | Check | Result | Severity | Tag | Summary | Evidence |
|---|---|---|---|---|---|---|
| OODT-01 | `check: sec-interpolation` | PASS | — | — | quoted | template/script.sh.erb:2 |
| — | `check: sec-tool-finding` | PASS | — | — | SC2148: missing shebang; ERB artefact | template/before.sh.erb:1 |
EOF
check "a sec-interpolation PASS citing the same line does not answer the tool finding" 1 "$(run "$TMP/tf-not-answered.md" "$TMP/findings.json" "$TMP/checks-tf.json" "$OTF")"
check "UNCITED names the file and code" 1 "$(count "UNCITED root sec-tool-finding template/script.sh.erb:SC2164")"

cat > "$TMP/tf-no-code.md" <<'EOF'
# Appverse Review: demo

## App: Demo (root)

### Security

#### Findings

| Rule | Check | Result | Severity | Tag | Summary | Evidence |
|---|---|---|---|---|---|---|
| OODT-01 | `check: sec-interpolation` | PASS | — | — | quoted | template/script.sh.erb:2 |
| — | `check: sec-tool-finding` | PASS | — | — | SC2148: missing shebang; ERB artefact | template/before.sh.erb:1 |
| QUA-03 | `check: sec-tool-finding` | PASS | — | — | cd without exit; before.sh sets -e | template/script.sh.erb:2 |
EOF
check "a row citing the line whose Summary omits the code does not answer it" 1 "$(run "$TMP/tf-no-code.md" "$TMP/findings.json" "$TMP/checks-tf.json" "$OTF")"
check "UNCITED" 1 "$(count "UNCITED root sec-tool-finding template/script.sh.erb:SC2164")"

cat > "$TMP/tf-answered.md" <<'EOF'
# Appverse Review: demo

## App: Demo (root)

### Security

#### Findings

| Rule | Check | Result | Severity | Tag | Summary | Evidence |
|---|---|---|---|---|---|---|
| OODT-01 | `check: sec-interpolation` | PASS | — | — | quoted | template/script.sh.erb:2 |
| — | `check: sec-tool-finding` | PASS | — | — | SC2148: missing shebang; ERB artefact | template/before.sh.erb:1 |
| QUA-03 | `check: sec-tool-finding` | PASS | — | — | SC2164: cd without exit; before.sh sets -e | template/script.sh.erb:2 |
EOF
check "a row naming the code in its Summary and citing the line answers it: exit 0" 0 "$(run "$TMP/tf-answered.md" "$TMP/findings.json" "$TMP/checks-tf.json" "$OTF")"
check "no UNCITED" 0 "$(grep -c '^UNCITED' "$TMP/out")"

echo "Test 12c: a sec-tool-finding candidate's label is the per-candidate table key check-rows' candidates() shares with compare-runs.py"
cat > "$TMP/tf_label.py" <<'PY'
import importlib.util, sys
spec = importlib.util.spec_from_file_location("cr", sys.argv[1])
cr = importlib.util.module_from_spec(spec)
spec.loader.exec_module(cr)
app = {"app_id": "root", "path": ".", "app_type": "batch_connect"}
check = {"id": "sec-tool-finding", "app_types": ["batch_connect"]}
print("|".join(lab for lab, _, _ in cr.candidates(check, app, sys.argv[2])))
PY
check "candidates() labels a tool_finding by site:code, so compare-runs.py's per-candidate table (which keys rows on check_rows.candidates()'s label) carries one row per (tool, code, file)" \
  "template/script.sh.erb:SC2164|template/before.sh.erb:SC2148" \
  "$(python3 "$TMP/tf_label.py" "$SCRIPT_DIR/references/check-rows.py" "$OTF")"

echo "Test 13: missing or unreadable inputs exit 2"
check "no report" 2 "$(run "$TMP/nope.md" "$TMP/findings.json" "$TMP/checks.json" "$O")"
check "no findings" 2 "$(run "$TMP/report.md" "$TMP/nope.json" "$TMP/checks.json" "$O")"
echo '{not json' > "$TMP/bad.json"
check "bad manifest" 2 "$(run "$TMP/report.md" "$TMP/findings.json" "$TMP/bad.json" "$O")"
mkdir -p "$TMP/empty-out"
check "no apps.json" 2 "$(run "$TMP/report.md" "$TMP/findings.json" "$TMP/checks.json" "$TMP/empty-out")"
echo '# no app sections' > "$TMP/noapp.md"
check "no App section" 2 "$(run "$TMP/noapp.md" "$TMP/findings.json" "$TMP/checks.json" "$O")"
check "wrong arg count" 2 "$(run "$TMP/report.md")"

echo "Test 14: the real manifest loads; a report with every Batch Connect row passes, one fewer fails"
R="$TMP/out-real"; mkdir -p "$R/root"
echo '[{"app_id": "root", "path": ".", "app_type": "batch_connect", "readme": "README.md"}]' > "$R/apps.json"
cat > "$R/root/security.json" <<'EOF'
{"counts": {"tool_finding": 1}, "candidates": [
 {"kind": "tool_finding", "check": "sec-tool-finding", "rule": null, "tag": null, "tool": "shellcheck", "code": "SC2164", "file": "template/script.sh.erb", "lines": [2], "level": "warning", "text": "cd without exit"}
]}
EOF
python3 - "$SCRIPT_DIR/references/checks.json" > "$TMP/real.md" <<'PY'
import json, sys
checks = json.load(open(sys.argv[1]))["checks"]
print("## App: Real (root)\n\n| Check | Result | Evidence |\n|---|---|---|")
for c in checks:
    if "batch_connect" in c["app_types"] and c["row_required"] == "always":
        print("| `check: %s` | PASS | none |" % c["id"])
print("\n| Rule | Check | Result | Severity | Tag | Summary | Evidence |\n|---|---|---|---|---|---|---|")
print("| QUA-03 | `check: sec-tool-finding` | PASS | — | — | SC2164: cd without exit; before.sh sets -e | template/script.sh.erb:2 |")
PY
check "exit 0 (the real manifest's sec-tool-finding row answers a real candidate)" 0 "$(run "$TMP/real.md" "$TMP/findings.json" "$SCRIPT_DIR/references/checks.json" "$R")"
grep -vF 'check: dead-code' "$TMP/real.md" > "$TMP/real2.md"
check "exit 1" 1 "$(run "$TMP/real2.md" "$TMP/findings.json" "$SCRIPT_DIR/references/checks.json" "$R")"
check "message" 1 "$(count "MISSING root dead-code")"
grep -vF 'check: sec-tool-finding' "$TMP/real.md" > "$TMP/real3.md"
check "dropping the sec-tool-finding row is UNCITED, not silently accepted" 1 "$(run "$TMP/real3.md" "$TMP/findings.json" "$SCRIPT_DIR/references/checks.json" "$R")"
check "message" 1 "$(count "MISSING root sec-tool-finding")"

echo; echo "Done: $pass passed, $fail failed."; [ "$fail" -eq 0 ]
