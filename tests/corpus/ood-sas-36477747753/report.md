# Appverse Review: ood-sas

**Repository:** https://github.com/fasrc/ood-sas  **Mode:** reviewer  **Date:** 2026-09-28
**Reviewed commit:** `462790a1fdd1616038ea3536454a4e508c668471` (2026-07-08)  **Repo shape:** inferred single app
**Reviewed with:** appverse-review @ 0.4.0 (`e548bfa`, https://github.com/Sweet-and-Fizzy/appverse-review) · **Model:** claude-sonnet-4-6 · **Rubric:** https://openondemand.connectci.org/appverse-review-rubric

> _Disclaimer: This is an automated review with human curation. It is provided without warranty of any kind and does not certify the app as secure or fit for any purpose. A listing is not an endorsement._

## Repo-level gate criteria

| Rule | Result | Evidence |
|---|---|---|
| — | PASS | Repository public and accessible (clone succeeded; GitHub API confirms `visibility: public`) |
| STR-01 | PASS | README.md — present and substantive; covers overview, requirements, installation, configuration, screenshots, troubleshooting |
| STR-01 | PASS | LICENSE.txt — MIT license, copyright Ohio Supercomputer Center and FAS-RC Harvard University |
| — | PASS | Repo not archived (GitHub API: `archived: false`) |

## Upkeep

| Signal | Value | Assessment |
|---|---|---|
| Last commit | 2026-07-08 (≈ 12 weeks ago) | Good sign — active within 12 months |
| Releases | 0 tagged releases on GitHub | Concern — no versioned releases |
| Issues responsiveness | 0 open issues | Neutral — no evidence either way |
| Contributors | 4 (whorka, elawrence42, paulasanematsu, pontiggi) | Good sign — multiple contributors |
| CHANGELOG | CHANGELOG.md present but describes bc_osc_matlab (MATLAB), not this app | Concern — copy-pasted, not current |
| CI | No `.github/workflows/` directory | Concern — no CI configuration |

| Dimension | Level | Evidence |
|---|---|---|
| Upkeep (repo-level) | Medium | Active within 12 months; only 1 of 5 good-practice signals met (multiple contributors); no releases, wrong-app CHANGELOG, no CI |

## App: SAS (root)

### Signals

| Dimension | Level | Evidence |
|---|---|---|
| Security | Low | No OODT findings; capability profile clean for a Batch Connect app |
| Portability | Medium | Partially portable — cluster name and module version documented in README, but `/scratch` working directory in script.sh.erb is not |
| Documentation | Medium | Adequate — covers all four deployer questions; troubleshooting and screenshots present; no environment variable docs |

### Structure

| Rule | Result | Severity | Summary | Evidence |
|---|---|---|---|---|
| STR-02 | PASS | — | Required manifest.yml fields present | manifest.yml: name, category, role, description all present |
| STR-03 | PASS | — | YAML validity | form.yml and manifest.yml parse without errors; duplicate `help` keys in form.yml are valid YAML (last-wins, flagged under Code Quality) |
| STR-07 | PASS | — | Standard Batch Connect layout | form.yml, submit.yml.erb, template/ all present; manifest.yml role: batch_connect |
| STR-04 | PASS | — | No broken references | All form attributes referenced in submit.yml.erb and template/script.sh.erb exist in form.yml or are built-in OOD BC attributes |

### Security

Findings are classified under [OODT (Open OnDemand App Threats)](https://openondemand.connectci.org/appverse-review-rubric); codes are defined in the rubric's Security section.

**Check tiers:** Tiers 1–2  
Tier 3 not checked — no isolated execution environment.

| Tool | Status | Result |
|---|---|---|
| shellcheck | ran (on ERB-stripped scripts) | SC2164 (cd without error check, line 25), SC2086 (unquoted variables, note-level, lines 22/25/72) — no injection vectors; see Code Quality |
| semgrep | ran (`p/security-audit`, `p/secrets`) | 0 findings |
| bandit | not applicable | no Python files |
| trivy | not installed | — |
| rubocop | not installed | — |
| npm audit | not applicable | no package.json |

**Capability profile — Batch Connect app:**

| File | Capabilities | Anomalies |
|---|---|---|
| form.yml | Collects user inputs: partition, time, memory, cores, GPUs, SAS version, email, reservation, extra Slurm options | None |
| submit.yml.erb | Passes form values to Slurm native options; extra_slurm split on whitespace and passed as individual flags (documented feature) | None — extra_slurm is an intentional pass-through; user runs jobs under their own UID (PUN model, self-harm only) |
| template/before.sh.erb | Exports module shell function | None |
| template/script.sh.erb | Purges/loads Lmod modules; creates /scratch/$USER/$SLURM_JOBID workdir; launches Xfce desktop (xfwm4, xfce4-panel, xfsettingsd) via TurboVNC; writes OOM score to /proc/self/oom_score_adj (documented, self-process only); runs SAS via xfce4-terminal; waits for child processes | /proc/self/oom_score_adj write is defensive and documented in code comment; no outbound network; no dotfile writes; no SSH key reads; no cron; no binary files in template/ |

#### Findings

No OODT security findings.

### Portability
- Rating: **Partially portable** — form.yml cluster name (`odyssey3`) and SAS module version (`sas/9.4-fasrc01`) are documented in the README configuration table; however, the `/scratch/$USER/$SLURM_JOBID` working directory in template/script.sh.erb is hardcoded and not called out as something deployers must change.
- QUA-02 finding: template/script.sh.erb:21 — `/scratch` path hardcoded, not in README configuration table.

### Documentation
- Rating: **Adequate** — covers all four deployer questions (what it launches, prerequisites, installation, configuration); troubleshooting and screenshots present; no environment variable documentation.
- Evidence per rung:
  - what it launches: README.md:22–30 (Appverse overview: "SAS is an Open OnDemand Batch Connect app that launches SAS as an interactive desktop session")
  - prerequisites: README.md:64–81 (Requirements section: SAS Lmod module, Xfce 4+, TurboVNC 2.1+, websockify, OOD v3.0+, Slurm, Lmod)
  - installation: README.md:84–152 (App Installation section: clone + configure steps)
  - configuration: README.md:110–149 (form.yml attributes table and manifest.yml attributes table)
  - known limitations: README.md:198–201 ("Multi-node jobs are not supported; Only tested on Centos 7 and Rocky 8")
  - troubleshooting: README.md:158–175 (section present with three named scenarios; some generic language — "module load software/1.0", wrong attribute name "modules" vs "sas_version")
  - screenshots: README.md:38–48 (two screenshots: SAS desktop and SAS plot example)
  - environment variables: none (script-internal variables WORKDIR and SEND_256_COLORS_TO_REMOTE are not deployer-facing; no documented deployer-configured env vars)
  - info panel: none
  - architecture: none

### Code Quality

| Check | Rule | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| Error handling in scripts | QUA-03 | FAIL | low | No `set -e` in script.sh.erb; `cd $WORKDIR` has no error check (shellcheck SC2164) | template/script.sh.erb:1 (missing set -e); line 25 (cd without \|\| exit) |
| Input validation on form fields (`check: numeric-field-bounds`) | QUA-07 | FAIL | low | custom_memory_per_node and custom_num_cores have min but no max; custom_time text field has no pattern constraint | form.yml:30–37 (custom_memory_per_node, no max), form.yml:38–46 (custom_num_cores, no max), form.yml:15–20 (custom_time, no pattern) |
| Magic numbers / undocumented literals | QUA-08 | WARN | low | Hex color `#D3D3D3` for desktop background has no comment | template/script.sh.erb:46 |
| Duplicated code blocks | QUA-09 | PASS | — | No large duplicated blocks | — |
| Commented-out dead code | QUA-04 | WARN | low | ~17 lines of commented-out Singularity container invocation code remain in script.sh.erb | template/script.sh.erb:78–94 |
| ERB handles missing/empty values | QUA-10 | PASS | — | optional fields (custom_reservation, custom_email_address) produce null YAML when blank; required fields use blank? guards | submit.yml.erb:6–7 |
| Desktop/panel icon matches target OS (`check: icon-matches-target-os`) | QUA-06 | WARN | low | xfce4-panel.xml sets button-icon to `fedora-logo-icon`; README states app was tested on Rocky 8.10, not Fedora | template/config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml:40 |
| Copy-paste artifact: wrong-app CHANGELOG | QUA-05 | WARN | low | CHANGELOG.md is copied from OSC/bc_osc_matlab; all entries describe MATLAB versions and bc_osc_matlab issues; links point to `github.com/OSC/bc_osc_matlab` | CHANGELOG.md:11–63 |
| Copy-paste artifact: wrong-app help text | QUA-05 | WARN | low | sas_version field help says "Loading the Matlab module for requested version" | form.yml:60–61 |
| Duplicate YAML key: custom_num_cores.help | QUA-06 | WARN | low | Two `help:` keys under custom_num_cores; first value ("Number of Cpus to allocate") is silently overridden by second | form.yml:44–45 |
| Duplicate YAML key: custom_num_gpus.help | QUA-06 | WARN | low | Two `help:` keys under custom_num_gpus; first value is silently overridden by second | form.yml:54–55 |
| README typos | QUA-06 | WARN | low | "notificationl" (line 125) should be "notification"; "forml.yml" (line 136) should be "form.yml" | README.md:125, README.md:136 |
| Wrong help text: troubleshooting attribute name | QUA-06 | WARN | low | Troubleshooting section says update the "`modules` attribute" — actual attribute in form.yml is `sas_version` | README.md:169 |
| Portability: hardcoded /scratch path | QUA-02 | WARN | low | /scratch working directory path is FASRC-specific and not documented in README configuration table | template/script.sh.erb:21 |

**Per-app decision:** N/A (single-app repo — see Overall recommendation below)

## Review scope

**Examined:** README.md, LICENSE.txt, manifest.yml, form.yml, submit.yml.erb, template/script.sh.erb, template/before.sh.erb, template/config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml, template/config/menus/xfce-applications.menu, template/config/xfce4/terminal/terminalrc, CHANGELOG.md, .gitignore, icon.png (listed), images/ (listed). Static analysis: shellcheck (tier 2, on ERB-stripped scripts), semgrep p/security-audit and p/secrets (tier 2).

**Not examined:** Runtime behavior (tier 3 — no isolated execution environment); catalog moderation state (requires reviewer login).

## Catalog checks

- Duplicate check against the existing catalog — No SAS app found in the 100-item catalog listing (API queried 2026-09-28). Result: **no duplicate found**.
  - **Duplicate-check rationale:** _The catalog returned no app titled "SAS" or anything similar. This appears to be the first SAS submission. Accept as a unique entry._
- `software` value matches a catalog Software entry — **N/A** (inferred repo — no `appverse.yml` with a `software` field). However, a "SAS" Software entry already exists in the catalog (`appverse_software` node titled "SAS"), which would be available if the contributor later adds an `appverse.yml`.
- `app_type` and `implementation_tags` are in the catalog vocabularies — **N/A** (inferred repo — no `appverse.yml` with these fields).

## Overall recommendation

**Accept with suggestions.** All repo-level gate criteria pass: the repository is public, has a substantive README, carries an MIT license, and is not archived. The security posture is clean — no OODT findings across tiers 1–2, and the capability profile is narrow and expected for a Batch Connect app. Documentation is Adequate and portability is Partially portable, both at the target for inclusion. The primary issues are code-quality improvements: the script lacks `set -e` error handling; numeric form fields `custom_memory_per_node` and `custom_num_cores` are missing upper bounds; the CHANGELOG is a copy-paste from the OSC MATLAB app and describes no SAS-specific changes; and several copy-paste artifacts remain in `form.yml` (MATLAB help text, duplicate YAML keys) and the README (typos, wrong attribute name in troubleshooting). These are all fixable improvements that do not block listing. This recommendation is conditional on the human reviewer confirming the catalog duplicate check (completed above: none found) and the absence of a conflicting submission.

---

## Draft feedback — edit before sending

Thank you for submitting ood-sas to Appverse. The app passes all gate criteria and the security check is clean. The following improvements would strengthen it before or after listing.

**Error handling (`template/script.sh.erb`):** The job script has no `set -e`, so if an early step (like `module purge` or `mkdir`) fails, the script continues silently. Adding `set -e` near the top (after the diagnostic `echo` block) will cause the job to abort cleanly on failure. The `cd $WORKDIR` on line 25 also lacks an error check; shellcheck recommends `cd "$WORKDIR" || exit 1`.

**Form input validation (`form.yml`):** The `custom_memory_per_node` field (line 30) and `custom_num_cores` field (line 38) are both `number_field` widgets with a `min` but no `max`. Adding a reasonable upper bound helps prevent accidental requests for extreme resources. The `custom_time` field (line 15) is a `text_field` that reaches Slurm directly; adding a `pattern:` constraint (e.g., `pattern: "^[0-9]{1,2}:[0-9]{2}:[0-9]{2}$"`) would catch malformed time strings before job submission.

**Copy-paste artifacts — CHANGELOG.md:** The CHANGELOG is copied from OSC's `bc_osc_matlab` repository. All entries describe MATLAB versions, and the version links at the bottom point to `github.com/OSC/bc_osc_matlab`. Please replace it with a SAS-specific changelog that records your actual release history. If there are no tagged releases yet, a single `[Unreleased]` section with your changes since the initial port is sufficient.

**Copy-paste artifacts — `form.yml`:** The `sas_version` help text (line 60) says "Loading the Matlab module for requested version" — this should reference SAS, not MATLAB. The `custom_num_cores` attribute (lines 44–45) and `custom_num_gpus` attribute (lines 54–55) each have two `help:` keys; YAML last-wins means the first help string is silently discarded. Remove the redundant first `help:` line in each case.

**README corrections (`README.md`):** Two typos appear in the configuration tables: "notificationl" (README.md:125) should be "notification", and "`forml.yml`" (README.md:136) should be "`form.yml`". The "Module not found" troubleshooting tip (README.md:169) says to update the "`modules` attribute", but the actual form attribute is `sas_version`.

**Portability — `/scratch` path (`template/script.sh.erb:21`):** The working directory `WORKDIR=/scratch/$USER/$SLURM_JOBID` is FASRC-specific. Other sites may use `/tmp`, `/work`, `/scratch2`, or a different convention. Add a note to the README's configuration table so deployers know to update this path.

**Minor suggestions (no action required for listing):**
- `xfce4-panel.xml` sets `button-icon` to `fedora-logo-icon` (line 40), but the README states the app was tested on Rocky 8, where that icon may not exist. Consider using a generic icon or the Xfce default.
- About 17 lines of commented-out Singularity container code remain at the bottom of `template/script.sh.erb` (lines 78–94). These appear to be leftover from a containerized variant; removing them would reduce confusion.
- The hex color `#D3D3D3` in `template/script.sh.erb:46` (`xsetroot -solid`) is undocumented. A brief inline comment ("light gray desktop background") would clarify intent.
- No tagged releases are present on GitHub. Tagging a version (e.g., v1.0.0) helps deployers track which version they have installed and makes it easier to report issues against a specific state.
- No CI workflow is present. A simple GitHub Actions workflow that validates `form.yml` as YAML and runs shellcheck on the template scripts would catch regressions early.

<!-- feedback-covers: template/script.sh.erb:no-set-e, form.yml:missing-min-max, CHANGELOG.md:wrong-app-changelog, form.yml:wrong-app-reference, form.yml:duplicate-yaml-key:custom_num_cores.help, form.yml:duplicate-yaml-key:custom_num_gpus.help, README.md:readme-typo, README.md:wrong-help-text, template/script.sh.erb:hardcoded-path, template/config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml:readme-inconsistency:icon-os, template/script.sh.erb:commented-out-code, template/script.sh.erb:undocumented-hex-color -->
