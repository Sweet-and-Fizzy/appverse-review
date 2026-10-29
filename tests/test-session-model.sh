#!/usr/bin/env bash
# Test session-model.py: the model a session ran, read from its Claude Code execution log.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SM="$SCRIPT_DIR/references/session-model.py"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0
check() { local name="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then echo "  PASS  $name"; pass=$((pass+1)); else echo "  FAIL  $name: expected '$expected', got '$actual'"; fail=$((fail+1)); fi; }
run() { local out; out=$(python3 "$SM" "$1" 2>/dev/null); echo "$out|$?"; }

echo "Test 1: the init message names the model"
echo '[{"type": "system", "subtype": "init", "model": "claude-opus-5-5", "tools": []}, {"type": "result", "subtype": "success"}]' > "$TMP/a.json"
check "printed" "claude-opus-5-5|0" "$(run "$TMP/a.json")"

echo "Test 2: with no init model, the first assistant message's model"
echo '[{"type": "system", "subtype": "init"}, {"type": "assistant", "message": {"model": "claude-sonnet-5-5", "content": []}}]' > "$TMP/b.json"
check "printed" "claude-sonnet-5-5|0" "$(run "$TMP/b.json")"

echo "Test 3: a gateway model id is printed as is"
echo '[{"type": "system", "subtype": "init", "model": "ccs/Qwen/Qwen3.6-35B-A3B-FP8"}]' > "$TMP/c.json"
check "printed" "ccs/Qwen/Qwen3.6-35B-A3B-FP8|0" "$(run "$TMP/c.json")"

echo "Test 4: nothing usable is exit 1 with nothing printed"
echo '[{"type": "result"}]' > "$TMP/d.json"
check "no model" "|1" "$(run "$TMP/d.json")"
check "missing file" "|1" "$(run "$TMP/none.json")"
echo 'not json' > "$TMP/e.json"
check "not JSON" "|1" "$(run "$TMP/e.json")"

echo "Test 5: a model id with characters outside . _ / : - letters and digits is refused (it goes to GITHUB_ENV)"
printf '[{"type": "system", "subtype": "init", "model": "claude\\nEVIL=1"}]' > "$TMP/f.json"
check "newline refused" "|1" "$(run "$TMP/f.json")"
echo '[{"type": "system", "subtype": "init", "model": "a b"}]' > "$TMP/g.json"
check "space refused" "|1" "$(run "$TMP/g.json")"

echo
echo "session-model: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
