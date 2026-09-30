# Appverse Review: ood-sas

**Repository:** https://github.com/fasrc/ood-sas  **Mode:** reviewer  **Date:** 2026-09-29
**Reviewed commit:** `462790a1fdd1616038ea3536454a4e508c668471` (2026-07-08)  **Repo shape:** inferred single app
**Reviewed with:** appverse-review @ 0.6.0 (`d432e8d`, https://github.com/Sweet-and-Fizzy/appverse-review) · **Model:** claude-sonnet-4-6 · **Rubric:** https://openondemand.connectci.org/appverse-review-rubric

> _Disclaimer: This is an automated review with human curation. It is provided without warranty of any kind and does not certify the app as secure or fit for any purpose. A listing is not an endorsement._

## Repo-level gate criteria

| Rule | Result | Evidence |
|---|---|---|
| — | PASS | Repository public and accessible — clone succeeded |
| STR-01 | PASS | README.md — substantive content present (overview, requirements, installation, configuration, troubleshooting, screenshots) |
| STR-01 | PASS | LICENSE — LICENSE.txt with MIT license text |
| — | PASS | Repo not archived — recent commit 2026-07-08 and clone succeeded |

## Upkeep

| Signal | Value | Assessment |
|---|---|---|
| Last commit | 2026-07-08 (83 days ago) | Active within 12 months |
| Releases | 0 tagged releases | Concern |
| Issues responsiveness | 0 open issues | Neutral — no open issues to respond to |
| Contributors | 4 | Good sign — multiple contributors |
| CHANGELOG | File present; all entries describe bc_osc_matlab (MATLAB) and link to OSC/bc_osc_matlab; [Unreleased] empty | Not current for this app |
| CI | No .github/workflows/ directory | Absent |

| Dimension | Level | Evidence |
|---|---|---|
| Upkeep (repo-level) | Medium | Active (last commit 2026-07-08), 4 contributors; no releases, no CI, CHANGELOG is bc_osc_matlab copy-paste |

## App: SAS (root)

### Signals

| Dimension | Level | Evidence |
|---|---|---|
| Portability | Medium | Cluster name and module suffix hardcoded in form.yml but documented in README for customization |
| Documentation | Medium | Adequate — overview, prerequisites, installation, configuration, known limitations, troubleshooting, and screenshots present; no environment variable documentation section |

### Structure

| Rule | Result | Severity | Summary | Evidence |
|---|---|---|---|---|
| STR-02 | PASS | — | manifest.yml required fields | name, category, role, description all present |
| STR-03 | PASS | — | YAML validity | manifest.yml and form.yml parse without errors (duplicate YAML keys are valid YAML; semantic issue noted under Code Quality) |
| STR-05 | PASS | — | ERB tags balanced | submit.yml.erb — all `<%`, `<%=`, `<%-`, `-%>`, `%>` tags balanced |
| STR-06 | PASS | — | Template scripts syntactically correct | 2 files pass: template/before.sh.erb, template/script.sh.erb |
| STR-07 | PASS | — | Standard OOD structure | form.yml, submit.yml.erb, template/ with script.sh.erb and before.sh.erb all present |
| STR-04 | PASS | — | No broken references | All 7 attributes referenced in submit.yml.erb (custom_reservation, custom_email_address, custom_memory_per_node, custom_time, custom_num_cores, custom_num_gpus, extra_slurm) defined in form.yml |

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

**Capability profile (Batch Connect app):**

| Capability | Present | Notes |
|---|---|---|
| Reads Slurm environment variables (SLURM_JOBID, SLURM_JOB_PARTITION, etc.) | Yes | Expected |
| Purges and restores Lmod module environment | Yes | Expected |
| Creates scratch directory at `/scratch/$USER/$SLURM_JOBID` | Yes | Site-specific path; see Portability |
| Launches Xfce desktop stack (xfwm4, xsetroot, xfsettingsd, xfce4-panel, xfce4-terminal, dbus-send) | Yes | Expected for turbovnc BC app |
| Loads SAS module via `module load` constrained to select widget option (`sas/9.4-fasrc01`) | Yes | Expected; module value not from free-text input |
| Adjusts `/proc/self/oom_score_adj` (self only) | Yes | Expected; no cross-user impact |
| `eval exec $COMMAND` where COMMAND is a hardcoded local string (line 61) | Yes | Low-concern latent risk; see OODT-01 finding |
| `set -x` debug tracing active throughout job script | Yes | Advisory; see OODT-08 finding |
| Outbound network calls in ERB templates | No | Expected (none) |
| Credential access or ~/.ssh writes | No | Expected (none) |
| Binary files in template/ | No | Expected (none) |

#### Findings

| Rule | Result | Severity | Tag | Summary | Evidence |
|---|---|---|---|---|---|
| OODT-01 | WARN | low | unintentional | `eval exec $COMMAND` with unquoted `$COMMAND` (SC2086 corroborated); COMMAND is a hardcoded literal today — no live injection path — but eval on an unquoted variable is a latent word-splitting risk if the command is ever parameterized | template/script.sh.erb:72 |
| OODT-01 | WARN | low | unintentional | `$WORKDIR` unquoted in `mkdir -p $WORKDIR` (line 22) and `cd $WORKDIR` (line 25) (SC2086 corroborated); WORKDIR derives from system-provided env vars unlikely to contain glob chars, but the unquoted form is a defensive-coding gap | template/script.sh.erb:22,25 |
| OODT-01 | WARN | low | unintentional | `extra_slurm` text_field has no `pattern` constraint; submit.yml.erb splits the field on whitespace and passes each token verbatim as a native sbatch option — blast radius self-harm only under OOD's PUN model | submit.yml.erb:16–17; form.yml:72 |
| OODT-08 | WARN | low | unintentional | `set -x` is active throughout the job script (lines 19 and 44) with no matching `set +x` limit; all expanded command strings including env-var values are written to job stdout log for the full session duration | template/script.sh.erb:19,44 |

### Portability

- Rating: **Partially portable** — cluster name (`odyssey3`) and module string (`sas/9.4-fasrc01` with Harvard FASRC-specific suffix) are hardcoded in `form.yml` but documented in the README configuration table as requiring site-specific changes; scratch directory path is undocumented.

| Rule | Result | Severity | Summary | Evidence |
|---|---|---|---|---|
| QUA-02 | WARN | low | Cluster name `odyssey3` hardcoded; documented in README as needing change | form.yml:3 — `cluster: "odyssey3"` |
| QUA-02 | WARN | low | Only SAS module option is `sas/9.4-fasrc01` with Harvard FASRC-specific suffix; deployers must update to their site's module name | form.yml:63 — `["SAS 9.4", "sas/9.4-fasrc01"]` |
| QUA-02 | WARN | low | `WORKDIR` set to `/scratch/$USER/$SLURM_JOBID`; assumes a `/scratch` filesystem that may not exist at other sites; not documented in README as requiring change | template/script.sh.erb:21 — `export WORKDIR=/scratch/$USER/$SLURM_JOBID` |

### Documentation

- Rating: **Adequate** — overview, prerequisites, installation, configuration, known limitations, troubleshooting, and screenshots all present; Strong rung not met because there is no environment variable documentation section.
- Evidence per rung:
  what it launches: README §"Appverse overview" — describes SAS GUI session via TurboVNC/Xfce on HPC cluster; prerequisites: README §"Requirements" — compute node software, VNC, OOD requirements listed; installation: README §"App Installation" — clone, configure, verify steps; configuration: README §"Configure for your site" — form.yml attributes table with "Change to" column; known limitations: README §"Known Limitations" — multi-node not supported, tested on CentOS 7 / Rocky 8 only; troubleshooting: README §"Troubleshooting" — job log, module check, VNC timeout sections; screenshots: README §"Screenshots" — 2 images (sas_desktop.png, sas_plot_example.png); environment variables: none; info panel: none; architecture: none.

### Code Quality

| Check | Rule | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| Error handling in scripts | QUA-03 | WARN | low | No `set -e` anywhere in file; a failed `module load`, `mkdir -p`, or `cd` will not abort execution — errors silently continue into the SAS launch | template/script.sh.erb:1–19 — `set -x` present at line 19, no `set -e` found |
| Input validation on form fields (`check: numeric-field-bounds`) | QUA-07 | WARN | low | `custom_memory_per_node` and `custom_num_cores` (number_field) have `min` but no `max`; `custom_time`, `custom_reservation`, `custom_email_address` (text_field) have no `pattern` constraint | form.yml:30,38 (no max on number fields); form.yml:15,27,65 (no pattern on text fields) |
| Magic numbers / undocumented literals | QUA-08 | PASS | — | OOM score values 1000 (line 69) and 0 (line 71) have an explanatory comment at lines 66–68; no unexplained magic numbers | template/script.sh.erb:66–71 |
| Duplicated code blocks | QUA-09 | PASS | — | No large duplicated code blocks detected | — |
| Commented-out dead code | QUA-04 | WARN | low | Commented-out heredoc markers (lines 33–37, 57) left from refactoring the containerized path, and a complete dead Singularity exec block (lines 78–95) | template/script.sh.erb:33 — `#cat > myrun.sh <<EOF`; :78–95 — `#singularity exec ... ./myrun.sh` |
| ERB handles missing/empty values | QUA-10 | PASS | — | Blank guards present for main numeric/time fields; OOD framework handles nil for native reservation and email submission fields | submit.yml.erb:9–11 — ternary guards on memory, time, cores |
| Desktop/panel icon matches target OS (`check: icon-matches-target-os`) | QUA-06 | WARN | info | Panel `button-icon` is `fedora-logo-icon`; README documents testing on Rocky 8.10, where this Fedora icon may not exist | template/config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml:40 — `value="fedora-logo-icon"` |
| Duplicate YAML keys | QUA-06 | WARN | low | `custom_num_cores` has two `help:` keys (lines 44 and 45) and `custom_num_gpus` has two `help:` keys (lines 54 and 55); YAML last-wins silently discards the first value in each case | form.yml:44–45 (`custom_num_cores`); form.yml:54–55 (`custom_num_gpus`) |
| Copy-paste artifact — sas_version help text | QUA-05 | WARN | low | `sas_version` help text reads "Loading the Matlab module for requested version" — wrong-app-reference from a MATLAB form | form.yml:60–61 |
| Copy-paste CHANGELOG | QUA-05 | WARN | low | CHANGELOG.md describes bc_osc_matlab releases; all version-comparison URLs link to `OSC/bc_osc_matlab`; no SAS-specific change history present; [Unreleased] is empty | CHANGELOG.md:1 — all entries and links reference OSC/bc_osc_matlab |
| README typo | QUA-06 | WARN | info | Table header reads `` `forml.yml` `` instead of `` `form.yml` `` | README.md:136 |

## Review scope

**Examined:** manifest.yml, form.yml, submit.yml.erb, template/script.sh.erb, template/before.sh.erb, template/config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml, template/config/menus/xfce-applications.menu, template/config/xfce4/terminal/terminalrc, README.md, CHANGELOG.md, LICENSE.txt, icon.png (presence only), images/ (presence only), pre-review syntax.json, shellcheck.json, semgrep.json

**Not examined:** Runtime behavior (Tier 3 — no isolated execution environment); GitHub issues/PR history beyond open-issue count; full releases list (count confirmed by maintenance agent via GitHub API)

**Tools:** syntax/bash -n (ran — 2 files, 0 failures), shellcheck 0.9.0 (ran ERB-stripped — 5 findings: SC2086 ×3, SC2148 ×1, SC2164 ×1), semgrep 1.178.0 (ran — 0 findings), bandit (skipped — no applicable files), trivy (skipped — no applicable files), catalog (skipped in pre-review — queried directly during review; see Catalog checks)

## Catalog checks

- Duplicate check against the existing catalog — **No duplicate found.** Queried the catalog's published app list via JSON:API; no "SAS" entry is present. The closest entries are Stata and SageMath, which are distinct applications.
  - **Duplicate-check rationale:** _SAS (Statistical Analysis Software) is a distinct commercial statistical platform not represented by any existing Appverse app. The submission is not a site-specific variant of an existing listing. No duplicate._
- `software` value matches a catalog Software entry — **Not applicable** (inferred repo — root `manifest.yml` only; no `appverse.yml` with a `software` field). A Software entry titled "SAS" does exist in the catalog (ID: cfb88e77-2fa2-4dca-b8f2-6eaa568d8cb5), available for reference if the repo adopts `appverse.yml`.
- `app_type` and `implementation_tags` are in the catalog vocabularies — **Not applicable** (inferred repo; no `appverse.yml` with these fields).

## Overall recommendation

**Accept with suggestions.** The app passes all gate criteria: README.md is substantive, LICENSE.txt is MIT, the repo shape is identifiable, all required manifest.yml fields are present, YAML parses without errors, both template scripts pass syntax checking, and standard OOD Batch Connect structure is complete. Documentation is Adequate and portability is Partially portable, both meeting the rubric's inclusion targets. All four security findings are Low severity and unintentional, with blast radius limited to the submitting user's own job under OOD's per-user Nginx model. The main improvement areas are: (1) replacing the MATLAB CHANGELOG and sas_version help text (copy-paste artifacts from a different app); (2) adding `set -e` and properly quoting shell variables in the job script; (3) removing commented-out Singularity code; (4) fixing duplicate YAML `help` keys; (5) adding `max` bounds to number fields and `pattern` constraints to free-text fields reaching the scheduler; and (6) documenting the site-specific `/scratch` scratch path. The catalog checks are settled: no duplicate SAS app exists in the catalog, and a "SAS" Software entry is present for future reference.

---

## Draft feedback — edit before sending

Thank you for submitting the SAS Open OnDemand app to Appverse. The app has a solid structure and thorough documentation. The following items would strengthen the submission:

**Copy-paste artifacts:** `CHANGELOG.md` (line 1) contains entries that all describe `bc_osc_matlab` (MATLAB), including comparison links pointing to `github.com/OSC/bc_osc_matlab` — this is a wrong-app-changelog with no-changelog for this SAS app. Please replace its content with a CHANGELOG that describes this SAS app's history, or start fresh with a `## [Unreleased]` heading. Similarly, the `sas_version` attribute in `form.yml` (line 60) has help text that reads "Loading the Matlab module for requested version" — a wrong-app-reference from a MATLAB form. Please update it to describe loading the SAS module (for example, "SAS Lmod module to load on compute nodes").

**Error handling and defensive coding in `template/script.sh.erb`:** The script uses `set -x` (line 19) for tracing but has no `set -e` (no-set-e). Without `set -e`, a failed `module load`, `mkdir -p`, or `cd` will not abort the script and execution will silently continue into the SAS launch. Please add `set -e` near the top of the script. Additionally, `$WORKDIR` is unquoted in `mkdir -p $WORKDIR` (line 22) and `cd $WORKDIR` (line 25); the safer form is `mkdir -p "$WORKDIR"` and `cd "$WORKDIR" || exit` to prevent word-splitting (unquoted-variable). The `eval exec $COMMAND` at line 72 should use `eval exec "$COMMAND"` (eval-exec); while `COMMAND` is a hardcoded literal today, quoting it removes a latent word-splitting risk if the command is ever parameterized. Finally, `set -x` debug tracing (debug-tracing-enabled, lines 19 and 44) is active throughout the entire session and writes all expanded command strings — including environment variable values — to the job's stdout log. Consider wrapping only the diagnostic portion with `set -x` / `set +x` to limit what goes into the log.

**Dead code in `template/script.sh.erb`:** Lines 33–37 and 57 are commented-out heredoc markers from a refactoring that moved commands out of a heredoc (confirmed by the comment at line 33: "heredoc not necessary if not containerized"). Lines 78–95 are a complete Singularity container execution path that is no longer needed. Please remove this commented-out-code to keep the script readable.

**Form field issues in `form.yml`:** Two attributes have duplicate `help:` keys — `custom_num_cores` at lines 44 and 45 (duplicate-yaml-key:custom_num_cores.help) and `custom_num_gpus` at lines 54 and 55 (duplicate-yaml-key:custom_num_gpus.help). YAML takes the last value and silently discards the first in each case. Please remove the first `help:` entry for each attribute to match the intended behavior. Additionally, `custom_memory_per_node` (line 30) and `custom_num_cores` (line 38) are `number_field` widgets with `min` but no `max` (missing-min-max); adding a `max` prevents users from accidentally requesting an unreasonably large allocation. Free-text fields that reach the scheduler — `custom_time` (line 15), `custom_reservation` (line 65), and `custom_email_address` (line 27) — have no `pattern` constraint (missing-pattern); a pattern attribute validates format in the browser before submission and surfaces typos early.

**`extra_slurm` pass-through in `submit.yml.erb`:** Lines 16–17 split the `extra_slurm` text field on whitespace and pass each token directly as a native sbatch option without any validation (unsanitized-user-input). Under OOD's per-user model the blast radius is limited to the submitting user's own job, but adding a `pattern` attribute to `extra_slurm` in `form.yml` (line 72) — for example, one that matches `--long-option[=value]` tokens — would constrain the input and surface invalid entries earlier.

**Portability notes:** `form.yml` line 3 has `cluster: "odyssey3"` (hardcoded-cluster) and line 63 has `sas/9.4-fasrc01` with a Harvard FASRC-specific module suffix (hardcoded-module-version). Both are already documented in the README configuration table as needing site-specific changes, which is helpful. `template/script.sh.erb` line 21 sets `WORKDIR=/scratch/$USER/$SLURM_JOBID` (hardcoded-path), which assumes a `/scratch` filesystem. Please add a note in the README configuration or known-limitations section so deployers at sites without `/scratch` know to adjust this path.

<!-- feedback-covers: CHANGELOG.md:wrong-app-changelog, CHANGELOG.md:no-changelog, form.yml:wrong-app-reference, template/script.sh.erb:no-set-e, template/script.sh.erb:unquoted-variable, template/script.sh.erb:eval-exec, template/script.sh.erb:debug-tracing-enabled, template/script.sh.erb:commented-out-code, form.yml:duplicate-yaml-key:custom_num_cores.help, form.yml:duplicate-yaml-key:custom_num_gpus.help, form.yml:missing-min-max, form.yml:missing-pattern, submit.yml.erb:unsanitized-user-input, form.yml:hardcoded-cluster, form.yml:hardcoded-module-version, template/script.sh.erb:hardcoded-path -->

```json
[
  {
    "app_id": "root",
    "rule": "STR-06",
    "defect_key": "template/before.sh.erb:bash-syntax-error",
    "aspect": "structure",
    "severity": "info",
    "result": "PASS",
    "summary": "template/before.sh.erb passes bash -n (ERB-stripped)",
    "evidence": "template/before.sh.erb — syntax.json ok: true"
  },
  {
    "app_id": "root",
    "rule": "STR-06",
    "defect_key": "template/script.sh.erb:bash-syntax-error",
    "aspect": "structure",
    "severity": "info",
    "result": "PASS",
    "summary": "template/script.sh.erb passes bash -n (ERB-stripped)",
    "evidence": "template/script.sh.erb — syntax.json ok: true"
  },
  {
    "app_id": "root",
    "rule": "OODT-01",
    "defect_key": "template/script.sh.erb:eval-exec",
    "aspect": "security",
    "severity": "low",
    "result": "WARN",
    "tag": "unintentional",
    "summary": "eval exec $COMMAND at line 72 uses unquoted $COMMAND (SC2086 corroborated); COMMAND is a hardcoded local string and not from user input in this revision — no live injection path — but eval on an unquoted variable is a latent word-splitting risk if the command is ever parameterized",
    "evidence": "template/script.sh.erb:72 — eval exec $COMMAND",
    "line": 72
  },
  {
    "app_id": "root",
    "rule": "OODT-01",
    "defect_key": "template/script.sh.erb:unquoted-variable",
    "aspect": "security",
    "severity": "low",
    "result": "WARN",
    "tag": "unintentional",
    "summary": "mkdir -p $WORKDIR (line 22) and cd $WORKDIR (line 25) use unquoted $WORKDIR (SC2086 corroborated by shellcheck); WORKDIR derives from system-provided env vars unlikely to contain glob chars, but the unquoted form is a defensive-coding gap; shellcheck SC2164 also flags cd without || exit at line 25",
    "evidence": "template/script.sh.erb:22 — mkdir -p $WORKDIR; :25 — cd $WORKDIR",
    "line": 22
  },
  {
    "app_id": "root",
    "rule": "OODT-01",
    "defect_key": "submit.yml.erb:unsanitized-user-input",
    "aspect": "security",
    "severity": "low",
    "result": "WARN",
    "tag": "unintentional",
    "summary": "extra_slurm free-text field (no pattern constraint) is split on whitespace and each token passed verbatim as a native sbatch option; a user can supply arbitrary Slurm flags including --wrap=<cmd>; blast radius is self-harm only under OOD's per-user Nginx model",
    "evidence": "submit.yml.erb:16–17 — extra_slurm.split.each; form.yml:72 — extra_slurm widget: text_field with no pattern",
    "line": 16
  },
  {
    "app_id": "root",
    "rule": "OODT-08",
    "defect_key": "template/script.sh.erb:debug-tracing-enabled",
    "aspect": "security",
    "severity": "low",
    "result": "WARN",
    "tag": "unintentional",
    "summary": "set -x is active throughout the job script (lines 19 and 44) without a matching set +x limit; expanded command strings including env-var values are written to the job stdout log for the full session duration",
    "evidence": "template/script.sh.erb:19 — set -x; :44 — set -x (within Xfce launch block)",
    "line": 19
  },
  {
    "app_id": "root",
    "rule": "QUA-02",
    "defect_key": "form.yml:hardcoded-cluster",
    "aspect": "quality",
    "severity": "low",
    "result": "WARN",
    "summary": "Cluster name 'odyssey3' hardcoded at top-level cluster key; deployers at other sites must edit form.yml; documented in README as needing to change",
    "evidence": "form.yml:3 — cluster: \"odyssey3\"",
    "line": 3
  },
  {
    "app_id": "root",
    "rule": "QUA-02",
    "defect_key": "form.yml:hardcoded-module-version",
    "aspect": "quality",
    "severity": "low",
    "result": "WARN",
    "summary": "Only SAS module option is 'sas/9.4-fasrc01' with a Harvard FASRC-specific suffix; deployers must replace it with their site's SAS module name",
    "evidence": "form.yml:63 — [\"SAS 9.4\", \"sas/9.4-fasrc01\"]",
    "line": 63
  },
  {
    "app_id": "root",
    "rule": "QUA-02",
    "defect_key": "template/script.sh.erb:hardcoded-path",
    "aspect": "quality",
    "severity": "low",
    "result": "WARN",
    "summary": "WORKDIR set to /scratch/$USER/$SLURM_JOBID, assuming a /scratch filesystem that may not exist at other sites; not documented in README as requiring change",
    "evidence": "template/script.sh.erb:21 — export WORKDIR=/scratch/$USER/$SLURM_JOBID",
    "line": 21
  },
  {
    "app_id": "root",
    "rule": "QUA-03",
    "defect_key": "template/script.sh.erb:no-set-e",
    "aspect": "quality",
    "severity": "low",
    "result": "WARN",
    "summary": "Script has set -x (line 19) but no set -e; errors from module load, mkdir -p, or cd are silently ignored and execution continues into the SAS launch",
    "evidence": "template/script.sh.erb:1–19 — set -x present at line 19, no set -e anywhere in file",
    "line": 1
  },
  {
    "app_id": "root",
    "rule": "QUA-04",
    "defect_key": "template/script.sh.erb:commented-out-code",
    "aspect": "quality",
    "severity": "low",
    "result": "WARN",
    "summary": "Commented-out heredoc markers (lines 33–37, 57) left from refactoring, and a complete dead Singularity exec block (lines 78–95) no longer needed",
    "evidence": "template/script.sh.erb:33 — #cat > myrun.sh <<EOF; :78–95 — #singularity exec ... ./myrun.sh block",
    "line": 33
  },
  {
    "app_id": "root",
    "rule": "QUA-05",
    "defect_key": "form.yml:wrong-app-reference",
    "aspect": "quality",
    "severity": "low",
    "result": "WARN",
    "summary": "sas_version help text reads 'Loading the Matlab module for requested version' — copy-paste artifact from a MATLAB app",
    "evidence": "form.yml:60–61 — help: | Loading the Matlab module for requested version",
    "line": 60
  },
  {
    "app_id": "root",
    "rule": "QUA-05",
    "defect_key": "CHANGELOG.md:wrong-app-changelog",
    "aspect": "quality",
    "severity": "low",
    "result": "WARN",
    "summary": "CHANGELOG.md describes bc_osc_matlab (MATLAB) releases; all version-comparison URLs link to OSC/bc_osc_matlab; no SAS-specific change history is present; [Unreleased] is empty",
    "evidence": "CHANGELOG.md:1 — all entries and comparison links reference OSC/bc_osc_matlab",
    "line": 1
  },
  {
    "app_id": "root",
    "rule": "QUA-06",
    "defect_key": "form.yml:duplicate-yaml-key:custom_num_cores.help",
    "aspect": "quality",
    "severity": "low",
    "result": "WARN",
    "summary": "custom_num_cores has two 'help:' keys; YAML last-wins silently discards 'Number of Cpus to allocate' in favour of the sbatch docstring",
    "evidence": "form.yml:44 — help: \"Number of Cpus to allocate\"; :45 — help: | *sbatch -c, --cpus-per-task=\\<ncpus\\>*",
    "line": 44
  },
  {
    "app_id": "root",
    "rule": "QUA-06",
    "defect_key": "form.yml:duplicate-yaml-key:custom_num_gpus.help",
    "aspect": "quality",
    "severity": "low",
    "result": "WARN",
    "summary": "custom_num_gpus has two 'help:' keys; YAML last-wins silently discards the prose description in favour of the sbatch docstring",
    "evidence": "form.yml:54 — help: \"Number of GPUs to allocate. Available only on GPU enabled partitions\"; :55 — help: | *sbatch --gres=gpu:\\<ngpus\\>*",
    "line": 54
  },
  {
    "app_id": "root",
    "rule": "QUA-06",
    "defect_key": "README.md:readme-typo",
    "aspect": "quality",
    "severity": "info",
    "result": "WARN",
    "summary": "Table header reads 'forml.yml' instead of 'form.yml'",
    "evidence": "README.md:136 — | Slurm variable | `forml.yml` attribute |",
    "line": 136
  },
  {
    "app_id": "root",
    "rule": "QUA-06",
    "defect_key": "template/config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml:icon-os-mismatch",
    "aspect": "quality",
    "severity": "info",
    "result": "WARN",
    "summary": "Panel button-icon is 'fedora-logo-icon'; README documents testing on Rocky 8.10, where this Fedora icon may not exist",
    "evidence": "template/config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml:40 — value=\"fedora-logo-icon\"; README testing table: Rocky 8.10",
    "line": 40
  },
  {
    "app_id": "root",
    "rule": "QUA-07",
    "defect_key": "form.yml:missing-min-max",
    "aspect": "quality",
    "severity": "low",
    "result": "WARN",
    "summary": "custom_memory_per_node and custom_num_cores (number_field) have min but no max; users can request unbounded resource allocations",
    "evidence": "form.yml:30–37 (custom_memory_per_node: min 4, no max); form.yml:38–46 (custom_num_cores: min 1, no max)",
    "line": 33
  },
  {
    "app_id": "root",
    "rule": "QUA-07",
    "defect_key": "form.yml:missing-pattern",
    "aspect": "quality",
    "severity": "low",
    "result": "WARN",
    "summary": "Free-text fields reaching the scheduler — custom_time, custom_reservation, custom_email_address — have no pattern constraint for format validation",
    "evidence": "form.yml:15 (custom_time, no pattern); form.yml:27 (custom_email_address, no pattern); form.yml:65 (custom_reservation, no pattern)",
    "line": 15
  },
  {
    "app_id": "root",
    "rule": "MNT-03",
    "defect_key": "CHANGELOG.md:no-changelog",
    "aspect": "maintenance",
    "severity": "low",
    "result": "WARN",
    "summary": "CHANGELOG.md exists but contains only bc_osc_matlab (MATLAB) history; [Unreleased] is empty; no SAS-specific change history exists",
    "evidence": "CHANGELOG.md:1–63 — all entries and comparison URLs reference OSC/bc_osc_matlab",
    "line": 1
  },
  {
    "app_id": "root",
    "rule": "MNT-02",
    "defect_key": "releases:no-releases",
    "aspect": "maintenance",
    "severity": "info",
    "result": "WARN",
    "summary": "No tagged releases found; CHANGELOG entries are all MATLAB-era versions from the original bc_osc_matlab fork",
    "evidence": "releases — 0 tagged releases in the repository"
  },
  {
    "app_id": "root",
    "rule": "MNT-04",
    "defect_key": ".github/workflows:no-ci",
    "aspect": "maintenance",
    "severity": "info",
    "result": "WARN",
    "summary": "No CI configuration found; .github/ directory does not exist",
    "evidence": ".github/workflows — directory absent from target-repo"
  }
]
```
