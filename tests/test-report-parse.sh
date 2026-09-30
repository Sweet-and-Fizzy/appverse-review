#!/usr/bin/env bash
# Test references/report_parse.py: the one Markdown report parser shared by
# check-rows.py, check-rating.py and compare-runs.py (split_row, is_separator,
# header_name, normalize_result, rows_by_check, app_sections, section_for).
# One test per function, exact strings; each invokes the function directly
# via `python3 -c` since report_parse.py has no CLI of its own.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REFS="$SCRIPT_DIR/references"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0
check() { local name="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then echo "  PASS  $name"; pass=$((pass+1)); else echo "  FAIL  $name: expected '$expected', got '$actual'"; fail=$((fail+1)); fi; }
py() { PYTHONPATH="$REFS" python3 -c "$1" 2>"$TMP/err"; local rc=$?; if [ $rc -ne 0 ]; then cat "$TMP/err" >&2; fi; }

echo "Test 1: split_row -- a plain row"
out=$(py "
from report_parse import split_row
print('|'.join(split_row('| a | b | c |')))
")
check "cells" "a|b|c" "$out"

echo "Test 2: split_row -- an escaped pipe does not split the cell"
out=$(py "
from report_parse import split_row
print('|'.join(split_row('| a\\\\|b | c |')))
")
check "escaped pipe stays in one cell" 'a\|b|c' "$out"

echo "Test 3: split_row -- a backtick-fenced pipe does not split the cell"
out=$(py "
from report_parse import split_row
print('|'.join(split_row('| \`a | b\` | c |')))
")
check "fenced pipe stays in one cell" '`a | b`|c' "$out"

echo "Test 4: is_separator -- a ':---' style separator row is a separator"
out=$(py "
from report_parse import is_separator
print(is_separator('|:---|---:|:---:|'))
")
check "colon-dash separator recognized" "True" "$out"

echo "Test 4b: is_separator -- a row of real cells is not a separator"
out=$(py "
from report_parse import is_separator
print(is_separator('| a | b |'))
")
check "non-separator row rejected" "False" "$out"

echo "Test 5: header_name -- strips emphasis markers and lowercases"
out=$(py "
from report_parse import header_name
print(header_name('**Check**'))
")
check "header normalized" "check" "$out"

echo "Test 6: normalize_result -- a bolded severity-qualified cell"
out=$(py "
from report_parse import normalize_result
print(normalize_result('**WARN** (low)'))
")
check "WARN extracted" "WARN" "$out"

echo "Test 6b: normalize_result -- NOT CHECKED collapses internal whitespace"
out=$(py "
from report_parse import normalize_result
print(normalize_result('NOT   CHECKED'))
")
check "NOT CHECKED normalized" "NOT CHECKED" "$out"

echo "Test 6c: normalize_result -- a cell with no recognized result is None"
out=$(py "
from report_parse import normalize_result
print(normalize_result('n/a'))
")
check "unrecognized cell is None" "None" "$out"

echo "Test 7: rows_by_check -- a row without a check: marker in its Check cell is not collected"
out=$(py "
from report_parse import rows_by_check
body = '''
| Check | Result | Evidence |
|---|---|---|
| plain text, no marker | WARN | foo.txt:1 |
'''
print(rows_by_check(body))
")
check "no rows collected" "{}" "$out"

echo "Test 7b: rows_by_check -- the Evidence-overflow rule (more cells than headers)"
out=$(py "
from report_parse import rows_by_check
body = '''
| Check | Result | Evidence |
|---|---|---|
| \`check: qua-02\` | WARN | odyssey3 | documented | template/x.sh:5 |
'''
rows = rows_by_check(body)
print(rows['qua-02'][0]['evidence'])
")
check "overflow cells rejoin into Evidence" "odyssey3 | documented | template/x.sh:5" "$out"

echo "Test 7c: rows_by_check -- a normal row keeps result, severity, evidence and summary"
out=$(py "
from report_parse import rows_by_check
body = '''
| Check | Rule | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| \`check: str-06-syntax\` | STR-06 | FAIL | high | after.sh does not parse | template/after.sh:3 |
'''
r = rows_by_check(body)['str-06-syntax'][0]
print('{}/{}/{}/{}'.format(r['result'], r['severity'], r['summary'], r['evidence']))
")
check "row fields" "FAIL/high/after.sh does not parse/template/after.sh:3" "$out"

echo "Test 8: app_sections -- a single-app report using '##' headings"
out=$(py "
from report_parse import app_sections
text = '''# Appverse Review: demo

## App: Demo (root)

### Structure
body text here

## Review scope
x
'''
sections = app_sections(text)
heading, key, body = sections[0]
print(len(sections))
print(heading)
print(key)
print('body has Review scope:', 'Review scope' in body)
print('body has Structure:', 'Structure' in body)
"
)
check "one section found" "1
## App: Demo (root)
root
body has Review scope: False
body has Structure: True" "$out"

echo "Test 9: section_for -- matches the app's parenthesised id and falls back for a single-app report"
out=$(py "
from report_parse import app_sections, section_for
text = '''## App: Demo (root)

### Structure
demo body
'''
sections = app_sections(text)
app = {'app_id': 'root', 'path': '.'}
print(section_for(app, sections, single=True).strip())
"
)
check "section body returned" "### Structure
demo body" "$out"

out=$(py "
from report_parse import app_sections, section_for
text = '''## App: Demo (elsewhere)

### Structure
fallback body
'''
sections = app_sections(text)
app = {'app_id': 'root', 'path': '.'}
print(section_for(app, sections, single=True).strip())
"
)
check "no id match, single app with one section: the fallback returns it" "### Structure
fallback body" "$out"

echo "Test 9b: section_for -- no match and not single returns None"
out=$(py "
from report_parse import app_sections, section_for
text = '''## App: Demo (elsewhere)

### Structure
demo body
'''
sections = app_sections(text)
app = {'app_id': 'root', 'path': '.'}
print(section_for(app, sections, single=False))
"
)
check "no match, not single, is None" "None" "$out"

echo; echo "Done: $pass passed, $fail failed."; [ "$fail" -eq 0 ]
