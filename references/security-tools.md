# Static Analysis Tools

Optional tools that supplement the manual security review. The review-security
skill probes for these, runs whichever are installed, and folds their output into
the OODT-classified findings. **If none are installed the review still completes
normally** — tool findings supplement, never replace, the manual analysis.

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
shellcheck -f json -S warning <file.sh>
```

**ERB preprocessing:** shellcheck cannot parse ERB tags. For `.sh.erb` files,
strip ERB before scanning:

```bash
TMPFILE=$(mktemp "${TMPDIR:-/tmp}/sc-XXXXXX.sh")
sed 's/<%[^%]*%>/SHELLCHECK_PLACEHOLDER/g' "$TARGET" > "$TMPFILE"
shellcheck -f json -S warning "$TMPFILE"
rm "$TMPFILE"
```

Note in output that ERB substitutions were replaced with placeholders — some
shellcheck findings may be false positives due to the substitution. Review each
finding against the original file.

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
| **OODT mapping** | OODT-01 (subprocess/eval/exec), OODT-02 (hardcoded passwords), OODT-05 (binding to 0.0.0.0), OODT-08 (insecure config) |

**Run:**

```bash
bandit -r <directory> -f json -ll
```

`-ll` limits output to medium severity and above. Drop it for a comprehensive
scan.

**Key test IDs:**
- B102: `exec()` used
- B103: `set_bad_file_permissions` (chmod)
- B104: binding to `0.0.0.0`
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
semgrep scan --config auto --json <directory>
```

`--config auto` uses the curated community rulesets. For a faster focused scan:

```bash
semgrep scan --config "p/security-audit" --json <directory>
```

Semgrep is the most versatile tool in this list — it supports custom rules, so
AppVerse-specific patterns (e.g., form values reaching shell interpolation in ERB)
could be encoded as rules in the future.

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
trivy fs --format json --scanners vuln,misconfig <directory>
```

Useful for Passenger apps with dependency manifests and for apps that include
container definitions (Singularity `.def` files, Dockerfiles).

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

Lower priority for AppVerse — most OOD ERB files are config templates rather than
full Ruby apps, so rubocop findings tend to be noisy. Useful when the app includes
substantial Ruby code (e.g., custom initializers or Ruby-based Passenger apps).

## Detecting relevant tools for an app

Match file types found in the in-scope files to tools:

| File pattern | Tools to probe |
|-------------|---------------|
| `*.sh`, `*.bash`, `*.sh.erb` | shellcheck |
| `*.py` | bandit, semgrep |
| `*.rb`, `*.erb` | rubocop, semgrep |
| `package.json` | npm audit, trivy |
| `requirements.txt`, `Gemfile.lock` | trivy |
| `*.def`, `Dockerfile` | trivy |
| Any of the above | semgrep (universal) |

## Interpreting tool output

Tool findings arrive with tool-native severity (shellcheck levels, bandit
confidence/severity, semgrep severity, CVE CVSS scores). **Do not pass these
through as-is.** Map each finding to the OODT taxonomy using the OODT mapping
column above, then rate severity (High / Medium / Low) using the rubric's blast
radius criteria — the same way manual findings are rated. Tool severity scores are
useful context but OODT classification is what goes in the report.

Expect false positives, especially:
- shellcheck on ERB-stripped scripts (placeholder variables trigger warnings)
- rubocop on ERB templates (incomplete Ruby parsing)
- semgrep with auto rules on small codebases (broad patterns, narrow context)

When a tool finding duplicates a manually identified finding, merge them — cite
the tool as corroborating evidence rather than listing it twice.
