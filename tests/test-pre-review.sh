#!/usr/bin/env bash
# Test run-pre-review.sh / pre-review.py: tools and the shell syntax check run before the model, results as JSON.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RUN="$SCRIPT_DIR/references/run-pre-review.sh"
FIX="$SCRIPT_DIR/tests/fixtures"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0
check() { local name="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then echo "  PASS  $name"; pass=$((pass+1)); else echo "  FAIL  $name: expected '$expected', got '$actual'"; fail=$((fail+1)); fi; }
skip() { echo "  SKIP  $1"; pass=$((pass+1)); }
run() { bash "$RUN" "$@" > "$TMP/stdout" 2> "$TMP/stderr"; echo $?; }
# jq-free JSON reads: j <file> <python expression over d>
j() { python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(eval(sys.argv[2]))' "$1" "$2" 2>&1; }
# chk <out> <name> <field>: one field of one check record in summary.json
chk() { j "$1/summary.json" "[c for c in d['checks'] if c['name']=='$2'][0]['$3']"; }
# syn <out> <path> <field>: one field of one syntax.json entry
syn() { j "$1/syntax.json" "[e for e in d if e['path']=='$2'][0]['$3']"; }

echo "Test 1: missing target is exit 2"
check "exit 2" 2 "$(run "$TMP/nope" "$TMP/o1")"
check "stderr" 1 "$(grep -c 'target directory not found' "$TMP/stderr")"

echo "Test 2: containerized-server summary shape"
O="$TMP/cs"
check "exit 0" 0 "$(run "$FIX/containerized-server" "$O")"
check "schema" "pre-review/1" "$(j "$O/summary.json" "d['schema']")"
check "check names in order" "syntax,shellcheck,semgrep,bandit,trivy,catalog" "$(j "$O/summary.json" "','.join(c['name'] for c in d['checks'])")"
check "every status allowed" "True" "$(j "$O/summary.json" "all(c['status'] in ('ran','not_installed','failed_to_run','skipped') for c in d['checks'])")"
check "every record has the contract fields" "True" "$(j "$O/summary.json" "all(set(c)>=set(['name','status','version','command','exit_code','output_file','files_examined','note']) for c in d['checks'])")"
check "target absolute" "True" "$(j "$O/summary.json" "d['target'].startswith('/')")"
check "generated_at UTC" "True" "$(j "$O/summary.json" "d['generated_at'].endswith('Z')")"
check "catalog skipped" "skipped" "$(chk "$O" catalog status)"
check "catalog note" "catalog reads land in a later PR" "$(chk "$O" catalog note)"

echo "Test 3: containerized-server syntax.json"
check "paths" "template/after.sh,template/before.sh.erb,template/create_nginx_conf.sh.erb,template/script.sh.erb" "$(j "$O/syntax.json" "','.join(sorted(e['path'] for e in d))")"
check "after.sh not stripped" "False" "$(syn "$O" template/after.sh stripped)"
for f in before.sh.erb create_nginx_conf.sh.erb script.sh.erb; do
  check "$f stripped" "True" "$(syn "$O" "template/$f" stripped)"
done
check "all ok" "True" "$(j "$O/syntax.json" "all(e['ok'] for e in d)")"
check "syntax ran" "ran" "$(chk "$O" syntax status)"
check "syntax files_examined" "4" "$(chk "$O" syntax files_examined)"
check "syntax output_file" "syntax.json" "$(chk "$O" syntax output_file)"

echo "Test 4: bad shell fails, multi-line ERB strips cleanly with line numbers kept"
T="$TMP/t4"; mkdir -p "$T"
printf 'if [ ; then\n' > "$T/bad.sh"
printf '#!/bin/bash\n<%% if x\n%%>\nTIMEOUT=<%%= x %%>\necho "$TIMEOUT"\n<%%# a\ncomment %%>\n' > "$T/good.sh.erb"
O="$TMP/o4"
check "exit 0" 0 "$(run "$T" "$O")"
check "bad.sh not ok" "False" "$(syn "$O" bad.sh ok)"
check "bad.sh stderr syntax error" "True" "$(syn "$O" bad.sh stderr | grep -q 'syntax error' && echo True || echo False)"
check "bad.sh stderr names the repo path" "True" "$(syn "$O" bad.sh stderr | grep -q "^bad.sh:" && echo True || echo False)"
check "good.sh.erb ok" "True" "$(syn "$O" good.sh.erb ok)"
check "good.sh.erb stripped" "True" "$(syn "$O" good.sh.erb stripped)"
check "stripped copy line count" "$(wc -l < "$T/good.sh.erb" | tr -d ' ')" "$(wc -l < "$O/stripped/good.sh.erb.sh" | tr -d ' ')"
check "stripped copy ERBVALUE" 1 "$(grep -c '^TIMEOUT=ERBVALUE$' "$O/stripped/good.sh.erb.sh")"
check "stripped copy no ERB left" 0 "$(grep -c '<%' "$O/stripped/good.sh.erb.sh")"

echo "Test 5: monorepo"
O="$TMP/mono"
check "exit 0" 0 "$(run "$FIX/monorepo" "$O")"
check "shared/common.sh listed" "True" "$(j "$O/syntax.json" "any(e['path']=='shared/common.sh' for e in d)")"
check "bandit skipped" "skipped" "$(chk "$O" bandit status)"
check "bandit note" "no applicable files" "$(chk "$O" bandit note)"
check "bandit no output file" "False" "$([ -e "$O/bandit.json" ] && echo True || echo False)"
check "trivy skipped (no manifests)" "skipped" "$(chk "$O" trivy status)"

echo "Test 6: passenger-flask-app counts"
O="$TMP/flask"
check "exit 0" 0 "$(run "$FIX/passenger-flask-app" "$O")"
check "bandit files_examined" "4" "$(chk "$O" bandit files_examined)"
check "bandit ran or not_installed" "True" "$(j "$O/summary.json" "[c for c in d['checks'] if c['name']=='bandit'][0]['status'] in ('ran','not_installed')")"
check "trivy files_examined" "1" "$(chk "$O" trivy files_examined)"
if [ "$(chk "$O" trivy status)" = failed_to_run ] && chk "$O" trivy note | grep -qiE 'db|download|network|dial|connection'; then
  skip "trivy offline (cannot fetch its DB)"; skip "trivy offline (cannot fetch its DB)"
else
  check "trivy ran or not_installed" "True" "$(j "$O/summary.json" "[c for c in d['checks'] if c['name']=='trivy'][0]['status'] in ('ran','not_installed')")"
  if command -v trivy >/dev/null 2>&1; then
    check "trivy.json is trivy's own JSON" "True" "$(j "$O/trivy.json" "'SchemaVersion' in d")"
  else skip "trivy not installed"; fi
fi
if command -v bandit >/dev/null 2>&1; then
  check "bandit.json is bandit's own JSON" "True" "$(j "$O/bandit.json" "'results' in d")"
else skip "bandit not installed"; fi

echo "Test 7: no tools on PATH"
BIN="$TMP/bin"; mkdir -p "$BIN"
for b in python3 bash sh env; do ln -s "$(command -v "$b")" "$BIN/$b"; done
T="$TMP/t7"; mkdir -p "$T"
printf 'echo hi\n' > "$T/a.sh"; printf 'print(1)\n' > "$T/b.py"; printf 'flask\n' > "$T/requirements.txt"
O="$TMP/o7"
check "exit 0" 0 "$(PATH="$BIN" "$BIN/bash" "$RUN" "$T" "$O" > "$TMP/stdout" 2> "$TMP/stderr"; echo $?)"
for t in shellcheck semgrep bandit trivy; do
  check "$t not_installed" "not_installed" "$(chk "$O" "$t" status)"
  check "$t note non-empty" "True" "$(j "$O/summary.json" "bool([c for c in d['checks'] if c['name']=='$t'][0]['note'])")"
  check "$t version empty" "" "$(chk "$O" "$t" version)"
  check "no $t.json" "False" "$([ -e "$O/$t.json" ] && echo True || echo False)"
done
check "shellcheck install hint" "apt install shellcheck / brew install shellcheck" "$(chk "$O" shellcheck note)"
check "bandit install hint" "pip install bandit" "$(chk "$O" bandit note)"
check "syntax ran" "ran" "$(chk "$O" syntax status)"

echo "Test 8: shellcheck output on containerized-server"
O="$TMP/cs"
if command -v shellcheck >/dev/null 2>&1; then
  check "shellcheck ran" "ran" "$(chk "$O" shellcheck status)"
  check "shellcheck.json is a list" "True" "$(j "$O/shellcheck.json" "isinstance(d, list)")"
  check "shellcheck.json non-empty" "True" "$(j "$O/shellcheck.json" "len(d) > 0")"
  check "every file under template/" "True" "$(j "$O/shellcheck.json" "all(e['file'].startswith('template/') for e in d)")"
  check "command" "True" "$(j "$O/summary.json" "[c for c in d['checks'] if c['name']=='shellcheck'][0]['command'].startswith('shellcheck -f json -S warning')")"
  check "files_examined" "4" "$(chk "$O" shellcheck files_examined)"
  check "version line carries a number" "True" "$(j "$O/summary.json" "any(ch.isdigit() for ch in [c for c in d['checks'] if c['name']=='shellcheck'][0]['version'])")"
else skip "shellcheck not installed"; fi
if [ "$(chk "$O" semgrep status)" = ran ]; then
  check "semgrep note explains files_examined" "files_examined is the tree size; semgrep applies its own ignore list (tests/, vendored dirs)" "$(chk "$O" semgrep note)"
else skip "semgrep did not run"; fi

echo "Test 9: flags"
T="$TMP/t9"; mkdir -p "$T"; printf 'echo hi\n' > "$T/a.sh"
check "--catalog accepted" 0 "$(run "$T" "$TMP/o9a" --catalog https://example.org)"
check "catalog still skipped" "skipped" "$(chk "$TMP/o9a" catalog status)"
check "--no-catalog accepted" 0 "$(run "$T" "$TMP/o9b" --no-catalog)"
check "unknown flag exit 2" 2 "$(run "$T" "$TMP/o9c" --bogus)"
check "usage on stderr" 1 "$(grep -c '^usage:' "$TMP/stderr")"

echo "Test 10: rerun into the same out-dir leaves no stale tool file"
O="$TMP/o10"; mkdir -p "$O/stripped"
echo '{"stale":true}' > "$O/bandit.json"; echo stale > "$O/stripped/old.sh"
check "exit 0" 0 "$(run "$FIX/monorepo" "$O")"
check "stale bandit.json gone" "False" "$([ -e "$O/bandit.json" ] && echo True || echo False)"
check "stale stripped copy gone" "False" "$([ -e "$O/stripped/old.sh" ] && echo True || echo False)"
check "second run exit 0" 0 "$(run "$FIX/monorepo" "$O")"
check "summary rewritten" "pre-review/1" "$(j "$O/summary.json" "d['schema']")"

has_sc() { command -v shellcheck >/dev/null 2>&1; }

echo "Test 11: a dangling or unreadable shell file fails its own entry, the rest still run"
T="$TMP/t11"; mkdir -p "$T"
printf 'echo hi\n' > "$T/good.sh"
ln -s /nonexistent "$T/dangling.sh.erb"
printf 'echo <%%= x %%>\n' > "$T/locked.sh.erb"; chmod 000 "$T/locked.sh.erb"
O="$TMP/o11"
check "exit 0" 0 "$(run "$T" "$O")"
check "syntax ran" "ran" "$(chk "$O" syntax status)"
check "good.sh ok" "True" "$(syn "$O" good.sh ok)"
check "dangling not ok" "False" "$(syn "$O" dangling.sh.erb ok)"
check "dangling stderr" "True" "$(syn "$O" dangling.sh.erb stderr | grep -qE 'No such file|not a regular file' && echo True || echo False)"
if [ -r "$T/locked.sh.erb" ]; then skip "running as root, chmod 000 is readable"; skip "root"; skip "root"
else
  check "unreadable not ok" "False" "$(syn "$O" locked.sh.erb ok)"
  check "unreadable stderr" "True" "$(syn "$O" locked.sh.erb stderr | grep -q 'Permission denied' && echo True || echo False)"
  if has_sc; then check "shellcheck note names the unreadable file" "True" "$(chk "$O" shellcheck note | grep -q 'not scanned (unreadable): locked.sh.erb' && echo True || echo False)"
  else skip "shellcheck not installed"; fi
fi
check "dangling excluded from syntax files_examined" "2" "$(chk "$O" syntax files_examined)"
if has_sc; then
  check "shellcheck ran" "ran" "$(chk "$O" shellcheck status)"
  check "shellcheck scanned only the readable file" "1" "$(chk "$O" shellcheck files_examined)"
else skip "shellcheck not installed"; skip "shellcheck not installed"; fi
chmod 600 "$T/locked.sh.erb"

echo "Test 12: symlinks out of the target and FIFOs are never read"
T="$TMP/t12"; mkdir -p "$T"
printf 'echo <%%= x %%>\n' > "$T/real.sh.erb"
ln -s /etc/hosts "$T/leak.sh.erb"
ln -s ./real.sh.erb "$T/inside.sh.erb"
mkfifo "$T/fifo.sh.erb"
O="$TMP/o12"
check "exit 0" 0 "$(run "$T" "$O")"
check "leak not ok" "False" "$(syn "$O" leak.sh.erb ok)"
check "leak stderr" "symlink outside target, not checked" "$(syn "$O" leak.sh.erb stderr)"
check "no stripped copy of leak" "False" "$([ -e "$O/stripped/leak.sh.erb.sh" ] && echo True || echo False)"
check "fifo not ok" "False" "$(syn "$O" fifo.sh.erb ok)"
check "fifo stderr" "not a regular file, not checked" "$(syn "$O" fifo.sh.erb stderr)"
check "inside checked" "True" "$(syn "$O" inside.sh.erb ok)"
check "inside stripped copy" "1" "$(grep -c 'ERBVALUE' "$O/stripped/inside.sh.erb.sh")"
check "syntax files_examined counts real + inside only" "2" "$(chk "$O" syntax files_examined)"
if has_sc; then check "shellcheck files_examined" "2" "$(chk "$O" shellcheck files_examined)"
  check "no shellcheck entry for leak or fifo" "0" "$(j "$O/shellcheck.json" "len([e for e in d if e['file'] in ('leak.sh.erb','fifo.sh.erb')])")"
else skip "shellcheck not installed"; skip "shellcheck not installed"; fi
check "semgrep files_examined excludes leak and fifo" "2" "$(chk "$O" semgrep files_examined)"

echo "Test 13: a file named like an option is passed as a path"
T="$TMP/t13"; mkdir -p "$T"; printf '#!/bin/bash\ncd "$1"\n' > "$T/-x.sh"
O="$TMP/o13"
check "exit 0" 0 "$(run "$T" "$O")"
check "-x.sh ok" "True" "$(syn "$O" -x.sh ok)"
check "-x.sh stderr empty" "" "$(syn "$O" -x.sh stderr)"
if has_sc; then
  check "shellcheck ran" "ran" "$(chk "$O" shellcheck status)"
  check "SC2164 reported against -x.sh" "True" "$(j "$O/shellcheck.json" "any(e['file']=='-x.sh' and e['code']==2164 for e in d)")"
else skip "shellcheck not installed"; skip "shellcheck not installed"; fi

echo "Test 14: out-dir must not be the target; an out-dir inside the target is not walked"
T="$TMP/t14"; mkdir -p "$T"; printf 'echo hi\n' > "$T/a.sh"; printf 'x: 1\n' > "$T/form.yml"
check "out == target exit 2" 2 "$(run "$T" "$T")"
check "out == target message" 1 "$(grep -c 'out-dir must not be the target' "$TMP/stderr")"
check "out == target via trailing slash exit 2" 2 "$(run "$T" "$T/")"
check "first run inside target" 0 "$(run "$T" "$T/pre-review")"
check "second run inside target" 0 "$(run "$T" "$T/pre-review")"
check "syntax lists only a.sh" "a.sh" "$(j "$T/pre-review/syntax.json" "','.join(e['path'] for e in d)")"
check "semgrep files_examined ignores out-dir" "2" "$(chk "$T/pre-review" semgrep files_examined)"

echo "Test 15: a crashing tool with empty stderr reports its stdout"
FB="$TMP/fakebin"; mkdir -p "$FB"
for b in python3 bash sh env; do ln -s "$(command -v "$b")" "$FB/$b"; done
printf '#!/bin/sh\n[ "$1" = --version ] && { echo "Version: 9.9"; exit 0; }\necho "fatal: could not open cache"\nexit 1\n' > "$FB/trivy"; chmod +x "$FB/trivy"
T="$TMP/t15"; mkdir -p "$T"; printf 'flask\n' > "$T/requirements.txt"
O="$TMP/o15"
check "exit 0" 0 "$(PATH="$FB" "$FB/bash" "$RUN" "$T" "$O" > "$TMP/stdout" 2> "$TMP/stderr"; echo $?)"
check "trivy failed_to_run" "failed_to_run" "$(chk "$O" trivy status)"
check "note is stdout" "fatal: could not open cache" "$(chk "$O" trivy note)"
check "trivy exit_code" "1" "$(chk "$O" trivy exit_code)"
check "no trivy.json" "False" "$([ -e "$O/trivy.json" ] && echo True || echo False)"

echo; echo "Done: $pass passed, $fail failed."; [ "$fail" -eq 0 ]
