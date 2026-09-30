# Appverse Review: tillicum-llama-chat

**Repository:** https://github.com/UWrc/tillicum-llama-chat  **Mode:** reviewer  **Date:** 2026-09-30
**Reviewed commit:** `f7c8d35004b824812d7c552c6dc17d9b7fd98653` (2026-09-09)  **Repo shape:** inferred single app
**Reviewed with:** appverse-review @ 0.8.0 (`e8ee094`, https://github.com/Sweet-and-Fizzy/appverse-review) · **Model:** claude-sonnet-4-6 · **Rubric:** https://openondemand.connectci.org/appverse-review-rubric

> _Disclaimer: This is an automated review with human curation. It is provided without warranty of any kind and does not certify the app as secure or fit for any purpose. A listing is not an endorsement._

## Repo-level gate criteria

| Rule | Result | Evidence |
|---|---|---|
| — | PASS | Repository public and accessible (clone succeeded) |
| STR-01 | PASS | README.md — present and substantive (14 939 characters, 12 headings, no placeholder text) |
| STR-01 | FAIL | LICENSE — no LICENSE file of any form found in the repository root |
| — | PASS | Repo not archived (active commit 2026-09-09) |

## Upkeep

| Signal | Value | Assessment |
|---|---|---|
| Last commit | 2026-09-09 | Within 12 months |
| Releases | None | No tagged releases |
| Issues responsiveness | NOT CHECKED | No issues data available (unauthenticated API) |
| Contributors | 1 (npho@uw.edu) | Single contributor |
| CHANGELOG | None | No CHANGELOG.md |
| CI | None | No `.github/` directory |

| Dimension | Level | Evidence |
|---|---|---|
| Upkeep (repo-level) | Medium | Brand-new submission (single commit 2026-09-09); waiver applied; no releases, CI, or CHANGELOG |

## App: Llama.cpp WebUI (.)

### Signals

| Dimension | Level | Evidence |
|---|---|---|
| Portability | High | Not portable — cluster name `tillicum`, all model paths (`/gpfs/models/*`), SIF path, partition names hardcoded throughout `form.yml` and `template/` |
| Documentation | High | Minimal — what it launches, prerequisites, and installation documented; no configuration or known-limitations section |

### Structure

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| STR-02 | `check: str-02-metadata` | PASS | info | Required metadata fields present: `name`, `category`, `role`, `description` | manifest.yml:2,3,5,6 |
| STR-03 | `check: str-03-yaml-valid` | PASS | info | `manifest.yml` and `form.yml` parse without errors | manifest.yml:1 |
| STR-06 | `check: str-06-syntax` | PASS | info | Template scripts syntactically correct: 3 files pass; 0 fail; 0 not checked (`template/after.sh` plain; `template/before.sh.erb` and `template/script.sh.erb` ERB-stripped) | template/after.sh |
| STR-07 | `check: str-07-layout` | PASS | info | Standard OOD structure present: `form.yml`, `submit.yml.erb`, `template/script.sh.erb` | submit.yml.erb |
| STR-04 | `check: str-04-references` | PASS | info | All attributes interpolated in `submit.yml.erb` are defined; `auto_accounts` is an OOD auto field | submit.yml.erb:4 |

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
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `auto_accounts` → `accounting_id` and `auto_qos` → `qos` are OOD auto fields routed to the scheduler API, not shell | reviewed OK: submit.yml.erb:4,5 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `gpu_partition` is a select widget; ternary guards at lines 9–10 limit output to numeric literals; line 11 is YAML-quoted and constrained by the select | reviewed OK: submit.yml.erb:9,10,11 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `bc_num_hours` sanitised by `.to_f` before scheduler interpolation | reviewed OK: submit.yml.erb:12 |
| OODT-01 | `check: sec-interpolation` | WARN | medium | unintentional | `extra_slurm_args` (text\_field) is split on whitespace and each token inserted as a native sbatch option; unsanitised free-text reaches the scheduler; gated by `enable_advanced_args` but user-controlled when enabled | submit.yml.erb:18 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `sif_path` (hidden\_field, admin-set) and `model_path` (select, fixed options) in `before.sh.erb` are both shell-quoted; `before.sh.erb` validates readability before the job runs | reviewed OK: template/before.sh.erb:23,31 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `sif_path` (hidden, admin-set), `model_path` (select, fixed options), `temperature` (number\_field with bounds 0–1, guarded), and `api_key` (encoded by `Base64.strict_encode64` in ERB) are safe; check\_box values produce `0`/`1` only | reviewed OK: template/script.sh.erb:21,23,25,29,32,33,36,39,42 |
| OODT-01 | `check: sec-interpolation` | WARN | low | unintentional | `extra_llama_args` (text\_field, gated by advanced toggle) is split and passed verbatim to `llama-server`; user can inject arbitrary server flags; self-harm only | template/script.sh.erb:31 |
| OODT-01 | `check: sec-interpolation` | WARN | low | unintentional | Mount source/destination text\_fields (`mount1_source`/`dest`, `mount2_source`/`dest`, `mount3_source`/`dest`) pass user-supplied paths to Apptainer `--mount`; shell-quoted but no format constraint; Apptainer limits access to the user's own paths; self-harm only | template/script.sh.erb:34,35,37,38,40,41 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | Unquoted-variable candidates: `$API_KEY_B64` is quoted inside the `printf` command; `$MODEL_PATH` is double-quoted within the `dirname` sub-shell; `$API_KEY` used only in `${#API_KEY}` (length) | reviewed OK: template/script.sh.erb:30,115,122,157 |
| OODT-04 | `check: sec-network-call` | PASS | info | — | `socket.socket()` in `after.sh` inline Python polls `127.0.0.1:$port` for proxy readiness; expected local health-check | reviewed OK: template/after.sh:15 |
| OODT-04 | `check: sec-network-call` | PASS | info | — | `http.client` import and `HTTPConnection`/`HTTPException` are the proxy's upstream forwarding path; `XMLHttpRequest` at lines 94–95 is JavaScript source inside a Python string literal (`SHIM`), not a Python network call | reviewed OK: template/proxy.py:44,94,95,345,355 |
| OODT-05 | `check: sec-config-flag` | WARN | medium | unintentional | Proxy binds to `0.0.0.0` by default; necessary for OOD's node-proxy routing, but allows other users on the same compute node to connect to the port directly, bypassing OOD authentication; documented in the README's Architecture diagram; B104 corroborates | template/proxy.py:52 |
| — | `check: sec-eval-exec` | — | — | — | No eval/exec candidates | — |
| — | `check: sec-credential-string` | — | — | — | No credential-string candidates | — |
| — | `check: sec-permissive-mode` | — | — | — | No permission-change candidates | — |
| — | `check: sec-file-write-outside-job` | — | — | — | No file-write-outside-job candidates | — |
| — | `check: sec-binary-in-template` | — | — | — | No binary files in `template/` | — |
| QUA-06 | `check: sec-tool-finding` | PASS | info | — | SC2148 (no shebang) and SC2154 (`port` referenced but not assigned) are artefacts of linting OOD's job-script files one at a time; `port` is assigned by `before.sh.erb` and is an OOD contract variable | reviewed OK: template/after.sh:1,4; template/before.sh.erb:1; template/script.sh.erb:152 |
| OODT-01 | `check: sec-tool-finding` | WARN | info | unintentional | SC2086: `${SCRIPT_PID}` unquoted in `pkill -P ${SCRIPT_PID}`; the variable is set by the OOD framework, not user-supplied, so injection risk is negligible | template/after.sh:35 |
| OODT-05 | `check: sec-tool-finding` | WARN | medium | unintentional | B104: Bandit confirms binding to all interfaces at `proxy.py:52`; see sec-config-flag finding above | template/proxy.py:52 |
| QUA-03 | `check: sec-tool-finding` | WARN | low | unintentional | B110: `try`/`except`/`pass` at `proxy.py:352` and `proxy.py:365` silently discards all upstream errors (connection failures, malformed responses) rather than logging them | template/proxy.py:352,365 |
| QUA-06 | `check: sec-tool-finding` | PASS | info | — | SC2054: commas inside array elements at script.sh.erb:112,115,117,122,124,128,136,138 are Apptainer `--mount type=bind,src=...,dst=...` syntax, not array separators; false positive for this codebase | reviewed OK: template/script.sh.erb:112,115,117,122,124,128,136,138 |
| QUA-06 | `check: sec-tool-finding` | WARN | info | unintentional | SC2140: mixed-quoting pattern `"A"B"C"` at `script.sh.erb:128` in the home-directory bind-mount argument; functionally correct but non-idiomatic | template/script.sh.erb:128 |
| STR-04 | `check: sec-tool-finding` | PASS | info | — | SC2154 (`port` not assigned) in `script.sh.erb:152` is an artefact; already covered in the artifacts PASS row above | reviewed OK: template/script.sh.erb:152 |
| QUA-04 | `check: sec-tool-finding` | PASS | info | — | SC2317: commands at `script.sh.erb:208,209,211,213,214,215` are inside the `on_term()` trap handler, invoked indirectly by `trap on_term TERM`; not unreachable | reviewed OK: template/script.sh.erb:208,209,211,213,214,215 |

#### Additional observations (review)

| Rule | Result | Severity | Tag | Summary | Evidence |
|---|---|---|---|---|---|
| OODT-05 | WARN | medium | unintentional | CORS wildcard via origin reflection: `_relay_headers` replaces the upstream `Access-Control-Allow-Origin` with the client's `Origin` and adds `Access-Control-Allow-Credentials: true`, allowing any cross-origin page that knows the session URL to make credentialed API requests; not listed by security.json | template/proxy.py:213,215 |
| OODT-05 | WARN | low | unintentional | CSRF token set by `view.html.erb` (cookie `csrftoken`) is not verified by `proxy.py`; `SameSite=Strict` on the session cookie provides baseline protection in modern browsers, but the token provides no additional defence as currently implemented; not listed by security.json | view.html.erb:5 |

**Capability profile (Batch Connect):**

| Capability | Present | Assessment |
|---|---|---|
| Spawns Apptainer container with GPU (`--nv`) | Yes | Expected — LLM inference app |
| Reads model files under `/gpfs/models/` (read-only mount) | Yes | Expected — model loading |
| Reads Apptainer SIF from `/gpfs/containers/` | Yes | Expected |
| Reverse-proxy HTTP server on `0.0.0.0:<port>` | Yes | Expected for OOD routing; see OODT-05 |
| Outbound HTTP to `127.0.0.1:<llama_port>` (proxy forwarding) | Yes | Expected |
| User-supplied Apptainer bind mounts (selective mode) | Yes | Scoped to the user's own accessible paths |
| Optional home-directory mount (`/gpfs/home/$USER`) | Yes | User opt-in; documented |
| API key passed to llama-server via base64-encoded ERB | Yes | Shell-special chars neutralised; safe |
| `--tools all` enables built-in llama-server tools (filesystem, shell) | Yes | README warns this is trusted-user functionality |
| YOLO mode (broad Apptainer implicit mounts) | Yes | User opt-in; documented as security tradeoff |
| No writes to shell init files, SSH keys, or cron | Confirmed | No anomalous persistence |
| No outbound network calls from ERB or submit phases | Confirmed | All network activity is in the job-script or proxy |

### Portability
- Rating: Not portable — cluster name, all model paths, SIF path, partition names, and home-directory prefix are hardcoded throughout `form.yml` and `template/`; a deployer at another site must replace all of these with no centralized configuration guide

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| QUA-02 | `check: hardcoded-site-paths` | WARN | medium | Absolute path `/home/` (within `/gpfs/home/$USER`) in bind-mount argument; site-specific storage prefix | template/script.sh.erb:128 |
| QUA-02 | | WARN | medium | Cluster name `tillicum` hardcoded in `form.yml` as a top-level YAML key, not a user-selectable form attribute | form.yml:2 |
| QUA-02 | | WARN | medium | All model paths hardcoded as `/gpfs/models/...` in `model_path` select options | form.yml:36,37,38,39,40,41,42,43,44 |
| QUA-02 | | WARN | medium | GPU partition names (`gpu-h200`, `gpu-h200-mig`) are Tillicum-specific | form.yml:48 |
| QUA-02 | `check: portability-rating` | FAIL | medium | Not portable — cluster name, all model paths, SIF path (`/gpfs/containers/...`), partition names, and storage prefix must all be replaced for another site; see hardcoded-* records above | form.yml:2,22,36,48 |

### Documentation
- Rating: Minimal — what it launches, prerequisites, and installation documented; configuration and known-limitations sections absent
- Evidence per rung:
  - what it launches: "Llama.cpp WebUI — Open OnDemand Application", README.md:3
  - prerequisites: "Current defaults", README.md:17
  - installation: "Deployment", README.md:271
  - configuration: none
  - known limitations: none
  - troubleshooting: "Troubleshooting", README.md:345
  - screenshots: none
  - environment variables: README.md:329
  - info panel: none
  - architecture: "Architecture", README.md:34

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| QUA-01 | `check: documentation-rating` | FAIL | medium | Minimal — below the Adequate target; missing configuration and known-limitations sections; what it launches, prerequisites, installation, and troubleshooting are well-documented | README.md:1 |

### Code Quality

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| QUA-03 | `check: error-handling` | WARN | low | `template/script.sh.erb` uses `set -u` but not `set -e`; command failures (e.g., a failed `nohup apptainer run`) do not abort the script; `template/after.sh` has neither `set -e` nor `set -u` | template/script.sh.erb:18; template/after.sh:1 |
| QUA-07 | `check: numeric-field-bounds` | PASS | info | `auto_qos` has a fixed string value `"normal"` (null widget, not a numeric field); bounds not applicable | form.yml:5 |
| QUA-07 | `check: numeric-field-bounds` | WARN | low | `bc_num_hours` reaches the scheduler via `--time` but has no `min` or `max` bounds; `extra_slurm_args` is a free-text field that reaches the scheduler as native sbatch options but has no `pattern` | form.yml:19,90 |
| QUA-08 | `check: magic-numbers` | WARN | low | Undocumented numeric literals: `120` (proxy wait-timeout, `after.sh:7`); port-scan fallback range `15000`–`15099` (`script.sh.erb:59`); watchdog `sleep 30` (`script.sh.erb:198,199`) | template/after.sh:7; template/script.sh.erb:59,198,199 |
| QUA-08 | `check: magic-numbers` | WARN | info | Undocumented hex color literals in the loading-page CSS; cosmetic only | template/proxy.py:124,126,129,130,131 |
| QUA-09 | `check: duplicated-blocks` | PASS | info | No large duplicated code blocks in template files | template/script.sh.erb |
| QUA-04 | `check: dead-code` | PASS | info | `template.json` lists no commented-out code; the commented `--network none` block at `script.sh.erb:98–100` is accompanied by an explanatory comment and is not dead code | template/script.sh.erb:98 |
| QUA-10 | `check: erb-missing-value` | PASS | info | `before.sh.erb` validates readability of `sif_path` and `model_path`; `add_mount()` guards on empty source; ERB values that may be empty are handled | template/before.sh.erb:25,33 |
| QUA-10 | `check: erb-missing-value` | PASS | info | `auto_qos` has a fixed default value (line 5); cpu/mem ternary always resolves (line 9); `bc_num_hours.to_f` is nil-safe (line 12); `extra_slurm_args.empty?` is guarded by the `unless` block (line 14) | submit.yml.erb:5,9,12,14 |
| QUA-06 | `check: icon-matches-target-os` | PASS | info | No desktop or panel icon files in `template/`; `icon.png` at the repo root is the OOD panel icon, not an OS-specific icon reference | icon.png |
| QUA-06 | | WARN | low | Paragraph describing `model_path` default behavior is duplicated verbatim in `README.md` (lines 125–128 and 130–133); copy-paste artifact | README.md:125,130 |

## Review scope

**Examined:** `manifest.yml`, `form.yml`, `submit.yml.erb`, `template/after.sh`, `template/before.sh.erb`, `template/script.sh.erb`, `template/proxy.py`, `view.html.erb`, `README.md`, `form.js` (structure only), `icon.png` (type check)
**Not examined:** Runtime behavior (Tier 3 — no isolated execution environment); `form.js` JavaScript logic in depth (outside shell/ERB tool scope)
**Tools:** syntax (3 files, all pass), shellcheck (22 findings), semgrep (0 findings), bandit (3 findings), trivy (skipped — no applicable files)

## Catalog checks

- Duplicate check against the existing catalog — no duplicate found. Pages read: page 1 of the app list (100-item limit; some unpublished items omitted). No existing llama.cpp, llama-server, or Llama.cpp WebUI app is present. "AnythingLLM + Ollama" and "Multitenant LLM" are distinct products.
  - **Duplicate-check rationale:** _No app serving llama.cpp's built-in WebUI via llama-server appears in the catalog. The app is sufficiently differentiated from AnythingLLM+Ollama (different software, different serving architecture) and from Multitenant LLM (different deployment model) to stand on its own. No duplicate found in the pages read._
- `software` value matches a catalog Software entry — not applicable (inferred repo; `manifest.yml` carries no `software` field). No Software entry for "llama.cpp" currently exists in the catalog; a reviewer would need to create one before the app can be listed.
- `app_type` and `implementation_tags` are in the catalog vocabularies — not applicable (inferred repo; no `appverse.yml`).

## Overall recommendation

**Reject.** The repository has no LICENSE file — a required gate criterion that the decision rubric places in the Reject category. Adding an open-source LICENSE (MIT is recommended) and resubmitting would resolve this gate failure. Separately, the documentation is rated Minimal (below the Adequate target) and the app is Not portable due to Tillicum-specific values throughout `form.yml`; both would move the decision to Accept with suggestions once the license is present. The medium-severity security findings (proxy binding to `0.0.0.0` and the CORS origin-reflection in `proxy.py`) are Request-changes-class issues — fixable, tagged unintentional, and without a redesign requirement. No finding is tagged potentially malicious.

---

## Draft feedback — edit before sending

Thank you for submitting Llama.cpp WebUI. This is a well-architected app with a thoughtful reverse-proxy design, solid troubleshooting coverage, and clear documentation of the app's architecture. There is one blocking issue and several recommended and suggested improvements.

**Required (blocks listing):**

The repository has no open-source license file. Please add a `LICENSE` file (MIT is a common choice for OOD apps) to the repository root before resubmitting.

**Recommended (needed to reach the listing target):**

The README is rated Minimal rather than Adequate because it has no Configuration section explaining what a deployer at another site needs to change. The "Current defaults" table is a good start, but a deployer also needs to know which values in `form.yml` to replace: the `cluster:` key (currently `tillicum`), the `sif_path` hidden-field default (`/gpfs/containers/...`), all `model_path` option values (`/gpfs/models/...`), the `gpu_partition` option names (`gpu-h200`, `gpu-h200-mig`), and the `/gpfs/home/$USER` bind-mount path in `script.sh.erb` (line 128) for sites with a different home-directory prefix. Adding a "Configuration" section that lists these with instructions for replacing them would bring the documentation to Adequate. A "Known limitations" note — for example, that `--tools all` exposes filesystem and shell operations to the model (already stated at README.md line 244) — would complete that rung.

**Suggested (polish):**

- `template/script.sh.erb` uses `set -u` but not `set -e`; a failed `nohup apptainer run` command would not abort the script. Adding `set -eo pipefail` would surface such failures. `template/after.sh` has neither guard.
- `form.yml` line 19: `bc_num_hours` has no `min` or `max`; a bound like `min: 1` prevents zero-hour jobs. The `extra_slurm_args` field (line 90) reaches the scheduler as raw sbatch options with no `pattern` constraint; consider documenting the expected format in the help text.
- `template/proxy.py`, `_relay_headers` (lines 213–216): the proxy reflects any client `Origin` back with `Access-Control-Allow-Credentials: true`, effectively creating a CORS wildcard. Any cross-origin page that knows the session URL can make credentialed API requests through it. Consider validating the reflected origin against an allowed list or removing the reflection and relying on OOD's own authentication layer.
- The CSRF token cookie set in `view.html.erb` is not enforced by `template/proxy.py`; if you improve the CORS handling above, consider also verifying this token in the proxy request path.
- `template/proxy.py`, `try`/`except`/`pass` blocks at lines 352 and 365 silently discard all upstream errors; consider logging them at `DEBUG` level so they appear when `PROXY_DEBUG=1` is set.
- The user-supplied mount paths in `template/script.sh.erb` (`mount1_source`, `mount2_source`, `mount3_source`, and their destination counterparts, lines 34–41) are passed to Apptainer `--mount` without format validation; consider adding a note in the field help text about expected path formats.
- `README.md` lines 125–133: the paragraph describing `model_path`'s default behavior is duplicated verbatim; please remove the second copy.
- Numeric literals in `template/after.sh` (line 7, `120`) and `template/script.sh.erb` (line 59, the `15000`–`15099` port-scan range; lines 198–199, `sleep 30`) would benefit from brief comments explaining the chosen values.

<!-- feedback-covers: LICENSE:missing-license, README.md:docs-minimal, form.yml:hardcoded-cluster, form.yml:hardcoded-path, form.yml:hardcoded-partition, template/script.sh.erb:hardcoded-path, template/script.sh.erb:no-set-e, template/after.sh:no-set-e, form.yml:missing-min-max, form.yml:missing-pattern, submit.yml.erb:unsanitized-user-input, template/proxy.py:bind-all-interfaces, template/proxy.py:cors-wildcard, view.html.erb:disabled-xsrf, template/proxy.py:no-error-check, template/script.sh.erb:unsanitized-user-input, README.md:readme-inconsistency:model_path-description, template/after.sh:magic-number, template/script.sh.erb:magic-number -->
