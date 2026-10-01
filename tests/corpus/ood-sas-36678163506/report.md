# Appverse Review: ood-sas

**Repository:** https://github.com/fasrc/ood-sas  **Mode:** reviewer  **Date:** 2026-09-30
**Reviewed commit:** `462790a1fdd1616038ea3536454a4e508c668471` (2026-07-08)  **Repo shape:** inferred single app
**Reviewed with:** appverse-review @ 0.7.0 (`e167db4`, https://github.com/Sweet-and-Fizzy/appverse-review) · **Model:** claude-sonnet-4-6 · **Rubric:** https://openondemand.connectci.org/appverse-review-rubric

> _Disclaimer: This is an automated review with human curation. It is provided without warranty of any kind and does not certify the app as secure or fit for any purpose. A listing is not an endorsement._

## Repo-level gate criteria

| Rule | Result | Evidence |
|---|---|---|
| — | PASS | Repository public and accessible (clone succeeded) |
| STR-01 | PASS | README.md — present and substantive |
| STR-01 | PASS | LICENSE.txt — MIT license (Ohio Supercomputer Center / FAS-RC Harvard) |
| — | PASS | Repo not archived (GitHub API: `archived: false`) |

## Upkeep

| Signal | Value | Assessment |
|---|---|---|
| Last commit | 2026-07-08 | Within 12 months |
| Releases | None | No tagged releases |
| Issues responsiveness | 0 open issues | Neutral (no evidence either way) |
| Contributors | 4 (contributor-1, contributor-2, contributor-3, contributor-4) | Multiple contributors |
| CHANGELOG | Present (CHANGELOG.md) | Content describes a MATLAB app, not SAS — see QUA-05 |
| CI | None | No `.github/workflows` directory |

| Dimension | Level | Evidence |
|---|---|---|
| Upkeep (repo-level) | Medium | Active within 12 months; one good-practice signal (multiple contributors); no releases, no CI, CHANGELOG is wrong-app |

## App: SAS (root)

### Signals

| Dimension | Level | Evidence |
|---|---|---|
| Portability | Medium | `/scratch/` path hardcoded in script.sh.erb without documentation; cluster name and module version documented in README config table |
| Documentation | Medium | Adequate — what it launches, prerequisites, installation, configuration, and known limitations all present; troubleshooting section has unfilled placeholder text; no environment-variable docs |

### Structure

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| STR-02 | `check: str-02-metadata` | PASS | info | Required manifest fields present: name, category, role, description | manifest.yml:1-10 |
| STR-03 | `check: str-03-yaml-valid` | PASS | info | manifest.yml and form.yml are valid YAML; submit.yml.erb ERB tags balanced | manifest.yml; form.yml; submit.yml.erb |
| STR-06 | `check: str-06-syntax` | PASS | info | Template scripts syntactically correct: 2 files pass, 0 fail (from pre-review syntax.json) | template/before.sh.erb; template/script.sh.erb |
| STR-07 | `check: str-07-layout` | PASS | info | Standard BC layout present: form.yml, submit.yml.erb, template/script.sh.erb | submit.yml.erb |
| STR-04 | `check: str-04-references` | PASS | info | All variables referenced in submit.yml.erb are defined in form.yml; bc_email_on_started is a built-in OOD attribute | submit.yml.erb |

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
| OODT-01 | `check: sec-interpolation` | WARN | low | unintentional | text_field values custom_reservation, custom_email_address, custom_time, and extra_slurm reach the scheduler without sanitization; all self-harm (BC/PUN model) | submit.yml.erb:6,7,10,17; reviewed OK: submit.yml.erb:9,11,13 |
| OODT-01 | `check: sec-interpolation` | PASS | — | — | select and number_field interpolations in script.sh.erb are constrained by widget type or used only in echo statements | reviewed OK: template/script.sh.erb:11,12,64 |
| OODT-01 | `check: sec-eval-exec` | PASS | — | — | eval at line 72 operates on hardcoded COMMAND variable set at line 61, not on user-supplied input | reviewed OK: template/script.sh.erb:72 |
| OODT-08 | `check: sec-config-flag` | WARN | low | unintentional | set -x appears three times; trace output goes to job's output.log, readable only by job owner under default umask | template/script.sh.erb:19,44,54 |

#### Additional observations (review)

No findings.

No tool-detectable issues in the checked tiers.

**Capability profile (Batch Connect):** Standard BC/VNC desktop profile. Launches Xfce window manager (xfwm4, xfce4-panel) and SAS via Lmod (`module load sas/<version>`). Creates a per-job scratch directory at `/scratch/$USER/$SLURM_JOBID`. Sets OOM score on the parent process (line 69) and resets it for the child (line 71) — a documented defensive practice. GPU allocation via `--gres=gpu:<n>`. All capabilities consistent with a desktop interactive app; no anomalous outbound network calls, dotfile writes, or binary payloads.

### Portability

- Rating: **Partially portable** — `/scratch/` directory path is hardcoded in `template/script.sh.erb` without documentation in the README configuration table; cluster name (`odyssey3`) and SAS module version (`sas/9.4-fasrc01`) are hardcoded in `form.yml` but documented in the README configuration table.

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| QUA-02 | `check: hardcoded-site-paths` | WARN | medium | `/scratch/` path hardcoded in script.sh.erb; not listed in the README configuration table as a site-specific value | template/script.sh.erb:21 |
| QUA-02 | `check: portability-rating` | PASS | info | Partially portable — FASRC-specific cluster name and module version are documented in the README config table; one undocumented hardcoded path remains | template/script.sh.erb:21 |

### Documentation

- Rating: **Adequate** — what it launches, prerequisites, installation, configuration, and known limitations all present; troubleshooting section contains unfilled template placeholders (YOUR-APP, `module load software/1.0`) and environment variables are not documented.
- Evidence per rung:
  - what it launches: "Appverse overview", README.md:21
  - prerequisites: "Requirements", README.md:63
  - installation: "App Installation", README.md:84
  - configuration: "2. Configure for your site", README.md:99
  - known limitations: "Known Limitations", README.md:196
  - troubleshooting: "Troubleshooting", README.md:159 — none (placeholder: template text not updated for SAS)
  - screenshots: "Screenshots", README.md:37 — two images (images/sas_desktop.png, images/sas_plot_example.png)
  - environment variables: none
  - info panel: none
  - architecture: none

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| QUA-01 | `check: documentation-rating` | PASS | info | Adequate — all four core questions answered; troubleshooting has placeholder text, no env-var docs | README.md:21,63,84,99,196 |

### Code Quality

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| QUA-03 | `check: error-handling` | FAIL | low | script.sh.erb has no `set -e`; failures in module loading, mkdir, or xfwm4 launch proceed silently | template/script.sh.erb:1 |
| QUA-07 | `check: numeric-field-bounds` | WARN | low | custom_memory_per_node and custom_num_cores lack a max bound; four text_fields reaching the scheduler (custom_time, custom_email_address, custom_reservation, extra_slurm) have no pattern constraint | form.yml:30,38; reviewed OK: form.yml:47 |
| QUA-07 | `check: numeric-field-bounds` | WARN | low | text_fields custom_time, custom_email_address, custom_reservation, and extra_slurm reach the scheduler without a pattern constraint | form.yml:15,27,65,72 |
| QUA-08 | `check: magic-numbers` | WARN | low | Hex color `#D3D3D3` used as xsetroot background without a comment explaining the choice | template/script.sh.erb:46 |
| QUA-09 | `check: duplicated-blocks` | PASS | info | No significant duplicated code blocks | template/script.sh.erb |
| QUA-04 | `check: dead-code` | WARN | low | Three groups of commented-out code (lines 33–37, 39–42, 78–94); the largest block (lines 78–94) contains Singularity container invocations and a MATLAB environment variable (`SINGULARITYENV_MATLAB_PREFDIR`) | template/script.sh.erb:33,39,78 |
| QUA-10 | `check: erb-missing-value` | WARN | low | custom_reservation (submit.yml.erb:6) and custom_email_address (submit.yml.erb:7) are interpolated without a blank? guard; other interpolated fields are guarded | form.yml:27,65; reviewed OK: form.yml:15,30,38,47,72 |
| QUA-06 | `check: icon-matches-target-os` | WARN | low | `fedora-logo-icon` referenced in xfce4-panel.xml but the app is tested on Rocky 8.10 (README.md:183) | template/config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml:40 |
| QUA-05 | | WARN | low | CHANGELOG.md is a copy-paste from the OSC bc_osc_matlab MATLAB app: entries reference "MATLAB version 2018a" and all links point to `github.com/OSC/bc_osc_matlab` | CHANGELOG.md:10 |
| QUA-06 | | WARN | low | `sas_version` help text reads "Loading the Matlab module for requested version" — wrong-app copy-paste | form.yml:61 |
| QUA-06 | | WARN | low | Duplicate `help:` key under `custom_num_cores`; YAML last-wins, first value silently discarded | form.yml:44,45 |
| QUA-06 | | WARN | low | Duplicate `help:` key under `custom_num_gpus`; YAML last-wins, first value silently discarded | form.yml:54,55 |
| QUA-06 | | WARN | info | Table header typo in README.md: `` `forml.yml` `` instead of `` `form.yml` `` | README.md:136 |

## Review scope

**Examined:** manifest.yml, form.yml, submit.yml.erb, template/script.sh.erb, template/before.sh.erb, template/config/ (xfce4-panel.xml, terminalrc, xfce-applications.menu), README.md, LICENSE.txt, CHANGELOG.md, icon.png, images/

**Not examined:** Runtime behavior (Tier 3, no isolated execution environment); GitHub Issues history (0 open issues, responsiveness not assessable)

**Tools:** bash syntax (ran, 2 files), shellcheck (ran, 2 .sh.erb files ERB-stripped, 5 findings), semgrep (ran, 0 findings), bandit (skipped, no Python files), trivy (skipped, no applicable files)

## Catalog checks

- Duplicate check against the existing catalog — **No duplicate found.** No app named "SAS" or similar appears in the published app list.
  - **Duplicate-check rationale:** _The catalog lists statistical-computing apps (Stata, R, RStudio, SageMath) but no SAS. This submission is the first SAS app; no duplicate rejection applies. Reviewer should verify there is no in-progress submission from another site before approving._
- `software` value — **Not applicable (inferred repo).** This repo has no `appverse.yml`; the catalog infers the app from `manifest.yml`. The `software` field is a declared-repo requirement. A "SAS" Software entry does exist in the catalog and can be referenced if the contributor later adds `appverse.yml`.
- `app_type` and `implementation_tags` — **Not applicable (inferred repo).** The catalog derives the app type from `manifest.yml`'s `role: batch_connect`. No declared vocabulary terms to check.

## Overall recommendation

**Accept with suggestions** (pending the duplicate-check confirmation noted above). All gate criteria pass: README.md is substantive, an MIT license is present, manifest.yml provides the four required fields, the standard Batch Connect layout is intact, and YAML/shell syntax is clean. Documentation is Adequate and portability is Partially portable, both meeting the target for inclusion. The most important items to address before or after listing are: (1) adding `set -e` to `template/script.sh.erb` so errors in module loading and window-manager startup do not silently continue; (2) adding `max` bounds to the `custom_memory_per_node` and `custom_num_cores` number fields in `form.yml`; (3) replacing the CHANGELOG.md content, which currently describes the OSC MATLAB app; (4) correcting the `sas_version` help text, which says "Loading the Matlab module"; and (5) documenting the `/scratch/` path in the README configuration table. The Fedora panel icon, duplicate YAML keys, dead commented-out Singularity code, and the `forml.yml` README typo are minor polish items. No CI is present, and no tagged releases have been cut; both are good-practice suggestions.

---

## Draft feedback — edit before sending

Thank you for submitting **ood-sas** to the Appverse catalog. The app is well-structured, has a substantive README, and the core Batch Connect layout is clean. A few items need attention before or shortly after listing.

**Error handling (template/script.sh.erb):** `script.sh.erb` has no `set -e`. Without it, a failed `module load` or `mkdir` at line 21 continues silently and the user sees a 502 proxy error instead of a useful log message. Add `set -e` near the top (after `module purge`) so the job fails fast. See the [Appverse Best Practices guide](https://openondemand.connectci.org/appverse-best-practices) for the recommended pattern.

**Input validation (form.yml):** The `custom_memory_per_node` field (line 30) and `custom_num_cores` field (line 38) are `number_field` widgets that reach the scheduler but have no `max:` bound. A deployer with a 1 TB node could still receive a request for arbitrarily large memory. Please add `max:` values appropriate for your largest available node. Additionally, the text fields `custom_time` (line 15), `custom_email_address` (line 27), `custom_reservation` (line 65), and `extra_slurm` (line 72) have no `pattern:` constraint despite reaching the scheduler. Adding patterns (e.g., a time-format regex for `custom_time`, an email pattern for `custom_email_address`) lets OOD reject malformed values before sbatch sees them.

**Unguarded ERB interpolations (submit.yml.erb):** `custom_reservation` at line 6 and `custom_email_address` at line 7 are interpolated without a `blank?` guard. If either field is left empty, the YAML value becomes an empty string, which may be passed to sbatch as `--reservation=` or `--mail-user=`. Use the same `field.blank? ? nil : field` pattern that `custom_time` already uses at line 10 to skip these options when empty.

**Wrong-app content — CHANGELOG.md:** The CHANGELOG describes the OSC `bc_osc_matlab` MATLAB app (e.g., "Added MATLAB version 2018a"; all comparison links point to `github.com/OSC/bc_osc_matlab`). Please replace it with a SAS-specific changelog. The [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) format you are already using is fine.

**Wrong help text (form.yml line 61):** The `sas_version` attribute's `help:` reads "Loading the Matlab module for requested version." Please update it to describe SAS, e.g., "Lmod module to load SAS on compute nodes."

**Hardcoded `/scratch/` path (template/script.sh.erb line 21):** `WORKDIR` is set to `/scratch/$USER/$SLURM_JOBID`. Sites whose scratch filesystem is not mounted at `/scratch` will need to edit this line. Please add a row to the README configuration table (alongside `cluster` and `sas_version`) pointing deployers to line 21 and suggesting they substitute their site's scratch path.

**Polish items (suggestions, not blocking):** The `custom_num_cores` and `custom_num_gpus` attributes each have two `help:` keys in `form.yml` (lines 44/45 and 54/55); YAML silently uses the last value. Remove the first `help:` line in each case. The `xfce4-panel.xml` panel icon is `fedora-logo-icon` but the app is documented for Rocky 8.10 — consider switching to a Rocky-appropriate icon. The commented-out Singularity/MATLAB block (lines 78–94 of `script.sh.erb`) and the other two commented regions (lines 33–37, 39–42) are dead code that can be removed. The `xsetroot` call at `template/script.sh.erb:46` uses the hardcoded hex color `#D3D3D3` with no comment; if the color is intentional, a brief comment explaining the choice would help. The README table header at line 136 reads `` `forml.yml` `` — one-character typo for `form.yml`.

<!-- feedback-covers: template/script.sh.erb:no-set-e, form.yml:missing-min-max, form.yml:missing-pattern, submit.yml.erb:erb-missing-value-unhandled, CHANGELOG.md:wrong-app-changelog, form.yml:wrong-help-text, template/script.sh.erb:hardcoded-path, submit.yml.erb:unsanitized-user-input, template/script.sh.erb:debug-tracing-enabled, form.yml:duplicate-yaml-key:custom_num_cores.help, form.yml:duplicate-yaml-key:custom_num_gpus.help, template/config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml:icon-os-mismatch, template/script.sh.erb:commented-out-code, template/script.sh.erb:undocumented-hex-color, releases:no-releases, README.md:readme-typo -->
