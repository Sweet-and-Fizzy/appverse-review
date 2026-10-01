# Appverse Review: tillicum-llama-chat

**Repository:** https://github.com/UWrc/tillicum-llama-chat  **Mode:** reviewer  **Date:** 2026-09-30
**Reviewed commit:** `f7c8d35004b824812d7c552c6dc17d9b7fd98653` (2026-09-09)  **Repo shape:** inferred single app
**Reviewed with:** appverse-review @ 0.8.0 (`e8ee094`, https://github.com/Sweet-and-Fizzy/appverse-review) · **Model:** claude-sonnet-4-6 · **Rubric:** https://openondemand.connectci.org/appverse-review-rubric

> _Disclaimer: This is an automated review with human curation. It is provided without warranty of any kind and does not certify the app as secure or fit for any purpose. A listing is not an endorsement._

## Repo-level gate criteria

| Rule | Result | Evidence |
|---|---|---|
| — | PASS | Repository public and accessible (clone succeeded) |
| STR-01 | FAIL | README.md — present and substantive (184 content lines, 11,971 characters, no placeholder text) |
| STR-01 | FAIL | LICENSE — no LICENSE file found in the repository root |
| — | PASS | Repo not archived (`archived: false`) |

## Upkeep

| Signal | Value | Assessment |
|---|---|---|
| Last commit | 2026-09-09 (21 days before review) | Active |
| Releases | None | No tagged releases |
| Issues responsiveness | 0 open issues | Not assessed (no open issues) |
| Contributors | 2 (npho: 12 commits, jfrulla: 1 commit) | Multiple contributors |
| CHANGELOG | Not present | Missing |
| CI | Not present (no `.github/` directory) | Missing |

| Dimension | Level | Evidence |
|---|---|---|
| Upkeep (repo-level) | Medium | Active within 12 months; only 1 good-practice signal (multiple contributors) — needs 2+ for Low |

## App: Llama.cpp WebUI (.)

### Signals

| Dimension | Level | Evidence |
|---|---|---|
| Portability | Medium | Site-specific cluster, container, and model paths in `form.yml`; one hardcoded path in `template/script.sh.erb` |
| Documentation | High | README rated Minimal — what it launches, prerequisites, and installation present; configuration section absent |

### Structure

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| STR-02 | `check: str-02-metadata` | PASS | info | Required inferred-repo metadata present: `name`, `category`, `role`, `description` | manifest.yml:1 |
| STR-03 | `check: str-03-yaml-valid` | PASS | info | `manifest.yml` and `form.yml` parse as valid YAML | manifest.yml:1 |
| STR-06 | `check: str-06-syntax` | PASS | info | Template scripts syntactically correct: 3 files pass (1 plain, 2 ERB-stripped), 0 fail, 0 not checked | template/after.sh; template/before.sh.erb; template/script.sh.erb |
| STR-07 | `check: str-07-layout` | PASS | info | Standard Batch Connect layout: `form.yml`, `submit.yml.erb`, and `template/` present | form.yml; submit.yml.erb; template |
| STR-04 | `check: str-04-references` | PASS | info | No broken references; `auto_accounts` is an OOD built-in, not an undefined attribute | submit.yml.erb:4 |

### Security

Findings are classified under OODT (Open OnDemand App Threats); codes are defined in the rubric's Security section at https://openondemand.connectci.org/appverse-review-rubric#security.

**Check tiers:** Tiers 1–2

Tier 3 not checked — no isolated execution environment.

| Tool | Status | Result |
|---|---|---|
| shellcheck | Run (ERB-stripped) | 22 findings (SC2054, SC2317, SC2148, SC2154, SC2086), 4 of them linted in isolation from the job-script family |
| semgrep | Run | 0 findings |
| bandit | Run | 3 findings (B110, B104) |
| trivy | Not run (no applicable files) | — |

#### Findings

| Rule | Check | Result | Severity | Tag | Summary | Evidence |
|---|---|---|---|---|---|---|
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `auto_accounts` (OOD built-in) and `auto_qos` (OOD-managed, fixed value `normal`) reach the scheduler but are not user-editable; `gpu_partition` used in guarded ternaries (lines 9–10) and as a select value (line 11); `bc_num_hours` sanitized by `.to_f` | submit.yml.erb:4,5,9,10,11,12 |
| OODT-01 | `check: sec-interpolation` | WARN | low | unintentional | `extra_slurm_args` (text\_field) is split on whitespace and each token quoted into Slurm `native:` args; user-controlled Slurm options intended by design but unguarded by pattern — arbitrary Slurm flags accepted | submit.yml.erb:18 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `sif_path` (hidden admin-controlled field) and `model_path` (select widget, fixed options) rendered into shell; both double-quoted and admin-constrained | template/before.sh.erb:23,31 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `sif_path` (admin hidden field) and `model_path` (select) double-quoted in shell; `temperature` (number\_field, min 0–max 1, checked via `enable_advanced_args` ternary); `api_key` base64-encoded via `Base64.strict_encode64(...to_s)` before shell assignment; `storage_yolo`, `storage_home_mount`, and writable flags are check\_boxes (values 0 or 1); mount source/dest text\_fields go into apptainer bind mounts for the user's own files — self-contained OODT-03 scope | template/script.sh.erb:21,23,25,29,32,33,34,35,36,37,38,39,40,41,42 |
| OODT-01 | `check: sec-interpolation` | WARN | low | unintentional | `extra_llama_args` (text\_field) reaches `llama-server` command-line args after `read -r -a` word-split; gated by `enable_advanced_args` but no pattern constraint — arbitrary server flags accepted | template/script.sh.erb:31 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `API_KEY_B64` unquoted in `printf '%s' "$API_KEY_B64"` — contains only base64 characters (A–Z, a–z, 0–9, +/=), no injection risk; `$MODEL_PATH` used inside `$(dirname "...")` (select-constrained); `$API_KEY` used only for character-count display | template/script.sh.erb:30,115,122,157 |
| OODT-04 | `check: sec-network-call` | PASS | info | — | `socket.socket(AF_INET, SOCK_STREAM)` is a loopback port-readiness check for the proxy, not a data-exfiltration call | template/after.sh:15 |
| OODT-04 | `check: sec-network-call` | PASS | info | — | `import http.client` and all `HTTPConnection`/`HTTPException` uses are the expected forward-proxy implementation; `XMLHttpRequest` strings at lines 94–95 are JavaScript source code injected into HTML pages — not actual network calls from the proxy process | template/proxy.py:44,94,95,345,355 |
| OODT-05 | `check: sec-config-flag` | WARN | medium | unintentional | Proxy binds to `0.0.0.0` so OOD's node-routing layer can reach it; `llama-server` itself binds to `127.0.0.1` (safe). Without an `api_key`, co-located users on the shared compute node can reach the proxy and make unauthenticated inference calls. A CSRF token is set by `view.html.erb` with `SameSite=Strict` but the proxy does not enforce it on incoming requests. | template/proxy.py:52 |
| OODT-01 | `check: sec-tool-finding` | PASS | info | — | SC2148 (no shebang — `template/after.sh:1`, `template/before.sh.erb:1`) and SC2154 (`port` referenced but not assigned — `template/after.sh:4`, `template/script.sh.erb:152`) are artefacts of linting OOD job-script files one at a time: the shebang is absent by OOD convention and `$port` is set by OOD's `find_port` contract | template/after.sh:1,4; template/before.sh.erb:1; template/script.sh.erb:152 |
| OODT-01 | `check: sec-tool-finding` | WARN | low | unintentional | SC2086: `${SCRIPT_PID}` unquoted in `pkill -P` — word splitting unlikely (PID is numeric) but shellcheck correctly flags it | template/after.sh:35 |
| OODT-05 | `check: sec-tool-finding` | WARN | medium | unintentional | B104: binding to all interfaces — corroborates the `sec-config-flag` row above; same OODT-05 `bind-all-interfaces` finding at `proxy.py:52` | template/proxy.py:52 |
| QUA-03 | `check: sec-tool-finding` | WARN | low | unintentional | B110: `try`/`except`/`pass` at lines 352 and 365 swallows connection-cleanup errors silently | template/proxy.py:352,365 |
| QUA-06 | `check: sec-tool-finding` | PASS | info | — | SC2054 (comma inside array element) at lines 112, 115, 117, 122, 124, 128, 136, 138 — commas are correct `apptainer --mount type=bind,...` syntax; false positive for this mount form | template/script.sh.erb:112,115,117,122,124,128,136,138 |
| QUA-06 | `check: sec-tool-finding` | WARN | low | unintentional | SC2140: `"A"B"C"` mixed-quoting in the `apptainer --mount` spec at line 128 (`src="/gpfs/home/$USER",dst="/home/$USER"`) — bash string-concatenation produces the correct value but the pattern is unusual and may confuse readers or editors | template/script.sh.erb:128 |
| QUA-04 | `check: sec-tool-finding` | PASS | info | — | SC2317 (unreachable commands at lines 208–215) — these are the body of `on_term()`, which is reachable via `trap on_term TERM` at line 217; shellcheck cannot see the trap invocation | template/script.sh.erb:208,209,211,213,214,215 |

#### Additional observations (review)

No findings.

**Capability profile (Batch Connect):**

| Capability | Present | Assessment |
|---|---|---|
| Apptainer container launch with GPU pass-through (`--nv`) | Yes | Expected for GGUF inference |
| Loopback-only inference service (`llama-server` on `127.0.0.1`) | Yes | Safe — reachable only from same host |
| Python reverse proxy on `0.0.0.0` (all interfaces) | Yes | Required for OOD routing; co-user exposure without API key (see OODT-05 above) |
| User-configurable bind mounts into container | Yes | By design (YOLO/selective-mount security model documented in form) |
| User-configurable extra llama-server args | Yes | By design (advanced options, gated by checkbox) |
| User-configurable extra Slurm native args | Yes | By design (advanced options, gated by checkbox) |
| Outbound network from template scripts | No | `--offline` flag noted in comments; no curl/wget in scripts |
| Dotfile writes, cron, SSH key operations | No | None detected |
| Binary files in `template/` | No | None present |

### Portability

- Rating: **Partially portable** — site-specific cluster name (`tillicum`), container path, and all model paths are in `form.yml` attributes (good); one hardcoded `/gpfs/home/$USER` path is in the job script; additional model-directory and Gemma projector paths are hardcoded in `template/script.sh.erb`; README's "Current defaults" and "Currently configured models" tables document the current values but there is no dedicated configuration section describing what to change when deploying at a new site.

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | `/gpfs/home/$USER` used as `src` in the storage home bind mount — site-specific GPFS home path hardcoded in the job script | template/script.sh.erb:128 |
| QUA-02 | `check: portability-rating` | PASS | info | Partially portable — main site config (cluster name, container path, model paths) is in `form.yml` attributes; hardcoded paths in scripts are limited but present | template/script.sh.erb:128 |

### Documentation

- Rating: **Minimal** — what it launches, prerequisites, and installation are present; configuration section is absent; known limitations and screenshots are absent.
- Evidence per rung:
  - what it launches: "Llama.cpp WebUI — Open OnDemand Application", README.md:3
  - prerequisites: "Current defaults", README.md:17
  - installation: "Deployment", README.md:271
  - configuration: none
  - known limitations: none
  - troubleshooting: "Troubleshooting", README.md:345
  - screenshots: none
  - environment variables: README.md:329 (`PROXY_DEBUG=1` assignment)
  - info panel: none
  - architecture: "Architecture", README.md:34

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| QUA-01 | `check: documentation-rating` | FAIL | low | Documentation rated Minimal — below the Adequate target; missing configuration and known-limitations sections | README.md:1 |

### Code Quality

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| QUA-03 | `check: error-handling` | PASS | info | `before.sh.erb` uses explicit `if [ ! -r ... ]; then exit 1; fi` guards for all critical pre-checks; `after.sh` checks `$?` explicitly | template/before.sh.erb:25; template/after.sh:29 |
| QUA-03 | `check: error-handling` | WARN | low | `script.sh.erb` sets `set -u` (line 18) but not `set -e`; the background apptainer launch cannot be guarded by `set -e`, and the watchdog covers that path, but intermediate shell operations run without automatic exit-on-error | template/script.sh.erb:18 |
| QUA-07 | `check: numeric-field-bounds` | WARN | low | `bc_num_hours` has no `min` or `max` in `form.yml` — a very large value reaches the Slurm `--time` flag via `.to_f` (numeric sanitization), but no upper bound prevents unreasonable job durations | form.yml:19 |
| QUA-07 | `check: numeric-field-bounds` | WARN | low | `extra_slurm_args` (text\_field, reaches scheduler via `native:`) has no `pattern` constraint — arbitrary tokens are accepted and passed directly to Slurm | form.yml:90 |
| QUA-07 | `check: numeric-field-bounds` | PASS | info | `auto_qos` (form.yml:5) is an admin-controlled fixed string field (`value: "normal"`) — not a user-editable numeric input, no min/max required | form.yml:5 |
| QUA-08 | `check: magic-numbers` | WARN | low | `120` (WAIT_PORT timeout in seconds, `after.sh:7`) and `30` (sleep seconds in watchdog/cleanup, `script.sh.erb:198,199`) are undocumented numeric literals | template/after.sh:7; template/script.sh.erb:198,199 |
| QUA-08 | `check: magic-numbers` | PASS | info | Port range `15000`–`15099` at `script.sh.erb:59` is documented in README.md's "Port conflicts" section | template/script.sh.erb:59 |
| QUA-08 | `check: magic-numbers` | WARN | low | Seven undocumented hex color literals in the loading-page CSS (`#101014`, `#e5e5ea`, `#1c1c22`, `#2e2e36`, `#9a9aa3`, `#44444e`) — cosmetic but undocumented | template/proxy.py:124,126,129,130,131 |
| QUA-09 | `check: duplicated-blocks` | WARN | low | The model-directory and mmproj bind-mount lines (lines 115–117) are duplicated verbatim in the non-YOLO branch (lines 122–124); both could share a helper or be moved before the `if`/`else` | template/script.sh.erb:115,117,122,124 |
| QUA-04 | `check: dead-code` | PASS | info | No commented-out code detected by pre-review scanner; the `--network none` block at lines 97–100 is accompanied by a multi-line explanation of why it is intentionally excluded and must not be removed | template/script.sh.erb:97 |
| QUA-10 | `check: erb-missing-value` | PASS | info | `api_key` guarded by `.to_s` before `Base64.strict_encode64`; all check\_box fields always return a string value; `extra_slurm_args.empty?` is called after a conditional presence check; no unguarded nil risk detected | template/script.sh.erb:29; submit.yml.erb:14 |
| QUA-10 | `check: erb-missing-value` | PASS | info | `auto_qos` is an OOD built-in always returning `"normal"` (line 5); `gpu_partition` ternary always yields `2` or `8` (line 9); `bc_num_hours.to_f` is nil-safe via `.to_f` (line 12) — all nil-safe | submit.yml.erb:5,9,12 |
| QUA-06 | `check: icon-matches-target-os` | PASS | info | No desktop or panel icon files in `template/`; check not applicable | template |
| QUA-06 | | WARN | info | Duplicate paragraph in README: lines 125–128 and 130–133 are identical ("The `model_path` YAML default is intentionally empty…") — copy-paste artifact | README.md:125,130 |

## Review scope

**Examined:** `manifest.yml`, `form.yml`, `form.js` (client-side, not in security scope), `submit.yml.erb`, `template/after.sh`, `template/before.sh.erb`, `template/script.sh.erb`, `template/proxy.py`, `view.html.erb`, `README.md`, `icon.png`; GitHub repo metadata (releases, contributors, CI, archived status)

**Not examined:** Runtime behavior (no isolated execution environment); `template/proxy.py` runtime request handling beyond static analysis; dynamic form behavior in `form.js`

**Tools:** syntax (bash -n, 3 files, all pass), shellcheck 0.9.0 (22 findings, 4 artifacts), semgrep 1.178.0 (0 findings), bandit 1.9.4 (3 findings), trivy (skipped, no applicable files)

## Catalog checks

- **Duplicate check against the existing catalog** — No duplicate found. Queried page 1 of the published app list (87 apps returned, which appears to be the full published set based on the API count). The catalog contains "AnythingLLM + Ollama" (Ollama-based, different implementation), "Gradio Chatbot" (different serving layer), and "Multitenant LLM" (multi-tenant service) — none are llama.cpp-based Batch Connect apps using the same architecture.
  - **Duplicate-check rationale:** _No existing catalog entry uses llama.cpp with Apptainer as a Batch Connect app. This appears to be a distinct implementation. Reviewer should confirm coverage of the full catalog (87 apps returned on page 1)._
- **`software` value matches a catalog Software entry** — No match found for "llama.cpp" in the catalog. This is an inferred repo (no `appverse.yml`) so `software` is not declared; the reviewer must create a Software entry for "llama.cpp" before the app can be listed, or confirm the field in a future `appverse.yml`.
- **`app_type` and `implementation_tags` are in the catalog vocabularies** — `role: batch_connect` in `manifest.yml` maps to the batch-connect vocabulary. No `appverse.yml` is present, so `implementation_tags` are not declared; a reviewer creating the catalog entry should select from: `apptainer`, `gpu-enabled`, `containerized`, `batch connect`.

## Overall recommendation

**Request changes.** The repository does not include a LICENSE file, which is a required gate criterion. All other gate criteria pass: README.md is substantive (not a stub), `manifest.yml` has the required fields, YAML is valid, the standard Batch Connect layout is present, and shell scripts pass syntax checking. Security findings are all low or medium severity, tagged unintentional, and none warrants rejection. Documentation is rated Minimal — below the Adequate target — and should be improved alongside the license addition. Once a LICENSE file is added and documentation is brought to Adequate, the app would qualify for Accept with suggestions (pending the catalog duplicate check and Software entry creation).

---

## Draft feedback — edit before sending

Thank you for submitting **Llama.cpp WebUI** to Appverse. This is a well-constructed Batch Connect app with a thoughtful security model (YOLO vs. selective bind mounts, CSRF token in the session page, API key support) and detailed troubleshooting documentation. A few items need to be addressed before it can be listed.

**Required**

The repository is missing an open-source license file. Please add a `LICENSE` file at the repository root (MIT is recommended). Without it the app cannot be listed in the catalog, as the license is a gate criterion.

**Recommended**

The README is rated Minimal — it covers what the app launches, prerequisites, and how to deploy, but it is missing two sections needed to reach the Adequate target for listing:

- A **Configuration** section that enumerates what a deployer at a different site needs to change: the cluster name in `form.yml` (line 2), the `sif_path` default value (the Apptainer image path, line 25), the model entries under `model_path.options` (the `/gpfs/models/…` paths), the `/gpfs/home/$USER` path hardcoded in `template/script.sh.erb` (line 128), and the `/gpfs/models` bind mount (line 112) and Gemma projector path (lines 78–80). The "Current defaults" and "Adding another model" sections provide useful context but do not explicitly enumerate these as deployer-facing change points.
- A **Known Limitations** section noting, for example, that extra argument strings in the `Extra llama-server arguments` and `Extra Slurm options` fields are split on whitespace (shell-style quoting is not preserved), and that enabling all llama.cpp tools can expose filesystem and shell operations to the loaded model.

**Suggested**

- `form.yml` line 19 (`bc_num_hours`): add `min` and `max` bounds so the Slurm time request cannot exceed your site's policy.
- `form.yml` line 90 (`extra_slurm_args`): consider adding a `pattern` constraint or `help` text warning that only simple flags are supported, since the field reaches Slurm's `native:` args directly.
- `template/script.sh.erb` (line 18): add `set -e` alongside the existing `set -u` so intermediate shell errors exit the job rather than continuing silently.
- `template/script.sh.erb` lines 115–124: the model-directory and mmproj bind-mount lines appear in both the YOLO and non-YOLO branches — refactoring them before the `if`/`else` would remove the duplication.
- `README.md` lines 125–133: the paragraph beginning "The `model_path` YAML default is intentionally empty" appears twice; remove the duplicate.
- No releases or CHANGELOG are present; tagging a release and adding a `CHANGELOG.md` would make it easier for deployers to track changes.
- `submit.yml.erb`: `extra_slurm_args` is passed unsanitized (split on whitespace, each token quoted) into Slurm `native:` args (lines 14–18) — an allowlist `pattern` in `form.yml` or explicit `help` text would reduce the risk of unsanitized user input reaching the scheduler.
- `template/after.sh` line 7: the 120-second port-wait timeout and the `pkill -P ${SCRIPT_PID}` at line 35 (unquoted variable) are minor shellcheck findings; quoting the variable would silence the SC2086 warning.
- `template/script.sh.erb` lines 198–199: the 30-second watchdog/cleanup sleep is an undocumented magic number; extracting it to a named variable would improve readability.
- `template/proxy.py`: the proxy binds to `0.0.0.0` (required for OOD routing, but without an `api_key` co-located users can reach it); `try`/`except`/`pass` at lines 352 and 365 silently swallows connection-cleanup errors; and the loading-page CSS contains undocumented hex color literals — all low-priority cosmetic or informational items.

<!-- feedback-covers: LICENSE:missing-license, README.md:docs-minimal, template/script.sh.erb:hardcoded-path, form.yml:missing-min-max, form.yml:missing-pattern, template/script.sh.erb:no-set-e, template/script.sh.erb:duplicated-block, README.md:readme-typo, releases:no-releases, CHANGELOG.md:no-changelog, submit.yml.erb:unsanitized-user-input, template/script.sh.erb:unsanitized-user-input, template/proxy.py:bind-all-interfaces, template/after.sh:unquoted-variable, template/proxy.py:no-error-check, template/script.sh.erb:other:mixed-quoting, template/after.sh:magic-number, template/script.sh.erb:magic-number, template/proxy.py:undocumented-hex-color -->
