#!/usr/bin/env bash
# Test review_baseline.py: baseline input validation, kind, stable IDs and the write CLI.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
MOD="$SCRIPT_DIR/references/review_baseline.py"
IDS="$SCRIPT_DIR/references/compute-ids.py"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0
check() { local name="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then echo "  PASS  $name"; pass=$((pass+1)); else echo "  FAIL  $name: expected '$expected', got '$actual'"; fail=$((fail+1)); fi; }
# py <code>: run python with the module importable; the input JSON (if any) is in $RAW
py() { RAW="${RAW:-}" python3 -c "import sys,os; sys.path.insert(0, '$SCRIPT_DIR/references'); import review_baseline as b; raw=os.environ['RAW']
$1" 2>&1; }
valid() { # sha [extra json members, leading comma]
  printf '{"sha":"%s","sent_at":1700000000,"recommendation":"accept","apps":{"root":"accept"}%s}' "$1" "${2:-}"; }
FINDING='{"id":"i","app_id":"root","rule":"QUA-02","defect_key":"a:b","result":"FAIL","severity":"high","dismissed":false}'

echo "Test 1: stable_id matches compute-ids.py"
printf '[{"app_id":"root","rule":null,"defect_key":"README.md:x"},{"app_id":"root","rule":"QUA-02","defect_key":"form.yml:y"}]' > "$TMP/f.json"
python3 "$IDS" < "$TMP/f.json" > "$TMP/ids.json"
check "null rule" "$(python3 -c "import json;print(json.load(open('$TMP/ids.json'))[0]['id'])")" \
  "$(py "print(b.stable_id(dict(app_id='root', rule=None, defect_key='README.md:x')))")"
check "with rule" "$(python3 -c "import json;print(json.load(open('$TMP/ids.json'))[1]['id'])")" \
  "$(py "print(b.stable_id(dict(app_id='root', rule='QUA-02', defect_key='form.yml:y')))")"

echo "Test 2: validate basics"
RAW="" check "empty" "None|None" "$(RAW="" py "d,w=b.validate(raw,'abc1234'); print('%s|%s'%(d,w))")"
check "whitespace" "None|None" "$(RAW="  " py "d,w=b.validate(raw,'abc1234'); print('%s|%s'%(d,w))")"
check "no findings: not comparable" "False" "$(RAW="$(valid abc1234)" py "d,w=b.validate(raw,'abc1234'); print(d['comparable'])")"
check "empty findings: comparable" "True" "$(RAW="$(valid abc1234 ',"findings":[]')" py "d,w=b.validate(raw,'abc1234'); print(d['comparable'])")"
check "valid finding" "True" "$(RAW="$(valid abc1234 ",\"findings\":[$FINDING]")" py "d,w=b.validate(raw,'abc1234'); print(d['comparable'] and w is None)")"

echo "Test 3: same commit"
check "prefix match, case-insensitive" "True" "$(RAW="$(valid abc1234)" py "print(b.validate(raw,'ABC1234def0123456789abcdef0123456789abcd')[0]['same_commit'])")"
check "different commit" "False" "$(RAW="$(valid abc1234)" py "print(b.validate(raw,'abc1235def0123456789abcdef0123456789abcd')[0]['same_commit'])")"

echo "Test 4: malformed inputs"
bad() { local name="$1" raw="$2"
  check "$name" "None|1" "$(RAW="$raw" py "d,w=b.validate(raw,'abc1234'); print('%s|%s'%(d, 1 if w else 0))")"; }
bad "not JSON" "{"
bad "not an object" "[]"
bad "bad recommendation" '{"sha":"abc1234","sent_at":1,"recommendation":"maybe","apps":{}}'
bad "bad sha" '{"sha":"xyz","sent_at":1,"recommendation":"accept","apps":{}}'
bad "non-integer sent_at" '{"sha":"abc1234","sent_at":"1","recommendation":"accept","apps":{}}'
bad "bad app decision" '{"sha":"abc1234","sent_at":1,"recommendation":"accept","apps":{"a":"nope"}}'
bad "finding result PASS" "$(valid abc1234 ",\"findings\":[${FINDING/FAIL/PASS}]")"
bad "finding dismissed not bool" "$(valid abc1234 ",\"findings\":[${FINDING/false/\"no\"}]")"
bad "recommendation is a list" '{"sha":"abc1234","sent_at":1,"recommendation":["x"],"apps":{}}'
bad "app decision is an object" '{"sha":"abc1234","sent_at":1,"recommendation":"accept","apps":{"a":{}}}'
bad "findings not a list" "$(valid abc1234 ',"findings":{}')"

echo "Test 5: kind_for"
check "update" "update" "$(py "print(b.kind_for('root',dict(recommendation='accept', apps=dict(root='accept'))))")"
check "root from recommendation" "resubmission" "$(py "print(b.kind_for('root',dict(recommendation='request_changes', apps=dict(a='request_changes'))))")"
check "new app" "plain" "$(py "print(b.kind_for('b',dict(recommendation='request_changes', apps=dict(a='request_changes'))))")"
check "no baseline" "plain" "$(py "print(b.kind_for('a',None))")"

echo "Test 6: load"
valid abc1234 > "$TMP/ok.json"; echo '{' > "$TMP/bad.json"
check "no path" "None" "$(py "print(b.load(None))")"
check "absent file" "None" "$(py "print(b.load('$TMP/none.json'))")"
check "reads file" "accept" "$(py "print(b.load('$TMP/ok.json')['recommendation'])")"
check "malformed warns on stderr" "warning: baseline $TMP/bad.json unreadable" \
  "$(py "b.load('$TMP/bad.json')" | sed 's/ (.*//')"
check "malformed gives none" "None" "$(py "print(b.load('$TMP/bad.json'))" | tail -1)"

echo "Test 7: write CLI"
cli() { BASELINE_INPUT="$1" python3 "$MOD" write "$TMP/out.json" "$2" 2>&1; echo "exit $?"; }
rm -f "$TMP/out.json"
check "empty input" "kind: plain
exit 0" "$(cli '' abc1234)"
check "no file written" "no" "$([ -e "$TMP/out.json" ] && echo yes || echo no)"
check "same commit update" "kind: update, same commit
exit 0" "$(cli "$(valid abc1234)" abc1234)"
check "file same_commit" "True" "$(python3 -c "import json;print(json.load(open('$TMP/out.json'))['same_commit'])")"
rm -f "$TMP/out.json"
check "different commit resubmission" "kind: resubmission
exit 0" "$(cli '{"sha":"abc1234","sent_at":1,"recommendation":"reject","apps":{"root":"reject"}}' def5678)"
rm -f "$TMP/out.json"
check "malformed" "1|kind: plain|exit 0" "$(cli '{' abc1234 | sed -n '1s/^::warning::baseline input ignored: .*/1/p;2p;3p' | tr '\n' '|' | sed 's/|$//')"
check "unhashable recommendation via CLI" "1|kind: plain|exit 0" "$(cli '{"sha":"abc1234","sent_at":1,"recommendation":["x"],"apps":{}}' abc1234 | sed -n '1s/^::warning::baseline input ignored: .*/1/p;2p;3p' | tr '\n' '|' | sed 's/|$//')"
check "unhashable app decision via CLI" "1|kind: plain|exit 0" "$(cli '{"sha":"abc1234","sent_at":1,"recommendation":"accept","apps":{"a":{}}}' abc1234 | sed -n '1s/^::warning::baseline input ignored: .*/1/p;2p;3p' | tr '\n' '|' | sed 's/|$//')"
check "malformed writes nothing" "no" "$([ -e "$TMP/out.json" ] && echo yes || echo no)"

echo; echo "Done: $pass passed, $fail failed."; [ "$fail" -eq 0 ]
