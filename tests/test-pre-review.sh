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

# Under a bash older than 4 the syntax check prefixes every failure (it may
# be false). Where the only bash is older (macOS /bin/bash 3.2), the other
# bash -n tests run through a shim that reports 5.x and execs the real bash,
# so their stderr assertions see plain bash messages; Test 20 covers both the
# < 4 and >= 4 paths with its own shims, whatever the real bash is.
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

echo "Test 20: bash older than 4 keeps passes and prefixes failures; bash >= 4 does not"
# vbash <dir> <version>: a bash that reports <version> and execs the real
# bash. c.sh uses ;;& (bash 4 syntax); where the real bash accepts it, the
# shim rejects it the way bash 3.2 does, so the failure path is covered on
# any machine.
vbash() { mkdir -p "$1"; printf '#!/bin/sh\n[ "$1" = --version ] && { echo "GNU bash, version %s(1)-release"; exit 0; }\nif [ "$1" = -n ] && grep -qF ";;&" "$2" 2>/dev/null && "%s" -n "$2" 2>/dev/null; then echo "$2: line 2: syntax error near unexpected token \`&'"'"'" >&2; exit 2; fi\nexec "%s" "$@"\n' "$2" "$REAL_BASH" "$REAL_BASH" > "$1/bash"; chmod +x "$1/bash"; }
T="$TMP/t20"; mkdir -p "$T"; printf 'echo hi\n' > "$T/a.sh"; printf 'echo <%%= x %%>\n' > "$T/b.sh.erb"
printf 'case x in\n  a) echo a ;;&\n  *) echo b ;;\nesac\n' > "$T/c.sh"
vbash "$TMP/bash32" 3.2.57; vbash "$TMP/bash52" 5.2.21
O="$TMP/o20"
check "exit 0" 0 "$(PATH="$TMP/bash32:$PATH" "$REAL_BASH" "$RUN" "$T" "$O" > "$TMP/stdout" 2> "$TMP/stderr"; echo $?)"
check "syntax ran" "ran" "$(chk "$O" syntax status)"
check "syntax version recorded" "True" "$(chk "$O" syntax version | grep -qF 3.2.57 && echo True || echo False)"
check "syntax note" "bash 3.2.57 on PATH: failures may be false; install bash >= 4 to confirm; 1 of 3 files failed bash -n" "$(chk "$O" syntax note)"
check "syntax files_examined" "3" "$(chk "$O" syntax files_examined)"
check "valid a.sh ok" "True|" "$(j "$O/syntax.json" "'%s|%s' % ([e for e in d if e['path']=='a.sh'][0]['ok'], [e for e in d if e['path']=='a.sh'][0]['stderr'])")"
check "valid b.sh.erb ok and stripped" "True|True" "$(j "$O/syntax.json" "'%s|%s' % ([e for e in d if e['path']=='b.sh.erb'][0]['ok'], [e for e in d if e['path']=='b.sh.erb'][0]['stripped'])")"
check "c.sh (;;&) not ok" "False" "$(syn "$O" c.sh ok)"
check "c.sh stderr carries the bash < 4 prefix" "True" "$(syn "$O" c.sh stderr | grep -q '^bash 3.2.57 rejected this file (may be valid on bash >= 4): c.sh: line 2: syntax error' && echo True || echo False)"
O="$TMP/o20b"
check "exit 0 (bash 5)" 0 "$(PATH="$TMP/bash52:$PATH" "$REAL_BASH" "$RUN" "$T" "$O" > "$TMP/stdout" 2> "$TMP/stderr"; echo $?)"
check "syntax ran (bash 5)" "ran" "$(chk "$O" syntax status)"
check "syntax note (bash 5)" "1 of 3 files failed bash -n" "$(chk "$O" syntax note)"
check "c.sh stderr is the plain bash message" "True" "$(syn "$O" c.sh stderr | grep -q '^c.sh: line 2: syntax error' && echo True || echo False)"

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

echo "Test 30: tool-table.md, PATH-restricted (no tools)"
check "exact contents" "$(printf '%s\n' '**Check tiers:** Tier 1 only' '' 'Tier 3 not checked — no isolated execution environment.' '' '| Tool | Status | Result |' '|---|---|---|' '| shellcheck | Not run (not installed) | — |' '| semgrep | Not run (not installed) | — |' '| bandit | Not run (not installed) | — |' '| trivy | Not run (not installed) | — |')" "$(cat "$TMP/o7/tool-table.md")"
check "ends with a newline" "True" "$(python3 -c 'import sys; print(open(sys.argv[1]).read().endswith("|\n"))' "$TMP/o7/tool-table.md")"

echo "Test 31: tool-table.md, containerized-server with only shellcheck"
if has_sc; then
  FB="$TMP/fb31"; fakebin "$FB"; ln -sf "$(command -v shellcheck)" "$FB/shellcheck"
  O="$TMP/o31"
  check "exit 0" 0 "$(PATH="$FB" "$FB/bash" "$RUN" "$FIX/containerized-server" "$O" > "$TMP/stdout" 2> "$TMP/stderr"; echo $?)"
  # The shellcheck Result is recomputed from shellcheck.json so the test holds across shellcheck versions.
  SC_RESULT="$(python3 -c 'import json,sys,collections; d=json.load(open(sys.argv[1])); c=collections.Counter("SC%s" % e["code"] for e in d); print("%d findings (%s)" % (len(d), ", ".join(k for k, _ in sorted(c.items(), key=lambda kv: (-kv[1], kv[0]))[:5])))' "$O/shellcheck.json")"
  check "exact contents" "$(printf '%s\n' '**Check tiers:** Tiers 1–2' '' 'Tier 3 not checked — no isolated execution environment.' '' '| Tool | Status | Result |' '|---|---|---|' "| shellcheck | Run (ERB-stripped) | $SC_RESULT |" '| semgrep | Not run (not installed) | — |' '| bandit | Not run (no applicable files) | — |' '| trivy | Not run (no applicable files) | — |')" "$(cat "$O/tool-table.md")"
else skip "shellcheck not installed"; skip "shellcheck not installed"; fi

# Fact scanners (apps.json, <out>/<app_id>/readme.json and form.json).
# app <out> <python expression over a (apps.json)>; fact <out> <app_id> <name> <expression over d>
app() { python3 -c 'import json,sys; a=json.load(open(sys.argv[1])); print(eval(sys.argv[2]))' "$1/apps.json" "$2" 2>&1; }
fact() { j "$1/$2/$3.json" "$4"; }
# fct <out> <scanner> <field>: one field of one fact record in summary.json
fct() { j "$1/summary.json" "[c for c in d['facts'] if c['name']=='$2'][0]['$3']"; }
has_yaml() { python3 -c 'import yaml' 2>/dev/null; }
if has_yaml; then PARSER_NOTE="YAML parser: PyYAML"; else PARSER_NOTE="YAML parser: built-in subset (PyYAML not importable)"; fi
ROW="'%s|%s|%s|%s' % (e['app_id'], e['path'], e['app_type'], e['readme'])"

echo "Test 32: app shape in apps.json"
O="$TMP/mono"
check "monorepo apps" "good-app|apps/good-app|batch_connect|README.md,bad-app|apps/bad-app|batch_connect|README.md" "$(app "$O" "','.join($ROW for e in a)")"
check "monorepo per-app dirs" "True|True" "$(yn test -d "$O/good-app")|$(yn test -d "$O/bad-app")"
check "summary facts in order" "readme,form" "$(j "$O/summary.json" "','.join(c['name'] for c in d['facts'])")"
check "checks unchanged" "syntax,shellcheck,semgrep,bandit,trivy,catalog" "$(j "$O/summary.json" "','.join(c['name'] for c in d['checks'])")"
check "readme per_app" "{'good-app': 'ran', 'bad-app': 'ran'}" "$(fct "$O" readme per_app)"
check "form per_app" "{'good-app': 'ran', 'bad-app': 'skipped'}" "$(fct "$O" form per_app)"
check "single app is root" "root|.|batch_connect|README.md" "$(app "$TMP/cs" "','.join($ROW for e in a)")"
check "passenger app" "root|.|passenger|README.md" "$(app "$TMP/flask" "','.join($ROW for e in a)")"
T="$TMP/t32"; mkdir -p "$T/a" "$T/b" "$T/c"
printf 'apps:\n  - path: a\n  - path: b\n    app_type: companion_app\n  - path: c\n  - path: ../escape\n' > "$T/appverse.yml"
printf 'run app\n' > "$T/a/config.ru"; printf 'name: B\n' > "$T/b/manifest.yml"; printf 'x: 1\n' > "$T/c/README.md"
O="$TMP/o32"
check "exit 0" 0 "$(run "$T" "$O")"
check "entry point, declared app_type, unknown, outside target" "a|a|passenger|None,b|b|companion|None,c|c|unknown|c/README.md,escape|../escape|unknown|None" "$(app "$O" "','.join($ROW for e in a)")"
check "outside-target app is not read" "skipped" "$(j "$O/summary.json" "[c for c in d['facts'] if c['name']=='readme'][0]['per_app']['escape']")"
check "readme note names the outside path" "True" "$(fct "$O" readme note | grep -qF 'escape: app path outside target, not read' && echo True || echo False)"
T="$TMP/t32b"; mkdir -p "$T"; printf 'echo hi\n' > "$T/a.sh"
check "no manifest is still one root app" 0 "$(run "$T" "$TMP/o32b")"
check "root unknown" "root|.|unknown|None" "$(app "$TMP/o32b" "','.join($ROW for e in a)")"
check "readme skipped without a README" "skipped" "$(fct "$TMP/o32b" readme status)"
check "no readme.json without a README" "False" "$(yn test -e "$TMP/o32b/root/readme.json")"

echo "Test 33: readme.json, containerized-server"
O="$TMP/cs"
check "file" "README.md" "$(fact "$O" root readme "d['file']")"
check "headings" "1|MLflow Tracking Server|1,2|Requirements|5" "$(fact "$O" root readme "','.join('%s|%s|%s' % (h['level'], h['text'], h['line']) for h in d['headings'])")"
check "rung keys in order" "what it launches,prerequisites,installation,configuration,known limitations,troubleshooting,screenshots,environment variables,info panel,architecture" "$(fact "$O" root readme "','.join(d['rungs'])")"
check "prerequisites rung" "{'heading': 'Requirements', 'line': 5, 'placeholder': False}" "$(fact "$O" root readme "d['rungs']['prerequisites']")"
check "other rungs null" "True" "$(fact "$O" root readme "all(v is None for k, v in d['rungs'].items() if k != 'prerequisites')")"
check "no placeholders, screenshots, env_vars" "[]|[]|[]" "$(fact "$O" root readme "'%s|%s|%s' % (d['placeholders'], d['screenshots'], d['env_vars'])")"
check "readme record ran" "ran|{'root': 'ran'}" "$(fct "$O" readme status)|$(fct "$O" readme per_app)"

echo "Test 34: readme.json, vnc-stale-debugger (a # inside a code fence is not a heading)"
O="$TMP/vnc"
check "exit 0" 0 "$(run "$FIX/vnc-stale-debugger" "$O")"
check "headings" "1|HPC Debugger|1,2|Overview|6,2|Requirements|11,2|Installation|17,2|Configuration|26" "$(fact "$O" root readme "','.join('%s|%s|%s' % (h['level'], h['text'], h['line']) for h in d['headings'])")"
check "rungs resolved" "what it launches:Overview:6,prerequisites:Requirements:11,installation:Installation:17,configuration:Configuration:26" "$(fact "$O" root readme "','.join('%s:%s:%s' % (k, v['heading'], v['line']) for k, v in d['rungs'].items() if v)")"
check "no rung is placeholder" "False" "$(fact "$O" root readme "any(v['placeholder'] for v in d['rungs'].values() if v)")"
check "no placeholders, screenshots, env_vars" "[]|[]|[]" "$(fact "$O" root readme "'%s|%s|%s' % (d['placeholders'], d['screenshots'], d['env_vars'])")"

echo "Test 35: readme.json, placeholders, screenshots, env vars, synonyms"
T="$TMP/t35"; mkdir -p "$T"
cat > "$T/README.md" <<'EOF'
# [Application Name]

## Overview

<!-- 2-3 sentences: What does this app launch? Who is it for? -->
[Application Name] is an Open OnDemand Batch Connect app that launches [software name and version].

## Screenshots
![Session view](docs/session.png)
[![build](https://img.shields.io/badge/build-passing.svg)](https://ci.example.org)

## Setup
Set the cluster in form.yml.

```bash
# not a heading
export MY_APP_HOME=/data/app
```

### Environment variables

Set the environment variable before launch.

Setup heading
=============

## FAQ

- [e.g., Multi-node jobs are not supported]
EOF
O="$TMP/o35"
check "exit 0" 0 "$(run "$T" "$O")"
check "headings (ATX and setext, none from the fence)" "1|[Application Name]|1,2|Overview|3,2|Screenshots|8,2|Setup|12,3|Environment variables|20,1|Setup heading|24,2|FAQ|27" "$(fact "$O" root readme "','.join('%s|%s|%s' % (h['level'], h['text'], h['line']) for h in d['headings'])")"
check "placeholder lines" "1,5,6,29" "$(fact "$O" root readme "','.join(str(p['line']) for p in d['placeholders'])")"
check "placeholder phrase recorded" "[Application Name]" "$(fact "$O" root readme "d['placeholders'][0]['phrase']")"
check "overview rung is placeholder" "{'heading': 'Overview', 'line': 3, 'placeholder': True}" "$(fact "$O" root readme "d['rungs']['what it launches']")"
check "Setup is installation, not placeholder" "{'heading': 'Setup', 'line': 12, 'placeholder': False}" "$(fact "$O" root readme "d['rungs']['installation']")"
check "FAQ is troubleshooting, placeholder" "{'heading': 'FAQ', 'line': 27, 'placeholder': True}" "$(fact "$O" root readme "d['rungs']['troubleshooting']")"
check "screenshots rung" "{'heading': 'Screenshots', 'line': 8, 'placeholder': False}" "$(fact "$O" root readme "d['rungs']['screenshots']")"
check "environment variables rung" "{'heading': 'Environment variables', 'line': 20, 'placeholder': False}" "$(fact "$O" root readme "d['rungs']['environment variables']")"
check "screenshots (badge excluded)" "[{'line': 9, 'alt': 'Session view', 'target': 'docs/session.png'}]" "$(fact "$O" root readme "d['screenshots']")"
check "env_vars" "17:assignment,20:heading,22:phrase" "$(fact "$O" root readme "','.join('%s:%s' % (e['line'], e['match']) for e in d['env_vars'])")"
check "placeholder file is seeded" "True" "$(yn grep -qxF '[Application Name]' "$SCRIPT_DIR/references/readme-placeholders.txt")"

echo "Test 36: form.json, vnc-stale-debugger (form.yml.erb)"
O="$TMP/vnc"
FJ="$O/root/form.json"
check "form ran" "ran|{'root': 'ran'}" "$(fct "$O" form status)|$(fct "$O" form per_app)"
check "form note names the parser" "$PARSER_NOTE" "$(fct "$O" form note)"
check "file and submit file" "form.yml.erb|submit.yml.erb" "$(j "$FJ" "'%s|%s' % (d['file'], d['submit_file'])")"
check "names (attributes, then form-only)" "version,node_type,num_cores,input_file,bc_num_hours,bc_vnc_resolution" "$(j "$FJ" "','.join(a['name'] for a in d['attributes'])")"
A="[a for a in d['attributes'] if a['name']=="
check "num_cores" "number_field|0|48|None|False|29|True|True" "$(j "$FJ" "'|'.join(str(x[k]) for x in $A'num_cores'] for k in ('widget','min','max','pattern','required','line','defined','in_form'))")"
check "num_cores reaches the scheduler via ppn" "True|[2]|True" "$(j "$FJ" "'|'.join(str(x[k]) for x in $A'num_cores'] for k in ('interpolated_in_submit','submit_lines','reaches_scheduler'))")"
check "node_type referenced twice, reaches the scheduler" "True|[12, 24]|True" "$(j "$FJ" "'|'.join(str(x[k]) for x in $A'node_type'] for k in ('interpolated_in_submit','submit_lines','reaches_scheduler'))")"
check "version not referenced" "False|[]|False" "$(j "$FJ" "'|'.join(str(x[k]) for x in $A'version'] for k in ('interpolated_in_submit','submit_lines','reaches_scheduler'))")"
check "input_file defined, not in form" "text_field|37|True|False" "$(j "$FJ" "'|'.join(str(x[k]) for x in $A'input_file'] for k in ('widget','line','defined','in_form'))")"
check "bc_num_hours in form only" "None|12|False|True" "$(j "$FJ" "'|'.join(str(x[k]) for x in $A'bc_num_hours'] for k in ('widget','line','defined','in_form'))")"

echo "Test 37: form.json, YAML form.yml, unparseable forms, Passenger"
O="$TMP/o37a"
check "broken-app exit 0" 0 "$(run "$FIX/broken-app" "$O")"
check "broken-app form failed_to_run" "failed_to_run|{'root': 'failed_to_run'}" "$(fct "$O" form status)|$(fct "$O" form per_app)"
check "note carries the parse error" "True" "$(fct "$O" form note | grep -qE 'root: form\.yml: .*line 3, column 12' && echo True || echo False)"
check "form.json carries the error, no attributes" "True|[]" "$(j "$O/root/form.json" "'%s|%s' % ('line 3, column 12' in d['error'], d['attributes'])")"
check "readme still ran" "ran" "$(fct "$O" readme status)"
check "good-app hours bounds" "hours|number_field|1|48|3" "$(fact "$TMP/mono" good-app form "'|'.join(str(d['attributes'][0][k]) for k in ('name','widget','min','max','line'))")"
T="$TMP/t37"; mkdir -p "$T"
cat > "$T/form.yml" <<'EOF'
# a comment
cluster: "owens"
form:
  - account
  - env_name
  - hours
attributes:
  account:
    widget: text_field
    pattern: "^[a-z]+$"
    required: true
  env_name:
    widget: text_field
  hours: 4
EOF
cat > "$T/submit.yml.erb" <<'EOF'
---
cluster: "<%= env_name %>"
batch_connect:
  template: "<%= hours %>"
script:
  native: ["-A", "<%= account %>"]
EOF
O="$TMP/o37b"
check "exit 0" 0 "$(run "$T" "$O")"
check "form ran" "ran" "$(fct "$O" form status)"
check "account" "text_field|^[a-z]+\$|True|8|True|[6]|True" "$(fact "$O" root form "'|'.join(str($A'account'][0][k]) for k in ('widget','pattern','required','line','interpolated_in_submit','submit_lines','reaches_scheduler'))")"
check "env_name interpolated outside script" "False|True|[2]|False" "$(fact "$O" root form "'|'.join(str($A'env_name'][0][k]) for k in ('required','interpolated_in_submit','submit_lines','reaches_scheduler'))")"
check "hours (scalar attribute) reaches batch_connect.template" "None|14|True|[4]|True" "$(fact "$O" root form "'|'.join(str($A'hours'][0][k]) for k in ('widget','line','interpolated_in_submit','submit_lines','reaches_scheduler'))")"
T="$TMP/t37c"; mkdir -p "$T"
printf '<%% x = 1 %%>\nattributes:\n  a:\n    widget: {text_field\nform:\n  - a\n' > "$T/form.yml.erb"
O="$TMP/o37c"
check "unparseable form.yml.erb exit 0" 0 "$(run "$T" "$O")"
check "failed_to_run" "failed_to_run" "$(fct "$O" form status)"
check "error names the file and line 4" "True" "$(j "$O/root/form.json" "d['file'] == 'form.yml.erb' and 'line 4' in d['error']")"
check "note names parser and error" "True" "$(fct "$O" form note | grep -qF "$PARSER_NOTE; root: form.yml.erb: " && echo True || echo False)"
O="$TMP/flask"
check "passenger form skipped" "skipped|{'root': 'skipped'}" "$(fct "$O" form status)|$(fct "$O" form per_app)"
check "no form.json" "False" "$(yn test -e "$O/root/form.json")"

echo "Test 38: rerun removes the previous run's per-app dirs"
O="$TMP/o38"
check "monorepo run" 0 "$(run "$FIX/monorepo" "$O")"
check "single-app run into the same out-dir" 0 "$(run "$FIX/containerized-server" "$O")"
check "good-app dir gone" "False" "$(yn test -e "$O/good-app")"
check "root dir present" "True" "$(yn test -e "$O/root/readme.json")"

echo; echo "Done: $pass passed, $fail failed."; [ "$fail" -eq 0 ]
