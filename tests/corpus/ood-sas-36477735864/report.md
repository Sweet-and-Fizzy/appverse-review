# Appverse Review: ood-sas

**Repository:** https://github.com/fasrc/ood-sas  **Mode:** reviewer  **Date:** 2026-09-28
**Reviewed commit:** `462790a1fdd1616038ea3536454a4e508c668471` (2026-07-08)  **Repo shape:** inferred single app
**Reviewed with:** appverse-review @ 0.4.0 (`e548bfa`, https://github.com/Sweet-and-Fizzy/appverse-review) · **Model:** claude-sonnet-4-6 · **Rubric:** https://openondemand.connectci.org/appverse-review-rubric

> _Disclaimer: This is an automated review with human curation. It is provided without warranty of any kind and does not certify the app as secure or fit for any purpose. A listing is not an endorsement._

## Repo-level gate criteria

| Rule | Result | Evidence |
|---|---|---|
| — | PASS | Repository public and accessible — clone succeeded |
| STR-01 | PASS | README.md — substantive; contains overview, requirements, installation, configuration, troubleshooting, and screenshots |
| STR-01 | PASS | LICENSE.txt — MIT license present |
| STR-01 | PASS | manifest.yml — repo shape identifiable (inferred single app) |
| — | PASS | Repo not archived — confirmed via GitHub API |

## Upkeep

| Signal | Value | Assessment |
|---|---|---|
| Last commit | 2026-07-08 | Good sign — within 12 months |
| Releases | 0 | Concern — no tagged releases |
| Issues responsiveness | 0 open issues | Neutral — nothing to respond to |
| Contributors | 4 | Good sign — multiple contributors |
| CHANGELOG | Present but wrong-app content (bc_osc_matlab) | Concern — not current for this app |
| CI | None (.github/workflows absent) | Concern — no CI |

| Dimension | Level | Evidence |
|---|---|---|
| Upkeep (repo-level) | Medium | Active within 12 months; one good-practice signal (multiple contributors); no releases, no valid CHANGELOG, no CI |

## App: SAS (root)

### Signals

| Dimension | Level | Evidence |
|---|---|---|
| Security | Low | No OODT findings; Tier 1–2 reviewed; Batch Connect app with narrow, expected capability profile |
| Portability | Medium | Partially portable — cluster name and module version documented in README config table; `/scratch` working-directory path in script.sh.erb not documented |
| Documentation | Low | Strong — overview, prerequisites, installation, configuration table, troubleshooting, screenshots, known limitations all present |

### Structure

| Rule | Result | Severity | Summary | Evidence |
|---|---|---|---|---|
| STR-02 | PASS | — | Required metadata fields (name, category, role, description) | manifest.yml:1–8 |
| STR-03 | PASS | — | YAML validity — manifest.yml and form.yml parse without errors (duplicate `help:` keys are YAML-valid last-wins, reported under QUA-06) | form.yml, manifest.yml |
| STR-07 | PASS | — | Standard BC layout — form.yml, submit.yml.erb, template/ all present | form.yml:1, submit.yml.erb:1, template/ |
| STR-04 | PASS | — | No broken references — all variables in submit.yml.erb and script.sh.erb are defined in form.yml | submit.yml.erb, template/script.sh.erb |

### Security

Findings are classified under OODT (Open OnDemand App Threats); codes are defined in the [rubric's Security section](https://openondemand.connectci.org/appverse-review-rubric).

**Check tiers:** Tiers 1–2
Tier 3 not checked — no isolated execution environment.

| Tool | Status | Result |
|---|---|---|
| shellcheck | ran | 4 style findings (SC2086 ×3, SC2164 ×1, SC2143 ×1) — no security issues; see Code Quality |
| semgrep | ran | no applicable rules triggered on ERB/YAML |
| bandit | ran | no applicable files (no Python source) |
| trivy | not installed | — |

**Capability profile (Batch Connect):**

| File | Capabilities | Anomalies |
|---|---|---|
| form.yml | Defines form fields including dropdown select for SAS module version; free-text fields for time, email, reservation, extra Slurm options | None |
| submit.yml.erb | Maps form fields to Slurm native args; splits extra_slurm on whitespace to pass as separate args | None — documented pass-through feature |
| template/before.sh.erb | Conditionally exports the Lmod `module` shell function | None |
| template/script.sh.erb | Loads SAS Lmod module (from select dropdown), launches TurboVNC/Xfce session (xfwm4, xfce4-panel, xfce4-terminal), adjusts OOM score via `/proc/self/oom_score_adj`, uses `eval exec` on hardcoded COMMAND string | `eval exec $COMMAND` at line 72; COMMAND is hardcoded (no user input path); low risk — noted under Code Quality |

No outbound network calls in ERB files. No credential strings. No SSH-key reads. No cron or persistence writes. No binary files in template/. Module version comes from a single-option dropdown select — no injection vector. The `extra_slurm` field is an explicitly documented advanced pass-through to sbatch native options; within the PUN model, any consequence is self-harm to the submitting user's own allocation.

#### Findings

No OODT security findings.

### Portability

- Rating: **Partially portable** — cluster name (`odyssey3`) and SAS module version (`sas/9.4-fasrc01`) are hardcoded in form.yml but documented in the README configuration table with "Change to" instructions; the working-directory path `/scratch/$USER/$SLURM_JOBID` (template/script.sh.erb:21) is hardcoded and not mentioned in the README configuration table.

| Rule | Result | Severity | Summary | Evidence |
|---|---|---|---|---|
| QUA-02 | WARN | low | `/scratch/$USER/$SLURM_JOBID` hardcoded as WORKDIR; `/scratch` is site-specific and not listed in the README configuration table | template/script.sh.erb:21 |

### Documentation

- Rating: **Strong** — answers all four deployer questions: what it launches (Appverse overview section, line 27), what must be installed (Requirements section, line 65–75), how to deploy (App Installation section, line 84–99), what to customize (Configure section, line 99–151 with full configuration table). Also includes troubleshooting (line 159–172), screenshots (line 39–48), testing table (line 180–187), and known limitations (line 200–201). No info panel or architecture explanation, so Exemplary is not met.
- Evidence per rung:
  - what it launches: "SAS is an Open OnDemand Batch Connect app that launches SAS as an interactive desktop session on HPC clusters" — README.md:27
  - prerequisites: Requirements section lists SAS Lmod module, Xfce 4+, Lmod, TurboVNC 2.1+, websockify 0.8+, OOD v3+, Slurm — README.md:65–75
  - installation: App Installation section — clone, configure, verify — README.md:84–99
  - configuration: Full table of all form.yml attributes with FASRC settings and "Change to" column — README.md:99–151
  - known limitations: "Multi-node jobs are not supported; Only tested on Centos 7 and Rocky 8" — README.md:200–201
  - troubleshooting: Three common issues with steps — README.md:159–172
  - screenshots: Two screenshots (sas_desktop.png, sas_plot_example.png) — README.md:39–48
  - environment variables: none user-facing to document — N/A
  - info panel: none
  - architecture: none

No QUA-01 findings — the README configuration table explicitly marks site-specific values and instructs what to change.

### Code Quality

| Check | Rule | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| Error handling in scripts | QUA-03 | FAIL | low | No `set -e` or explicit exit-on-error in template/script.sh.erb; shellcheck SC2164 also flags `cd $WORKDIR` with no fallback | template/script.sh.erb:1 (no set -e), :25 (cd without \|\| exit) |
| Input validation on form fields | QUA-07 | FAIL | low | `custom_num_cores` (number_field) has `min: 1` but no `max`; `custom_memory_per_node` (number_field) has `min: 4` but no `max` | form.yml:38–46, form.yml:31–36 |
| Input validation — text field reaching scheduler | QUA-07 | WARN | low | `custom_time` (text_field) reaches `--time=` in sbatch native args with no `pattern:` constraint; malformed strings cause job rejection | form.yml:15–20 |
| Magic numbers / undocumented literals | QUA-08 | WARN | info | OOM score value `1000` at line 69 is the Linux max OOM score; purpose is explained in the surrounding comment but the value itself is undocumented inline | template/script.sh.erb:69 |
| Duplicated code blocks | QUA-09 | PASS | — | No large duplicated code blocks found | — |
| Commented-out dead code | QUA-04 | WARN | low | Large block of commented-out heredoc and Singularity execution code (lines 34–57 and 83–94); deploy-era scaffolding left in place | template/script.sh.erb:34 |
| ERB handles missing/empty values | QUA-10 | PASS | — | submit.yml.erb guards numeric fields with `.blank? ? default : value.to_s`; extra_slurm guarded by `unless .blank?`; OOD BC framework handles empty reservation_id and email | submit.yml.erb:9–11, :15 |
| Desktop/panel icon matches target OS | QUA-06 | NOT CHECKED | — | No desktop or panel icon configuration found in template/ | — |
| Duplicate `help:` key — custom_num_cores | QUA-06 | WARN | low | Two `help:` keys in custom_num_cores block; YAML last-wins silently discards the first (`"Number of Cpus to allocate"`) | form.yml:44–45 |
| Duplicate `help:` key — custom_num_gpus | QUA-06 | WARN | low | Two `help:` keys in custom_num_gpus block; YAML last-wins silently discards the first (`"Number of GPUs to allocate. Available only on GPU enabled partitions"`) | form.yml:54–55 |
| Copy-paste artifact — sas_version help text | QUA-05 | WARN | low | `sas_version` help text reads "Loading the Matlab module for requested version" — references MATLAB, copied from a MATLAB app | form.yml:61 |
| Copy-paste artifact — CHANGELOG | QUA-05 | WARN | low | CHANGELOG.md is the full changelog from OSC/bc_osc_matlab: all entries describe MATLAB versions, all version-comparison links point to github.com/OSC/bc_osc_matlab | CHANGELOG.md:1 |
| README typo | QUA-06 | WARN | info | "forml.yml" in the submit.yml.erb configuration table should be "form.yml" | README.md:136 |
| README inconsistency — cluster value | QUA-06 | WARN | info | README configuration table lists FASRC cluster setting as `odyssey`; form.yml has `odyssey3` | README.md:113 (cf. form.yml:3) |

## Review scope

**Examined:** manifest.yml, form.yml, submit.yml.erb, template/script.sh.erb, template/before.sh.erb, README.md, LICENSE.txt, CHANGELOG.md, icon.png (filename only), images/ (filenames only). Static analysis via shellcheck on ERB-stripped script.sh.erb; semgrep and bandit (no applicable files). GitHub API: repo metadata, release count, contributor count, open issues.

**Not examined:** Runtime behavior (Tier 3 — no isolated execution environment). `icon.png` binary content not audited.

## Catalog checks

- Duplicate check against the existing catalog — **PASS** — No app titled "SAS" or "Statistical Analysis System" found in the 100-app catalog listing queried via public JSON:API.
  - **Duplicate-check rationale:** _The catalog contains apps for other statistical/scientific tools (Stata, SageMath, R/RStudio, MATLAB) but no SAS app. fasrc/ood-sas is not a duplicate. If the reviewer is aware of a SAS app submitted outside the listed catalog entries, verify separately._
- `software` value matches a catalog Software entry — **NOT CHECKED** — Inferred repo (manifest.yml only; no `software` field). Not applicable.
- `app_type` and `implementation_tags` are in the catalog vocabularies — **NOT CHECKED** — Inferred repo (no appverse.yml). Not applicable.

## Overall recommendation

**Accept with suggestions** (pending human confirmation of the duplicate check). All structural gate criteria pass: README.md is substantive, MIT license is present, manifest.yml is valid with all required fields, and the Batch Connect layout is correct. The security posture is clean — no OODT findings, no anomalous capabilities, and the module version comes from a locked dropdown. Documentation is Strong. Portability is Partially portable (meets the target for inclusion). The repo is active within 12 months with 4 contributors. The main improvement areas are: (1) missing `set -e` and missing `|| exit` after `cd` in the job script — targets for inclusion that prevent silent failures if the working directory cannot be created; (2) missing `max` bounds on the `custom_num_cores` and `custom_memory_per_node` number fields; (3) copy-paste artifacts carried over from an OSC MATLAB app — the CHANGELOG.md describes MATLAB releases and links to OSC/bc_osc_matlab, and the `sas_version` help text still reads "Loading the Matlab module for requested version"; and (4) two duplicate YAML `help:` keys (last-wins semantics silently discard one). None of these are gate-criterion failures, but they should be addressed before the app reaches a wide deployer audience.

---

## Draft feedback — edit before sending

Thank you for submitting ood-sas to Appverse. The app has a clean security profile, strong documentation, and meets all structural gate criteria. Before the listing goes live, please address the following items. Line numbers refer to commit `462790a`.

**Error handling in template/script.sh.erb (line 1, line 25):** The job script does not use `set -e`, so failures in early steps (e.g., `mkdir -p $WORKDIR` or `module load`) are silently ignored and the job continues in an unexpected state. Add `set -e` near the top of the script (after the `set -x` line is fine), and change the `cd $WORKDIR` on line 25 to `cd "$WORKDIR" || exit 1` so a missing working directory exits loudly rather than running SAS in the wrong location. See the [Appverse Best Practices guide](https://openondemand.connectci.org/appverse-best-practices) for script error-handling recommendations.

**Missing `max` on number fields and missing `pattern` on text fields in form.yml:** `custom_num_cores` (lines 38–46) has `min: 1` but no `max`, and `custom_memory_per_node` (lines 31–36) has `min: 4` but no `max`. Without upper bounds, a user can request an arbitrarily large number of cores or gigabytes of memory, which may cause confusing Slurm errors or waste cluster resources. Add `max:` values appropriate for your largest expected workload (e.g., `max: 64` for cores, `max: 256` for memory). Also, `custom_time` (line 15) is a text_field whose value is passed directly to `--time=` in sbatch with no `pattern:` constraint; a malformed time string will cause the job to be rejected at submission. Adding `pattern: '^\d+:\d+(:\d+)?$'` (or similar) would catch common mistakes before the job reaches the scheduler.

**Copy-paste artifacts from a MATLAB app — please replace with SAS-appropriate content:**
- `CHANGELOG.md` (line 1): The entire changelog describes MATLAB versions from OSC's bc_osc_matlab app; version-comparison links point to `github.com/OSC/bc_osc_matlab`. Please replace with a changelog that describes this SAS app's own history, or start a fresh changelog with an initial entry for the first Appverse release.
- `form.yml` line 61: The `sas_version` attribute's `help:` text reads "Loading the Matlab module for requested version". Change it to describe the SAS module, e.g., "SAS module to load on the compute node".

**Duplicate `help:` keys in form.yml (lines 44–45 and 54–55):** Both `custom_num_cores` and `custom_num_gpus` have two `help:` keys. YAML parsers silently keep the last one, discarding the first. Remove the first `help:` line from each attribute (lines 44 and 54 respectively) and keep only the multi-line `*sbatch …*` format.

**Minor documentation fixes:**
- README.md line 136: "forml.yml" → "form.yml" (typo in the `submit.yml.erb` configuration table).
- README.md line 113: The configuration table says the FASRC `cluster` setting is `odyssey`, but form.yml line 3 has `odyssey3`. Update the README to match the actual value.

**Portability suggestion (template/script.sh.erb, line 21):** The working-directory path `/scratch/$USER/$SLURM_JOBID` is site-specific (not all clusters have a `/scratch` filesystem). Consider adding a note in the README's configuration table pointing deployers to this line, or making the path configurable via a form attribute.

**Suggestions (no action required for listing):**
- The large block of commented-out heredoc and Singularity code in template/script.sh.erb (lines 34–57 and 83–94) is deploy-era scaffolding that is no longer needed. Removing it would make the script easier to read.
- Adding tagged releases on GitHub and a CI workflow that lints the YAML and validates shell scripts would improve long-term confidence in the app.

<!-- feedback-covers: template/script.sh.erb:no-set-e, form.yml:missing-min-max, form.yml:other:missing-pattern, CHANGELOG.md:wrong-app-changelog, CHANGELOG.md:no-changelog, form.yml:wrong-app-reference, form.yml:duplicate-yaml-key:custom_num_cores.help, form.yml:duplicate-yaml-key:custom_num_gpus.help, README.md:readme-typo, README.md:readme-inconsistency:cluster, template/script.sh.erb:hardcoded-path, template/script.sh.erb:commented-out-code -->
