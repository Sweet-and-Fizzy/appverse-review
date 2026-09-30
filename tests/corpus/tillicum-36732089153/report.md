# Appverse Review: tillicum-llama-chat

**Repository:** https://github.com/UWrc/tillicum-llama-chat  **Mode:** reviewer  **Date:** 2026-09-30
**Reviewed commit:** `f7c8d35004b824812d7c552c6dc17d9b7fd98653` (2026-09-09)  **Repo shape:** inferred single app
**Reviewed with:** appverse-review @ 0.7.0 (`c79435b`, https://github.com/Sweet-and-Fizzy/appverse-review) · **Model:** claude-sonnet-4-6 · **Rubric:** https://openondemand.connectci.org/appverse-review-rubric

> _Disclaimer: This is an automated review with human curation. It is provided without warranty of any kind and does not certify the app as secure or fit for any purpose. A listing is not an endorsement._

## Repo-level gate criteria

| Rule | Result | Evidence |
|---|---|---|
| — | PASS | Repository public and accessible (clone succeeded) |
| STR-01 | PASS | README.md — present and substantive (14 939 bytes, detailed architecture, deployment, and troubleshooting) |
| STR-01 | FAIL | LICENSE — no LICENSE file found at repo root |
| — | PASS | Repo not archived |

## Upkeep

| Signal | Value | Assessment |
|---|---|---|
| Last commit | 2026-09-09 | Within 12 months — active |
| Releases | None | No tagged releases |
| Issues responsiveness | Not checked | Catalog query unavailable |
| Contributors | Not checked | git log unavailable |
| CHANGELOG | None | No CHANGELOG.md |
| CI | None | No .github/workflows/ directory |

| Dimension | Level | Evidence |
|---|---|---|
| Upkeep (repo-level) | Medium | Active (2026-09-09) but no releases, CHANGELOG, or CI confirmed |

## App: Llama.cpp WebUI (root)

### Signals

| Dimension | Level | Evidence |
|---|---|---|
| Portability | Medium | Site-specific /gpfs/ paths and cluster 'tillicum' centralized in form.yml; README documents model catalog and deployment |
| Documentation | High | README is substantive but lacks a prerequisites section and a configuration section; cannot reach Adequate |

### Structure

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| STR-02 | `check: str-02-metadata` | PASS | info | Required manifest.yml fields present: name, category, role, description | manifest.yml |
| STR-03 | `check: str-03-yaml-valid` | PASS | info | manifest.yml and form.yml parse without errors; submit.yml.erb ERB tags balanced | manifest.yml, form.yml, submit.yml.erb |
| STR-06 | `check: str-06-syntax` | PASS | info | Template scripts syntactically correct: 3 files pass (template/after.sh, template/before.sh.erb ERB-stripped, template/script.sh.erb ERB-stripped); 0 fail; 0 not checked | template/after.sh, template/before.sh.erb, template/script.sh.erb |
| STR-07 | `check: str-07-layout` | PASS | info | Standard Batch Connect layout: form.yml, submit.yml.erb, and template/script.sh.erb all present | form.yml, submit.yml.erb, template/script.sh.erb |
| STR-04 | `check: str-04-references` | PASS | info | All form attributes referenced in submit.yml.erb and template scripts are defined in form.yml or are OOD auto-fields | submit.yml.erb, template/before.sh.erb, template/script.sh.erb |

### Security

Findings are classified under OODT (Open OnDemand App Threats); codes are defined in the rubric's Security section.

**Check tiers:** Tiers 1–2

Tier 3 not checked — no isolated execution environment.

| Tool | Status | Result |
|---|---|---|
| shellcheck | Run (ERB-stripped) | 22 findings (SC2054, SC2317, SC2148, SC2154, SC2086) |
| semgrep | Run | 0 findings |
| bandit | Run | 3 findings (B110, B104) |
| trivy | Not run (no applicable files) | — |

#### Findings

| Rule | Check | Result | Severity | Tag | Summary | Evidence |
|---|---|---|---|---|---|---|
| OODT-01 | `check: sec-interpolation` | PASS | — | — | auto_accounts OOD auto-field: reaches scheduler as accounting_id YAML value; no shell execution | submit.yml.erb:4 |
| OODT-01 | `check: sec-interpolation` | PASS | — | — | auto_qos OOD auto-field: reaches scheduler as qos YAML value; no shell execution | submit.yml.erb:5 |
| OODT-01 | `check: sec-interpolation` | PASS | — | — | gpu_partition (select): ternary produces only literal integers, no user string reaches native args | submit.yml.erb:9 |
| OODT-01 | `check: sec-interpolation` | PASS | — | — | gpu_partition (select): ternary produces only literal integers | submit.yml.erb:10 |
| OODT-01 | `check: sec-interpolation` | PASS | — | — | gpu_partition (select): values constrained to 'gpu-h200' / 'gpu-h200-mig'; no injection surface | submit.yml.erb:11 |
| OODT-01 | `check: sec-interpolation` | PASS | — | — | bc_num_hours: sanitised via .to_f before reaching native args | submit.yml.erb:12 |
| OODT-01 | `check: sec-interpolation` | WARN | low | unintentional | extra_slurm_args (text_field) split on whitespace and passed as native Slurm args without sanitisation; gated behind enable_advanced_args; self-harm under PUN model | submit.yml.erb:18 |
| OODT-04 | `check: sec-network-call` | PASS | — | — | socket.socket: internal loopback poll waiting for proxy port to open; not an outbound data call | template/after.sh:15 |
| OODT-01 | `check: sec-interpolation` | PASS | — | — | sif_path (hidden_field): admin-managed default, not user-editable; shell-quoted | template/before.sh.erb:23 |
| OODT-01 | `check: sec-interpolation` | PASS | — | — | model_path (select): values constrained to form options | template/before.sh.erb:31 |
| OODT-04 | `check: sec-network-call` | PASS | — | — | http.client import: used by the reverse proxy to forward requests to llama-server on 127.0.0.1; expected proxy behaviour | template/proxy.py:44 |
| OODT-05 | `check: sec-config-flag` | WARN | medium | unintentional | Proxy binds to 0.0.0.0 by default; necessary for OOD /rnode/ routing but accessible to co-users on the compute node without OOD auth if port is known | template/proxy.py:52 |
| OODT-04 | `check: sec-network-call` | PASS | — | — | XMLHttpRequest.prototype.open patch injected into HTML shim: client-side JS rewrite, not a server-side network call | template/proxy.py:94 |
| OODT-04 | `check: sec-network-call` | PASS | — | — | XMLHttpRequest.prototype.open patch (continuation): same shim line | template/proxy.py:95 |
| OODT-04 | `check: sec-network-call` | PASS | — | — | http.client.HTTPConnection: proxy forwarding connection to llama-server; expected | template/proxy.py:345 |
| OODT-04 | `check: sec-network-call` | PASS | — | — | http.client.HTTPException: exception handler for upstream connection; expected | template/proxy.py:355 |
| OODT-01 | `check: sec-interpolation` | PASS | — | — | sif_path (hidden_field): admin-managed, shell-quoted | template/script.sh.erb:21 |
| OODT-01 | `check: sec-interpolation` | PASS | — | — | model_path (select): constrained to form options | template/script.sh.erb:23 |
| OODT-01 | `check: sec-interpolation` | PASS | — | — | temperature (number_field, min=0/max=1) guarded by enable_advanced_args ternary; bounded number only | template/script.sh.erb:25 |
| OODT-01 | `check: sec-interpolation` | PASS | — | — | api_key base64-encoded via Base64.strict_encode64 before embedding; encoding prevents shell special-character injection | template/script.sh.erb:29 |
| OODT-01 | `check: sec-interpolation` | PASS | — | — | $API_KEY_B64: used only inside `printf '%s' "$API_KEY_B64"` with proper double-quoting; no unquoted expansion | template/script.sh.erb:30 |
| OODT-01 | `check: sec-interpolation` | WARN | low | unintentional | extra_llama_args (text_field) passed as unsplit args to llama-server when advanced options enabled; user could inject flags such as `--host 0.0.0.0`; gated, self-harm under PUN model | template/script.sh.erb:31 |
| OODT-01 | `check: sec-interpolation` | PASS | — | — | storage_yolo (check_box): value is "0" or "1" only | template/script.sh.erb:32 |
| OODT-01 | `check: sec-interpolation` | PASS | — | — | storage_home_mount (check_box): value is "0" or "1" only | template/script.sh.erb:33 |
| OODT-01 | `check: sec-interpolation` | PASS | — | — | mount1_source (text_field): used as Apptainer bind-mount source; user can only mount what their Unix credentials permit; add_mount() guards empty values | template/script.sh.erb:34 |
| OODT-01 | `check: sec-interpolation` | PASS | — | — | mount1_dest (text_field): container-internal destination path | template/script.sh.erb:35 |
| OODT-01 | `check: sec-interpolation` | PASS | — | — | mount1_writable (check_box): value is "0" or "1" only | template/script.sh.erb:36 |
| OODT-01 | `check: sec-interpolation` | PASS | — | — | mount2_source: same reasoning as mount1_source | template/script.sh.erb:37 |
| OODT-01 | `check: sec-interpolation` | PASS | — | — | mount2_dest: container-internal destination | template/script.sh.erb:38 |
| OODT-01 | `check: sec-interpolation` | PASS | — | — | mount2_writable: check_box 0/1 | template/script.sh.erb:39 |
| OODT-01 | `check: sec-interpolation` | PASS | — | — | mount3_source: same reasoning as mount1_source | template/script.sh.erb:40 |
| OODT-01 | `check: sec-interpolation` | PASS | — | — | mount3_dest: container-internal destination | template/script.sh.erb:41 |
| OODT-01 | `check: sec-interpolation` | PASS | — | — | mount3_writable: check_box 0/1 | template/script.sh.erb:42 |
| OODT-01 | `check: sec-interpolation` | PASS | — | — | $MODEL_PATH in dirname inside command substitution; model_path is a select field with constrained values | template/script.sh.erb:115 |
| OODT-01 | `check: sec-interpolation` | PASS | — | — | $MODEL_PATH in dirname (non-YOLO branch): same reasoning | template/script.sh.erb:122 |
| OODT-01 | `check: sec-interpolation` | PASS | — | — | $API_KEY: used only in `[ -n "$API_KEY" ]` length test and `${#API_KEY}` count; not echoed directly | template/script.sh.erb:157 |

#### Additional observations (review)

| Rule | Result | Severity | Tag | Summary | Evidence |
|---|---|---|---|---|---|
| OODT-08 | WARN | low | unintentional | Comment claims llama-server network isolation is provided by `--offline` flag, but no `--offline` argument is passed in the apptainer invocation; without it llama-server can make outbound network requests; not listed by security.json | template/script.sh.erb:91-97 |

No tool-detectable issues in the checked tiers.

**Capability profile (Batch Connect):**

| Capability | Present | Notes |
|---|---|---|
| Apptainer container execution | Yes | `apptainer run --nv` with GPU allocation |
| Outbound network from container | Yes | Container inherits compute-node network; --offline not passed despite comment at line 91 |
| Reverse proxy (0.0.0.0) | Yes | Python proxy on OOD-routed port; binds all interfaces for OOD routing |
| File reads from compute node | Yes | Model SIF and GGUF bind-mounted read-only; user-controlled selective mounts |
| Writable user-controlled bind mounts | Yes | mount*_writable options when YOLO=0 |
| Home directory mount | Yes | Optional via storage_home_mount |
| Broad /gpfs mount (YOLO mode) | Yes | Default (storage_yolo defaults to "1") |
| LLM tool use (filesystem/shell) | Yes | `--tools all` passed; README notes trusted-user scope |
| Background processes | Yes | llama-server, proxy, watchdog subshells |
| Binary in template/ | No | — |
| Writes to dotfiles / cron / SSH keys | No | — |
| Credential strings in code | No | api_key is configurable, not hardcoded |

### Portability
- Rating: Partially portable — site-specific paths (/gpfs/ prefix, cluster 'tillicum', partition names) and model GGUF paths are centralized in form.yml and documented in the README's defaults table; template also contains /gpfs/ paths for the mmproj case statement and base models mount

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Site-specific /gpfs/ paths hardcoded in template: mmproj path in case statement, /gpfs/models base mount, and /gpfs/home/$USER in home mount | template/script.sh.erb:79,112,128 |
| QUA-02 | | WARN | low | Cluster name 'tillicum', SIF container path (/gpfs/containers/), and all nine model GGUF paths (/gpfs/models/) hardcoded in form.yml; a deployer must update every option before deploying | form.yml:2,25,36-44 |
| QUA-02 | `check: portability-rating` | PASS | info | Partially portable — site-specific values in form.yml attributes (documented); README explains how to add models and deploy | form.yml:2,25,35-44 |

### Documentation
- Rating: Minimal — not supported (stub README; see QUA-01)
- Evidence per rung:
  what it launches: "Llama.cpp WebUI — Open OnDemand Application", README.md:3 (intro);
  prerequisites: none (no prerequisites heading; prerequisites content is embedded in Current defaults and Deployment sections);
  installation: "Deployment", README.md:271;
  configuration: none (no configuration section; deployer must find paths in form.yml);
  known limitations: none;
  troubleshooting: "Troubleshooting", README.md:345;
  screenshots: none;
  environment variables: README.md:284,329 (LLAMA_PROXY_PY phrase, PROXY_DEBUG assignment);
  info panel: none;
  architecture: "Architecture", README.md:34

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| QUA-01 | `check: documentation-rating` | FAIL | high | Minimal — not supported (prerequisites heading absent; formal rung cannot be completed); README is substantive but deployer cannot reach Adequate without a prerequisites section; target is Adequate | README.md:1 |

### Code Quality

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| QUA-03 | `check: error-handling` | WARN | low | template/script.sh.erb uses `set -u` but no `set -e`; a failed command does not abort the job automatically; before.sh.erb and after.sh have explicit error checks | template/script.sh.erb:18 |
| QUA-07 | `check: numeric-field-bounds` | PASS | info | auto_qos is an OOD auto-field (widget=null); populated by OOD framework; no numeric min/max needed | form.yml:5 |
| QUA-07 | `check: numeric-field-bounds` | WARN | low | bc_num_hours has no min or max; empty value → .to_f → 0 → `--time=0:00`; Slurm would reject a zero-hour request | form.yml:19 |
| QUA-07 | `check: numeric-field-bounds` | WARN | low | extra_slurm_args (text_field, reaches_scheduler=true) has no pattern constraint; user can pass arbitrary Slurm flags | form.yml:90 |
| QUA-08 | `check: magic-numbers` | WARN | low | 120-second proxy wait timeout undocumented (WAIT_PORT=120) | template/after.sh:7 |
| QUA-08 | `check: magic-numbers` | WARN | low | Port-scan fallback range 15000–15099 and watchdog tail -n 30 are undocumented magic numbers | template/script.sh.erb:59,198,199 |
| QUA-08 | `check: magic-numbers` | PASS | info | Hex color literals in loading-page CSS are UI colors for the bundled loading page, not tunable parameters | template/proxy.py:124,126,129,130,131 |
| QUA-09 | `check: duplicated-blocks` | WARN | low | Identical bind-mount block for MODEL_PATH and MMPROJ_ARGS appears in both the YOLO branch (lines 115–118) and the non-YOLO branch (lines 122–125); could be extracted to a helper | template/script.sh.erb:115-118 |
| QUA-04 | `check: dead-code` | PASS | info | template.json detected no commented-out code blocks; a commented-out --network none block at lines 98–100 is accompanied by an explanatory comment and is not dead code per se | template/script.sh.erb:98-100 |
| QUA-10 | `check: erb-missing-value` | PASS | info | auto_qos at submit.yml.erb:5 is an OOD auto-field, always populated by framework; no missing-value concern | submit.yml.erb:5 |
| QUA-10 | `check: erb-missing-value` | PASS | info | gpu_partition at submit.yml.erb:9 uses a ternary with only literal integer constants; no missing-value scenario | submit.yml.erb:9 |
| QUA-10 | `check: erb-missing-value` | PASS | info | extra_slurm_args at submit.yml.erb:14 guarded by `unless extra_slurm_args.empty?`; presence checked before use | submit.yml.erb:14 |
| QUA-10 | `check: erb-missing-value` | WARN | low | bc_num_hours is interpolated without a presence check; an empty value yields `bc_num_hours.to_f` → 0, producing `--time=0:00` which Slurm would likely reject | submit.yml.erb:12 |
| QUA-06 | `check: icon-matches-target-os` | NOT CHECKED | info | No desktop or panel icons found in template/; icon.png at root is the OOD app icon and is not subject to this check | icon.png |
| QUA-06 | | WARN | info | README.md contains a duplicate paragraph about model_path YAML default (lines 125–128 repeated verbatim at lines 130–133) | README.md:125,130 |
| QUA-04 | | WARN | info | Commented-out `--network none` block at script.sh.erb:98–100 accompanied by comment claiming --offline is used instead, but --offline is absent from the actual invocation (see also OODT-08 additional observation) | template/script.sh.erb:98-100 |

## Review scope

**Examined:** README.md, manifest.yml, form.yml, submit.yml.erb, view.html.erb, form.js (surface scan), template/before.sh.erb, template/script.sh.erb, template/after.sh, template/proxy.py; pre-review fact files (readme.json, form.json, template.json, security.json, syntax.json); tool outputs (shellcheck, semgrep, bandit)

**Not examined:** Runtime behaviour (Tier 3 not checked — no isolated execution environment); git commit history (git log unavailable in this session); GitHub issues; catalog duplicate query (network access to connectci.org unavailable)

**Tools:** syntax (bash -n, 3 files), shellcheck (22 findings), semgrep (0 findings), bandit (3 findings), trivy (not run — no applicable files)

## Catalog checks

- Duplicate check against the existing catalog — NOT CHECKED (network access to openondemand.connectci.org unavailable in this review environment)
  - **Duplicate-check rationale:** _LLM inference web-UI apps for OOD are an emerging category. The reviewer should query the catalog for existing llama.cpp or llama-server apps before approving. If a similar app exists, assess whether this one offers a meaningfully different approach (e.g., different container base, MIG GPU support, different model catalog management). The Tillicum-specific defaults are not themselves a reason to reject if the approach is novel._
- `software` value matches a catalog Software entry — NOT APPLICABLE (inferred repo; no appverse.yml; no `software` field)
- `app_type` and `implementation_tags` are in the catalog vocabularies — NOT APPLICABLE (inferred repo; role `batch_connect` in manifest.yml is a known OOD role)

## Overall recommendation

**Request changes.** The app has no LICENSE file, which is a hard gate criterion for catalog listing. All other aspects are sound: the README is detailed (architecture, troubleshooting, model catalog management), the Batch Connect layout is correct, all shell scripts pass syntax checking, security findings are low-to-medium severity and either intentional (advanced user fields) or architectural (0.0.0.0 proxy binding required for OOD routing), and the repo is active. Once a license is added, the remaining issues — documentation below Adequate (missing prerequisites and configuration sections) and portability improvements (the /gpfs/ paths in form.yml and template/ need updating at every new site) — put this in "Accept with suggestions" territory, conditional on the catalog duplicate check passing. This assessment is also conditional on the catalog duplicate and software-entry checks noted above, which could not be performed.

---

## Draft feedback — edit before sending

Thank you for submitting **Llama.cpp WebUI** to Appverse. The app is well-documented in several areas (architecture, llama-server invocation, troubleshooting) and the Batch Connect structure is correct. There are two required changes and several suggestions.

**Required — blocks listing:**

1. **Add an open-source license.** No LICENSE file was found at the repo root. An open-source license (MIT is recommended) is required before the app can appear in the catalog. Add `LICENSE` at the root.

2. **Add a Prerequisites section to README.md.** The `README.md` pre-review scan found no prerequisites heading; without it the formal documentation rung is a stub and the rating cannot reach Minimal. A deployer at another site needs to know what must be in place before cloning: at minimum, the llama.cpp Apptainer SIF path, GGUF model files, Python 3, and compute nodes with GPU access. A dedicated "Prerequisites" (or "Requirements") heading would make this immediately visible and allow the documentation to reach Minimal (and with a configuration section, Adequate).

**Suggested — documentation (target is Adequate):**

3. **Add a Configuration section.** The app targets the `tillicum` cluster with /gpfs/ paths throughout `form.yml` (line 2: cluster name, line 25: SIF path, lines 36–44: model GGUF paths) and `template/script.sh.erb` (lines 79, 112, 128). A deployer needs a checklist of every value to change. Even a short table — cluster name, SIF path, model paths, partition names — would raise the documentation to Adequate.

**Suggested — security (medium):**

4. **Note the 0.0.0.0 proxy binding.** `template/proxy.py` line 52 binds to `0.0.0.0` by default (LISTEN_HOST). This is required for OOD /rnode/ routing and therefore architectural, but the port is reachable by co-users on the same compute node without OOD authentication if the port number is known. Consider documenting this trade-off in the README for deployers who share nodes.

**Suggested — security (low):**

5. **Guard `extra_slurm_args` before passing to the scheduler.** In `submit.yml.erb` (line 18), the `extra_slurm_args` field is split on whitespace and forwarded as native Slurm arguments without sanitisation. The field is gated behind an advanced-args checkbox, so the risk is self-harm under the PUN model, but adding a pattern constraint (e.g., `pattern: '^[\w=,\-\s]*$'`) in `form.yml` line 90 would limit the surface. Also consider adding `missing-pattern` validation.

6. **Guard `extra_llama_args` before passing to llama-server.** In `template/script.sh.erb` (line 31), `extra_llama_args` is forwarded as unsplit arguments to llama-server when advanced options are enabled. A user could inject flags such as `--host 0.0.0.0`. The field is gated and self-harm under the PUN model, but documenting the trust boundary or adding a pattern constraint would reduce the surface.

7. **Add or remove `--offline` from the llama-server invocation.** `template/script.sh.erb` lines 91–97 include a comment saying network isolation is provided by llama.cpp's `--offline` flag, but the flag is not passed to `apptainer run`. Either pass `--offline` to prevent the server from making outbound network calls, or remove the comment to avoid misleading future maintainers.

**Suggested — portability:**

8. **Extract site-specific paths to configuration.** The cluster name `tillicum` is hardcoded at `form.yml` line 2. SIF container path (`/gpfs/containers/`, form.yml line 25) and all nine model GGUF paths (`/gpfs/models/`, form.yml lines 36–44) are hardcoded in the form. Site-specific `/gpfs/` paths also appear in `template/script.sh.erb` at lines 79, 112, and 128. Consider a deployment-time configuration file or environment variable so adopters can adapt the app without editing every option individually.

**Suggested — code quality:**

9. **Add `set -e` to `template/script.sh.erb`.** The script uses `set -u` (line 18) but not `set -e`, so a failed command does not abort the job. Consider adding `set -eo pipefail` at the top, or adding explicit `|| exit 1` guards on critical commands.

10. **Add `min` and `max` to `bc_num_hours` in `form.yml`.** The field (line 19) has no bounds. An empty or zero value produces `--time=0:00` (line 12 of `submit.yml.erb`), which Slurm would reject. Setting `min: 1` and a reasonable `max` (e.g., `max: 48`) avoids a confusing scheduler error. Similarly, `extra_slurm_args` in `form.yml` line 90 has no pattern constraint; a pattern would limit the flags users can pass.

11. **Add a presence check for `bc_num_hours` in `submit.yml.erb`.** At line 12, `bc_num_hours` is interpolated without checking for an empty value. An empty form submission yields `bc_num_hours.to_f` → 0 → `--time=0:00`, which Slurm would reject with a confusing error. A guard such as `bc_num_hours.presence || "1"` prevents this.

12. **Document magic numbers.** The fallback port-scan range 15000–15099 (template/script.sh.erb line 59) and the 120-second proxy wait (template/after.sh line 7) are undocumented literals; a brief inline comment explaining the choice and rationale would help future maintainers.

13. **Extract the duplicated bind-mount block in `template/script.sh.erb`.** The bind-mount block for MODEL_PATH and MMPROJ_ARGS at lines 115–118 is duplicated verbatim at lines 122–125 for the YOLO vs non-YOLO branches. Extracting to a shell function would eliminate the duplication.

14. **Duplicate paragraph in README.md.** The paragraph beginning "The `model_path` YAML default is intentionally empty…" appears twice consecutively (lines 125–128 and 130–133). Remove the duplicate.

<!-- feedback-covers: LICENSE:missing-license, README.md:docs-stub, submit.yml.erb:unsanitized-user-input, template/script.sh.erb:unsanitized-user-input, template/proxy.py:bind-all-interfaces, template/script.sh.erb:other:missing-offline-control, form.yml:hardcoded-cluster, form.yml:hardcoded-path, template/script.sh.erb:hardcoded-path, template/script.sh.erb:no-set-e, form.yml:missing-min-max, form.yml:missing-pattern, submit.yml.erb:erb-missing-value-unhandled, template/after.sh:magic-number, template/script.sh.erb:magic-number, template/script.sh.erb:duplicated-block, README.md:readme-inconsistency:model-path-description -->

```json
[
  {
    "app_id": "root",
    "rule": "STR-01",
    "defect_key": "README.md:missing-readme",
    "aspect": "structure",
    "severity": "info",
    "result": "PASS",
    "summary": "README.md present and substantive (14939 bytes)",
    "evidence": "README.md"
  },
  {
    "app_id": "root",
    "rule": "STR-01",
    "defect_key": "LICENSE:missing-license",
    "aspect": "structure",
    "severity": "high",
    "result": "FAIL",
    "summary": "No LICENSE file found; open-source license required for catalog listing",
    "evidence": "LICENSE"
  },
  {
    "app_id": "root",
    "rule": "STR-02",
    "defect_key": "manifest.yml:missing-field:description",
    "aspect": "structure",
    "severity": "info",
    "result": "PASS",
    "summary": "Required manifest.yml fields present: name, category, role, description",
    "evidence": "manifest.yml"
  },
  {
    "app_id": "root",
    "rule": "STR-03",
    "defect_key": "manifest.yml:yaml-parse-error",
    "aspect": "structure",
    "severity": "info",
    "result": "PASS",
    "summary": "manifest.yml, form.yml, and submit.yml.erb parse without errors",
    "evidence": "manifest.yml, form.yml, submit.yml.erb"
  },
  {
    "app_id": "root",
    "rule": "STR-06",
    "defect_key": "template/after.sh:bash-syntax-error",
    "aspect": "structure",
    "severity": "info",
    "result": "PASS",
    "summary": "bash -n passes",
    "evidence": "template/after.sh"
  },
  {
    "app_id": "root",
    "rule": "STR-06",
    "defect_key": "template/before.sh.erb:bash-syntax-error",
    "aspect": "structure",
    "severity": "info",
    "result": "PASS",
    "summary": "bash -n passes (ERB-stripped)",
    "evidence": "template/before.sh.erb"
  },
  {
    "app_id": "root",
    "rule": "STR-06",
    "defect_key": "template/script.sh.erb:bash-syntax-error",
    "aspect": "structure",
    "severity": "info",
    "result": "PASS",
    "summary": "bash -n passes (ERB-stripped)",
    "evidence": "template/script.sh.erb"
  },
  {
    "app_id": "root",
    "rule": "STR-07",
    "defect_key": "submit.yml.erb:missing-submit-yml",
    "aspect": "structure",
    "severity": "info",
    "result": "PASS",
    "summary": "Standard Batch Connect layout present: form.yml, submit.yml.erb, template/script.sh.erb all found",
    "evidence": "form.yml, submit.yml.erb, template/script.sh.erb"
  },
  {
    "app_id": "root",
    "rule": "STR-04",
    "defect_key": "submit.yml.erb:form-submit-mismatch",
    "aspect": "structure",
    "severity": "info",
    "result": "PASS",
    "summary": "All form attributes referenced in submit.yml.erb and template scripts are defined in form.yml or are OOD auto-fields",
    "evidence": "submit.yml.erb, template/before.sh.erb, template/script.sh.erb"
  },
  {
    "app_id": "root",
    "rule": "OODT-01",
    "defect_key": "submit.yml.erb:unsanitized-user-input",
    "aspect": "security",
    "severity": "low",
    "result": "WARN",
    "tag": "unintentional",
    "summary": "extra_slurm_args (text_field) split on whitespace and passed as native Slurm args without sanitisation; gated behind advanced-args checkbox; self-harm under PUN model",
    "evidence": "submit.yml.erb:18; reviewed OK: submit.yml.erb:4,5,9,10,11,12",
    "line": 18
  },
  {
    "app_id": "root",
    "rule": "OODT-01",
    "defect_key": "template/before.sh.erb:unsanitized-user-input",
    "aspect": "security",
    "severity": "info",
    "result": "PASS",
    "tag": "—",
    "summary": "sif_path is admin-managed hidden field; model_path is a constrained select — no injection surface",
    "evidence": "reviewed OK: template/before.sh.erb:23,31"
  },
  {
    "app_id": "root",
    "rule": "OODT-01",
    "defect_key": "template/script.sh.erb:unsanitized-user-input",
    "aspect": "security",
    "severity": "low",
    "result": "WARN",
    "tag": "unintentional",
    "summary": "extra_llama_args (text_field) passed as unsplit args to llama-server when advanced options enabled; user could inject flags (e.g. --host 0.0.0.0); gated, self-harm under PUN model",
    "evidence": "template/script.sh.erb:31; reviewed OK: template/script.sh.erb:21,23,25,29,32,33,34,35,36,37,38,39,40,41,42,115,122,157",
    "line": 31
  },
  {
    "app_id": "root",
    "rule": "OODT-01",
    "defect_key": "template/script.sh.erb:unquoted-variable",
    "aspect": "security",
    "severity": "info",
    "result": "PASS",
    "tag": "—",
    "summary": "API_KEY_B64 is inside printf double-quotes; MODEL_PATH is select-constrained; API_KEY used only in length test",
    "evidence": "reviewed OK: template/script.sh.erb:30,115,122,157"
  },
  {
    "app_id": "root",
    "rule": "OODT-04",
    "defect_key": "template/after.sh:unexpected-network-call",
    "aspect": "security",
    "severity": "info",
    "result": "PASS",
    "tag": "—",
    "summary": "socket.socket: internal loopback poll for proxy port readiness; expected session-wait behaviour",
    "evidence": "reviewed OK: template/after.sh:15"
  },
  {
    "app_id": "root",
    "rule": "OODT-04",
    "defect_key": "template/proxy.py:unexpected-network-call",
    "aspect": "security",
    "severity": "info",
    "result": "PASS",
    "tag": "—",
    "summary": "All http.client and XMLHttpRequest references are the reverse proxy's own forwarding operations to llama-server or JS-shim rewrites; expected proxy behaviour",
    "evidence": "reviewed OK: template/proxy.py:44,94,95,345,355"
  },
  {
    "app_id": "root",
    "rule": "OODT-05",
    "defect_key": "template/proxy.py:bind-all-interfaces",
    "aspect": "security",
    "severity": "medium",
    "result": "WARN",
    "tag": "unintentional",
    "summary": "Proxy binds to 0.0.0.0 by default (LISTEN_HOST); necessary for OOD /rnode/ routing but accessible to co-users on the compute node without OOD auth if port is known",
    "evidence": "template/proxy.py:52",
    "line": 52
  },
  {
    "app_id": "root",
    "rule": "OODT-08",
    "defect_key": "template/script.sh.erb:other:missing-offline-control",
    "aspect": "security",
    "severity": "low",
    "result": "WARN",
    "tag": "unintentional",
    "summary": "Comment at lines 91–97 claims llama-server network isolation uses --offline flag, but no --offline is passed to apptainer; without it llama-server can make outbound network calls; not listed by security.json",
    "evidence": "template/script.sh.erb:91-97",
    "line": 91
  },
  {
    "app_id": "root",
    "rule": "QUA-02",
    "defect_key": "template/script.sh.erb:hardcoded-path",
    "aspect": "quality",
    "severity": "low",
    "result": "WARN",
    "summary": "Site-specific /gpfs/ paths hardcoded in template: mmproj path in case statement, /gpfs/models base bind mount, and /gpfs/home/$USER in home mount (template.json candidate at line 128 is the /home/ dst; the site-specific src is at the same line)",
    "evidence": "template/script.sh.erb:79,112,128"
  },
  {
    "app_id": "root",
    "rule": "QUA-02",
    "defect_key": "form.yml:hardcoded-path",
    "aspect": "quality",
    "severity": "low",
    "result": "WARN",
    "summary": "SIF container path (/gpfs/containers/) and all nine model GGUF paths (/gpfs/models/) hardcoded in form.yml hidden field and select options; deployer must update every entry",
    "evidence": "form.yml:25,36-44"
  },
  {
    "app_id": "root",
    "rule": "QUA-02",
    "defect_key": "form.yml:hardcoded-cluster",
    "aspect": "quality",
    "severity": "low",
    "result": "WARN",
    "summary": "Cluster name 'tillicum' hardcoded at form.yml top level; must be changed for any other site",
    "evidence": "form.yml:2"
  },
  {
    "app_id": "root",
    "rule": "QUA-02",
    "defect_key": "form.yml:other:portability-rating",
    "aspect": "quality",
    "severity": "info",
    "result": "PASS",
    "summary": "Partially portable — site-specific values centralized in form.yml attributes; README documents model catalog and deployment process",
    "evidence": "form.yml:2,25,35-44"
  },
  {
    "app_id": "root",
    "rule": "QUA-01",
    "defect_key": "README.md:docs-stub",
    "aspect": "quality",
    "severity": "high",
    "result": "FAIL",
    "summary": "Documentation not formally rated: prerequisites rung absent (no prerequisites heading); formal rung system cannot reach Minimal; README is substantive and passes STR-01 but lacks the sections a deployer needs",
    "evidence": "README.md:1"
  },
  {
    "app_id": "root",
    "rule": "QUA-03",
    "defect_key": "template/script.sh.erb:no-set-e",
    "aspect": "quality",
    "severity": "low",
    "result": "WARN",
    "summary": "script.sh.erb uses set -u but not set -e; a failed command does not abort the job",
    "evidence": "template/script.sh.erb:18"
  },
  {
    "app_id": "root",
    "rule": "QUA-07",
    "defect_key": "form.yml:missing-min-max",
    "aspect": "quality",
    "severity": "low",
    "result": "WARN",
    "summary": "bc_num_hours has no min or max; empty value → to_f → 0 → --time=0:00 in submit.yml.erb; auto_qos (OOD auto-field) does not require numeric bounds",
    "evidence": "form.yml:19; reviewed OK: form.yml:5"
  },
  {
    "app_id": "root",
    "rule": "QUA-07",
    "defect_key": "form.yml:missing-pattern",
    "aspect": "quality",
    "severity": "low",
    "result": "WARN",
    "summary": "extra_slurm_args (text_field, reaches_scheduler=true) has no pattern constraint; user can pass arbitrary Slurm flags",
    "evidence": "form.yml:90"
  },
  {
    "app_id": "root",
    "rule": "QUA-08",
    "defect_key": "template/after.sh:magic-number",
    "aspect": "quality",
    "severity": "low",
    "result": "WARN",
    "summary": "120-second proxy wait timeout undocumented (WAIT_PORT=120)",
    "evidence": "template/after.sh:7"
  },
  {
    "app_id": "root",
    "rule": "QUA-08",
    "defect_key": "template/script.sh.erb:magic-number",
    "aspect": "quality",
    "severity": "low",
    "result": "WARN",
    "summary": "Port-scan fallback range 15000-15099 and watchdog tail -n 30 are undocumented magic numbers",
    "evidence": "template/script.sh.erb:59,198,199"
  },
  {
    "app_id": "root",
    "rule": "QUA-08",
    "defect_key": "template/proxy.py:undocumented-hex-color",
    "aspect": "quality",
    "severity": "info",
    "result": "PASS",
    "summary": "Hex color literals in loading-page CSS are UI colors for the bundled loading page, not tunable parameters",
    "evidence": "reviewed OK: template/proxy.py:124,126,129,130,131"
  },
  {
    "app_id": "root",
    "rule": "QUA-09",
    "defect_key": "template/script.sh.erb:duplicated-block",
    "aspect": "quality",
    "severity": "low",
    "result": "WARN",
    "summary": "Identical bind-mount block for MODEL_PATH and MMPROJ_ARGS duplicated in YOLO branch (lines 115-118) and non-YOLO branch (lines 122-125)",
    "evidence": "template/script.sh.erb:115-118"
  },
  {
    "app_id": "root",
    "rule": "QUA-04",
    "defect_key": "template/script.sh.erb:commented-out-code",
    "aspect": "quality",
    "severity": "info",
    "result": "WARN",
    "summary": "Commented-out --network none block at lines 98-100; --offline claim in accompanying comment is inaccurate (see OODT-08 finding)",
    "evidence": "template/script.sh.erb:98-100"
  },
  {
    "app_id": "root",
    "rule": "QUA-10",
    "defect_key": "submit.yml.erb:erb-missing-value-unhandled",
    "aspect": "quality",
    "severity": "low",
    "result": "WARN",
    "summary": "bc_num_hours interpolated without presence check; empty value yields --time=0:00; auto_qos (OOD auto-field), gpu_partition (guarded ternary), and extra_slurm_args (empty? guard) all handled",
    "evidence": "submit.yml.erb:12; reviewed OK: submit.yml.erb:5,9,14"
  },
  {
    "app_id": "root",
    "rule": "QUA-06",
    "defect_key": "icon.png:icon-os-mismatch",
    "aspect": "quality",
    "severity": "info",
    "result": "NOT CHECKED",
    "summary": "No desktop or panel icons in template/; icon.png at root is the OOD app icon, not subject to this check",
    "evidence": "icon.png"
  },
  {
    "app_id": "root",
    "rule": "QUA-06",
    "defect_key": "README.md:readme-inconsistency:model-path-description",
    "aspect": "quality",
    "severity": "info",
    "result": "WARN",
    "summary": "Duplicate paragraph about model_path YAML default appears at lines 125–128 and 130–133 verbatim",
    "evidence": "README.md:125,130"
  },
  {
    "app_id": "root",
    "rule": "MNT-01",
    "defect_key": "commits:stale-repo",
    "aspect": "maintenance",
    "severity": "info",
    "result": "PASS",
    "summary": "Last commit 2026-09-09, within 12 months; repo is active",
    "evidence": "commits"
  },
  {
    "app_id": "root",
    "rule": "MNT-02",
    "defect_key": "releases:no-releases",
    "aspect": "maintenance",
    "severity": "info",
    "result": "WARN",
    "summary": "No tagged releases found",
    "evidence": "releases"
  },
  {
    "app_id": "root",
    "rule": "MNT-03",
    "defect_key": "CHANGELOG.md:no-changelog",
    "aspect": "maintenance",
    "severity": "info",
    "result": "WARN",
    "summary": "No CHANGELOG.md found",
    "evidence": "CHANGELOG.md"
  },
  {
    "app_id": "root",
    "rule": "MNT-04",
    "defect_key": ".github/workflows:no-ci",
    "aspect": "maintenance",
    "severity": "info",
    "result": "WARN",
    "summary": "No CI workflow found (.github/workflows/ absent)",
    "evidence": ".github/workflows"
  },
  {
    "app_id": "root",
    "rule": "MNT-05",
    "defect_key": "contributors:single-contributor",
    "aspect": "maintenance",
    "severity": "info",
    "result": "NOT CHECKED",
    "summary": "Contributor count not checked; git log unavailable in this review session",
    "evidence": "contributors"
  },
  {
    "app_id": "root",
    "rule": "MNT-06",
    "defect_key": "issues:unresponsive-issues",
    "aspect": "maintenance",
    "severity": "info",
    "result": "NOT CHECKED",
    "summary": "Issue responsiveness not checked; catalog query unavailable",
    "evidence": "issues"
  }
]
```
