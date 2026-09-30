# Appverse Review: ood-sas

**Repository:** https://github.com/fasrc/ood-sas  **Mode:** reviewer  **Date:** 2026-09-28
**Reviewed commit:** `462790a1fdd1616038ea3536454a4e508c668471` (2026-07-08)  **Repo shape:** inferred single app
**Reviewed with:** appverse-review @ 0.4.0 (`e548bfa`, https://github.com/Sweet-and-Fizzy/appverse-review) · **Model:** claude-opus-4-6 · **Rubric:** https://openondemand.connectci.org/appverse-review-rubric

> _Disclaimer: This is an automated review with human curation. It is provided without warranty of any kind and does not certify the app as secure or fit for any purpose. A listing is not an endorsement._

## Repo-level gate criteria

| Rule | Result | Evidence |
|---|---|---|
| — | PASS | Repository public and accessible (the clone succeeded) |
| STR-01 | PASS | README.md — substantive; covers overview, features, requirements, installation, configuration, troubleshooting, testing, known limitations, and screenshots |
| STR-01 | PASS | LICENSE — MIT license present in LICENSE.txt |
| — | PASS | Repo not archived (`gh api` returned `archived: false`) |

## Upkeep

| Signal | Value | Assessment |
|---|---|---|
| Last commit | 2026-07-08 (~2.7 months ago) | Good sign |
| Releases | 0 releases, 0 tags | Concern |
| Issues responsiveness | 0 open issues | Neutral |
| Contributors | 4 | Good sign |
| CHANGELOG | Present but documents MATLAB app (copy-paste from OSC/bc_osc_matlab) | Concern |
| CI | No `.github/workflows/` directory | Concern |

| Dimension | Level | Evidence |
|---|---|---|
| Upkeep (repo-level) | Medium | Active within 12 months; 1 good-practice signal (multiple contributors) — needs 2+ for Low |

## App: SAS (root)

### Signals

| Dimension | Level | Evidence |
|---|---|---|
| Security | Medium | 3 Low-severity OODT findings (unsanitized input pass-through, unquoted variables, debug tracing) |
| Portability | Medium | Partially portable — main config in form.yml and documented, but undocumented hardcoded /scratch path in script |
| Documentation | Medium | Adequate — covers installation and configuration; lacks environment variable documentation for Strong |

### Structure

| Rule | Result | Severity | Summary | Evidence |
|---|---|---|---|---|
| STR-02 | PASS | — | Required metadata fields | manifest.yml has name, category, role, description |
| STR-03 | PASS | — | YAML validity | manifest.yml, form.yml parse without errors; submit.yml.erb and script.sh.erb have balanced ERB tags |
| STR-07 | PASS | — | Standard OOD structure | form.yml, submit.yml.erb, template/ with script.sh.erb all present |
| STR-04 | PASS | — | No broken references | All variables in submit.yml.erb and template/script.sh.erb are defined in form.yml attributes |

### Security

Findings are classified under OODT (Open OnDemand App Threats); codes are defined in the rubric's Security section.

**Check tiers:** Tiers 1–2
Tier 3 not checked — no isolated execution environment.

| Tool | Status | Result |
|---|---|---|
| shellcheck | Ran | 4 findings (SC2086 ×3, SC2164 ×1) on script.sh.erb; SC2148 ×1 on before.sh.erb (expected — sourced file) |
| semgrep | Ran | Clean (0 findings across 12 files, 39 rules) |
| bandit | Not applicable | No `.py` files |
| trivy | Not installed | — |
| rubocop | Not installed | — |

**Capability profile (Batch Connect):**

| File | Capabilities | Anomalies |
|---|---|---|
| `form.yml` | 13 form attributes: free-text fields (`custom_time`, `custom_email_address`, `custom_reservation`, `extra_slurm`), number fields (`custom_memory_per_node`, `custom_num_cores`, `custom_num_gpus`), select (`sas_version`), OOD built-ins | None |
| `submit.yml.erb` | TurboVNC template; passes form values to Slurm native options (`--mem`, `--time`, `--cpus-per-task`, `--gres=gpu`); splits `extra_slurm` into individual sbatch arguments | User text (`extra_slurm`) reaches sbatch without validation |
| `template/before.sh.erb` | Exports the `module` shell function if available | None |
| `template/script.sh.erb` | Logs job info; purges/restores/loads modules; creates scratch directory; launches Xfce desktop (xfwm4, xfce4-panel); launches SAS via xfce4-terminal; adjusts OOM score | Debug tracing (`set -x`); `eval` with unquoted variable |
| `template/config/*` | Static Xfce panel, terminal, and menu configuration | None |

No outbound network calls, no SSH key access, no dotfile writes, no cron, no base64-decode-and-execute, no binary files in `template/`.

#### Findings

| Rule | Result | Severity | Tag | Summary | Evidence |
|---|---|---|---|---|---|
| OODT-01 | FAIL | low | unintentional | `extra_slurm` text field passes unsanitized user input to sbatch native options; each whitespace-delimited token becomes a separate argument with no `pattern` constraint. Under PUN, blast radius is self-harm only. | submit.yml.erb:16, form.yml:73 |
| OODT-01 | FAIL | low | unintentional | Unquoted shell variables: `$WORKDIR` (lines 22, 25) and `$COMMAND` (line 72, used with `eval exec`). Values are system/hardcoded, not user-controlled; injection risk is minimal. Corroborated by shellcheck SC2086. | template/script.sh.erb:22 |
| OODT-08 | FAIL | low | unintentional | `set -x` enables bash debug tracing, outputting all executed commands (paths, usernames, module names) to the job log. On shared filesystems with permissive log permissions, this could expose system information. | template/script.sh.erb:19 |

### Portability

- Rating: Partially portable — main site-specific values (cluster, module, partition) are centralized in `form.yml` and documented in the README configuration table. `template/script.sh.erb` contains an undocumented hardcoded `/scratch` path, and help text links to a Harvard-specific URL.

| Rule | Result | Severity | Summary | Evidence |
|---|---|---|---|---|
| QUA-02 | WARN | medium | Hardcoded `/scratch/$USER/$SLURM_JOBID` path not documented in README configuration table | template/script.sh.erb:21 |
| QUA-02 | WARN | low | Site-specific Harvard URL in `bc_queue` help text | form.yml:26 |

### Documentation

- Rating: Adequate — covers what it launches, prerequisites, installation, configuration, and known limitations. Troubleshooting and screenshots are also present. Environment variable documentation is absent (script.sh.erb sets `WORKDIR` and `SEND_256_COLORS_TO_REMOTE` without README documentation), preventing a Strong rating.
- Evidence per rung:
  what it launches: Appverse overview section, README.md:27; prerequisites: Requirements section, README.md:63–83; installation: App Installation section, README.md:86–97;
  configuration: Configure for your site section, README.md:99–155; known limitations: README.md:198–201;
  troubleshooting: README.md:159–175; screenshots: README.md:38–48; environment variables: none;
  info panel: none; architecture: none

### Code Quality

| Check | Rule | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| Error handling in scripts | QUA-03 | FAIL | medium | No `set -e` or explicit error checks; `module purge`, `module load`, `mkdir -p`, and `cd` all run without error handling | template/script.sh.erb:19 |
| Input validation on form fields (`check: numeric-field-bounds`) | QUA-07 | FAIL | medium | `custom_memory_per_node` (min:4) and `custom_num_cores` (min:1) lack `max` bounds | form.yml:34, form.yml:39 |
| Magic numbers / undocumented literals | QUA-08 | WARN | low | Hardcoded hex color `#D3D3D3` for desktop background with no comment | template/script.sh.erb:46 |
| Duplicated code blocks | QUA-09 | PASS | info | No large duplicated code blocks found | template/script.sh.erb, submit.yml.erb |
| Commented-out dead code | QUA-04 | WARN | low | ~25 lines of commented-out Singularity/container setup code | template/script.sh.erb:33–42, 57, 78–95 |
| ERB handles missing/empty values | QUA-10 | WARN | low | `custom_reservation` and `custom_email_address` used without `.blank?` guards, unlike other values in same file | submit.yml.erb:6–7 |
| Desktop/panel icon matches target OS (`check: icon-matches-target-os`) | QUA-06 | WARN | low | Panel icon `fedora-logo-icon` does not match target OS Rocky 8.10 | template/config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml:40 |
| CHANGELOG describes wrong app | QUA-05 | FAIL | medium | Entire CHANGELOG.md describes MATLAB app (bc_osc_matlab), not SAS | CHANGELOG.md:11, 23, 55 |
| Form help references wrong software | QUA-05 | FAIL | medium | `sas_version` help says "Loading the Matlab module" | form.yml:61 |
| Troubleshooting has template placeholders | QUA-05 | WARN | low | Generic "module load software/1.0" and nonexistent "modules" attribute | README.md:165, 170 |
| Duplicate YAML key in custom_num_cores | QUA-06 | WARN | low | Duplicate `help` key; first value silently discarded | form.yml:44 |
| Duplicate YAML key in custom_num_gpus | QUA-06 | WARN | low | Duplicate `help` key; first value silently discarded | form.yml:54 |
| Cluster name inconsistency | QUA-06 | WARN | low | README says "odyssey"; form.yml has "odyssey3" | README.md:117, form.yml:3 |
| README typos | QUA-06 | WARN | low | "notificationl", "forml.yml", "Univesity" | README.md:125, 137, 235 |

## Review scope

**Examined:** `manifest.yml`, `form.yml`, `submit.yml.erb`, `template/script.sh.erb`, `template/before.sh.erb`, `template/config/` (xfce4-panel.xml, xfce-applications.menu, terminalrc), `README.md`, `LICENSE.txt`, `CHANGELOG.md`, `.gitignore`, `icon.png`, `images/` (screenshots); GitHub API (archived status, releases, tags, contributors, issues); static analysis with shellcheck and semgrep.
**Not examined:** runtime behavior (Tier 3 — no isolated execution environment); trivy (not installed); rubocop (not installed).

## Catalog checks

- Duplicate check against the existing catalog — no SAS app found in the published catalog (100 apps queried via JSON:API).
  - **Duplicate-check rationale:** _No existing SAS app in the Appverse catalog. This is a new submission for SAS software. No duplicate._
- `software` value matches a catalog Software entry — not directly applicable for inferred repo (no `appverse.yml` with `software` field); however, a "SAS" Software entry does exist in the catalog.
- `app_type` and `implementation_tags` are in the catalog vocabularies — not applicable for inferred repo (no `appverse.yml`).

## Overall recommendation

The app passes all gate criteria: the README is substantive, the MIT license is present, `manifest.yml` has all required fields, YAML files are valid, and the Batch Connect layout is complete. Documentation is Adequate and configuration is Partially portable, both meeting their targets for inclusion. The catalog has no existing SAS app (not a duplicate) and a SAS Software entry exists. However, the app has clear improvement areas: the CHANGELOG and a form help string are copy-pasted from a MATLAB template and describe the wrong software, the main job script lacks error handling (`set -e`), and two numeric form fields are missing upper bounds. Three Low-severity security findings note unsanitized pass-through of extra Slurm options, unquoted shell variables, and debug tracing left enabled. The recommendation is **Accept with suggestions**.

---

## Draft feedback — edit before sending.

Thank you for submitting ood-sas to the Appverse. The app is well-structured as a Batch Connect VNC desktop app, the README covers installation and configuration clearly, and all gate criteria pass. Below are suggestions to improve the app before or after listing.

**Copy-paste artifacts from the MATLAB template.** The `CHANGELOG.md` (lines 11, 23, 55) describes MATLAB version additions and links to `OSC/bc_osc_matlab` — please rewrite it to document SAS changes. In `form.yml` (line 61), the `sas_version` help text reads "Loading the Matlab module for requested version" — update this to reference SAS. In `README.md` (lines 165 and 170), the Troubleshooting section contains template placeholder text ("module load software/1.0" and "update the `modules` attribute") that should reference the actual SAS module name and the `sas_version` attribute.

**Error handling.** In `template/script.sh.erb` (line 19), the script uses `set -x` for debug tracing but does not include `set -e` or explicit error checks. Adding `set -e` would catch failures in `module purge` (line 17), `mkdir -p` (line 22), `cd` (line 25), and `module load` (line 64) rather than letting the script continue silently. See the [Best Practices Guide](https://openondemand.connectci.org/appverse-best-practices) for error handling recommendations.

**Input validation.** In `form.yml`, `custom_memory_per_node` (line 34) and `custom_num_cores` (line 39) have `min` bounds but no `max` bounds, allowing users to request arbitrarily large values. Adding `max` values appropriate for your cluster would prevent accidental over-requests. Also, `form.yml` has duplicate `help` keys under `custom_num_cores` (line 44) and `custom_num_gpus` (line 54) — YAML last-wins parsing silently discards the first value in each pair; consolidate them into a single `help` entry per attribute.

**Portability.** In `template/script.sh.erb` (line 21), the scratch directory path `/scratch/$USER/$SLURM_JOBID` is hardcoded and not documented in the README configuration table. Consider making it configurable or documenting it so deployers at other sites know to update it. In `form.yml` (line 26), the `bc_queue` help text links to a Harvard-specific URL (`docs.rc.fas.harvard.edu`); other sites would need to replace this.

**Security (low severity).** In `submit.yml.erb` (line 16), the `extra_slurm` text field passes unsanitized user input to sbatch native options. Since this runs under the PUN (per-user Nginx) model, the blast radius is self-harm only, but adding a `pattern` constraint on the form field would be a defensive improvement. In `template/script.sh.erb`, several shell variables are unquoted (`$WORKDIR` at lines 22 and 25, `$COMMAND` at line 72 with `eval exec`); quoting them is good defensive practice. The `set -x` debug tracing (line 19) outputs all commands to the job log, which could expose paths and module names on shared filesystems — consider removing it or gating it behind a debug flag.

**Minor polish.** In `template/script.sh.erb` (lines 33–42 and 78–95), approximately 25 lines of commented-out Singularity/container code remain — consider removing them to reduce confusion. The hex color `#D3D3D3` on line 46 would benefit from a brief comment. In `submit.yml.erb` (lines 6–7), `custom_reservation` and `custom_email_address` are used without `.blank?` guards, unlike the memory and time values on lines 9–11; adding guards would prevent empty strings from reaching the scheduler. In `README.md`, the configuration table says the cluster is "odyssey" (line 117) but `form.yml` has "odyssey3" (line 3) — update one to match. The panel icon in `template/config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml` (line 40) is `fedora-logo-icon`, which may not exist on the Rocky 8 systems listed in the Testing table. The README also has minor typos: "notificationl" (line 125), "forml.yml" (line 137), and "Univesity" (line 235).

Maintenance-wise, the repo is active and has multiple contributors, which are positive signals. Consider tagging releases to help deployers track updates, and adding a CI workflow for YAML/shell linting. The CHANGELOG issue is covered above under copy-paste artifacts.

<!-- feedback-covers: submit.yml.erb:unsanitized-user-input, template/script.sh.erb:unquoted-variable, template/script.sh.erb:debug-tracing-enabled, template/script.sh.erb:no-set-e, form.yml:missing-min-max, template/script.sh.erb:commented-out-code, template/script.sh.erb:undocumented-hex-color, submit.yml.erb:erb-missing-value-unhandled, CHANGELOG.md:wrong-app-changelog, form.yml:wrong-app-reference, README.md:template-placeholder, form.yml:duplicate-yaml-key:custom_num_cores.help, form.yml:duplicate-yaml-key:custom_num_gpus.help, README.md:readme-inconsistency:cluster-name, template/config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml:incorrect-default, README.md:readme-typo, template/script.sh.erb:hardcoded-path, form.yml:hardcoded-path -->
