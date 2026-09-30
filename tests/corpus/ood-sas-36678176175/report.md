# Appverse Review: ood-sas

**Repository:** https://github.com/fasrc/ood-sas  **Mode:** reviewer  **Date:** 2026-09-30
**Reviewed commit:** `462790a1fdd1616038ea3536454a4e508c668471` (2026-07-08)  **Repo shape:** inferred single app
**Reviewed with:** appverse-review @ 0.7.0 (`e167db4`, https://github.com/Sweet-and-Fizzy/appverse-review) · **Model:** claude-sonnet-4-6 · **Rubric:** https://openondemand.connectci.org/appverse-review-rubric

> _Disclaimer: This is an automated review with human curation. It is provided without warranty of any kind and does not certify the app as secure or fit for any purpose. A listing is not an endorsement._

## Repo-level gate criteria

| Rule | Result | Evidence |
|---|---|---|
| — | PASS | Repository public and accessible (clone succeeded, commit reviewed) |
| STR-01 | PASS | README.md — present and substantive; SAS-specific content, screenshots, configuration table |
| STR-01 | PASS | LICENSE — LICENSE.txt present (MIT, copyright Ohio Supercomputer Center / FAS-RC Harvard) |
| — | NOT CHECKED | Repo not archived — GitHub API unavailable; recent commit (2026-07-08) indicates active |

## Upkeep

| Signal | Value | Assessment |
|---|---|---|
| Last commit | 2026-07-08 | Within 12 months |
| Releases | None found | No git tags present |
| Issues responsiveness | Not checked | GitHub API unavailable |
| Contributors | Not checked | GitHub API unavailable |
| CHANGELOG | Present (CHANGELOG.md) but describes a MATLAB app (bc_osc_matlab), not SAS | Content is a copy-paste artifact; links point to github.com/OSC/bc_osc_matlab |
| CI | None | No .github/workflows directory |

| Dimension | Level | Evidence |
|---|---|---|
| Upkeep (repo-level) | Medium | Active (last commit 2026-07-08); no releases, no CI, CHANGELOG describes wrong app |

## App: SAS (.)

### Signals

| Dimension | Level | Evidence |
|---|---|---|
| Portability | Medium | /scratch/ path hardcoded in script; cluster and module documented in README config table |
| Documentation | Medium | Installation, configuration, and known limitations present; troubleshooting section is placeholder text |

### Structure

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| STR-02 | `check: str-02-metadata` | PASS | info | Required manifest.yml fields present: name, category, role, description | manifest.yml:1-10 |
| STR-03 | `check: str-03-yaml-valid` | PASS | info | manifest.yml and form.yml parse as valid YAML; no errors | manifest.yml:1, form.yml:1 |
| STR-06 | `check: str-06-syntax` | PASS | info | Template scripts syntactically correct: 2 files pass; 0 fail (bash -n, ERB-stripped) | template/before.sh.erb, template/script.sh.erb |
| STR-07 | `check: str-07-layout` | PASS | info | Standard Batch Connect layout: form.yml, submit.yml.erb, and template/ all present | form.yml:1, submit.yml.erb:1, template/script.sh.erb:1 |
| STR-04 | `check: str-04-references` | PASS | info | All attributes referenced in submit.yml.erb and template/ are defined in form.yml | submit.yml.erb:6-18 |

### Security

Findings are classified under OODT (Open OnDemand App Threats); codes are defined in the rubric's Security section.

**Check tiers:** Tiers 1–2

Tier 3 not checked — no isolated execution environment.

| Tool | Status | Result |
|---|---|---|
| shellcheck | Run (ERB-stripped) | 5 findings (SC2086, SC2148, SC2164) |
| semgrep | Run | 0 findings |
| bandit | Not run (no applicable files) | — |
| trivy | Not run (no applicable files) | — |

#### Findings

| Rule | Check | Result | Severity | Tag | Summary | Evidence |
|---|---|---|---|---|---|---|
| OODT-01 | `check: sec-interpolation` | WARN | low | unintentional | text_field values (custom_reservation, custom_email_address, custom_time) interpolated without sanitisation into scheduler fields; unquoted in YAML; under PUN model self-harm only | submit.yml.erb:6,7,10; reviewed OK: submit.yml.erb:9,11,13,17 |
| OODT-01 | `check: sec-interpolation` | PASS | — | — | select widget (sas_version) and number_field (custom_num_gpus) interpolations in echo statements; select restricts to predefined values; echo output not executed | reviewed OK: template/script.sh.erb:11,12,64 |
| OODT-01 | `check: sec-eval-exec` | PASS | — | — | `eval exec $COMMAND` at line 72; COMMAND is a static string set at line 61, not derived from user input | reviewed OK: template/script.sh.erb:72 |
| OODT-08 | `check: sec-config-flag` | WARN | info | unintentional | `set -x` shell tracing enabled in three places; trace output goes to job's output.log in user-owned ondemand directory; not inherently world-readable | template/script.sh.erb:19,44,54 |

#### Additional observations (review)

| Rule | Result | Severity | Tag | Summary | Evidence |
|---|---|---|---|---|---|
| OODT-01 | PASS | — | — | `extra_slurm` Slurm option passthrough: split on whitespace and passed as individual native items; intentional design documented in help text; not listed by security.json as a concern | submit.yml.erb:15-18 |

No tool-detectable issues in the checked tiers.

**Capability profile (Batch Connect):**

| Capability | Expected | Result |
|---|---|---|
| Net::HTTP / open-uri in ERB | Never | Not found |
| Outbound curl/wget in template | Rare in script | Not found |
| Shell init file writes | Never | Not found |
| Credential file access | Never | Not found |
| Binary files in template/ | Very rare | Not found |
| Other users' files | Never | Not found |

The app launches an Xfce desktop with TurboVNC, loads a SAS Lmod module, creates a scratch working directory, and runs `xfce4-terminal` to launch the SAS GUI. This profile is within the expected range for a Batch Connect VNC desktop app.

### Portability
- Rating: **Partially portable** — site-specific values (cluster name, queue name, SAS module) are documented in the README configuration table; `/scratch/` path in the job script is undocumented and may not exist at other sites.

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| QUA-02 | `check: hardcoded-site-paths` | WARN | medium | `/scratch/` path hardcoded in job script; other sites may use a different scratch mount point | template/script.sh.erb:21 |
| QUA-02 | `check: portability-rating` | PASS | info | Partially portable — cluster, partition, and module documented in README config table; above the partially-portable threshold | README.md:108-129 |

### Documentation
- Rating: **Adequate** — installation, configuration, and known limitations are documented; troubleshooting section consists of placeholder text (not app-specific); no environment variable documentation.
- Evidence per rung:
  - what it launches: "Appverse overview", README.md:21
  - prerequisites: "Requirements", README.md:63
  - installation: "App Installation", README.md:84
  - configuration: "2. Configure for your site", README.md:99
  - known limitations: "Known Limitations", README.md:196
  - troubleshooting: "Troubleshooting", README.md:159 — placeholder (generic template text, not app-specific)
  - screenshots: "Screenshots", README.md:37 — two images present (sas_desktop.png, sas_plot_example.png)
  - environment variables: none
  - info panel: none
  - architecture: none

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| QUA-01 | `check: documentation-rating` | PASS | info | Adequate — installation and configuration documented; troubleshooting is placeholder; above the Adequate threshold | README.md:84,99,196 |

### Code Quality

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| QUA-03 | `check: error-handling` | WARN | low | Neither script uses `set -e`; `cd` without `\|\| exit` (SC2164 at line 25); silent failure on directory change or module load | template/script.sh.erb:19, template/before.sh.erb:1 |
| QUA-07 | `check: numeric-field-bounds` | WARN | low | custom_memory_per_node and custom_num_cores have `min` but no `max`; custom_time, custom_email_address, and custom_reservation are text_fields reaching the scheduler with no `pattern` | form.yml:30,38; form.yml:15,27,65; reviewed OK: form.yml:47,72 |
| QUA-08 | `check: magic-numbers` | WARN | info | Hex colour `#D3D3D3` used for desktop background without a comment explaining the choice | template/script.sh.erb:46 |
| QUA-09 | `check: duplicated-blocks` | PASS | info | No large duplicated code blocks found | template/script.sh.erb:1 |
| QUA-04 | `check: dead-code` | WARN | low | Large blocks of commented-out code: a heredoc block (lines 33–42) and a Singularity invocation block (lines 78–94); 26 commented lines total | template/script.sh.erb:33,39,78 |
| QUA-10 | `check: erb-missing-value` | WARN | low | custom_reservation (line 6) and custom_email_address (line 7) are optional fields interpolated without a blank? guard; other interpolations are guarded (PASS) | submit.yml.erb:6,7; reviewed OK: submit.yml.erb:9,10,11,12,15 |
| QUA-06 | `check: icon-matches-target-os` | WARN | low | `fedora-logo-icon` used for the Xfce applications menu button; README documents Rocky 8.10 as the tested OS; Fedora icon does not match | template/config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml:40 |
| QUA-05 | | WARN | medium | CHANGELOG.md is a verbatim copy from bc_osc_matlab (OSC MATLAB app): entries reference MATLAB versions, and all diff links point to github.com/OSC/bc_osc_matlab | CHANGELOG.md:10-62 |
| QUA-06 | | WARN | low | sas_version widget help text reads "Loading the Matlab module for requested version" — wrong application reference | form.yml:61 |
| QUA-06 | | WARN | low | Duplicate YAML key `help` under custom_num_cores; last-wins silently drops the first value | form.yml:44,45 |
| QUA-06 | | WARN | low | Duplicate YAML key `help` under custom_num_gpus; last-wins silently drops the first value | form.yml:54,55 |
| QUA-06 | | WARN | info | README configuration table says FASRC cluster value is "odyssey" but form.yml has "odyssey3" | README.md:115, form.yml:3 |
| QUA-06 | | WARN | info | Typo in README: "forml.yml" should be "form.yml" | README.md:136 |

## Review scope

**Examined:** manifest.yml, form.yml, submit.yml.erb, template/script.sh.erb, template/before.sh.erb, template/config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml, template/config/menus/xfce-applications.menu, template/config/xfce4/terminal/terminalrc, README.md, LICENSE.txt, CHANGELOG.md, images/  
**Not examined:** Runtime behavior (Tier 3; no isolated execution environment); GitHub release/contributor/issue data (GitHub API blocked in this environment)  
**Tools:** syntax (bash -n, GNU bash 5.2.21, 2 files), shellcheck (0.9.0, 5 findings), semgrep (1.178.0, 0 findings), bandit (skipped, no applicable files), trivy (skipped, no applicable files)

## Catalog checks

- Duplicate check against the existing catalog — **No duplicate found.** No published app with "SAS" in the title exists in the catalog. (Stata is present, but that is a different statistical software product.)
  - **Duplicate-check rationale:** _fasrc/ood-sas would be the first SAS app in the Appverse catalog. No identical or substantially similar app exists. Accept as first entry._
- `software` value — Not applicable for inferred repo (no appverse.yml; no `software` field). The reviewer should reference the existing **SAS** Software node (UUID `cfb88e77-2fa2-4dca-b8f2-6eaa568d8cb5`) when creating the catalog entry.
- `app_type` and `implementation_tags` — Not applicable for inferred repo (no appverse.yml). The reviewer should select **batch-connect-VNC** (catalog vocabulary term) when creating the catalog entry, as the app uses the `turbovnc` Batch Connect template.

## Overall recommendation

This app passes all structure gate criteria (README, LICENSE, manifest fields, standard layout, valid YAML, clean syntax). Documentation is Adequate and portability is Partially portable, both at or above their thresholds. No security findings are tagged potentially malicious; all security candidates are WARN or PASS at low severity. The primary concerns are code quality: the CHANGELOG.md is a verbatim copy from an Ohio Supercomputer Center MATLAB app (bc_osc_matlab) and must be replaced, the sas_version widget contains a leftover "Matlab module" help text, number fields are missing upper bounds, and a large block of commented-out Singularity code remains in the job script. These are fixable suggestions rather than gate blockers. **Accept with suggestions**, pending the catalog duplicate and Software entry checks (which the automated review cannot perform).

---

## Draft feedback — edit before sending

Thank you for submitting ood-sas to the Appverse! The app passes the required structure checks and has solid installation and configuration documentation. A few items need attention before listing, and several suggestions would improve quality for other deployers.

**Copy-paste artifacts to fix (medium priority)**

`CHANGELOG.md` (lines 10–63) is a verbatim copy from the OSC MATLAB app (`bc_osc_matlab`): the entries describe MATLAB versions and all diff links point to `github.com/OSC/bc_osc_matlab`. Please replace it with a changelog that describes this SAS app's own history. If there have been no versioned releases yet, a minimal entry such as `## [Unreleased]` or an initial entry noting when the SAS app was first published is sufficient.

**Wrong help text**

In `form.yml` at line 61, the `sas_version` widget's `help` field reads "Loading the Matlab module for requested version." Please update this to describe SAS (e.g., "The SAS Lmod module to load on the compute node").

**Duplicate YAML keys**

`form.yml` defines the `help` key twice for both `custom_num_cores` (lines 44–46) and `custom_num_gpus` (lines 54–56). In YAML, the second definition silently wins and the first is discarded — the single-line help strings on lines 44 and 54 are never seen. Remove the duplicate keys and keep only the multi-line `|` version for each field. See the [YAML specification](https://yaml.org/spec/1.2.2/#mapping-key-uniqueness) for details.

**Hardcoded scratch path**

`template/script.sh.erb` at line 21 sets `WORKDIR=/scratch/$USER/$SLURM_JOBID`. The `/scratch/` mount point is site-specific; other clusters may use `/scratch1/`, `/tmp/`, `/nobackup/`, or a different path. Please either document this in the README configuration table (under `form.yml attributes` or a new `template/script.sh.erb` section) or make it configurable via a form attribute. See the [Appverse Best Practices guide](https://openondemand.connectci.org/appverse-best-practices) for portability recommendations.

**Error handling**

Neither `template/script.sh.erb` nor `template/before.sh.erb` sets `set -e`. Without it, a failed `module load` or other command silently continues and the job appears to start normally while SAS may not be running. Add `set -e` near the top of each script (after `set -x` if you want tracing). Also, the `cd $WORKDIR` at line 25 of `script.sh.erb` lacks `|| exit`; if the directory creation failed, the script would continue in the wrong directory. ShellCheck (SC2164) flagged this.

**Scheduler field sanitisation and missing-value guards (submit.yml.erb)**

In `submit.yml.erb`, `custom_reservation` (line 6), `custom_email_address` (line 7), and `custom_time` (line 10) are interpolated as plain strings into Slurm scheduler fields with no sanitisation call (no `shellescape`, `to_i`, or `to_f`). Under OOD's PUN model the blast radius is self-harm only, but it is good practice to convert or escape user-supplied text before it reaches the scheduler. Additionally, `custom_reservation` (line 6) and `custom_email_address` (line 7) are optional fields interpolated without a `blank?` guard; an empty submission produces a bare null YAML value in those scheduler fields. Consider adding a presence guard, for example `<%= custom_reservation.blank? ? nil : custom_reservation.shellescape %>`, so that blank optional fields are passed as nil rather than an empty string.

**Input validation (form.yml)**

`form.yml` is missing upper bounds (`max`) on `custom_memory_per_node` (line 30) and `custom_num_cores` (line 38). A deployer's cluster may have hard resource limits that users can unknowingly exceed. Add a reasonable `max` for each. Also, the text fields `custom_time` (line 15), `custom_email_address` (line 27), and `custom_reservation` (line 65) reach the scheduler with no `pattern` validation — a time format like `HH:MM:SS` could be constrained with a simple regex (e.g., `pattern: "^[0-9]{2}:[0-9]{2}:[0-9]{2}$"` for time) to give users earlier feedback on invalid input.

**Commented-out code**

`template/script.sh.erb` contains two large blocks of commented-out code: a heredoc skeleton at lines 33–42 and a Singularity invocation block at lines 78–94. These appear to be earlier implementation attempts. If they are not needed, removing them would make the script easier for deployers to read and adapt.

**Minor items**

- `template/config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml` line 40 uses `fedora-logo-icon` as the Xfce applications-menu button icon, but the README documents Rocky 8.10 as the tested OS. On Rocky Linux this icon may not render. Replace with a neutral icon (e.g., `applications-system`) or the correct OS icon.
- The README troubleshooting section (line 159) still contains generic template text ("YOUR-APP", "module load software/1.0"). Please update these placeholders with SAS-specific guidance.
- README line 136 has a typo: "forml.yml" should be "form.yml".
- README line 115 says the FASRC cluster value is "odyssey" but `form.yml` line 3 has `cluster: "odyssey3"` — please align them.

<!-- feedback-covers: CHANGELOG.md:wrong-app-changelog, form.yml:wrong-help-text, form.yml:duplicate-yaml-key:custom_num_cores.help, form.yml:duplicate-yaml-key:custom_num_gpus.help, template/script.sh.erb:hardcoded-path, template/script.sh.erb:no-set-e, template/before.sh.erb:no-set-e, form.yml:missing-min-max, form.yml:missing-pattern, template/script.sh.erb:commented-out-code, template/config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml:icon-os-mismatch, submit.yml.erb:erb-missing-value-unhandled, submit.yml.erb:unsanitized-user-input, README.md:readme-typo, README.md:readme-inconsistency:cluster -->
