# Appverse Review: ood-sas

**Repository:** https://github.com/fasrc/ood-sas  **Mode:** reviewer  **Date:** 2026-09-29
**Reviewed commit:** `462790a1fdd1616038ea3536454a4e508c668471` (2026-07-08)  **Repo shape:** inferred single app
**Reviewed with:** appverse-review @ 0.6.0 (`e0f0d29`, https://github.com/Sweet-and-Fizzy/appverse-review) · **Model:** claude-sonnet-4-6 · **Rubric:** https://openondemand.connectci.org/appverse-review-rubric

> _Disclaimer: This is an automated review with human curation. It is provided without warranty of any kind and does not certify the app as secure or fit for any purpose. A listing is not an endorsement._

## Repo-level gate criteria

| Rule | Result | Evidence |
|---|---|---|
| — | PASS | Repository public and accessible — clone succeeded at reviewed commit |
| STR-01 | PASS | README.md — present and substantive (overview, requirements, installation, configuration, troubleshooting, screenshots, known limitations) |
| STR-01 | PASS | LICENSE.txt — MIT license present |
| — | PASS | Repo not archived — accessible at reviewed commit |

## Upkeep

| Signal | Value | Assessment |
|---|---|---|
| Last commit | 2026-07-08 (83 days before review date) | Active within 12 months |
| Releases | 0 tagged releases | Concern — no versioned releases |
| Issues responsiveness | 0 open issues | Neutral — nothing to respond to |
| Contributors | 4 contributors | Good sign — multiple contributors |
| CHANGELOG | CHANGELOG.md present but contains only MATLAB entries copied from OSC/bc_osc_matlab; all diff links point to that repo | Concern — not current for this app |
| CI | No `.github/workflows` directory | Concern — no CI configuration |

| Dimension | Level | Evidence |
|---|---|---|
| Upkeep (repo-level) | Medium | Active within 12 months, multiple contributors (4), but only one good-practice signal present (releases, CHANGELOG, CI all absent or wrong-app) |

## App: SAS (root)

### Signals

| Dimension | Level | Evidence |
|---|---|---|
| Portability | Medium | Main form.yml site-specific values documented in README config table; two undocumented site-specific items remain: `/scratch/$USER/$SLURM_JOBID` working-directory path in script and FASRC Slurm docs URL in `bc_queue` help text |
| Documentation | Medium | Adequate — overview, prerequisites, installation, configuration, known limitations all present with real content; Strong rung blocked by absent environment-variable docs section |

### Structure

| Rule | Result | Severity | Summary | Evidence |
|---|---|---|---|---|
| STR-02 | PASS | info | Required manifest.yml fields present | name=SAS, category=Interactive Apps, role=batch_connect, description present |
| STR-03 | PASS | info | YAML validity | form.yml and manifest.yml parse without errors |
| STR-06 | PASS | info | Template scripts syntactically correct | 2 files pass: template/before.sh.erb, template/script.sh.erb (from pre-review syntax.json) |
| STR-07 | PASS | info | Standard OOD structure | form.yml, submit.yml.erb, template/script.sh.erb all present |
| STR-04 | PASS | info | No broken references | All variables in submit.yml.erb and template/ resolve in form.yml; bc_email_on_started is an OOD built-in |

### Security

Findings are classified under OODT (Open OnDemand App Threats); codes are defined in the rubric's Security section.

**Check tiers:** Tiers 1–2

Tier 3 not checked — no isolated execution environment.

| Tool | Status | Result |
|---|---|---|
| shellcheck | Ran (ERB-stripped) | 5 findings: SC2086 (×3, info), SC2148 (error), SC2164 (warning) |
| semgrep | Ran | 0 findings |
| bandit | Not run (no applicable Python files) | — |
| trivy | Not run (no applicable files) | — |

**Capability profile — Batch Connect (turbovnc)**

| Capability | Present | Anomaly |
|---|---|---|
| Module purge and load | Yes | None — expected |
| Creates job-scoped scratch directory under `/scratch/$USER/$SLURM_JOBID` | Yes | Path is site-specific and not in README config table |
| Spawns full Xfce desktop (xfwm4, xsetroot, xfsettingsd, xfce4-panel) | Yes | None — expected for VNC desktop app |
| Launches SAS via xfce4-terminal → `/bin/bash -l -c "sas -dms"` | Yes | None — expected |
| Writes to `/proc/self/oom_score_adj` | Yes | Commented explanation present; self-harm scope only |
| `set -x` always-on debug tracing | Yes | Writes all expanded commands to job log unconditionally |
| `extra_slurm` free-text tokens passed as raw native Slurm options | Yes | User can inject `--wrap=...` to replace job script |
| Unquoted shell variables in path and eval | Yes | `$WORKDIR` (lines 22, 25) and `$COMMAND` (line 72) unquoted |
| Outbound network calls in ERB | No | — |
| Hardcoded credentials | No | — |
| Binary files in template/ | No | — |
| Writes to ~/.ssh or shell init files | No | — |
| Access to other users' files | No | — |
| Inactive Singularity container block (commented out, lines 79–95) would bind-mount host paths | Inactive | Not executed; comment-only |

#### Findings

| Rule | Result | Severity | Tag | Summary | Evidence |
|---|---|---|---|---|---|
| OODT-01 | FAIL | medium | unintentional | `extra_slurm` free-text field split on whitespace and each token passed as a raw native Slurm option; `--wrap=<cmd>` replaces the entire job script with arbitrary commands | submit.yml.erb:15–18 |
| OODT-01 | FAIL | low | unintentional | Unquoted `$WORKDIR` in mkdir and cd, and unquoted `$COMMAND` in eval exec, enable word-splitting and potential globbing; shellcheck SC2086 corroborates all three sites | template/script.sh.erb:22, 25, 72 |
| OODT-08 | FAIL | low | unintentional | `set -x` is enabled unconditionally at script top-level, writing all expanded commands (module paths, arguments) to the job output log with no opt-out path | template/script.sh.erb:19 |

### Portability
- Rating: **Partially portable** — main form.yml site-specific values (cluster `odyssey3`, `sas/9.4-fasrc01` module name, resource defaults, partition) are documented in the README configuration table with "Change to" guidance; two undocumented site-specific items remain.
  - `WORKDIR=/scratch/$USER/$SLURM_JOBID` at template/script.sh.erb:21 — the `/scratch/` convention is FASRC-specific and absent from the README config table.
  - FASRC Slurm docs URL (`docs.rc.fas.harvard.edu`) embedded in the `bc_queue` help text at form.yml:26 — deployers at other sites see an institution-specific link with no indication it should be replaced.

### Documentation
- Rating: **Adequate** — the Minimal and Adequate rungs are fully satisfied; the Strong rung is blocked by the absent environment-variable documentation section.
- Evidence per rung:
  - what it launches: README.md lines 21–32 — SAS interactive desktop via TurboVNC/Xfce on HPC cluster
  - prerequisites: README.md lines 63–83 — Xfce 4+, Lmod 6.0.1+, TurboVNC 2.1+, websockify 0.8.0+, OOD v3.0+, Slurm
  - installation: README.md lines 84–97 — clone + configure + verify steps with a verification check
  - configuration: README.md lines 99–148 — configuration table for form.yml, submit.yml.erb, and manifest.yml attributes with FASRC settings and "Change to" column
  - known limitations: README.md lines 198–202 — multi-node not supported, CentOS 7/Rocky 8 only
  - troubleshooting: README.md lines 159–177 — 3 scenarios, but two contain unreplaced template placeholder text ("module load software/1.0", "module spider software")
  - screenshots: README.md lines 37–48 — 2 screenshots (sas_desktop.png, sas_plot_example.png)
  - environment variables: none — no README section documents script-internal variables (WORKDIR, SEND_256_COLORS_TO_REMOTE) or deployer-facing env vars; this blocks the Strong rung
  - info panel: none
  - architecture: none — turbovnc template is mentioned but no architecture description

### Code Quality

| Check | Rule | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| Error handling in scripts | QUA-03 | FAIL | low | Script sets `set -x` for tracing but omits `set -e`; `mkdir`, `module load`, and `cd` have no explicit error checks | template/script.sh.erb:19 |
| Input validation on form fields (`check: numeric-field-bounds`) | QUA-07 | FAIL | medium | `custom_memory_per_node` and `custom_num_cores` are number_fields with a lower bound (`min`) but no upper bound (`max`), allowing unbounded resource requests | form.yml:31, 38 |
| Input validation — free-text patterns | QUA-07 | FAIL | low | Five text_fields that pass values to the scheduler (`custom_time`, `bc_queue`, `custom_email_address`, `custom_reservation`, `extra_slurm`) have no `pattern` constraint | form.yml:15, 21, 27, 65, 72 |
| Magic numbers / undocumented literals | QUA-08 | WARN | info | `xsetroot -solid "#D3D3D3"` sets desktop background with no inline comment explaining the color or how to change it | template/script.sh.erb:46 |
| Duplicated code blocks | QUA-09 | PASS | info | No large duplicated blocks found | — |
| Commented-out dead code | QUA-04 | WARN | low | Large commented-out Singularity container block (heredoc wrapper, XDG exports, singularity exec) from an abandoned approach | template/script.sh.erb:34–37, 39–42, 57, 79–95 |
| ERB handles missing/empty values | QUA-10 | WARN | low | `reservation_id: <%= custom_reservation %>` and `email: <%= custom_email_address %>` lack `.blank?` guards; other numeric fields in the same file guard correctly | submit.yml.erb:6, 7 |
| Desktop/panel icon matches target OS (`check: icon-matches-target-os`) | QUA-06 | WARN | low | `button-icon = "fedora-logo-icon"` in the xfce4 panel config; README states tested on Rocky 8.10 — the Fedora desktop icon is not part of Rocky Linux and falls back to a missing-icon placeholder | template/config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml:40 |
| Hardcoded site paths | QUA-02 | WARN | medium | `WORKDIR=/scratch/$USER/$SLURM_JOBID` hardcodes a FASRC-specific scratch convention not documented in the README config table | template/script.sh.erb:21 |
| Site-specific mixin in help text | QUA-02 | WARN | low | FASRC Slurm docs URL embedded in `bc_queue` help text with no "update this" note | form.yml:26 |
| Duplicate YAML keys | QUA-06 | WARN | medium | `custom_num_cores` has two `help:` keys (lines 44 and 45–46); YAML last-wins silently drops the first | form.yml:44 |
| Duplicate YAML keys | QUA-06 | WARN | medium | `custom_num_gpus` has two `help:` keys (lines 54 and 55–56); first value silently discarded | form.yml:54 |
| Copy-paste artifact — wrong app | QUA-05 | WARN | low | `sas_version` help text reads "Loading the Matlab module for requested version" — carried over from a MATLAB app | form.yml:61 |
| Copy-paste artifact — template placeholder | QUA-05 | WARN | low | Troubleshooting steps use generic "software/1.0" and "software" placeholders not updated for SAS | README.md:165, 170 |
| Copy-paste artifact — wrong-app CHANGELOG | QUA-05 | WARN | low | CHANGELOG.md contains only MATLAB entries copied from OSC/bc_osc_matlab; all version links and issue links point to that repository; no SAS change history is recorded | CHANGELOG.md:9–63 |
| README typo | QUA-06 | WARN | info | Column heading reads "forml.yml" — should be "form.yml" | README.md:136 |

**Per-app decision:** Accept with suggestions

## Review scope

**Examined:** README.md, LICENSE.txt, manifest.yml, form.yml, submit.yml.erb, CHANGELOG.md, template/script.sh.erb, template/before.sh.erb, template/config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml, template/config/menus/xfce-applications.menu, template/config/xfce4/terminal/terminalrc, images/ (2 PNG files); pre-review syntax.json, shellcheck.json, semgrep.json

**Not examined:** Runtime behavior (no isolated execution environment — Tier 3 not checked); icon file existence on target OS (no Rocky 8 environment available to verify)

**Tools:** syntax (ran, GNU bash 5.2.21, 2 files — all PASS); shellcheck 0.9.0 (ran, 5 findings); semgrep 1.178.0 (ran, 0 findings); bandit (skipped — no Python files); trivy (skipped — no applicable files); catalog (skipped — catalog reads deferred)

## Catalog checks

- Duplicate check against the existing catalog — NOT CHECKED (network access blocked during review; catalog query was not reachable)
  - **Duplicate-check rationale:** _SAS is commercial statistical software with a large but relatively niche HPC user base. A reviewer should query the catalog for any existing SAS app before approving. If a duplicate exists, apply the same-app/forked-with-changes analysis from the Reviewer Process. If this is the first SAS app, accept as a novel entry._
- `software` value matches a catalog Software entry — NOT CHECKED (inferred repo; manifest.yml carries no `software` field; the catalog infers this from GitHub metadata when no appverse.yml is present — reviewer should verify that inference resolves correctly)
- `app_type` and `implementation_tags` are in the catalog vocabularies — NOT CHECKED (network access blocked; inferred repo has no explicit vocabulary fields)

## Overall recommendation

**Accept with suggestions** (pending catalog checks). The app passes all structure gate criteria — a substantive README, MIT license, valid manifest.yml, complete Batch Connect layout, and clean shell syntax. Documentation is Adequate (meets the listing target) and configuration portability is Partially portable (meets the listing target). The primary improvement areas are: (1) the `extra_slurm` free-text field in `submit.yml.erb` passes user-supplied tokens directly as native Slurm options with no constraint, which allows `--wrap=<cmd>` to replace the job script entirely (medium OODT-01); (2) `custom_memory_per_node` and `custom_num_cores` are number_fields missing `max` bounds (medium QUA-07); (3) the `/scratch/$USER/$SLURM_JOBID` working-directory path is site-specific but absent from the README configuration table (medium QUA-02); (4) two `form.yml` attributes have duplicate `help:` keys that silently discard the first value (medium QUA-06); and (5) several copy-paste artifacts remain from the template the app was cloned from — a MATLAB reference in the `sas_version` help text, placeholder text in the troubleshooting section, and a CHANGELOG copied wholesale from OSC/bc_osc_matlab. None of these findings are High or Critical severity, and all are fixable without redesigning the app. Approval is conditional on the catalog checks above (duplicate check, software entry, vocabulary terms).

---

## Draft feedback — edit before sending

Thank you for submitting ood-sas to Appverse. The app is well-structured and the README covers the essentials a deployer needs. A few items to address before the listing goes live, and some optional improvements:

**Input constraints (form.yml)**

The `extra_slurm` text field at `form.yml` line 72 passes whatever the user types directly to `sbatch` as native options (see `submit.yml.erb` lines 15–18). A user who enters `--wrap=some-command` replaces the entire job script with that command. Consider adding a `pattern` constraint to this field (e.g., an allowlist that accepts only `--constraint=`, `--nodelist=`, and similar safe flags), or removing it in favour of a fixed set of `select` options for the most-requested extras. While you're in that file, `custom_memory_per_node` (line 31) and `custom_num_cores` (line 38) are `number_field` widgets with a `min` but no `max`; adding an upper bound prevents accidental over-allocation. The other free-text fields that reach the scheduler — `custom_time` (line 15), `bc_queue` (line 21), `custom_email_address` (line 27), and `custom_reservation` (line 65) — also have no `pattern` constraint.

**Copy-paste artifacts**

Three files contain text that appears to have been carried over from the app template or a MATLAB predecessor without being updated for SAS:

- `form.yml` line 61: the `sas_version` help text reads "Loading the Matlab module for requested version." Please update to describe SAS.
- `README.md` lines 165 and 170: the troubleshooting section still says "module load software/1.0" and "module spider software." Replace these with the actual SAS module name.
- `CHANGELOG.md`: the entire content was copied from [OSC/bc_osc_matlab](https://github.com/OSC/bc_osc_matlab) — all version entries (lines 9–63) describe MATLAB releases, and all diff links point to that repo. Please replace or reset the CHANGELOG with SAS-specific history (even a single "Initial release" entry is better than MATLAB entries).

**Portability — undocumented site-specific items**

The script at `template/script.sh.erb` line 21 sets `WORKDIR=/scratch/$USER/$SLURM_JOBID`. The `/scratch/` path convention is FASRC-specific; sites that use `/tmp`, `/local`, or a group-prefix path will need to change this, but the value does not appear in the README's configuration table. Please add it there so deployers know it exists.

The `bc_queue` help text at `form.yml` line 26 embeds a link to FASRC's Slurm partition documentation (`docs.rc.fas.harvard.edu`). Deployers at other sites will see an institution-specific URL with no indication to replace it; a generic placeholder or a note like "replace with your site's partition docs" would help.

**Script hygiene**

`template/script.sh.erb` uses `set -x` at line 19 for debugging but has no `set -e`; a failed `mkdir`, `module load`, or `cd` will pass silently. Adding `set -e` (or explicit `|| exit` checks) makes failures visible. The three unquoted variable expansions flagged by shellcheck — `$WORKDIR` at lines 22 and 25, and `$COMMAND` at line 72 — should be double-quoted. The `cd` at line 25 should also have a `|| exit` fallback (shellcheck SC2164).

The optional items: `template/script.sh.erb` still contains a large commented-out Singularity container block (lines 34–95) from an abandoned approach — removing it would make the script considerably easier to read. The `submit.yml.erb` optional fields `custom_reservation` (line 6) and `custom_email_address` (line 7) pass their raw value without a `.blank?` guard; an empty optional field sends `--reservation=` or `email=` to Slurm with no value, which may produce an error.

The `form.yml` has duplicate `help:` keys for `custom_num_cores` (lines 44 and 45–46) and `custom_num_gpus` (lines 54 and 55–56). YAML's last-wins rule silently discards the first value in each case; remove the redundant inline `help:` line to make the intent explicit.

Finally, the Xfce panel configuration at `template/config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml` line 40 sets `button-icon = "fedora-logo-icon"`. The README states the app was tested on Rocky 8.10 (RHEL family), where this icon does not exist; it will fall back to a missing-icon placeholder. Use a generic icon name such as `applications-other` or one available on Rocky Linux.

<!-- feedback-covers: submit.yml.erb:unsanitized-user-input, form.yml:missing-min-max, form.yml:missing-pattern, form.yml:wrong-app-reference, README.md:template-placeholder, CHANGELOG.md:wrong-app-changelog, template/script.sh.erb:hardcoded-path, form.yml:site-specific-mixin, template/script.sh.erb:no-set-e, template/script.sh.erb:unquoted-variable, template/script.sh.erb:debug-tracing-enabled, template/script.sh.erb:commented-out-code, submit.yml.erb:erb-missing-value-unhandled, form.yml:duplicate-yaml-key:custom_num_cores.help, form.yml:duplicate-yaml-key:custom_num_gpus.help, template/config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml:icon-os-mismatch -->
