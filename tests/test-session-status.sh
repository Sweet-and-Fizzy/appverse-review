#!/usr/bin/env bash
# Test session-status.py: how a Claude Code session ended, read from its execution log.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SS="$SCRIPT_DIR/references/session-status.py"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0
check() { local name="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then echo "  PASS  $name"; pass=$((pass+1)); else echo "  FAIL  $name: expected '$expected', got '$actual'"; fail=$((fail+1)); fi; }
run() { local out; out=$(python3 "$SS" "$1" 2>/dev/null); echo "$out|$?"; }

echo "Test 1: a session that finished"
echo '[{"type": "system", "subtype": "init"}, {"type": "result", "subtype": "success", "is_error": false, "result": "Done."}]' > "$TMP/ok.json"
check "ok" "ok|0" "$(run "$TMP/ok.json")"

echo "Test 2: a session that ran out of turns"
echo '[{"type": "result", "subtype": "error_max_turns", "is_error": true}]' > "$TMP/turns.json"
check "max_turns" "max_turns|0" "$(run "$TMP/turns.json")"

echo "Test 3: a session the API stopped because its input passed the model's limit (the llama repair2 case and Anthropic's wording)"
echo '[{"type": "result", "subtype": "success", "is_error": true, "result": "API Error: 400 Your input is too long for ccs/Qwen/Qwen3.6-35B-A3B-FP8. The limit counts your input only"}]' > "$TMP/gw.json"
check "gateway wording" "context_overflow|0" "$(run "$TMP/gw.json")"
echo '[{"type": "result", "subtype": "success", "is_error": true, "result": "API Error: 400 {\"type\":\"error\",\"error\":{\"type\":\"invalid_request_error\",\"message\":\"prompt is too long: 212345 tokens > 200000 maximum\"}}"}]' > "$TMP/anth.json"
check "Anthropic wording" "context_overflow|0" "$(run "$TMP/anth.json")"
echo '[{"type": "result", "subtype": "success", "is_error": true, "result": "API Error: 400 This model'"'"'s maximum context length is 131072 tokens. However, you requested 140000 tokens"}]' > "$TMP/vllm.json"
check "OpenAI-style wording" "context_overflow|0" "$(run "$TMP/vllm.json")"

echo "Test 3b: more overflow wordings (Anthropic's max_tokens form, vLLM's)"
echo '[{"type": "result", "is_error": true, "result": "API Error: 400 input length and `max_tokens` exceed context limit: 190000 + 32000 > 200000"}]' > "$TMP/anth2.json"
check "exceed context limit" "context_overflow|0" "$(run "$TMP/anth2.json")"
echo '[{"type": "result", "is_error": true, "result": "API Error: 400 The decoder prompt (length 270000) is longer than the maximum model length of 262144."}]' > "$TMP/vllm2.json"
check "longer than the maximum model length" "context_overflow|0" "$(run "$TMP/vllm2.json")"

echo "Test 3c: a rate limit and an output cap are errors, not overflows"
echo '[{"type": "result", "is_error": true, "result": "API Error: 429 too many tokens per minute"}]' > "$TMP/rate.json"
check "rate limit" "error|0" "$(run "$TMP/rate.json")"
echo '[{"type": "result", "is_error": true, "result": "API Error: Claude'"'"'s response exceeded the 8192 output token maximum."}]' > "$TMP/outcap.json"
check "output cap" "error|0" "$(run "$TMP/outcap.json")"

echo "Test 4: another API error is not an overflow; a long answer that mentions length is not one either"
echo '[{"type": "result", "subtype": "success", "is_error": true, "result": "API Error: 529 overloaded"}]' > "$TMP/other.json"
check "other error" "error|0" "$(run "$TMP/other.json")"
echo '[{"type": "result", "subtype": "success", "is_error": false, "result": "The README is too long for a stub."}]' > "$TMP/prose.json"
check "prose" "ok|0" "$(run "$TMP/prose.json")"

echo "Test 5: no result message, or an unreadable log"
echo '[{"type": "system", "subtype": "init"}]' > "$TMP/none.json"
check "no result" "no_result|0" "$(run "$TMP/none.json")"
echo 'not json' > "$TMP/bad.json"
check "not JSON" "|1" "$(run "$TMP/bad.json")"
check "missing file" "|1" "$(run "$TMP/missing.json")"
check "usage" "|1" "$(run "")"

echo; echo "session-status: $pass passed, $fail failed"; [ "$fail" -eq 0 ]
