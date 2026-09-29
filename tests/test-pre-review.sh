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
has_sc() { command -v shellcheck >/dev/null 2>&1; }
yn() { if "$@"; then echo True; else echo False; fi; }

# The syntax check needs bash >= 4. Where the only bash is older (macOS
# /bin/bash 3.2), the bash -n tests run through a shim that reports 5.x and
# execs the real bash, so the stripping and bookkeeping paths stay covered;
# Test 20 covers the bash < 4 path itself.
REAL_BASH="$(command -v bash)"
BASH4="$REAL_BASH"
if [ "$("$REAL_BASH" -c 'echo "${BASH_VERSINFO[0]}"')" -lt 4 ]; then
  mkdir -p "$TMP/bash4"; BASH4="$TMP/bash4/bash"
  printf '#!/bin/sh\n[ "$1" = --version ] && { echo "GNU bash, version 5.2.0(1)-release (shim)"; exit 0; }\nexec "%s" "$@"\n' "$REAL_BASH" > "$BASH4"
  chmod +x "$BASH4"; PATH="$TMP/bash4:$PATH"; export PATH
  echo "NOTE: bash on PATH is older than 4; bash -n tests run through a version shim"
fi
# fakebin <dir>: a PATH dir holding only python3, sh, env and bash (>= 4)
fakebin() { mkdir -p "$1"; for b in python3 sh env; do ln -sf "$(command -v "$b")" "$1/$b"; done; ln -sf "$BASH4" "$1/bash"; }

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
if [ "$(chk "$O" trivy status)" = failed_to_run ] && chk "$O" trivy note | grep 'FATAL' | grep -qE 'download|DB|network'; then
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
BIN="$TMP/bin"; fakebin "$BIN"
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
  check "command" "shellcheck --norc -f json -S info <file> (per shell file; .sh.erb scanned as its ERB-stripped copy)" "$(chk "$O" shellcheck command)"
  check "files_examined" "4" "$(chk "$O" shellcheck files_examined)"
  check "version line carries a number" "True" "$(j "$O/summary.json" "any(ch.isdigit() for ch in [c for c in d['checks'] if c['name']=='shellcheck'][0]['version'])")"
else skip "shellcheck not installed"; fi
if python3 -c 'import shutil,sys; sys.exit(shutil.which("semgrep") is None)'; then
  check "semgrep ran" "ran" "$(chk "$O" semgrep status)"
  [ "$(chk "$O" semgrep status)" = ran ] || echo "        semgrep note: $(chk "$O" semgrep note)"
  check "semgrep note explains files_examined and names the rulesets" "files_examined is semgrep's paths.scanned; rulesets p/security-audit, p/secrets" "$(chk "$O" semgrep note)"
  check "semgrep files_examined is paths.scanned" "$(j "$O/semgrep.json" "len(d['paths']['scanned'])")" "$(chk "$O" semgrep files_examined)"
else skip "semgrep not installed"; skip "semgrep not installed"; skip "semgrep not installed"; fi

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
check "refused .sh.erb not stripped" "False" "$(syn "$O" leak.sh.erb stripped)"
check "no stripped copy of leak" "False" "$([ -e "$O/stripped/leak.sh.erb.sh" ] && echo True || echo False)"
check "fifo not ok" "False" "$(syn "$O" fifo.sh.erb ok)"
check "fifo stderr" "not a regular file, not checked" "$(syn "$O" fifo.sh.erb stderr)"
check "inside checked" "True" "$(syn "$O" inside.sh.erb ok)"
check "inside stripped copy" "1" "$(grep -c 'ERBVALUE' "$O/stripped/inside.sh.erb.sh")"
check "syntax files_examined counts real + inside only" "2" "$(chk "$O" syntax files_examined)"
if has_sc; then check "shellcheck files_examined" "2" "$(chk "$O" shellcheck files_examined)"
  check "no shellcheck entry for leak or fifo" "0" "$(j "$O/shellcheck.json" "len([e for e in d if e['file'] in ('leak.sh.erb','fifo.sh.erb')])")"
else skip "shellcheck not installed"; skip "shellcheck not installed"; fi
if [ "$(chk "$O" semgrep status)" = ran ]; then
  check "semgrep scanned neither leak nor fifo" "0" "$(j "$O/semgrep.json" "len([p for p in d['paths']['scanned'] if p in ('leak.sh.erb','fifo.sh.erb')])")"
else skip "semgrep did not run"; fi

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
if [ "$(chk "$T/pre-review" semgrep status)" = ran ]; then
  check "semgrep files_examined ignores out-dir" "2" "$(chk "$T/pre-review" semgrep files_examined)"
  check "semgrep command excludes out-dir, anchored" "True" "$(yn grep -q -- '--exclude /pre-review ' <<< "$(chk "$T/pre-review" semgrep command)")"
else skip "semgrep did not run"; skip "semgrep did not run"; fi

echo "Test 15: a crashing tool with empty stderr reports its stdout"
FB="$TMP/fakebin"; fakebin "$FB"
printf '#!/bin/sh\n[ "$1" = --version ] && { echo "Version: 9.9"; exit 0; }\necho "fatal: could not open cache"\nexit 1\n' > "$FB/trivy"; chmod +x "$FB/trivy"
T="$TMP/t15"; mkdir -p "$T"; printf 'flask\n' > "$T/requirements.txt"
O="$TMP/o15"
check "exit 0" 0 "$(PATH="$FB" "$FB/bash" "$RUN" "$T" "$O" > "$TMP/stdout" 2> "$TMP/stderr"; echo $?)"
check "trivy failed_to_run" "failed_to_run" "$(chk "$O" trivy status)"
check "note is stdout" "fatal: could not open cache" "$(chk "$O" trivy note)"
check "trivy exit_code" "1" "$(chk "$O" trivy exit_code)"
check "no trivy.json" "False" "$([ -e "$O/trivy.json" ] && echo True || echo False)"

has_trivy() { command -v trivy >/dev/null 2>&1; }
has_semgrep() { python3 -c 'import shutil,sys; sys.exit(shutil.which("semgrep") is None)'; }

echo "Test 14b: an in-target out-dir is skipped by path, not by name"
T="$TMP/t14b"; mkdir -p "$T/app/pre-review"
printf 'flask==0.12\n' > "$T/requirements.txt"; printf 'flask==0.12\n' > "$T/app/pre-review/requirements.txt"
printf 'echo hi\n' > "$T/app/pre-review/b.sh"
O="$T/pre-review"
check "exit 0" 0 "$(run "$T" "$O")"
check "trivy command skips the out-dir by relative path" "True" "$(yn grep -qF -- '--skip-dirs pre-review --config' <<< "$(chk "$O" trivy command)")"
if [ "$(chk "$O" semgrep status)" = ran ]; then
  check "semgrep still scans app/pre-review" "True" "$(j "$O/semgrep.json" "'app/pre-review/b.sh' in d['paths']['scanned']")"
else skip "semgrep did not run"; fi
if [ "$(chk "$O" trivy status)" = ran ]; then
  check "trivy still scans app/pre-review" "True" "$(j "$O/trivy.json" "'app/pre-review/requirements.txt' in [r['Target'] for r in d.get('Results', [])]")"
else skip "trivy did not run"; fi

echo "Test 16: a target's trivy.yaml cannot make trivy write outside the out-dir"
T="$TMP/t16"; mkdir -p "$T" "$TMP/escape"; printf 'flask==0.12\n' > "$T/requirements.txt"
printf 'output: %s/escape/pwned.json\n' "$TMP" > "$T/trivy.yaml"
printf 'CVE-2018-1000656\n' > "$T/.trivyignore"
O="$TMP/o16"
if has_trivy; then
  check "exit 0" 0 "$(run "$T" "$O")"
  check "no file written at trivy.yaml's output path" "False" "$([ -e "$TMP/escape/pwned.json" ] && echo True || echo False)"
  check "command passes the empty config and ignore file and the absolute target" "True" "$(yn grep -qF -- "--config $O/trivy-empty.yaml --ignorefile $O/trivy-empty.ignore $T" <<< "$(chk "$O" trivy command)")"
  if [ "$(chk "$O" trivy status)" = ran ]; then
    check "note names trivy.yaml and .trivyignore" "target ships .trivyignore; its suppressions were ignored; target ships trivy.yaml; its suppressions were ignored" "$(chk "$O" trivy note)"
    check "trivy.json written in out-dir" "True" "$(j "$O/trivy.json" "'SchemaVersion' in d")"
  else echo "        trivy note: $(chk "$O" trivy note)"; skip "trivy did not run (offline?)"; skip "trivy did not run"; fi
else skip "trivy not installed"; skip "trivy not installed"; skip "trivy not installed"; skip "trivy not installed"; skip "trivy not installed"; fi

echo "Test 17: a target's .shellcheckrc cannot silence shellcheck"
T="$TMP/t17"; mkdir -p "$T"; printf 'disable=all\n' > "$T/.shellcheckrc"
printf '#!/bin/bash\nrm -rf $HOME/$x\n' > "$T/a.sh"
O="$TMP/o17"
check "exit 0" 0 "$(run "$T" "$O")"
if has_sc; then
  check "findings despite disable=all" "True" "$(j "$O/shellcheck.json" "len(d) > 0")"
  check "note names .shellcheckrc" "target ships .shellcheckrc; its suppressions were ignored" "$(chk "$O" shellcheck note)"
else skip "shellcheck not installed"; skip "shellcheck not installed"; fi

echo "Test 18: a target's .semgrepignore is reported"
T="$TMP/t18"; mkdir -p "$T"; printf '*\n' > "$T/.semgrepignore"; printf 'echo hi\n' > "$T/a.sh"
O="$TMP/o18"
check "exit 0" 0 "$(run "$T" "$O")"
if has_semgrep; then
  check "semgrep ran" "ran" "$(chk "$O" semgrep status)"
  check "files_examined 0" "0" "$(chk "$O" semgrep files_examined)"
  check "note names .semgrepignore" "files_examined is semgrep's paths.scanned; rulesets p/security-audit, p/secrets; target ships .semgrepignore; it may suppress findings" "$(chk "$O" semgrep note)"
else skip "semgrep not installed"; skip "semgrep not installed"; skip "semgrep not installed"; fi

echo "Test 19: finding_count and top_codes"
O="$TMP/cs"
check "every record has finding_count and top_codes" "True" "$(j "$O/summary.json" "all('finding_count' in c and isinstance(c['top_codes'], list) for c in d['checks'])")"
check "catalog finding_count null" "None" "$(chk "$O" catalog finding_count)"
check "trivy (skipped) finding_count null" "None" "$(chk "$O" trivy finding_count)"
if has_sc; then
  # Recomputed from shellcheck.json so the test holds across shellcheck versions.
  check "shellcheck finding_count is len(shellcheck.json)" "$(j "$O/shellcheck.json" "len(d)")" "$(chk "$O" shellcheck finding_count)"
  check "shellcheck top_codes: most frequent, then by code" "$(python3 -c 'import json,sys,collections; c=collections.Counter("SC%s" % e["code"] for e in json.load(open(sys.argv[1]))); print(",".join(k for k, _ in sorted(c.items(), key=lambda kv: (-kv[1], kv[0]))[:5]))' "$O/shellcheck.json")" "$(j "$O/summary.json" "','.join([c for c in d['checks'] if c['name']=='shellcheck'][0]['top_codes'])")"
  check "SC2086 present" "True" "$(j "$O/shellcheck.json" "any(e['code']==2086 for e in d)")"
  check "SC2155 present" "True" "$(j "$O/shellcheck.json" "any(e['code']==2155 for e in d)")"
else for i in 1 2 3 4; do skip "shellcheck not installed"; done; fi

echo "Test 20: bash older than 4 is failed_to_run, every file still listed"
OB="$TMP/oldbash"; mkdir -p "$OB"
printf '#!/bin/sh\n[ "$1" = --version ] && { echo "GNU bash, version 3.2.57(1)-release"; exit 0; }\nexec "%s" "$@"\n' "$REAL_BASH" > "$OB/bash"; chmod +x "$OB/bash"
T="$TMP/t20"; mkdir -p "$T"; printf 'echo hi\n' > "$T/a.sh"; printf 'echo <%%= x %%>\n' > "$T/b.sh.erb"
O="$TMP/o20"
check "exit 0" 0 "$(PATH="$OB:$PATH" "$REAL_BASH" "$RUN" "$T" "$O" > "$TMP/stdout" 2> "$TMP/stderr"; echo $?)"
check "syntax failed_to_run" "failed_to_run" "$(chk "$O" syntax status)"
check "syntax note" "bash >= 4 required for the syntax check (found 3.2.57)" "$(chk "$O" syntax note)"
check "syntax.json lists both files" "a.sh,b.sh.erb" "$(j "$O/syntax.json" "','.join(e['path'] for e in d)")"
check "every entry ok false with the reason" "True" "$(j "$O/syntax.json" "all(not e['ok'] and e['stderr']=='not checked: bash >= 4 required' and not e['stripped'] for e in d)")"

echo "Test 21: shellcheck reports SC2086 (info level)"
T="$TMP/t21"; mkdir -p "$T"; printf '#!/bin/bash\necho $1\n' > "$T/a.sh"
O="$TMP/o21"
check "exit 0" 0 "$(run "$T" "$O")"
if has_sc; then
  check "SC2086 reported" "True" "$(j "$O/shellcheck.json" "any(e['code']==2086 for e in d)")"
  check "top_codes" "SC2086" "$(j "$O/summary.json" "','.join([c for c in d['checks'] if c['name']=='shellcheck'][0]['top_codes'])")"
else skip "shellcheck not installed"; skip "shellcheck not installed"; fi

echo "Test 22: a <%% literal keeps the code after it"
T="$TMP/t22"; mkdir -p "$T"
printf '#!/bin/bash\n<%%%% rm -rf $HOME/$1 %%>\necho <%%= x %%>\n' > "$T/a.sh.erb"
O="$TMP/o22"
check "exit 0" 0 "$(run "$T" "$O")"
check "stripped copy keeps the literal region" "<% rm -rf \$HOME/\$1 %>" "$(sed -n 2p "$O/stripped/a.sh.erb.sh")"
check "real tag still stripped" "echo ERBVALUE" "$(sed -n 3p "$O/stripped/a.sh.erb.sh")"

echo "Test 23: syntax note counts checked files only"
T="$TMP/t23"; mkdir -p "$T"; printf 'if [ ; then\n' > "$T/bad.sh"; printf 'echo hi\n' > "$T/good.sh"
ln -s /etc/hosts "$T/leak.sh"; mkfifo "$T/fifo.sh"
O="$TMP/o23"
check "exit 0" 0 "$(run "$T" "$O")"
check "syntax note" "1 of 2 files failed bash -n" "$(chk "$O" syntax note)"
check "syntax exit_code" "1" "$(chk "$O" syntax exit_code)"

echo "Test 24: no bash on PATH still writes syntax.json"
NB="$TMP/nobash"; mkdir -p "$NB"; ln -s "$(command -v python3)" "$NB/python3"
T="$TMP/t24"; mkdir -p "$T"; printf 'echo hi\n' > "$T/a.sh"
O="$TMP/o24"
check "exit 0" 0 "$(PATH="$NB" "$NB/python3" "$SCRIPT_DIR/references/pre-review.py" "$T" "$O" > "$TMP/stdout" 2> "$TMP/stderr"; echo $?)"
check "syntax not_installed" "not_installed" "$(chk "$O" syntax status)"
check "syntax.json entry" "False|not checked: bash not found on PATH" "$(j "$O/syntax.json" "'%s|%s' % (d[0]['ok'], d[0]['stderr'])")"

echo "Test 25: trivy failure note is its FATAL line"
FB="$TMP/fb25"; fakebin "$FB"
printf '#!/bin/sh\n[ "$1" = --version ] && { echo "Version: 9.9"; exit 0; }\necho "INFO starting" >&2\necho "FATAL Fatal error: init error: DB error: failed to download vulnerability DB" >&2\necho "INFO trailing" >&2\nexit 1\n' > "$FB/trivy"; chmod +x "$FB/trivy"
T="$TMP/t25"; mkdir -p "$T"; printf 'flask\n' > "$T/requirements.txt"
O="$TMP/o25"
check "exit 0" 0 "$(PATH="$FB" "$FB/bash" "$RUN" "$T" "$O" > "$TMP/stdout" 2> "$TMP/stderr"; echo $?)"
check "note is the FATAL line" "FATAL Fatal error: init error: DB error: failed to download vulnerability DB" "$(chk "$O" trivy note)"
printf '#!/bin/sh\n[ "$1" = --version ] && { echo "Version: 9.9"; exit 0; }\necho "INFO starting" >&2\necho "error: last line" >&2\necho "" >&2\nexit 1\n' > "$FB/trivy"
O="$TMP/o25b"
check "exit 0 (no FATAL)" 0 "$(PATH="$FB" "$FB/bash" "$RUN" "$T" "$O" > "$TMP/stdout" 2> "$TMP/stderr"; echo $?)"
check "note is the last non-empty line" "error: last line" "$(chk "$O" trivy note)"

echo "Test 26: shell files over 1 MB are skipped"
T="$TMP/t26"; mkdir -p "$T"; printf 'echo hi\n' > "$T/small.sh"
python3 -c "import sys; open(sys.argv[1],'w').write('echo x\n' * 160000)" "$T/big.sh"
O="$TMP/o26"
check "exit 0" 0 "$(run "$T" "$O")"
check "big.sh ok false" "False" "$(syn "$O" big.sh ok)"
check "big.sh reason" "skipped: file larger than 1 MB" "$(syn "$O" big.sh stderr)"
check "syntax files_examined" "1" "$(chk "$O" syntax files_examined)"
if has_sc; then
  check "shellcheck files_examined" "1" "$(chk "$O" shellcheck files_examined)"
  check "no shellcheck entry for big.sh" "0" "$(j "$O/shellcheck.json" "len([e for e in d if e['file']=='big.sh'])")"
  check "shellcheck note names big.sh" "not scanned (larger than 1 MB): big.sh" "$(chk "$O" shellcheck note)"
else skip "shellcheck not installed"; skip "shellcheck not installed"; skip "shellcheck not installed"; fi

echo "Test 27: shellcheck exiting >= 2 is failed_to_run"
FB="$TMP/fb27"; fakebin "$FB"
printf '#!/bin/sh\n[ "$1" = --version ] && { echo "version: 0.0.1"; exit 0; }\necho "boom" >&2\nexit 3\n' > "$FB/shellcheck"; chmod +x "$FB/shellcheck"
T="$TMP/t27"; mkdir -p "$T"; printf 'echo hi\n' > "$T/a.sh"
O="$TMP/o27"
check "exit 0" 0 "$(PATH="$FB" "$FB/bash" "$RUN" "$T" "$O" > "$TMP/stdout" 2> "$TMP/stderr"; echo $?)"
check "shellcheck failed_to_run" "failed_to_run" "$(chk "$O" shellcheck status)"
check "exit_code 3" "3" "$(chk "$O" shellcheck exit_code)"
check "note" "a.sh: boom" "$(chk "$O" shellcheck note | tr -d '\n')"
check "finding_count null" "None" "$(chk "$O" shellcheck finding_count)"

echo "Test 28: a tool that runs past the timeout is failed_to_run"
FB="$TMP/fb28"; fakebin "$FB"
printf '#!/bin/sh\n[ "$1" = --version ] && { echo "version: 0.0.1"; exit 0; }\nexec /bin/sleep 5\n' > "$FB/shellcheck"; chmod +x "$FB/shellcheck"
O="$TMP/o28"
check "exit 0" 0 "$(PRE_REVIEW_TIMEOUT=1 PATH="$FB" "$FB/bash" "$RUN" "$T" "$O" > "$TMP/stdout" 2> "$TMP/stderr"; echo $?)"
check "shellcheck failed_to_run" "failed_to_run" "$(chk "$O" shellcheck status)"
check "note says timed out" "a.sh: timed out after 1 s" "$(chk "$O" shellcheck note)"

echo "Test 29: .sh.erb shellcheck lines map to source lines"
T="$TMP/t29"; mkdir -p "$T"
printf '#!/bin/bash\n<%% if x\n   y %%>\ncd /tmp\necho ok\n' > "$T/a.sh.erb"
O="$TMP/o29"
check "exit 0" 0 "$(run "$T" "$O")"
if has_sc; then
  check "SC2164 on source line 4" "4" "$(j "$O/shellcheck.json" "[e['line'] for e in d if e['code']==2164][0]")"
  check "file is the source path" "a.sh.erb" "$(j "$O/shellcheck.json" "[e['file'] for e in d if e['code']==2164][0]")"
else skip "shellcheck not installed"; skip "shellcheck not installed"; fi

echo; echo "Done: $pass passed, $fail failed."; [ "$fail" -eq 0 ]
