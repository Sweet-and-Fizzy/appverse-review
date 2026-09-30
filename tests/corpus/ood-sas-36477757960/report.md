# Appverse Review: ood-sas

**Repository:** https://github.com/fasrc/ood-sas  **Mode:** reviewer  **Date:** 2026-09-28
**Reviewed commit:** `462790a1fdd1616038ea3536454a4e508c668471` (2026-07-08)  **Repo shape:** inferred single app
**Reviewed with:** appverse-review @ 0.4.0 (`e548bfa`, https://github.com/Sweet-and-Fizzy/appverse-review) · **Model:** claude-sonnet-4-6 · **Rubric:** https://openondemand.connectci.org/appverse-review-rubric

> _Disclaimer: This is an automated review with human curation. It is provided without warranty of any kind and does not certify the app as secure or fit for any purpose. A listing is not an endorsement._

## Repo-level gate criteria

| Rule | Result | Evidence |
|---|---|---|
| — | PASS | Repository public and accessible (clone succeeded) |
| STR-01 | PASS | `README.md` — present and substantive; multiple sections covering overview, requirements, installation, configuration, troubleshooting, testing, known limitations |
| STR-01 | PASS | `LICENSE.txt` — MIT license |
| — | PASS | Repo shape identifiable — root `manifest.yml` (inferred single app) |
| — | PASS | Repo not archived — active, last commit 2026-07-08 |

## Upkeep

| Signal | Value | Assessment |
|---|---|---|
| Last commit | 2026-07-08 (~82 days ago) | Active within 12 months |
| Releases | No git tags found | No tagged releases |
| Issues responsiveness | NOT CHECKED (GitHub API unavailable) | — |
| Contributors | NOT CHECKED (git shortlog unavailable in environment) | — |
| CHANGELOG | Present but entire content describes MATLAB / OSC (copy-paste artifact; not current for this app) | Concern |
| CI | No `.github/workflows/` directory | No CI present |

| Dimension | Level | Evidence |
|---|---|---|
| Upkeep (repo-level) | Medium | Active within 12 months; zero confirmed good-practice signals (releases absent, changelog invalid, CI absent; contributors and issue responsiveness not checked) |

## App: SAS (root)

### Signals

| Dimension | Level | Evidence |
|---|---|---|
| Security | High | One medium-severity OODT-01 finding: unsanitized `extra_slurm` text field passes user-supplied tokens as native sbatch arguments |
| Portability | Medium | Partially portable — cluster name and module version documented as needing change; `/scratch` path and FASRC-specific URL in form help are undocumented site-specific values |
| Documentation | Medium | Adequate — covers what it launches, prerequisites, installation, configuration, and known limitations; missing environment variable documentation blocks Strong |

### Structure

| Rule | Result | Severity | Summary | Evidence |
|---|---|---|---|---|
| STR-02 | PASS | — | Required `manifest.yml` fields present (`name`, `category`, `role`, `description`) | `manifest.yml:1-11` |
| STR-03 | PASS | — | `manifest.yml` and `form.yml` parse without errors | `manifest.yml`, `form.yml` |
| STR-07 | PASS | — | Standard Batch Connect layout: `form.yml`, `submit.yml.erb`, `template/script.sh.erb` all present | `form.yml`, `submit.yml.erb`, `template/` |
| STR-04 | PASS | — | No broken references — all variables in `submit.yml.erb` and ERB context references in `template/script.sh.erb` resolve to `form.yml` attributes or built-in OOD methods | `submit.yml.erb`, `template/script.sh.erb` |
| STR-05 | PASS | — | ERB tags balanced in `submit.yml.erb` and `template/script.sh.erb` | `submit.yml.erb`, `template/script.sh.erb` |
| STR-06 | PASS | — | Shell syntax clean after ERB stripping (`bash -n` exit 0) | `template/script.sh.erb` |

### Security

Findings are classified under OODT (Open OnDemand App Threats); codes are defined in the rubric's Security section.

**Check tiers:** Tiers 1–2
Tier 3 not checked — no isolated execution environment

| Tool | Status | Result |
|---|---|---|
| shellcheck | Ran (on ERB-stripped `script.sh.erb`) | SC2086 (×2 — unquoted `$WORKDIR`, `$COMMAND`), SC2164 (`cd` without `\|\| exit`), SC2143 (style) |
| semgrep | Available but blocked by review sandbox | Not run |
| bandit | N/A | No Python files |
| trivy | N/A | No dependency manifests or container definitions |

**Capability profile — Batch Connect (TurboVNC/Xfce)**

| Capability | Files | Anomalies |
|---|---|---|
| Form field presentation (time, queue, account, email, memory, cores, GPUs, SAS version, reservation, extra Slurm options) | `form.yml` | `extra_slurm` is a free-text field with no constraint or pattern; memory and cores fields lack `max` |
| Maps form values to Slurm native options; splits `extra_slurm` on whitespace and injects tokens | `submit.yml.erb` | Unsanitized `extra_slurm` tokens reach `sbatch` |
| Loads SAS module; launches Xfce WM, panel, and SAS GUI via `xfce4-terminal`; manages OOM score | `template/script.sh.erb` | `eval exec $COMMAND` with unquoted variable; `set -x` active throughout |
| Exports `module` function if available | `template/before.sh.erb` | None |
| Static Xfce panel layout; `button-icon: fedora-logo-icon` | `template/config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml` | Fedora-specific icon on Rocky 8 system (quality, not security) |

Batch Connect baseline checks: no outbound `curl`/`wget` in ERB, no `Net::HTTP`, no SSH key reads, no base64-decode-execute, no dotfile writes, no cron installs, no binary files in `template/`. Profile is consistent with the narrow Batch Connect baseline.

#### Findings

| Rule | Result | Severity | Tag | Summary | Evidence |
|---|---|---|---|---|---|
| OODT-01 | FAIL | medium | unintentional | Free-text `extra_slurm` field passes user-supplied whitespace-split tokens as unsanitized native `sbatch` arguments; a token such as `--wrap=cmd` can substitute an arbitrary command for the OOD-generated job script on the compute node | `submit.yml.erb:15-18` |
| OODT-01 | WARN | low | unintentional | `eval exec $COMMAND` uses an unquoted variable (shellcheck SC2086); `COMMAND` is currently a static string but the `eval`-with-unquoted-variable pattern is an unsafe sink if the assignment ever incorporates user-derived input | `template/script.sh.erb:72` |
| OODT-08 | FAIL | low | unintentional | `set -x` is active throughout the job script (set at line 19, resumed at line 44), tracing all executed commands and their arguments to the job output files owned by the submitting user | `template/script.sh.erb:19,44` |

### Portability

- Rating: **Partially portable** — cluster name and SAS module version are hardcoded but documented in the README configuration table; `/scratch` scratch path in the job script and a site-specific URL in a form help tooltip are undocumented.

  - `form.yml:3` — `cluster: "odyssey3"` — documented in README as needing change
  - `form.yml:63` — `options: ["SAS 9.4", "sas/9.4-fasrc01"]` — FASRC-specific module string, documented in README as needing change
  - `form.yml:26` — `bc_queue` help text embeds a link to `docs.rc.fas.harvard.edu` (FASRC partition docs), shown to users at any deploying site without a note that it is institution-specific
  - `template/script.sh.erb:21` — `WORKDIR=/scratch/$USER/$SLURM_JOBID` hardcodes an FASRC-specific scratch filesystem path not present at all sites and not documented in the README configuration table

### Documentation

- Rating: **Adequate** — README answers all four Adequate-rung questions (what it launches, prerequisites, installation, configuration) and also provides known limitations, troubleshooting, and screenshots; missing environment variable documentation blocks the Strong rung.
- Evidence per rung:
  - what it launches: README lines 26–31 ("SAS is an Open OnDemand Batch Connect app that launches SAS as an interactive desktop session on HPC clusters")
  - prerequisites: README lines 64–82 (SAS Lmod module, Xfce 4+, TurboVNC 2.1+, websockify 0.8.0+, OOD v3.0+, Slurm)
  - installation: README lines 84–152 (clone, configure, verify steps with `git clone` command)
  - configuration: README lines 99–129 (form.yml and submit.yml.erb attribute tables with FASRC settings and "change to" columns)
  - known limitations: README lines 197–202 (multi-node unsupported, Rocky 8/CentOS 7 only)
  - troubleshooting: README lines 159–176 (three common failure scenarios)
  - screenshots: README lines 43–48 (`images/sas_desktop.png`, `images/sas_plot_example.png`)
  - environment variables: none — no section documents env vars exported or consumed by the job script — blocks Strong
  - info panel: none — blocks Exemplary
  - architecture: none — blocks Exemplary

### Code Quality

| Check | Rule | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| Error handling in scripts | QUA-03 | FAIL | medium | `set -x` present for tracing but `set -e` absent; errors in `module load`, `mkdir`, `xfwm4`, `xsetroot`, and `xfsettingsd` are silently ignored | `template/script.sh.erb:19` |
| Input validation on form fields (`check: numeric-field-bounds`) | QUA-07 | FAIL | medium | `custom_memory_per_node` and `custom_num_cores` define `min` and `step` but no `max`; unbounded resource requests reach the scheduler | `form.yml:31-35,39-43` |
| Input validation on form fields (text fields to scheduler) | QUA-07 | FAIL | medium | Four `text_field` attributes that reach the scheduler have no `pattern` constraint: `custom_time` (line 16), `custom_email_address` (line 27), `custom_reservation` (line 65), `extra_slurm` (line 72) | `form.yml:16,27,65,72` |
| Magic numbers / undocumented literals | QUA-08 | WARN | low | `xsetroot -solid "#D3D3D3"` hardcodes a desktop background color with no inline comment | `template/script.sh.erb:46` |
| Magic numbers / undocumented literals (Xfce panel) | QUA-08 | WARN | low | Xfce panel config contains undocumented bare values: position `p=6;x=99;y=24`, size `48`, length `100` without comments | `template/config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml:8,10,11` |
| Duplicated code blocks | QUA-09 | PASS | — | No large duplicated code blocks found | `template/script.sh.erb` |
| Commented-out dead code | QUA-04 | WARN | low | Two large blocks of commented-out code remain: a heredoc wrapping approach (lines 34–57) and a Singularity container approach (lines 78–94); neither is used | `template/script.sh.erb:34-57,78-94` |
| ERB handles missing/empty values | QUA-10 | WARN | low | `reservation_id` (line 6) and `email` (line 7) are rendered without blank guards; other fields on lines 9–11 use `.blank?` guards | `submit.yml.erb:6-7` |
| Desktop/panel icon matches target OS (`check: icon-matches-target-os`) | QUA-06 | WARN | low | Applications menu `button-icon` is `fedora-logo-icon` (Fedora-specific); README documents testing on Rocky 8 only | `template/config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml:41` |
| CHANGELOG copy-paste artifact | QUA-05 | WARN | medium | Entire CHANGELOG copied from `OSC/bc_osc_matlab`: all version entries describe MATLAB releases and all comparison links point to `github.com/OSC/bc_osc_matlab` | `CHANGELOG.md:9-62` |
| Copy-paste wrong-app reference in form help | QUA-05 | WARN | low | `sas_version` help text reads "Loading the Matlab module for requested version" — a copy-paste artifact from a MATLAB app | `form.yml:60-61` |
| Duplicate YAML keys — `custom_num_cores.help` | QUA-06 | WARN | low | `custom_num_cores` has two `help:` keys (lines 44 and 45–46); YAML last-wins silently drops the first value ("Number of Cpus to allocate") | `form.yml:44-45` |
| Duplicate YAML keys — `custom_num_gpus.help` | QUA-06 | WARN | low | `custom_num_gpus` has two `help:` keys (lines 54 and 55–56); YAML last-wins silently drops the first value ("Number of GPUs to allocate. Available only on GPU enabled partitions") | `form.yml:54-56` |
| README typos | QUA-06 | WARN | low | "notificationl" (line 125) and "Harvard Univesity" (line 234) | `README.md:125,234` |

## Review scope

**Examined:** `manifest.yml`, `README.md`, `LICENSE.txt`, `form.yml`, `submit.yml.erb`, `template/script.sh.erb`, `template/before.sh.erb`, `template/config/menus/xfce-applications.menu`, `template/config/xfce4/terminal/terminalrc`, `template/config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml`, `.gitignore`, `CHANGELOG.md`; shellcheck on ERB-stripped `script.sh.erb`; catalog JSON:API queries (duplicate check, software entry, vocabularies)

**Not examined:** Runtime behavior (Tier 3 — no isolated execution environment); semgrep (blocked by review sandbox); contributor count and issue responsiveness (git shortlog and GitHub API unavailable in this environment — reviewer should check manually)

## Catalog checks

- Duplicate check against the existing catalog — **No SAS app found** in the 100-app catalog listing queried via JSON:API.
  - **Duplicate-check rationale:** _No existing SAS app appears in the Appverse catalog. The catalog contains Stata (a different stats package) and MATLAB apps but no SAS app. This submission is not a duplicate. A deployer searching for a SAS OOD app would find no existing option, so the app fills a real catalog gap._
- `software` value matches a catalog Software entry — **N/A** (inferred repo; `manifest.yml` has no `software` field). A "SAS" Software entry was confirmed present in the catalog via JSON:API — when this app is promoted to a declared repo with `appverse.yml`, the `software` value should be set to `SAS`.
- `app_type` and `implementation_tags` are in the catalog vocabularies — **N/A** (inferred repo; neither field appears in `manifest.yml`). For reference, the catalog's `app_type` vocabulary includes `batch-connect-VNC` which would be appropriate for this app.

## Overall recommendation

**Accept with suggestions** — pending manual confirmation of the catalog checks the automated review cannot settle (contributor count, issue responsiveness). All repo-level gate criteria pass: the repository is public, has a substantive README, an MIT license, an identifiable shape (`manifest.yml`), and is not archived. Documentation is Adequate and portability is Partially portable, both at or above the target for inclusion. The app is actively maintained (last commit 82 days ago). The one medium-severity security finding — the `extra_slurm` free-text field passing unsanitized tokens to `sbatch` (`submit.yml.erb:15-18`) — is fixable with targeted changes and is tagged unintentional; per the rubric, medium-severity findings do not block an "accept with suggestions" outcome. The improvement areas below should be addressed before or shortly after listing.

---

## Draft feedback — edit before sending

Thank you for submitting ood-sas to the Appverse. The app passes all structural gate criteria and meets the documentation and portability targets for listing. The points below are things to address to make the app easier to deploy and maintain at other sites.

**Security — `extra_slurm` field (submit.yml.erb, lines 15–18):** The `extra_slurm` free-text field splits user input on whitespace and injects each token as a raw native `sbatch` argument with no constraint. A user can supply `--wrap=any_command` as a single whitespace-free token, substituting an arbitrary shell command for the OOD-generated job script. The simplest fix is to remove the field and expose only the specific options your users need as dedicated form fields. If you want to keep a pass-through field, add a `pattern` attribute that restricts it to known-safe option syntax and document the limitation in the form help text. See the [Appverse Best Practices guide](https://openondemand.connectci.org/appverse-best-practices) for input-validation patterns. Related: `submit.yml.erb` lines 6–7 (`reservation_id` and `email`) render optional fields directly without the `.blank?` guards used on lines 9–11; adding those guards prevents empty-string values from reaching `sbatch` when users leave those fields blank.

**Error handling — script.sh.erb:** The script sets `set -x` (line 19) for tracing but omits `set -e`; errors in `module purge`, `mkdir`, `xfwm4`, `xsetroot`, and `xfsettingsd` are silently swallowed and the job continues regardless. Add `set -e` near the top of `template/script.sh.erb` to abort on errors and produce a clear failure message in the output log. Also, `cd $WORKDIR` (line 25) lacks an `|| exit 1` guard — if the scratch directory was not created, the script silently continues in the wrong directory. Related: `eval exec $COMMAND` at line 72 uses an unquoted variable (`$COMMAND`); while the string is currently static, this pattern is an unsafe sink if the variable assignment ever incorporates user input — replace `eval exec $COMMAND` with the literal `exec xfce4-terminal -e "/bin/bash -l -c \"sas -dms\" "` directly. Finally, `set -x` remains active through the entire script (line 19 and resumed at line 44), tracing all commands to the job output files; consider removing it or guarding it with a debug flag before production listing.

**Input validation — form.yml:** `custom_memory_per_node` (lines 31–35) and `custom_num_cores` (lines 39–43) define `min` and `step` but have no `max`; a user can request arbitrarily large allocations. Add a reasonable `max` for each. Four `text_field` attributes that reach the scheduler have no `pattern` constraint: `custom_time` (line 16), `custom_email_address` (line 27), `custom_reservation` (line 65), and `extra_slurm` (line 72). Add `pattern` attributes or helper text that restricts these to valid inputs.

**Portability — form.yml and script.sh.erb:** `cluster: "odyssey3"` (form.yml line 3) and the module option `"sas/9.4-fasrc01"` (form.yml line 63) are already documented in the README configuration table — thank you. Two undocumented site-specific values remain: the `WORKDIR=/scratch/$USER/$SLURM_JOBID` path (template/script.sh.erb line 21) assumes a `/scratch` filesystem that may not exist at other sites; add a note to the README configuration table telling deployers to update this path. The `bc_queue` help text (form.yml line 26) embeds a link to `docs.rc.fas.harvard.edu` which will appear in the form at any site — replace it with a generic description or make it configurable.

**Copy-paste artifacts:** The `CHANGELOG.md` content was copied from `OSC/bc_osc_matlab`: all version entries describe MATLAB releases (e.g., "Added MATLAB version 2018a" at line 9) and all comparison links (lines 55–62) point to `github.com/OSC/bc_osc_matlab`. Please replace this with a CHANGELOG that describes the actual history of this SAS app, or start fresh from the current version. Similarly, `form.yml` line 61 reads "Loading the Matlab module for requested version" — this should say "SAS module."

**Duplicate YAML keys in form.yml:** `custom_num_cores` has two `help:` keys (lines 44 and 45–46), and `custom_num_gpus` has two `help:` keys (lines 54 and 55–56). YAML's last-wins rule silently discards the first definition in each case. Remove the duplicate keys, keeping the `help: |` block on lines 45–46 and 55–56 (which are the ones that survive).

**Minor polish:** The Xfce panel config at `template/config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml` line 41 sets `button-icon="fedora-logo-icon"`, a Fedora-specific icon; the README documents testing on Rocky 8 only, so this icon is unlikely to render. Replace it with a Rocky 8-compatible icon name such as `start-here` or `distributor-logo`. The same `xfce4-panel.xml` file also has undocumented magic numbers at lines 8, 10, and 11 (panel position `p=6;x=99;y=24`, size `48`, length `100`) with no comments; add brief comments if deployers may need to adjust them. In `README.md`, fix two typos: "notificationl" (line 125, should be "notification") and "Harvard Univesity" (line 234, should be "University"). The large commented-out blocks in `template/script.sh.erb` (lines 34–57 and 78–94 — a heredoc wrapping approach and an unused Singularity approach) add noise; remove them if they are not planned for future use.

**Suggestions for future improvement:** The repository has no tagged releases and no CI workflow. Adding a simple GitHub Actions workflow to run `shellcheck` and YAML validation on pull requests would catch issues early. Adding version tags would give deployers a stable reference to pin to and would make the CHANGELOG more useful.

<!-- feedback-covers: submit.yml.erb:unsanitized-user-input, submit.yml.erb:erb-missing-value-unhandled, template/script.sh.erb:no-set-e, template/script.sh.erb:eval-exec, template/script.sh.erb:debug-tracing-enabled, form.yml:missing-min-max, form.yml:other:missing-pattern-constraint, template/script.sh.erb:hardcoded-path, form.yml:site-specific-mixin, CHANGELOG.md:wrong-app-changelog, form.yml:wrong-app-reference, form.yml:duplicate-yaml-key:custom_num_cores.help, form.yml:duplicate-yaml-key:custom_num_gpus.help, template/config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml:incorrect-default, README.md:readme-typo, template/script.sh.erb:commented-out-code, template/script.sh.erb:undocumented-hex-color, template/config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml:magic-number, form.yml:hardcoded-cluster, form.yml:hardcoded-module-version -->

---

```json
[
  {
    "app_id": "root",
    "rule": "OODT-01",
    "defect_key": "submit.yml.erb:unsanitized-user-input",
    "aspect": "security",
    "severity": "medium",
    "result": "FAIL",
    "tag": "unintentional",
    "summary": "Free-text `extra_slurm` field passes user-supplied whitespace-split tokens as unsanitized native sbatch arguments; a token such as `--wrap=cmd` can substitute an arbitrary command for the OOD-generated job script on the compute node.",
    "evidence": "submit.yml.erb:15-18",
    "line": 15
  },
  {
    "app_id": "root",
    "rule": "OODT-01",
    "defect_key": "template/script.sh.erb:eval-exec",
    "aspect": "security",
    "severity": "low",
    "result": "WARN",
    "tag": "unintentional",
    "summary": "`eval exec $COMMAND` at line 72 uses an unquoted variable (shellcheck SC2086); COMMAND is currently a static string but the eval-with-unquoted-variable pattern is an unsafe sink if the assignment ever incorporates user-derived input.",
    "evidence": "template/script.sh.erb:72",
    "line": 72
  },
  {
    "app_id": "root",
    "rule": "OODT-08",
    "defect_key": "template/script.sh.erb:debug-tracing-enabled",
    "aspect": "security",
    "severity": "low",
    "result": "FAIL",
    "tag": "unintentional",
    "summary": "`set -x` is active throughout the job script (set at line 19, resumed at line 44), tracing all executed commands and their arguments to the job output files.",
    "evidence": "template/script.sh.erb:19,44",
    "line": 19
  },
  {
    "app_id": "root",
    "rule": "QUA-02",
    "defect_key": "form.yml:hardcoded-cluster",
    "aspect": "quality",
    "severity": "medium",
    "result": "WARN",
    "summary": "cluster: \"odyssey3\" is hardcoded to an FASRC-specific cluster name; deployers at other sites must change it. Documented in the README configuration table.",
    "evidence": "form.yml:3",
    "line": 3
  },
  {
    "app_id": "root",
    "rule": "QUA-02",
    "defect_key": "form.yml:hardcoded-module-version",
    "aspect": "quality",
    "severity": "medium",
    "result": "WARN",
    "summary": "sas_version option value \"sas/9.4-fasrc01\" is an FASRC-specific Lmod module string; deployers must substitute their own module name. Documented in the README configuration table.",
    "evidence": "form.yml:63",
    "line": 63
  },
  {
    "app_id": "root",
    "rule": "QUA-02",
    "defect_key": "form.yml:site-specific-mixin",
    "aspect": "quality",
    "severity": "low",
    "result": "WARN",
    "summary": "bc_queue help text embeds a link to docs.rc.fas.harvard.edu (FASRC partition docs), which will appear in the OOD form at any deploying site without a note that it is institution-specific.",
    "evidence": "form.yml:26",
    "line": 26
  },
  {
    "app_id": "root",
    "rule": "QUA-02",
    "defect_key": "template/script.sh.erb:hardcoded-path",
    "aspect": "quality",
    "severity": "medium",
    "result": "WARN",
    "summary": "WORKDIR=/scratch/$USER/$SLURM_JOBID hardcodes an FASRC-specific scratch filesystem path that may not exist at other sites; not documented in the README configuration table.",
    "evidence": "template/script.sh.erb:21",
    "line": 21
  },
  {
    "app_id": "root",
    "rule": "QUA-03",
    "defect_key": "template/script.sh.erb:no-set-e",
    "aspect": "quality",
    "severity": "medium",
    "result": "FAIL",
    "summary": "Script sets set -x for tracing but omits set -e; errors in module load, mkdir, xfwm4, xsetroot, and xfsettingsd commands are silently ignored, making failures hard to diagnose.",
    "evidence": "template/script.sh.erb:19",
    "line": 19
  },
  {
    "app_id": "root",
    "rule": "QUA-04",
    "defect_key": "template/script.sh.erb:commented-out-code",
    "aspect": "quality",
    "severity": "low",
    "result": "WARN",
    "summary": "Two large blocks of commented-out code remain in the script: a heredoc wrapping approach (lines 34-57) and a Singularity container approach (lines 78-94); neither is used and both add noise.",
    "evidence": "template/script.sh.erb:34-57,78-94",
    "line": 34
  },
  {
    "app_id": "root",
    "rule": "QUA-05",
    "defect_key": "CHANGELOG.md:wrong-app-changelog",
    "aspect": "quality",
    "severity": "medium",
    "result": "WARN",
    "summary": "The entire CHANGELOG was copied from OSC/bc_osc_matlab: all version entries describe MATLAB releases, and all comparison links point to github.com/OSC/bc_osc_matlab.",
    "evidence": "CHANGELOG.md:9-62",
    "line": 9
  },
  {
    "app_id": "root",
    "rule": "QUA-05",
    "defect_key": "form.yml:wrong-app-reference",
    "aspect": "quality",
    "severity": "low",
    "result": "WARN",
    "summary": "sas_version help text reads \"Loading the Matlab module for requested version\" — a copy-paste artifact from a MATLAB app; the field loads a SAS module.",
    "evidence": "form.yml:60-61",
    "line": 61
  },
  {
    "app_id": "root",
    "rule": "QUA-06",
    "defect_key": "form.yml:duplicate-yaml-key:custom_num_cores.help",
    "aspect": "quality",
    "severity": "low",
    "result": "WARN",
    "summary": "custom_num_cores has two help: keys (lines 44 and 45-46); YAML last-wins silently drops the first value (\"Number of Cpus to allocate\").",
    "evidence": "form.yml:44-45",
    "line": 44
  },
  {
    "app_id": "root",
    "rule": "QUA-06",
    "defect_key": "form.yml:duplicate-yaml-key:custom_num_gpus.help",
    "aspect": "quality",
    "severity": "low",
    "result": "WARN",
    "summary": "custom_num_gpus has two help: keys (lines 54 and 55-56); YAML last-wins silently drops the first value (\"Number of GPUs to allocate. Available only on GPU enabled partitions\").",
    "evidence": "form.yml:54-56",
    "line": 54
  },
  {
    "app_id": "root",
    "rule": "QUA-06",
    "defect_key": "template/config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml:incorrect-default",
    "aspect": "quality",
    "severity": "low",
    "result": "WARN",
    "summary": "Applications menu button-icon is set to \"fedora-logo-icon\", a Fedora-specific icon; the README documents testing on Rocky 8 only, where this icon may not be present.",
    "evidence": "template/config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml:41",
    "line": 41
  },
  {
    "app_id": "root",
    "rule": "QUA-06",
    "defect_key": "README.md:readme-typo",
    "aspect": "quality",
    "severity": "low",
    "result": "WARN",
    "summary": "Two typos in README.md: \"notificationl\" (line 125, should be \"notification\") and \"Harvard Univesity\" (line 234, should be \"University\").",
    "evidence": "README.md:125,234",
    "line": 125
  },
  {
    "app_id": "root",
    "rule": "QUA-07",
    "defect_key": "form.yml:missing-min-max",
    "aspect": "quality",
    "severity": "medium",
    "result": "FAIL",
    "summary": "custom_memory_per_node and custom_num_cores both define min and step but have no max; a user can request arbitrarily large memory or core counts that reach the scheduler unchecked.",
    "evidence": "form.yml:31-35,39-43",
    "line": 31
  },
  {
    "app_id": "root",
    "rule": "QUA-07",
    "defect_key": "form.yml:other:missing-pattern-constraint",
    "aspect": "quality",
    "severity": "medium",
    "result": "FAIL",
    "summary": "Four text_field attributes that reach the scheduler have no pattern constraint: custom_time (line 16), custom_email_address (line 27), custom_reservation (line 65), extra_slurm (line 72); arbitrary strings can be passed to sbatch.",
    "evidence": "form.yml:16,27,65,72",
    "line": 16
  },
  {
    "app_id": "root",
    "rule": "QUA-08",
    "defect_key": "template/script.sh.erb:undocumented-hex-color",
    "aspect": "quality",
    "severity": "low",
    "result": "WARN",
    "summary": "xsetroot -solid \"#D3D3D3\" at line 46 hardcodes a desktop background color with no inline comment explaining the choice.",
    "evidence": "template/script.sh.erb:46",
    "line": 46
  },
  {
    "app_id": "root",
    "rule": "QUA-08",
    "defect_key": "template/config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml:magic-number",
    "aspect": "quality",
    "severity": "low",
    "result": "WARN",
    "summary": "Xfce panel configuration contains undocumented bare values: position string \"p=6;x=99;y=24\" (line 8), size 48 (line 10), and length 100 (line 11); no comments explain these choices.",
    "evidence": "template/config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml:8,10,11",
    "line": 8
  },
  {
    "app_id": "root",
    "rule": "QUA-09",
    "defect_key": "template/script.sh.erb:duplicated-block",
    "aspect": "quality",
    "severity": "info",
    "result": "PASS",
    "summary": "No large duplicated code blocks found.",
    "evidence": "template/script.sh.erb"
  },
  {
    "app_id": "root",
    "rule": "QUA-10",
    "defect_key": "submit.yml.erb:erb-missing-value-unhandled",
    "aspect": "quality",
    "severity": "low",
    "result": "WARN",
    "summary": "submit.yml.erb renders optional fields reservation_id (line 6) and email (line 7) directly without blank guards; other fields on lines 9-11 use .blank? guards. A blank custom_reservation or custom_email_address emits an empty value that may cause sbatch errors.",
    "evidence": "submit.yml.erb:6-7",
    "line": 6
  },
  {
    "app_id": "root",
    "rule": "MNT-02",
    "defect_key": "releases:no-releases",
    "aspect": "maintenance",
    "severity": "info",
    "result": "WARN",
    "summary": "No tagged releases found; the repository has no versioned release history.",
    "evidence": "git tag output: empty"
  },
  {
    "app_id": "root",
    "rule": "MNT-04",
    "defect_key": ".github/workflows:no-ci",
    "aspect": "maintenance",
    "severity": "info",
    "result": "FAIL",
    "summary": "No CI configuration present; no .github/workflows/ directory found in the repository.",
    "evidence": ".github/workflows/ (absent)"
  }
]
```
