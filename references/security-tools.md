# Static Analysis Tools

Optional tools that supplement the manual security review.
`references/run-pre-review.sh` runs these before the review and writes their
JSON beside a summary; the review-security skill reads that output and folds
it into the OODT-classified findings. This file is the specification the
script implements; the commands below are the ones it runs. **If none are
installed the review still completes normally** — tool findings supplement,
never replace, the manual analysis.

## Executable form

- **Script:** `references/run-pre-review.sh <target-dir> <out-dir>`, backed by
  `references/pre-review.py`.
- **Output files:** `<out-dir>/summary.json` (one record per check, in order
  syntax, shellcheck, semgrep, bandit, trivy, catalog); `<out-dir>/syntax.json`;
  `<out-dir>/shellcheck.json`, `semgrep.json`, `bandit.json`, `trivy.json` (the
  tool's own JSON, present only when that tool ran).
- **Candidate sites:** `<out-dir>/<app_id>/security.json`, the sites the
  security skill must answer (see "Candidate enumeration" below). `app_id`
  here is the same `app_id` `apps.json` gives the app and a finding record
  uses ("root" for a single-app repo, the normalised subpath for a monorepo
  app); the per-app fact directory is `<out-dir>/<app_id>/`.
- **Finding counts:** each record carries `finding_count` (null when the
  tool did not run) and `top_codes` (up to five most frequent codes); the
  skill's Result column is rendered from these, never recounted.
- **Syntax check:** `bash -n` with the first `bash` on PATH; the `syntax`
  record's `version` names it. With an older bash (macOS `/bin/bash` is 3.2)
  a pass stands; a failure's `stderr` starts `bash <ver> rejected this file
  (may be valid on bash >= 4): ` and the note says failures may be false.
- **Tool table:** `<out-dir>/tool-table.md` is the Check tiers line and the
  Tool / Status / Result table, rendered from `summary.json`. The security
  skill pastes it verbatim.
- **Status vocabulary:** each check's `status` is `ran`, `not_installed`,
  `failed_to_run`, or `skipped`. The skill renders these as `Run`,
  `Not run (not installed)`, `Not run (failed)`, and `Not run (<note>)`.
- **CI:** the workflow installs shellcheck, bandit, and a pinned semgrep.
  trivy is local-only until CI installs it from a pinned source (see the
  planning discussion); in CI its row is `not_installed`.
- **Scanner configuration in the target:** shellcheck runs with `--norc` and
  trivy with an empty config and ignore file written to the out-dir, so a
  target's `.shellcheckrc`, `trivy.yaml`, or `.trivyignore` cannot silence
  findings (or, for `trivy.yaml`, redirect output). semgrep and bandit have
  no such switch; when the target ships `.semgrepignore` or `.bandit`, the
  summary note says it may suppress findings.
- Adding a tool means adding it to both this table and `pre-review.py` — the
  script is the executable form of this spec, not an independent
  implementation.

## Tool Lookup Table

### shellcheck — Shell script linter

| Field | Value |
|-------|-------|
| **Covers** | `.sh`, `.bash`, `.sh.erb` (after ERB stripping) |
| **Detect** | `command -v shellcheck` |
| **Install** | `brew install shellcheck` (macOS) / `apt install shellcheck` (Debian/Ubuntu) / `dnf install ShellCheck` (Fedora/RHEL) / `pacman -S shellcheck` (Arch) |
| **Project** | https://www.shellcheck.net |
| **OODT mapping** | OODT-01 (injection via unquoted variables), OODT-08 (insecure defaults) |

**Run:**

```bash
shellcheck --norc -f json -S info <file.sh>
```

`-S info` keeps SC2086 (unquoted variable), which shellcheck rates at info
level and `-S warning` would drop. `--norc` ignores any `.shellcheckrc` in
the target or the reviewer's home directory.

**ERB preprocessing:** shellcheck cannot parse ERB tags. For `.sh.erb` files,
strip ERB before scanning. The strip must be **multi-line aware** — a
line-oriented `sed` substitution cannot match `<% ... %>` blocks that span
multiple lines, causing shellcheck to see leftover Ruby as shell, invent
parse errors, and (worse) stop analysing the file at the first error, hiding
real findings below it.

```bash
TMPFILE=$(mktemp "${TMPDIR:-/tmp}/sc-XXXXXX.sh")

python3 - "$TARGET" "$TMPFILE" <<'PY'
import re, sys
src, dst = sys.argv[1], sys.argv[2]
text = open(src).read()

def keep_newlines(match, filler=''):
    """Replace tag with filler + same number of newlines to preserve line numbers."""
    return filler + '\n' * match.group(0).count('\n')

text = re.sub(r'<%#.*?%>', lambda m: keep_newlines(m), text, flags=re.S)
text = re.sub(r'<%=.*?%>', lambda m: keep_newlines(m, 'ERBVALUE'), text, flags=re.S)
text = re.sub(r'<%.*?%>',  lambda m: keep_newlines(m), text, flags=re.S)
open(dst, 'w').write(text)
PY

shellcheck --norc -f json -S info "$TMPFILE"
rm "$TMPFILE"
```

Substitution order matters: comments first (so `%>` inside a comment doesn't
terminate something else), then `<%= %>` → `ERBVALUE` (so assignments like
`TIMEOUT=<%= x %>` stay valid), then bare `<% %>` → empty. Newline
preservation keeps `file:line` evidence citable against the original `.erb`.

Linting OOD's job-script files one at a time leaves artefacts that are not
defects: SC2154 for a variable the sibling `before.sh` sets or OOD's
contract provides (`$host`, `$port`, `$password`), SC2148 on a file OOD
sources rather than executes, and SC1090/SC1091 for a `source` shellcheck
was not given. pre-review.py marks them `artifact: true` (see "Tool finding codes: rule
and tag" below). A quick
`bash -n "$TMPFILE"` before running shellcheck is a useful sanity check on
the strip itself.

**Key finding codes:**
- SC2086: unquoted variable (injection risk in scripts that handle form values)
- SC2091: unquoted command substitution
- SC2046: unquoted `$(...)` — word splitting
- SC2006: use `$(...)` instead of legacy backticks

---

### bandit — Python security linter

| Field | Value |
|-------|-------|
| **Covers** | `.py` |
| **Detect** | `command -v bandit` |
| **Install** | `pip install bandit` (all platforms) |
| **Project** | https://bandit.readthedocs.io |
| **OODT mapping** | OODT-01 (subprocess/eval/exec), OODT-02 (hardcoded passwords), OODT-05 (binding to 0.0.0.0, a finding only for a service with no authentication), OODT-08 (insecure config) |

**Run:**

```bash
bandit -r <directory> -f json
```

No severity filter (`-ll`): the reviewer rates severity under the rubric, so
bandit reports everything and low-severity results are weighed, not hidden.

**Key test IDs:**
- B102: `exec()` used
- B103: `set_bad_file_permissions` (chmod)
- B104: binding to `0.0.0.0` (OOD's node proxy needs a non-loopback bind;
  a finding only when the service has no authentication)
- B108: hardcoded `/tmp` path
- B602: `subprocess` with `shell=True`
- B605: `os.system()` call
- B608: SQL injection (string formatting in queries)

---

### semgrep — Multi-language structural pattern matching

| Field | Value |
|-------|-------|
| **Covers** | Python, Ruby, JavaScript, Shell, YAML, and many more |
| **Detect** | `command -v semgrep` |
| **Install** | `pip install semgrep` (all platforms) / `brew install semgrep` (macOS) |
| **Project** | https://semgrep.dev |
| **OODT mapping** | All OODT categories depending on ruleset |

**Run:**

```bash
semgrep --config=p/security-audit --config=p/secrets --metrics=off --exclude vendor --exclude node_modules --json <directory>
```

Do **not** use `--config auto` — it requires metrics to be enabled and fails
with an opaque error when they are off (the default in many environments and
the expected posture when scanning someone else's code). Use explicit rulesets
instead.

For Ruby-heavy apps, add `--config=p/ruby`. Semgrep supports custom rules, so
Appverse-specific patterns (e.g., form values reaching shell interpolation in
ERB) could be encoded as rules in the future.

---

### npm audit — Node.js dependency vulnerability scan

| Field | Value |
|-------|-------|
| **Covers** | Node.js apps with `package.json` + `package-lock.json` |
| **Detect** | `command -v npm` (plus `package.json` must exist in target) |
| **Install** | Comes with Node.js — https://nodejs.org |
| **Project** | https://docs.npmjs.com/cli/commands/npm-audit |
| **OODT mapping** | OODT-08 (supply chain / known CVEs in dependencies) |

**Run:**

```bash
cd <app-directory> && npm audit --json 2>/dev/null
```

Only applicable when a `package.json` is present. If `package-lock.json` is
missing, run `npm install --package-lock-only` first (does not install
dependencies, just generates the lock file).

Not run by run-pre-review.sh; manual only.

---

### trivy — Comprehensive vulnerability scanner

| Field | Value |
|-------|-------|
| **Covers** | Dependency manifests (requirements.txt, Gemfile.lock, package-lock.json), container definitions, IaC configs |
| **Detect** | `command -v trivy` |
| **Install** | `brew install trivy` (macOS) / `apt install trivy` after adding the [Aqua repo](https://aquasecurity.github.io/trivy/latest/getting-started/installation/) (Debian/Ubuntu) / see https://aquasecurity.github.io/trivy for other platforms |
| **Project** | https://aquasecurity.github.io/trivy |
| **OODT mapping** | OODT-06 (container security), OODT-08 (supply chain / known CVEs) |

**Run:**

```bash
trivy fs --format json --scanners vuln,misconfig,secret --skip-dirs vendor --skip-dirs node_modules <directory>
```

The `--skip-dirs` flags exclude vendored dependencies — without them, trivy
reports CVEs in third-party code that is not the reviewed app's dependency
tree, burying real findings in noise. Useful for Passenger apps with dependency
manifests and for apps that include container definitions (Singularity `.def`
files, Dockerfiles).

---

### rubocop — Ruby / ERB linter (security cops)

| Field | Value |
|-------|-------|
| **Covers** | `.rb`, `.erb` |
| **Detect** | `command -v rubocop` |
| **Install** | `gem install rubocop` (all platforms with Ruby) |
| **Project** | https://rubocop.org |
| **OODT mapping** | OODT-01 (eval/exec), OODT-08 (insecure defaults) |

**Run:**

```bash
rubocop --only Security -f json <directory>
```

Lower priority for Appverse — most OOD ERB files are config templates rather than
full Ruby apps, so rubocop findings tend to be noisy. Useful when the app includes
substantial Ruby code (e.g., custom initializers or Ruby-based Passenger apps).

Not run by run-pre-review.sh; manual only.

## What the script runs per file type

`pre-review.py` picks tools by file type; a tool with no applicable files is
`skipped`.

| Files in the target | Tool |
|-------------|---------------|
| `*.sh`, `*.bash`, `*.sh.erb` | shellcheck (and the `bash -n` syntax check) |
| `*.py` | bandit |
| `package.json`, `requirements.txt`, `Gemfile.lock`, `Dockerfile`, `*.def` | trivy |
| any file | semgrep |

## Candidate enumeration

`pre-review.py` also writes `<out-dir>/<app_id>/security.json`: every site in
the app's security scope that a rubric pattern names. Each candidate is a row
the security skill must answer (FAIL, WARN, or a PASS that cites it and says
why it is acceptable); a candidate is not a finding. The file starts with
`counts` (one entry per kind, zeros included), then `scope`, `files`,
`attributes`, `candidates`, and `skipped_files`. The `security` record in
`summary.json["facts"]` is `ran` per app with the non-zero counts in its note.

**Scope.** Batch Connect: `submit.yml(.erb)`, `form.yml(.erb)`,
`connection.yml(.erb)`, everything under `template/`, and container
definitions (`Dockerfile*`, `Containerfile*`, `*.def`) anywhere in the app.
Passenger, companion, widget and unknown apps: every file in the app except
`vendor/`, `node_modules/`, `.git/`, docs (`*.md`, `*.txt`, `*.rst`), licences,
changelogs, images, fonts, lock files and test code (`test/`, `tests/`, `spec/`,
`*_test.rb`, `test_*.py`, `*_spec.rb`, `*.test.js`). Every app adds the root
`appverse.yml` `shared_paths`. Files are read under the shell-file rule; a
refused or (outside `template/`) binary file is listed in `skipped_files`.

**Candidate fields.** `kind`, `check` (the manifest check id), `rule`,
`tag` (the mechanism tag from finding-codes.md that fits the match, or null),
`file` (repo-relative, with the monorepo app path), `line`, `text` (the
trimmed source line, at most 200 characters), `note` (what matched).
`interpolation` adds `attributes`, `guarded`, `presence_checked` and `quoted`. Comment lines
(`#`, `//`, `<!--`, and `<%# %>` tags) are never candidates, and a trailing
comment is ignored. A command word counts only in command position: at the
start of a line, after `;`, `&`, `|`, `(`, `{`, a backtick, `$(`, or a keyword
(`then`, `do`, `sudo`, `exec`, `RUN`, ...). In Python, Ruby or JavaScript it
counts at the start of a string (`["curl", url]`, `"curl ..."`).

| Kind | Matches | Check | Rule | Tag |
|---|---|---|---|---|
| `interpolation` | Every line in `submit.yml.erb` or a `template/**/*.erb` file with a `<%= %>` tag that carries a form attribute: the bare name, `context.<name>` or `@<name>`, or a variable or block parameter (`x.split.each do \|opt\|`) assigned from one. `guarded`: the value is sanitised or validated in every such tag: each output reference ends in `.to_i`, `.to_f` or `.shellescape`, or sits in `Shellwords.escape()`, `Integer()` or `Float()`, or an enclosing ERB condition on the attribute validates it (`=~`, `match`, `include?`, `in?`). A presence test is not a guard. `presence_checked`: every such tag has its own presence test (`if`, `unless`, ternary, `\|\|`, `.presence`, `.blank?`, `.present?`, `.empty?`, `.nil?`, `fetch`) or sits under an ERB condition that references the attribute. `quoted`: every such tag is inside quotes on its line (lexical). The note names the widget, the carrying variable, the YAML key in `submit.yml.erb`, the sanitiser, and `quoted (YAML)`, `quoted (shell)` or `unquoted`; shell double quotes add `still expands $(...)`, since they do not stop command substitution | `sec-interpolation` | OODT-01 | `unsanitized-user-input` |
| `unquoted_expansion` | `$VAR` or `${VAR}` outside quotes in a template shell file, where `VAR` is assigned from a `<%= %>` tag carrying a form attribute (or from such a variable). Plain `X=$VAR` assignments and `[[ ]]` tests are skipped | `sec-interpolation` | OODT-01 | `unquoted-variable` |
| `eval_exec` | Shell `eval`; `exec`, `source` or `.` of a variable; `sh -c` with a variable; a pipe into a shell (`\| bash`, `base64 -d \| sh`); `source <(curl ...)`; `eval(` / `exec(` / `new Function(`; `os.system` / `os.popen`; a `subprocess` call with `shell=True` (anchored at the call, note gives the `shell=True` line); `child_process.exec`; a Ruby `system` / `Open3` / `IO.popen` string, a backtick command or `%x(...)` with `#{}` | `sec-eval-exec` | OODT-01 | `eval-exec`; `curl-pipe-exec` for a download piped into a shell; `command-injection` for shell-string execution |
| `network_call` | `curl`, `wget`, `ssh`, `scp`, `sftp`, `nc`, `ncat`, `netcat`, `socat`, `telnet` in command position; HTTP and socket clients (`requests.*`, `urlopen`, `Net::HTTP`, `open-uri`, `TCPSocket`, `fetch("https://...")`, `axios`); a URL. URLs are skipped for local hosts (`localhost`, `127.*`, `unix:`, a variable, `#{}` or ERB host), example and schema hosts, DTD/XSD links, `href` links, `echo` / `printf` / `help:` / `label:` / `description:` lines, form and manifest files, and dependency manifests (`Gemfile`, `package.json`, `pyproject.toml`, ...) | `sec-network-call` | OODT-04 | `unexpected-network-call` |
| `file_write_outside_job` | A shell redirect, or a `cp` / `mv` / `install` / `ln` / `rsync` destination or `tee` argument, that is `$HOME`, `~`, or an absolute path (except `/dev/` and `/proc/self/`); `crontab` or `systemctl --user enable\|start` in command position; elsewhere, a `crontab` command string, or a write (`open(..., "w")`, `.write`, `File.write`, `FileUtils`, `shutil.copy`, `writeFile`, `>>`) on a line naming `.ssh/`, `authorized_keys`, a shell init file, `/etc/cron`, `.config/systemd/user` or `.config/autostart` | `sec-file-write-outside-job` | OODT-07 | `ssh-key-write` (`.ssh/`, `authorized_keys`), `cron-install` (crontab, `/etc/cron`, `systemd/user`), `dotfile-write` (a dotfile or dot-directory); `write-outside-job` for any other target (`/tmp`, `/usr/local`, `$HOME/<not a dotfile>`) |
| `permission_change` | `chmod`, `chown`, `chgrp`, `umask`, `setfacl` in command position; `os.chmod` / `os.chown` / `os.umask`, `File.chmod`, `FileUtils.chmod`, `fs.chmod`. The note states the mode (`chmod 700`, `umask 077`) and `world-writable` or `not world-writable`: world-writable when the last octal digit sets other-write, for `o+w` / `a+w` / `+w`, or for a `umask` that leaves other-write | `sec-permissive-mode` | OODT-03 | `permissive-file-mode` |
| `credential_string` | A literal of four or more characters (no spaces, not a path, URL, variable or ERB tag) assigned (`=`, `:`, `=>`) to a name containing password, passphrase, pass, secret, token, api key, access key, private key or credential; an unquoted value of eight or more characters needs a letter and a digit. Names ending `_dir`, `_path`, `_file`, `_url`, `_name`, `_env`, `_field`, `_label`, `_id` and similar are skipped. Also `--password=<literal>`-style flags, `-----BEGIN ... PRIVATE KEY`, and AWS / GitHub / Slack token shapes | `sec-credential-string` | OODT-02 | `hardcoded-credential` |
| `config_flag` | `0.0.0.0`, `[::]`, `::` as a host or a `listen(` / `bind(` argument, `INADDR_ANY` (OODT-05 `bind-all-interfaces`, a fact to judge: the finding is a service reachable without authentication, not the bind, which OOD's node proxy needs); `Access-Control-Allow-Origin: *`, `allow_origin='*'`, `origins="*"`, `CORS(app)`, `cors()` (OODT-05 `cors-wildcard`); `--no-auth`, `--auth none`, an empty `--...token=` / `--...password=` or `.token = ''` (OODT-05 `disabled-auth`); `disable_check_xsrf=True`, `WTF_CSRF_ENABLED = False`, `@csrf_exempt`, `skip_before_action :verify_authenticity_token` (OODT-05 `disabled-xsrf`); `--disable-ssl`, `--no-check-certificate`, `--insecure`, `curl -k`, `verify=False`, `rejectUnauthorized: false` (OODT-08 `disabled-ssl`); `set -x`, `bash -x` (the note says trace output goes to the job's own output.log, world-readable only if the job directory is), `app.run(debug=True)`, `DEBUG = True` (OODT-08 `debug-tracing-enabled`); `disable_host_check`, `allow_remote_access=True`, `ALLOWED_HOSTS = ['*']` (OODT-08 `dns-rebinding-relaxed`); `PIP_INDEX_URL=`, `--index-url`, `--trusted-host` (OODT-08 `supply-chain-untrusted-index`) | `sec-config-flag` | per match, as listed | per match, as listed |
| `binary_in_template` | A file under `template/` with a NUL byte in its first 8 KB, at line 1, `text` "binary file (N bytes)". An image or font by its magic bytes (PNG, JPEG, GIF, ICO, WOFF/WOFF2, TTF/OTF) is not a candidate and is listed in `skipped_files`; SVG is text and is scanned | `sec-binary-in-template` | OODT-04 | `binary-in-template` |
| `tool_finding` | Every shellcheck, semgrep or bandit finding at a file in the app's security scope (see "What the script runs per file type" above), one candidate per (tool, code, file): shellcheck `file`, `line`, `code` (rendered `SC%d`), `level`, `message`; semgrep `results[].path`, `start.line`, `check_id`, `extra.severity`, `extra.message`; bandit `results[].filename`, `line_number`, `test_id`, `issue_severity`, `issue_text`. Excluded: shellcheck `style` level, semgrep `INFO` severity (bandit has no floor — every severity is a candidate). A candidate's `lines` lists every line that tool raised that code at in that file (instead of a single `line`); `rule` and `tag` are null on the candidate itself — a FAIL/WARN record uses the rule and tag "Tool finding codes: rule and tag" gives the code; `artifact` is true when every finding in the candidate is an artefact of linting OOD's job-script files (that table's Artefact column) | `sec-tool-finding` | null | null |

One candidate is written per (file, line, kind, tag), so a line can carry
several kinds (`curl "$u" | bash` is an `eval_exec` and a `network_call`).
Candidates are ordered by file, line, then kind in the table's order;
`tool_finding` candidates are appended after the pattern-matched ones, one
group per (tool, code, file).

**tool_finding ceiling.** The ceiling counts the app's (tool, code, file)
candidates, artefacts included, after the severity floor and before any
collapsing. When there are more than 15, all of them collapse, never some,
to one per (tool, code) across every file: `lines` then holds `file:line`
strings (instead of bare line numbers within a single `file`, which is
`null` on a collapsed candidate), a collapsed candidate is an artefact only
when every finding in it is, and `security.json`'s
`counts.tool_finding_collapsed` is `true`. Separately, a candidate's `lines`
keeps at most its first 20 entries, with `lines_total` giving the full
count when it was cut. This keeps a noisy tree from
producing hundreds of near-duplicate rows; the security skill says once in
the report when the ceiling applied.

**trivy is excluded.** trivy's findings (dependency CVEs, container
misconfigurations, secrets by pattern) are not anchored to a single line the
way the other tools' are, so they are never `tool_finding` candidates. trivy
stays visible only in `tool-table.md`'s Tool / Status / Result row; a trivy
finding worth recording is an additional observation, not a candidate row.

### Tool finding codes: rule and tag

A `tool_finding` row that records a FAIL or WARN uses the rule and tag this
table gives its code. Tags are finding-codes.md vocabulary tags, or
`other:<slug>` where no vocabulary tag fits. A code not listed here takes
the rule its defect belongs to and a vocabulary tag of that rule, or
`other:<slug>`. A security code records under an OODT rule; a hygiene code
records under the QUA-xx (or STR-xx) rule this table names, and its row
stays in the Security tables with that rule in its Rule cell, never moved
to Code Quality. The "Artefact" column says when a code is an artefact of
linting OOD's job-script files (a `.sh.erb` file, or `template/before.sh*`,
`template/script.sh*`, `template/after.sh*`) one at a time: pre-review.py
marks such a candidate `artifact: true`, and the security skill answers
those together in one PASS row.

| Code | What it flags | Rule | Tag | Artefact |
|---|---|---|---|---|
| SC2086 | Unquoted variable expansion (word splitting, globbing) | OODT-01 | `unquoted-variable` | no |
| SC2164 | `cd` without `\|\| exit`, so a failed `cd` runs the rest in the wrong directory | QUA-03 | `no-error-check` | no |
| SC2155 | `local`/`export` and assignment in one statement, masking the command's exit status | QUA-03 | `no-error-check` | no |
| SC2054 | Comma inside an array element (often Apptainer `--bind a,b` syntax, which is correct) | QUA-06 | `other:array-element-comma` | no |
| SC2140 | Word of the form `"A"B"C"` (mixed quoting) | QUA-06 | `other:mixed-quoting` | no |
| SC2034 | Variable assigned but never used | QUA-04 | `other:unused-variable` | no |
| SC2329 | Function never invoked (a `trap` handler is invoked: PASS) | QUA-04 | `other:uninvoked-function` | no |
| SC2154 | Variable referenced but not assigned | STR-04 | `undefined-variable:{var_name}` | in a job-script file, when a sibling `template/before.sh*` assigns it or it is an OOD contract name (`port`, `host`, `display`, `password`, `app_port`, `csrftoken`) |
| SC2148 | No shebang | QUA-06 | `other:missing-shebang` | in a job-script file |
| SC1090 | `source` of a non-constant path shellcheck cannot follow | QUA-06 | `other:unfollowed-source` | in a job-script file |
| SC1091 | `source` of a file shellcheck was not given | QUA-06 | `other:unfollowed-source` | in a job-script file |
| B602 | `subprocess` call with `shell=True` | OODT-01 | `command-injection` | no |
| B104 | Binding to all interfaces (`0.0.0.0`); a finding only when the service has no authentication, else PASS | OODT-05 | `bind-all-interfaces` | no |
| B110 | `try`/`except`/`pass` swallowing every error | QUA-03 | `no-error-check` | no |

## Interpreting tool output

Tool findings arrive with tool-native severity (shellcheck levels, bandit
confidence/severity, semgrep severity, CVE CVSS scores). **Do not pass these
through as-is.** Map each finding to the OODT taxonomy using the OODT mapping
column above, then rate severity (High / Medium / Low) using the rubric's blast
radius criteria — the same way manual findings are rated. Tool severity scores are
useful context but OODT classification is what goes in the report.

Expect false positives, especially:
- shellcheck on OOD job-script files (the artefact codes in the table
  above: SC2154, SC2148, SC1090, SC1091)
- rubocop on ERB templates (incomplete Ruby parsing)
- semgrep on small codebases (broad patterns, narrow context)
- trivy/npm audit on vendored dependencies (use `--skip-dirs` / `--exclude`)

When a tool finding duplicates a manually identified finding, merge them — cite
the tool as corroborating evidence rather than listing it twice.
