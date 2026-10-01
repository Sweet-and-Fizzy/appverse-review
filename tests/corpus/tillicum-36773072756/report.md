# Appverse Review: tillicum-llama-chat

**Repository:** https://github.com/UWrc/tillicum-llama-chat  **Mode:** reviewer  **Date:** 2026-09-30
**Reviewed commit:** `f7c8d35004b824812d7c552c6dc17d9b7fd98653` (2026-09-09)  **Repo shape:** inferred single app
**Reviewed with:** appverse-review @ 0.8.0 (`0987de4`, https://github.com/Sweet-and-Fizzy/appverse-review) · **Model:** claude-sonnet-4-6 · **Rubric:** https://openondemand.connectci.org/appverse-review-rubric

> _Disclaimer: This is an automated review with human curation. It is provided without warranty of any kind and does not certify the app as secure or fit for any purpose. A listing is not an endorsement._

## Repo-level gate criteria

| Rule | Result | Evidence |
|---|---|---|
| — | PASS | Repository public and accessible (clone succeeded) |
| STR-01 | PASS | README.md — present and substantive (11,971 characters, 184 content lines, no placeholder text) |
| STR-01 | FAIL | LICENSE — no LICENSE file found in the repository |
| — | PASS | Repo not archived (archived: false) |

## Upkeep

| Signal | Value | Assessment |
|---|---|---|
| Last commit | 2026-09-09 | Active within 12 months |
| Releases | None | No tagged releases |
| Issues responsiveness | 0 open issues | Neutral — no evidence of responsiveness either way |
| Contributors | 2 (npho, jfrulla) | Multiple contributors |
| CHANGELOG | Absent | Not present |
| CI | Absent | No .github/workflows/ directory |

| Dimension | Level | Evidence |
|---|---|---|
| Upkeep (repo-level) | Medium | Brand-new repo (created 2026-09-01); history requirement waived; multiple contributors but no releases, CHANGELOG, or CI |

## App: Llama.cpp WebUI (.)

### Signals

| Dimension | Level | Evidence |
|---|---|---|
| Portability | Medium | Model paths and SIF path centralized in form.yml attributes; mmproj path and /gpfs/models bind mount hardcoded in template/script.sh.erb |
| Documentation | Medium | Adequate — installation (Deployment), configuration, and known-limitations sections present; screenshots absent |

### Structure

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| STR-02 | `check: str-02-metadata` | PASS | info | Required manifest fields present: name, category, role, description | manifest.yml:2-11 |
| STR-03 | `check: str-03-yaml-valid` | PASS | info | manifest.yml and form.yml parse without errors | manifest.yml:1 |
| STR-06 | `check: str-06-syntax` | PASS | info | Template scripts syntactically correct: 3 files pass; 0 fail; 0 not checked (template/before.sh.erb and template/script.sh.erb checked as ERB-stripped copies) | template/after.sh; template/before.sh.erb; template/script.sh.erb |
| STR-07 | `check: str-07-layout` | PASS | info | Standard OOD Batch Connect layout: form.yml, submit.yml.erb, and template/script.sh.erb all present | form.yml; submit.yml.erb; template/script.sh.erb |
| STR-04 | `check: str-04-references` | PASS | info | All variables referenced in submit.yml.erb are defined in form.yml or are OOD built-in attributes (auto_accounts, cluster) | submit.yml.erb:1 |

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
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `auto_accounts` (OOD-managed auto attribute, whitelisted account values) reaches scheduler only as accounting_id YAML value | reviewed OK: submit.yml.erb:4 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `auto_qos` (OOD-managed auto attribute, whitelisted QoS values) reaches scheduler only as qos YAML value | reviewed OK: submit.yml.erb:5 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `gpu_partition` guarded by ternary (`gpu_partition == 'gpu-h200-mig' ? 2 : 8`); outputs integer literal only, not raw field value | reviewed OK: submit.yml.erb:9 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `gpu_partition` guarded by ternary (`? 34 : 240`); outputs integer literal only | reviewed OK: submit.yml.erb:10 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `gpu_partition` is a select field with two enumerated options; value constrained to "gpu-h200" or "gpu-h200-mig"; YAML-quoted | reviewed OK: submit.yml.erb:11 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `bc_num_hours` sanitised by `.to_f`; YAML-quoted numeric result only | reviewed OK: submit.yml.erb:12 |
| OODT-01 | `check: sec-interpolation` | WARN | low | unintentional | `extra_slurm_args` (text_field, no pattern) splits on whitespace and passes each token as a quoted YAML native arg to the Slurm scheduler; user can inject arbitrary scheduler options; gated by `enable_advanced_args` but not further validated; self-harm only in BC/PUN model | submit.yml.erb:18 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `sif_path` (hidden_field, administrator-managed default value); shell-quoted assignment; no user editing | reviewed OK: template/before.sh.erb:23 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `model_path` (select with enumerated GGUF paths); shell-quoted assignment | reviewed OK: template/before.sh.erb:31 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `sif_path` (admin-managed hidden_field); shell-quoted with tilde expansion; script validates readability with `[ ! -r ]` before use | reviewed OK: template/script.sh.erb:21 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `model_path` (select, enumerated paths); shell-quoted with tilde expansion | reviewed OK: template/script.sh.erb:23 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `temperature` (number_field, min:0, max:1) and `enable_advanced_args` (check_box); ternary outputs "0.8" or the bounded numeric value; shell-quoted | reviewed OK: template/script.sh.erb:25 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `api_key` sanitised by `Base64.strict_encode64(context.api_key.to_s)` before interpolation; output is alphanumeric+/= only; shell injection impossible; design rationale documented in a comment | reviewed OK: template/script.sh.erb:29 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `$API_KEY_B64` is double-quoted within the `printf` subshell (`printf '%s' "$API_KEY_B64"`); word splitting does not apply | reviewed OK: template/script.sh.erb:30 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `extra_llama_args` (text_field); shell-quoted assignment; split with `read -r -a` and passed as a properly quoted array to llama-server (not to the shell); intentional advanced feature | reviewed OK: template/script.sh.erb:31 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `storage_yolo` (check_box, returns "0" or "1"); shell-quoted | reviewed OK: template/script.sh.erb:32 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `storage_home_mount` (check_box, "0" or "1"); shell-quoted | reviewed OK: template/script.sh.erb:33 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `mount1_source` (text_field); shell-quoted assignment; used as Apptainer bind-mount source path within the submitting user's own permissions; `add_mount()` returns early on empty values | reviewed OK: template/script.sh.erb:34 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `mount1_dest` (text_field); shell-quoted; container destination path | reviewed OK: template/script.sh.erb:35 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `mount1_writable` (check_box, "0" or "1"); shell-quoted | reviewed OK: template/script.sh.erb:36 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `mount2_source` (text_field); same analysis as mount1_source | reviewed OK: template/script.sh.erb:37 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `mount2_dest` (text_field); same analysis as mount1_dest | reviewed OK: template/script.sh.erb:38 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `mount2_writable` (check_box, "0" or "1"); shell-quoted | reviewed OK: template/script.sh.erb:39 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `mount3_source` (text_field); same analysis as mount1_source | reviewed OK: template/script.sh.erb:40 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `mount3_dest` (text_field); same analysis as mount1_dest | reviewed OK: template/script.sh.erb:41 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `mount3_writable` (check_box, "0" or "1"); shell-quoted | reviewed OK: template/script.sh.erb:42 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `$MODEL_PATH` is double-quoted within the `dirname` subshell; model_path is a select field constrained to enumerated paths | reviewed OK: template/script.sh.erb:115 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `$MODEL_PATH` same analysis as line 115 | reviewed OK: template/script.sh.erb:122 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `$API_KEY` used in `[ -n "$API_KEY" ]` test (quoted) and `${#API_KEY}` length expression (integer); no word splitting risk | reviewed OK: template/script.sh.erb:157 |
| OODT-04 | `check: sec-network-call` | PASS | info | — | Loopback TCP socket check (`127.0.0.1:port`) to confirm the proxy port is open; standard OOD after.sh readiness-wait pattern | reviewed OK: template/after.sh:15 |
| OODT-04 | `check: sec-network-call` | PASS | info | — | `import http.client` is the proxy's standard-library HTTP module; all downstream HTTP calls are to `127.0.0.1:$UPSTREAM_PORT` (llama-server loopback) | reviewed OK: template/proxy.py:44 |
| OODT-04 | `check: sec-network-call` | PASS | info | — | `"var oo=XMLHttpRequest.prototype.open;"` is JavaScript source code embedded as a string constant in the `SHIM` variable; not a server-side network call | reviewed OK: template/proxy.py:94 |
| OODT-04 | `check: sec-network-call` | PASS | info | — | `XMLHttpRequest.prototype.open=function(m,u){…}` same SHIM string constant | reviewed OK: template/proxy.py:95 |
| OODT-04 | `check: sec-network-call` | PASS | info | — | `http.client.HTTPConnection(UPSTREAM_HOST, UPSTREAM_PORT)` connects to `127.0.0.1:$UPSTREAM_PORT`; core proxy-forwarding function | reviewed OK: template/proxy.py:345 |
| OODT-04 | `check: sec-network-call` | PASS | info | — | Exception handler for upstream HTTP connection errors; proxy falls back to serving the loading page | reviewed OK: template/proxy.py:355 |
| OODT-05 | `check: sec-config-flag` | WARN | low | unintentional | `LISTEN_HOST` defaults to `"0.0.0.0"`; proxy binds to all interfaces; on a shared compute node other users can reach the LLM UI on this port without going through OOD's authentication layer (corroborated by bandit B104) | template/proxy.py:52 |
| — | `check: sec-tool-finding` | PASS | info | — | SC2148 (no shebang) at template/after.sh:1, template/before.sh.erb:1 and SC2154 (port referenced but not assigned) at template/after.sh:4, template/script.sh.erb:152 are artefacts of linting OOD's job-script files one at a time; `port` is an OOD contract variable set by `before.sh` | reviewed OK: template/after.sh:1,4; template/before.sh.erb:1; template/script.sh.erb:152 |
| OODT-01 | `check: sec-tool-finding` | WARN | low | unintentional | SC2086: `${SCRIPT_PID}` unquoted in `pkill -P ${SCRIPT_PID}`; SCRIPT_PID is a PID (integer) so exploitation is implausible, but the variable should be double-quoted | template/after.sh:35 |
| OODT-05 | `check: sec-tool-finding` | WARN | low | unintentional | B104: binding to all interfaces at line 52 (corroborates the sec-config-flag row above) | template/proxy.py:52 |
| QUA-03 | `check: sec-tool-finding` | PASS | info | — | B110: `try`/`except`/`pass` at lines 352 and 365 handle client-disconnect (`BrokenPipeError`/`ConnectionResetError`) and connection-cleanup (`conn.close()`) scenarios; both are intentionally silenced | reviewed OK: template/proxy.py:352,365 |
| QUA-06 | `check: sec-tool-finding` | PASS | info | — | SC2054 at lines 112,115,117,122,124,128,136,138: commas are intentional Apptainer `--mount type=bind,src=…,dst=…` spec separators; shellcheck false positive for this pattern | reviewed OK: template/script.sh.erb:112,115,117,122,124,128,136,138 |
| QUA-06 | `check: sec-tool-finding` | WARN | low | unintentional | SC2140: mixed quoting in bind-mount argument (`src="/gpfs/home/$USER",dst="/home/$USER"`); valid bash but non-standard quoting style | template/script.sh.erb:128 |
| QUA-04 | `check: sec-tool-finding` | PASS | info | — | SC2317 at lines 208–215: commands inside `on_term()` appear unreachable to shellcheck; `on_term` is invoked via `trap on_term TERM` at line 217; shellcheck false positive for trap handlers | reviewed OK: template/script.sh.erb:208,209,211,213,214,215 |

#### Additional observations (review)

| Rule | Result | Severity | Tag | Summary | Evidence |
|---|---|---|---|---|---|
| OODT-05 | WARN | medium | unintentional | Proxy's `_relay_headers` replaces the upstream `Access-Control-Allow-Origin` with whatever `Origin` the client sent, and adds `Access-Control-Allow-Credentials: true`; this creates an effective CORS open to all origins for any client that can reach the proxy through OOD routing; not listed by security.json | template/proxy.py:212-216 |

The proxy rewrites `Origin` and `Referer` to `localhost` before forwarding to llama-server (acceptable), but then echoes the browser's original `Origin` back as the CORS response header with `Allow-Credentials: true`. Any web page that can reach the OOD `/rnode/<host>/<port>/` endpoint (which normally requires an OOD session) can make credentialed cross-origin requests to the LLM API.

**Capability profile (Batch Connect):**

| Capability | Expected? | Finding |
|---|---|---|
| Outbound network calls in ERB | No | None — all network activity is in template/ shell/Python scripts, not in submit.yml.erb or form.yml.erb |
| Loopback HTTP proxy (`proxy.py`) | Yes (design) | Documented in README; llama-server bound to 127.0.0.1 only |
| Proxy bound to 0.0.0.0 | Unusual but OOD-required | WARN OODT-05 above |
| Binary files in template/ | No | None |
| Writes outside job directory | No | Logs written to `$TMPDIR/llama-webui-$SLURM_JOB_ID/` (within job scope) |
| Apptainer container with GPU | Yes (design) | `--nv` flag; user-configurable bind mounts |
| `--tools all` in llama-server invocation | Documented | README notes this can expose filesystem and shell operations; intended for trusted users |
| JS shim injected into HTML | Yes (design) | Documented proxy behaviour; rewrites root-absolute paths |

### Portability

- Rating: Partially portable — model paths, SIF path, cluster name, and partitions are form.yml attributes (hidden_field defaults and select options), documented in the README; mmproj projector path and model-directory bind mount are hardcoded in the template script.

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | `/home/` at line 128 is the generic container home-directory destination (`dst="/home/$USER"`), not a site-specific path (PASS); however, `/gpfs/models/gemma-4-31B-it-GGUF/*` case pattern (line 78), mmproj path `/gpfs/models/gemma-4-31B-it-GGUF/mmproj-BF16.gguf` (line 79), and `/gpfs/models` bind-mount source (line 112) are site-specific paths hardcoded in the template script, not exposed as form.yml attributes | template/script.sh.erb:78,79,112; reviewed OK: template/script.sh.erb:128 |
| QUA-02 | `check: portability-rating` | PASS | info | Partially portable — main configuration (model catalog, SIF path, cluster, partitions) is in form.yml attributes and documented in the README | form.yml:22 |

### Documentation

- Rating: Adequate — installation (Deployment), configuration (adding models), and known limitations (shell-quoting behavior) are all present; troubleshooting is extensive; screenshots absent prevents Strong.
- Evidence per rung:
  - what it launches: "Llama.cpp WebUI — Open OnDemand Application", README.md:3
  - prerequisites: "Current defaults", README.md:17
  - installation: "Deployment", README.md:271
  - configuration: content: README.md:137 (add model option in form.yml)
  - known limitations: content: README.md:200 (shell-quoting limitation for extra args field)
  - troubleshooting: "Troubleshooting", README.md:345
  - screenshots: none
  - environment variables: README.md:329 (PROXY_DEBUG=1 assignment)
  - info panel: none
  - architecture: "Architecture", README.md:34

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| QUA-01 | `check: documentation-rating` | PASS | info | Adequate — what it launches, prerequisites, installation, configuration, and known limitations all evidenced; screenshots absent | README.md:1 |

### Code Quality

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| QUA-03 | `check: error-handling` | WARN | low | `template/script.sh.erb` uses `set -u` but not `set -e`; a failing command will not abort the script; `template/before.sh.erb` has explicit exit-on-error checks for critical paths | template/script.sh.erb:18 |
| QUA-07 | `check: numeric-field-bounds` | WARN | low | `bc_num_hours` has no `min` or `max` in form.yml; it is parsed as a float in submit.yml.erb and reaches the scheduler | form.yml:19 |
| QUA-07 | `check: numeric-field-bounds` | WARN | low | `extra_slurm_args` (text_field, reaches scheduler) has no `pattern` constraint; a user can pass arbitrary Slurm options | form.yml:90 |
| QUA-07 | `check: numeric-field-bounds` | PASS | info | `auto_qos` (OOD-managed text, not numeric), `num_gpus` (hidden_field, min:1, max:1) and `temperature` (number_field, min:0, max:1) reviewed OK | form.yml:5,7,57 |
| QUA-08 | `check: magic-numbers` | WARN | low | `WAIT_PORT=120` at line 7 (120-second proxy timeout) is a bare numeric literal with no inline comment explaining the choice | template/after.sh:7 |
| QUA-08 | `check: magic-numbers` | WARN | low | Port scan range `15000`–`15099` at line 59 is documented in the README's "Port conflicts" section but not in an inline comment | template/script.sh.erb:59 |
| QUA-08 | `check: magic-numbers` | WARN | low | `tail -n 30` at line 199 (last 30 log lines shown on llama-server exit) is a bare literal; the preceding echo partially documents intent | template/script.sh.erb:198,199 |
| QUA-08 | `check: magic-numbers` | WARN | low | Seven hex-color literals in the `LOADING_PAGE` inline CSS (`#101014`, `#e5e5ea`, `#1c1c22`, `#2e2e36`, `#9a9aa3`, `#44444e`) carry no comments explaining the palette | template/proxy.py:124,126,129,130,131 |
| QUA-09 | `check: duplicated-blocks` | WARN | low | Model-directory and mmproj bind-mount logic is duplicated verbatim for the YOLO and non-YOLO branches (lines 115–116 repeated at lines 122–124); could be extracted to a shared function | template/script.sh.erb:115,122 |
| QUA-04 | `check: dead-code` | PASS | info | No commented-out code detected by template.json; commented-out `--network none` block at lines 98–100 includes an explanatory NOTE comment that preserves the design rationale | template/script.sh.erb:98 |
| QUA-10 | `check: erb-missing-value` | PASS | info | ERB expressions in submit.yml.erb handle nil values: auto_qos is OOD-managed (always set), gpu_partition ternary guards against nil, bc_num_hours uses .to_f (nil.to_f = 0.0), extra_slurm_args guarded by .empty? and enable_advanced_args check before use | reviewed OK: submit.yml.erb:5,9,12,13,14 |
| QUA-06 | `check: icon-matches-target-os` | PASS | info | No desktop or panel icon files in template/; check not applicable | template |
| QUA-06 | | WARN | low | README.md paragraph "The `model_path` YAML default is intentionally empty…" appears twice in succession; the second copy at lines 130–133 is a duplicate of lines 126–129 | README.md:130 |

## Review scope

**Examined:** README.md, manifest.yml, form.yml, submit.yml.erb, template/after.sh, template/before.sh.erb, template/script.sh.erb, template/proxy.py, view.html.erb, form.js (structure), icon.png (presence only); pre-review facts (readme.json, form.json, template.json, security.json, syntax.json); GitHub API (repo metadata, contributors, releases)

**Not examined:** Runtime behavior (Tier 3; no isolated execution environment); form.js functional behavior (JavaScript, no browser environment); OOD session page view.html.erb (structure reviewed; runtime CSRF enforcement not verified); llama.cpp container internals

**Tools:** syntax (bash -n, GNU bash 5.2.21), shellcheck 0.9.0 (ERB-stripped), semgrep 1.178.0, bandit 1.9.4; trivy skipped (no applicable files); catalog skipped by pre-review script

## Catalog checks

- Duplicate check against the existing catalog — no duplicate found. Checked page 1 of the app list (100 apps). Existing LLM-adjacent entries include "AnythingLLM + Ollama" (different software stack) and "Multitenant LLM" (different deployment model); no llama.cpp-specific Batch Connect app is present.
  - **Duplicate-check rationale:** _No duplicate. The app is a dedicated llama.cpp Batch Connect launcher with a custom OOD reverse proxy; it is meaningfully distinct from the catalog's existing LLM entries. Reviewer should confirm this assessment and verify no further pages are needed._
- `software` value matches a catalog Software entry — not applicable; this is an inferred repo (manifest.yml only, no appverse.yml) and carries no `software` field.
- `app_type` and `implementation_tags` are in the catalog vocabularies — not applicable; inferred repos derive their type from the manifest `role` field, not from appverse.yml vocabulary entries. Catalog app-type vocabulary fetched (dashboard, widget, companion_app, batch-connect-basic, batch-connect-VNC) for reference.

## Overall recommendation

**Reject.** The repository has no LICENSE file, a hard gate criterion: the decision rubric explicitly lists "no license" as a Reject trigger. Every other gate criterion passes, and the application is otherwise well-built — documentation is Adequate, portability is Partially portable, the template scripts are syntactically clean, and the security findings are bounded to low/medium severity with no potentially-malicious indicators. The contributor can unblock this review by adding an open-source LICENSE file (MIT is recommended per the Appverse contributor guide) and resubmitting.

---

## Draft feedback — edit before sending

Thank you for submitting **Llama.cpp WebUI** to Appverse. The application is well-documented and the Batch Connect integration is thoughtfully designed. One gate-criterion failure and a few quality items need to be addressed before the app can be listed.

**Required — gate criterion:**

The repository has no `LICENSE` file. An open-source license is required for all Appverse listings; please add one (MIT is recommended). Without it the app cannot be listed regardless of quality.

**Required — input validation targets:**

`form.yml` line 19: `bc_num_hours` has no `min` or `max` bounds. Since the value is parsed as a float in `submit.yml.erb` and passed directly to Slurm's `--time` argument, please add explicit bounds (for example, `min: 0.25` and `max: 48`) to prevent accidental zero-duration or runaway job requests.

`form.yml` line 90: `extra_slurm_args` is a free-text field that reaches the Slurm scheduler as native arguments with no `pattern` constraint. Additionally, `submit.yml.erb` line 18 interpolates each split token directly (`<%= arg %>`) without further sanitisation, so any string typed in the field reaches Slurm verbatim. Consider adding a `pattern` (for example, restricting to flag-style tokens: `^(--[a-zA-Z][a-zA-Z0-9-]+(=[^\s]+)?\s*)*$`) or documenting the field's expected format prominently to reduce the risk of accidental scheduler manipulation.

**Required — error handling:**

`template/script.sh.erb` line 18 uses `set -u` but not `set -e`. A failing command (for example, a `mkdir` failure) will silently continue execution. Please add `set -e` or add explicit error checks for the commands that can fail after the initial validation block.

**Suggested — security:**

`template/proxy.py` lines 212–216: the proxy's `_relay_headers` method echoes whatever `Origin` the browser sends back as `Access-Control-Allow-Origin` and adds `Access-Control-Allow-Credentials: true`. This effectively opens the LLM API to any web page that can reach the OOD rnode endpoint. Consider restricting the reflected origin to the expected OOD hostname, or validating the Origin against a configurable allowlist, to prevent cross-origin access to the running LLM session.

`template/proxy.py` line 52: the proxy defaults to `0.0.0.0`. On shared compute nodes this makes the LLM UI reachable by co-tenants without going through OOD's authentication layer. If the compute environment allows it, consider defaulting to a loopback address or verifying that OOD's node-proxy guarantees are sufficient for your deployment.

`template/after.sh` line 35: `pkill -P ${SCRIPT_PID}` — please double-quote `${SCRIPT_PID}` to follow shellcheck's SC2086 guidance.

**Suggested — portability:**

`template/script.sh.erb` lines 78–79 hardcode the `/gpfs/models/gemma-4-31B-it-GGUF/` path in a `case` pattern (for the mmproj projector) and as a literal path in `MMPROJ_ARGS`. Similarly, line 112 hardcodes `/gpfs/models` as the bind-mount source. A deployer adding models from a different path prefix will need to edit the script directly. Consider exposing the mmproj path as a form.yml attribute or deriving it dynamically from the selected model path.

**Suggested — maintenance:**

The repository has no tagged releases, no CHANGELOG, and no CI workflow. Releases give deployers a clear version reference; a CHANGELOG communicates what changed between updates; and a CI workflow (even a simple YAML-validation check) gives contributors faster feedback. All three are good practice; see the [Appverse Best Practices guide](https://openondemand.connectci.org/appverse-best-practices).

**Suggested — code quality:**

`template/after.sh` line 7 (`WAIT_PORT=120`) and `template/script.sh.erb` lines 59 (`seq 15000 15099`) and 198–199 (`tail -n 30`) are bare numeric literals; a brief inline comment explaining the choice (timeout duration, port-range source, log-line count) makes the values easier to revisit. Similarly, the seven hex-color literals in `template/proxy.py` lines 124–131 (`#101014`, `#e5e5ea`, `#1c1c22`, `#2e2e36`, `#9a9aa3`, `#44444e`) carry no comments explaining the palette.

`template/script.sh.erb` lines 115–116 and 122–124 duplicate the model-directory and mmproj bind-mount logic verbatim for the YOLO and non-YOLO branches. Extracting to a shared `add_model_mounts()` function would reduce the risk of the two branches diverging on future edits.

**Polish:**

README.md lines 130–133: the paragraph beginning "The `model_path` YAML default is intentionally empty" is duplicated from lines 125–128. Please remove the second copy.

`template/script.sh.erb` line 128 uses non-standard mixed quoting (`src="/gpfs/home/$USER",dst="/home/$USER"` inside an unquoted array element); consider quoting the entire argument consistently. (See SC2140.)

<!-- feedback-covers: LICENSE:missing-license, submit.yml.erb:unsanitized-user-input, form.yml:missing-min-max, form.yml:missing-pattern, template/script.sh.erb:no-set-e, template/proxy.py:cors-wildcard, template/proxy.py:bind-all-interfaces, template/after.sh:unquoted-variable, template/script.sh.erb:hardcoded-path, README.md:readme-inconsistency:duplicate-paragraph, template/script.sh.erb:other:mixed-quoting, template/after.sh:magic-number, template/script.sh.erb:magic-number, template/proxy.py:undocumented-hex-color, template/script.sh.erb:duplicated-block -->
