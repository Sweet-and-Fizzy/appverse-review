# Appverse Review: ood-sas

**Repository:** https://github.com/fasrc/ood-sas  **Mode:** reviewer  **Date:** 2026-09-30
**Reviewed commit:** `462790a1fdd1616038ea3536454a4e508c668471` (2026-07-08)  **Repo shape:** inferred single app
**Reviewed with:** appverse-review @ 0.8.0 (`0987de4`, https://github.com/Sweet-and-Fizzy/appverse-review) · **Model:** claude-sonnet-4-6 · **Rubric:** https://openondemand.connectci.org/appverse-review-rubric

> _Disclaimer: This is an automated review with human curation. It is provided without warranty of any kind and does not certify the app as secure or fit for any purpose. A listing is not an endorsement._

## Repo-level gate criteria

| Rule | Result | Evidence |
|---|---|---|
| — | PASS | Repository public and accessible (clone succeeded) |
| STR-01 | PASS | README.md — present and substantive (235 lines, 4 593 chars of content) |
| STR-01 | PASS | LICENSE.txt — MIT License present |
| — | NOT CHECKED | Repo not archived — `gh` unavailable; recent commit (2026-07-08) suggests active |

## Upkeep

| Signal | Value | Assessment |
|---|---|---|
| Last commit | 2026-07-08 | Within 12 months |
| Releases | No tagged releases found | MNT-02 WARN |
| Issues responsiveness | Not assessed | not read by design |
| Contributors | Not assessed | not read by design |
| CHANGELOG | Present but describes OSC MATLAB app, not SAS | MNT-03 WARN |
| CI | No `.github/workflows/` directory | MNT-04 WARN |

| Dimension | Level | Evidence |
|---|---|---|
| Upkeep (repo-level) | Medium | active within 12 months; no confirmed good-practice signals (no releases, CI absent, CHANGELOG wrong app) |

## App: SAS (.)

### Signals

| Dimension | Level | Evidence |
|---|---|---|
| Portability | Medium | `/scratch/` hardcoded in script; cluster name and module documented as site-specific |
| Documentation | Medium | Adequate — what it launches, prerequisites, installation, configuration, known limitations all present; troubleshooting placeholder |

### Structure

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| STR-02 | `check: str-02-metadata` | PASS | — | Required metadata fields — name, category, role, description all present | manifest.yml |
| STR-03 | `check: str-03-yaml-valid` | PASS | — | YAML validity — manifest.yml and form.yml parse without errors (duplicate YAML keys in form.yml are valid YAML, last-wins; see Code Quality) | manifest.yml; form.yml |
| STR-06 | `check: str-06-syntax` | PASS | — | Template scripts syntactically correct: 2 files pass; 0 fail; 0 not checked | template/before.sh.erb; template/script.sh.erb |
| STR-07 | `check: str-07-layout` | PASS | — | Standard OOD structure — form.yml, submit.yml.erb, template/script.sh.erb all present | form.yml; submit.yml.erb; template/script.sh.erb |
| STR-04 | `check: str-04-references` | PASS | — | No broken references — all attributes used in submit.yml.erb and template/ are defined in form.yml | submit.yml.erb; template/script.sh.erb |

### Security

Findings are classified under OODT (Open OnDemand App Threats); codes are defined in the rubric's Security section at https://openondemand.connectci.org/appverse-review-rubric#security.

**Check tiers:** Tiers 1–2

Tier 3 not checked — no isolated execution environment.

| Tool | Status | Result |
|---|---|---|
| shellcheck | Run (ERB-stripped) | 5 findings (SC2086, SC2148, SC2164), 1 of them linted in isolation from the job-script family |
| semgrep | Run | 0 findings |
| bandit | Not run (no applicable files) | — |
| trivy | Not run (no applicable files) | — |

#### Findings

| Rule | Check | Result | Severity | Tag | Summary | Evidence |
|---|---|---|---|---|---|---|
| OODT-01 | `check: sec-interpolation` | WARN | low | unintentional | `custom_reservation` (text_field) and `custom_email_address` (text_field) interpolated unquoted into YAML reservation_id/email with no sanitiser; `custom_time` (text_field) and `extra_slurm` (text_field) reach native Slurm args with no sanitiser or shellescape; number_field guard (.to_i) and presence checks acceptable on sanitised candidates | submit.yml.erb:6,7,10,17; reviewed OK: submit.yml.erb:9,11,13 |
| OODT-01 | `check: sec-interpolation` | WARN | low | unintentional | `sas_version` (select) interpolated unquoted in `module load` — select constrains values but no shellescape; echo-only uses acceptable | template/script.sh.erb:64; reviewed OK: template/script.sh.erb:11,12 |
| OODT-01 | `check: sec-eval-exec` | PASS | — | — | `eval exec $COMMAND` — COMMAND is a hardcoded string set at line 61, not user-controlled | template/script.sh.erb:72 |
| OODT-08 | `check: sec-config-flag` | WARN | low | unintentional | `set -x` shell tracing enabled in three places; trace output goes to the job's own output.log, world-readable only if the job directory is | template/script.sh.erb:19,44,54 |
| STR-06 | `check: sec-tool-finding` | PASS | — | — | SC2148 (missing shebang) on before.sh.erb — artefact of linting OOD job-script files one at a time | template/before.sh.erb:1 |
| OODT-01 | `check: sec-tool-finding` | WARN | info | unintentional | SC2086: Double quote to prevent globbing and word splitting — $WORKDIR and $COMMAND are unquoted; $WORKDIR set from non-user environment variables, low practical risk | template/script.sh.erb:22,25,72 |
| QUA-03 | `check: sec-tool-finding` | WARN | low | unintentional | SC2164: `cd $WORKDIR` at line 25 without `|| exit`; if mkdir or cd fails the script continues in the wrong directory | template/script.sh.erb:25 |

#### Additional observations (review)

| Rule | Result | Severity | Tag | Summary | Evidence |
|---|---|---|---|---|---|
| OODT-07 | PASS | — | — | `echo 1000 > /proc/self/oom_score_adj` writes to /proc filesystem but only to the process's own OOM score; not persistent beyond the job; documented in README as intentional OOM management; not listed by security.json | template/script.sh.erb:69,71 |

**Capability profile (Batch Connect):**

| Capability | Present | Assessment |
|---|---|---|
| Lmod module load (`module purge`, `module load`) | Yes | Expected |
| TurboVNC / Xfce window manager | Yes | Expected (turbovnc template) |
| Working directory creation under `/scratch/` | Yes | Site-specific path, documented |
| OOM score adjustment via `/proc/self/oom_score_adj` | Yes | Intentional, self-only, documented |
| Shell tracing (`set -x`) | Yes | Persists in job output.log only |
| No outbound network calls in ERB | — | Expected |
| No binary files in template/ | — | Expected |
| No credential strings | — | Expected |

### Portability
- Rating: Partially portable — `/scratch/` hardcoded in script (undocumented); cluster name `odyssey3` and SAS module `sas/9.4-fasrc01` documented as site-specific values

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| QUA-02 | `check: hardcoded-site-paths` | WARN | medium | `/scratch/` hardcoded in WORKDIR assignment; not mentioned in README configuration table as needing to be changed | template/script.sh.erb:21 |
| QUA-02 | `check: portability-rating` | PASS | — | Partially portable — main configuration in form.yml attributes documented in README; one undocumented hardcoded path (`/scratch/`) | template/script.sh.erb:21 |

### Documentation
- Rating: Adequate — what it launches, prerequisites, installation, configuration, and known limitations all have evidence; troubleshooting section is a template placeholder
- Evidence per rung:
  what it launches: "Appverse overview", README.md:21; prerequisites: "Requirements", README.md:63; installation: "App Installation", README.md:84; configuration: "2. Configure for your site", README.md:99; known limitations: "Known Limitations", README.md:196; troubleshooting: none (placeholder); screenshots: "Screenshots", README.md:37; environment variables: none; info panel: none; architecture: none

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| QUA-01 | `check: documentation-rating` | PASS | — | Adequate — meets target; troubleshooting placeholder prevents Strong | README.md:21 |

### Code Quality

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| QUA-03 | `check: error-handling` | FAIL | low | No `set -e` in script.sh.erb; script continues on errors including failed module loads and working directory issues | template/script.sh.erb |
| QUA-07 | `check: numeric-field-bounds` | FAIL | low | `custom_memory_per_node` (number_field) has min=4 but no max; `custom_num_cores` (number_field) has min=1 but no max; `custom_num_gpus` PASS (min=0, max=8) | form.yml:30,38; reviewed OK: form.yml:47 |
| QUA-07 | `check: numeric-field-bounds` | FAIL | low | `custom_time`, `custom_email_address`, `custom_reservation` (text_fields reaching scheduler) have no `pattern` constraint | form.yml:15,27,65 |
| QUA-07 | `check: numeric-field-bounds` | WARN | low | `extra_slurm` (text_field reaching scheduler) has no `pattern` — intentionally unrestricted by design; a pattern would limit its purpose | form.yml:72 |
| QUA-08 | `check: magic-numbers` | WARN | info | Hex color `#D3D3D3` used in `xsetroot` call without a comment explaining the value | template/script.sh.erb:46 |
| QUA-09 | `check: duplicated-blocks` | PASS | — | No large duplicated code blocks | template/script.sh.erb; template/before.sh.erb |
| QUA-04 | `check: dead-code` | WARN | low | Large blocks of commented-out Singularity container launch code left in script (lines 33–57 heredoc scaffold, lines 78–94 singularity exec invocation) | template/script.sh.erb:33,39,78 |
| QUA-10 | `check: erb-missing-value` | PASS | — | All interpolated fields have either presence checks, OOD-enforced defaults, or are optional fields that produce acceptable empty YAML values when blank | submit.yml.erb:6,7,9,10,11,12,15 |
| QUA-06 | `check: icon-matches-target-os` | WARN | info | Panel icon `fedora-logo-icon` references a Fedora-specific icon; app is documented as tested on Rocky 8.10 | template/config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml:40 |
| QUA-05 | | WARN | low | CHANGELOG.md contains content from OSC's `bc_osc_matlab` app (all entries describe MATLAB versions; diff links point to `github.com/OSC/bc_osc_matlab`) | CHANGELOG.md:9 |
| QUA-06 | | WARN | low | `sas_version` help text says "Loading the Matlab module for requested version" — should reference SAS | form.yml:61 |
| QUA-06 | | WARN | low | README configuration table says cluster is `odyssey` but form.yml sets `cluster: "odyssey3"` | README.md:115 |
| QUA-06 | | WARN | low | Duplicate `help:` key in `custom_num_cores` attribute — last-wins, first entry ("Number of Cpus to allocate") is silently discarded | form.yml:44 |
| QUA-06 | | WARN | low | Duplicate `help:` key in `custom_num_gpus` attribute — last-wins, first entry ("Number of GPUs to allocate. Available only on GPU enabled partitions") is silently discarded | form.yml:54 |
| QUA-06 | | WARN | low | README typos: "notificationl" (line 125), "`forml.yml`" (line 136), "Univesity" (line 234) | README.md:125,136,234 |

## Review scope

**Examined:** manifest.yml, form.yml, submit.yml.erb, template/script.sh.erb, template/before.sh.erb, template/config/ (xfce4-panel.xml, terminalrc, menus/xfce-applications.menu), README.md, LICENSE.txt, CHANGELOG.md; pre-review security candidates (10 interpolation, 1 eval-exec, 3 config-flag, 3 tool-finding); shellcheck and semgrep outputs

**Not examined:** Runtime behaviour (Tier 3 not checked — no isolated execution environment); GitHub releases, contributors, and issue responsiveness (`gh` unavailable); `.github/` absent so no CI workflow to examine

**Tools:** syntax (bash -n, 2 files); shellcheck (0.9.0, 2 files ERB-stripped, 5 findings); semgrep (1.178.0, 12 files, 0 findings); bandit skipped (no applicable files); trivy skipped (no applicable files)

## Catalog checks

- Duplicate check against the existing catalog — No SAS app found. Read pages 1–2 of the app list (~116 apps total); no entry titled "SAS" or close variant present.
  - **Duplicate-check rationale:** _No existing SAS app in the catalog. This submission is the first SAS application; no duplicate or near-duplicate was found across both pages of the published app list._
- `software` value — not applicable for inferred repo (manifest.yml only; no `software` field). A Software entry titled "SAS" exists in the catalog (UUID cfb88e77-2fa2-4dca-b8f2-6eaa568d8cb5), available for use if/when an `appverse.yml` is added.
- `app_type` and `implementation_tags` are in the catalog vocabularies — not applicable for inferred repo (no `appverse.yml`).

## Overall recommendation

**Accept with suggestions.** All gate criteria pass: README.md is substantive, LICENSE.txt (MIT) is present, manifest.yml includes the required name/category/role/description fields, and the standard Batch Connect layout (form.yml, submit.yml.erb, template/script.sh.erb) is in place with all scripts syntactically valid. Documentation is Adequate and portability is Partially portable, both at or above the inclusion thresholds. Security findings are low severity and unintentional — unquoted text-field interpolations in submit.yml.erb and a select field used unquoted in `module load` are addressable without design changes. The primary improvement areas are: `set -e` is missing from script.sh.erb (code quality target); numeric fields `custom_memory_per_node` and `custom_num_cores` lack a `max` bound, and several text fields reaching the scheduler lack `pattern` constraints (code quality target); CHANGELOG.md carries content copied from OSC's MATLAB app with no SAS-specific history; and the `sas_version` help text incorrectly references "Matlab." These are fixable suggestions. The app is conditional on the duplicate check, which found no existing SAS app (pages 1–2 of the catalog, ~116 apps).

---

## Draft feedback — edit before sending

Thank you for submitting the SAS Open OnDemand app to Appverse. The app has a solid structure and good documentation. Here are the items to address before listing:

**Unquoted form-field interpolations in submit.yml.erb** (suggested): `submit.yml.erb` interpolates `custom_reservation` (line 6), `custom_email_address` (line 7), `custom_time` (line 10), and tokens from `extra_slurm` (line 17) into scheduler arguments without sanitisation. These values go through OOD's YAML-to-scheduler pipeline rather than a direct shell, so the practical risk is low, but adding `.shellescape` (or `.to_i`/`.to_f` for numeric values) where applicable would improve robustness against unexpected input.

**Unquoted select interpolation and debug tracing in template/script.sh.erb** (suggested): `context.sas_version` at line 64 of `template/script.sh.erb` is expanded unquoted in `module load` with no shellescape — if OOD does not validate select values server-side, a crafted request could inject shell content. Wrapping with `shellescape` is low effort. Additionally, `set -x` shell tracing is permanently enabled at lines 19, 44, and 54, writing all expanded command text to the job's output.log; this is helpful for debugging but exposes environment and command details — consider limiting tracing to a bounded debug section or removing it for production deployments.

**Error handling** (suggested): `template/script.sh.erb` has no `set -e`, so the script silently continues if `mkdir -p $WORKDIR` or `cd $WORKDIR` fail (line 21–25 of script.sh.erb). Adding `set -e` near the top would make failures visible; alternatively, add explicit `|| exit 1` guards on the `mkdir` and `cd` lines. See the [Appverse Best Practices guide](https://openondemand.connectci.org/appverse-best-practices) for error-handling recommendations.

**Input validation on form fields** (suggested): Two numeric fields in `form.yml` are missing a `max` bound — `custom_memory_per_node` (line 30, has `min: 4` but no `max`) and `custom_num_cores` (line 38, has `min: 1` but no `max`). Adding reasonable upper limits prevents users from accidentally requesting very large allocations. Additionally, three text fields that reach the scheduler — `custom_time` (line 15), `custom_email_address` (line 27), and `custom_reservation` (line 65) — have no `pattern` attribute. Adding a regex pattern (e.g., a time format pattern for `custom_time`) helps catch format errors before job submission.

**Wrong CHANGELOG** (suggested): `CHANGELOG.md` was copied from the OSC MATLAB app (`bc_osc_matlab`) and contains only MATLAB version history; all version links point to `github.com/OSC/bc_osc_matlab`. Please replace the content with SAS-specific history, or start fresh with an `[Unreleased]` section.

**Wrong help text** (suggested): The `sas_version` attribute in `form.yml` (line 61) has `help: | Loading the Matlab module for requested version`. This should reference SAS, not Matlab.

**README cluster inconsistency** (suggested): The README configuration table at line 115 says the cluster is `odyssey`, but `form.yml` (line 3) sets `cluster: "odyssey3"`. Please update one to match the other.

**Commented-out dead code** (suggested): `template/script.sh.erb` contains large blocks of commented-out Singularity container code (lines 33–57 and 78–94). If this approach is no longer in use, removing the dead code will make the script easier to understand for deployers.

**Hardcoded scratch path** (suggested): `template/script.sh.erb` line 21 sets `WORKDIR=/scratch/$USER/$SLURM_JOBID`. Not all sites have `/scratch/`; consider adding a note in the README configuration table that this path may need to be adjusted, or making it a form attribute with a configurable default.

**Troubleshooting section** (suggested): The Troubleshooting section in README.md still contains template placeholder text ("`module load software/1.0`", "`YOUR-APP`", "`which xfwm4`"). Please replace with SAS-specific troubleshooting steps.

**Minor typos** (suggested): README.md has "notificationl" (line 125, should be "notification"), "`forml.yml`" (line 136, should be "`form.yml`"), and "Univesity" (line 234, should be "University"). Also, `form.yml` has duplicate `help:` keys in `custom_num_cores` (lines 44–45) and `custom_num_gpus` (lines 54–55); the first `help` value is silently discarded by YAML parsers.

<!-- feedback-covers: submit.yml.erb:unsanitized-user-input, template/script.sh.erb:unsanitized-user-input, template/script.sh.erb:debug-tracing-enabled, template/script.sh.erb:no-set-e, template/script.sh.erb:no-error-check, form.yml:missing-min-max, form.yml:missing-pattern, CHANGELOG.md:wrong-app-changelog, form.yml:wrong-help-text, README.md:readme-inconsistency:cluster, template/script.sh.erb:commented-out-code, template/script.sh.erb:hardcoded-path, README.md:readme-typo, form.yml:duplicate-yaml-key:custom_num_cores.help, form.yml:duplicate-yaml-key:custom_num_gpus.help -->
