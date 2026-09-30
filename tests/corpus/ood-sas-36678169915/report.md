# Appverse Review: ood-sas

**Repository:** https://github.com/fasrc/ood-sas  **Mode:** reviewer  **Date:** 2026-09-30
**Reviewed commit:** `462790a1fdd1616038ea3536454a4e508c668471` (2026-07-08)  **Repo shape:** inferred single app
**Reviewed with:** appverse-review @ 0.7.0 (`e167db4`, https://github.com/Sweet-and-Fizzy/appverse-review) · **Model:** claude-sonnet-4-6 · **Rubric:** https://openondemand.connectci.org/appverse-review-rubric

> _Disclaimer: This is an automated review with human curation. It is provided without warranty of any kind and does not certify the app as secure or fit for any purpose. A listing is not an endorsement._

## Repo-level gate criteria

| Rule | Result | Evidence |
|---|---|---|
| — | PASS | Repository public and accessible (clone succeeded) |
| STR-01 | PASS | README.md — present and substantive; clear overview, configuration table, installation steps, troubleshooting |
| STR-01 | PASS | LICENSE — MIT license present as `LICENSE.txt` |
| — | PASS | Repo not archived (active public repository) |

## Upkeep

| Signal | Value | Assessment |
|---|---|---|
| Last commit | 2026-07-08 (83 days ago) | Active within 12 months |
| Releases | None visible | No tagged releases in repository |
| Issues responsiveness | Not checked | GitHub API not queried |
| Contributors | Not checked | GitHub API not queried |
| CHANGELOG | Present (CHANGELOG.md) | Content describes MATLAB/bc_osc_matlab — copy-paste artifact (see QUA-05) |
| CI | None | No `.github/workflows/` directory |

| Dimension | Level | Evidence |
|---|---|---|
| Upkeep (repo-level) | Medium | Active within 12 months; no releases, no CI, CHANGELOG present but describes wrong app |

## App: SAS (root)

### Signals

| Dimension | Level | Evidence |
|---|---|---|
| Portability | Medium | Partially portable — form.yml attributes documented in README; `/scratch/` absolute path in script undocumented |
| Documentation | Medium | Adequate — overview, prerequisites, installation, configuration, and known limitations all present; troubleshooting section has unfilled template placeholders |

### Structure

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| STR-02 | `check: str-02-metadata` | PASS | info | Required manifest.yml fields present: `name`, `category`, `role`, `description` | manifest.yml:2,3,5,6 |
| STR-03 | `check: str-03-yaml-valid` | PASS | info | manifest.yml and form.yml parse without errors | manifest.yml:1 |
| STR-06 | `check: str-06-syntax` | PASS | info | Template scripts syntactically correct: 2 files pass; 0 fail; 0 not checked (from pre-review syntax.json) | template/before.sh.erb; template/script.sh.erb |
| STR-07 | `check: str-07-layout` | PASS | info | Standard Batch Connect layout present: `form.yml`, `submit.yml.erb`, `template/script.sh.erb` | form.yml |
| STR-04 | `check: str-04-references` | PASS | info | All form attributes referenced in `submit.yml.erb` and `template/` are defined in `form.yml`; `bc_email_on_started` is a built-in OOD attribute | submit.yml.erb:1 |

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
| OODT-01 | `check: sec-interpolation` | WARN | medium | unintentional | `custom_reservation` (text_field, unquoted, no sanitiser) reaches `script.reservation_id`; a malformed value could produce a malformed YAML document for the submitter's own job | submit.yml.erb:6 |
| OODT-01 | `check: sec-interpolation` | WARN | low | unintentional | `custom_email_address` (text_field, unquoted, no sanitiser) reaches `script.email`; limited blast radius (scheduler email parameter only) | submit.yml.erb:7 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `custom_memory_per_node` (number_field) has a blank-guard default and `.to_s` conversion; in a YAML-quoted string | submit.yml.erb:9 |
| OODT-01 | `check: sec-interpolation` | WARN | low | unintentional | `custom_time` (text_field) reaches `--time=` with a blank-guard default and `.to_s`, but no pattern validation; a malformed time string causes Slurm to reject the job | submit.yml.erb:10 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `custom_num_cores` (number_field) sanitised by `.to_i`; blank-guarded; YAML-quoted | submit.yml.erb:11 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `custom_num_gpus` (number_field) sanitised by `.to_i`; wrapped in a zero-check conditional | submit.yml.erb:13 |
| OODT-01 | `check: sec-interpolation` | WARN | medium | unintentional | `extra_slurm` (text_field) split by whitespace and each token passed as a native Slurm option with no sanitisation; by design as a pass-through but arbitrary scheduler options accepted | submit.yml.erb:17 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `context.custom_num_gpus` in `echo` statement only; no shell expansion risk | template/script.sh.erb:11 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `context.sas_version` in `echo` statement; select widget constrained to predefined options | template/script.sh.erb:12 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `context.sas_version` in `module load`; select widget with fixed options — OOD enforces selection | template/script.sh.erb:64 |
| OODT-01 | `check: sec-eval-exec` | PASS | info | — | `eval exec $COMMAND` where `$COMMAND` is a hardcoded constant defined two lines earlier (`xfce4-terminal -e …`) | template/script.sh.erb:72 |
| OODT-08 | `check: sec-config-flag` | WARN | low | unintentional | `set -x` at three points traces shell commands and values to the job's `output.log`; sensitive values could appear if job directory permissions are open | template/script.sh.erb:19,44,54 |

#### Additional observations (review)

| Rule | Result | Severity | Tag | Summary | Evidence |
|---|---|---|---|---|---|
| OODT-06 | WARN | low | unintentional | Commented-out singularity block (lines 78–94) includes bind-mount directives for sensitive paths (`/etc/sssd/`, `/var/lib/sss`, `/etc/slurm`) that would create container security concerns if un-commented; not listed by security.json | template/script.sh.erb:78 |

No tool-detectable issues in the checked tiers.

**Capability profile (Batch Connect):**

| Capability | Present | Assessment |
|---|---|---|
| Loads Lmod module (`sas/9.4-fasrc01`) | Yes | Expected |
| Creates working directory under `/scratch/$USER/$SLURM_JOBID` | Yes | Site-specific path (hardcoded); see QUA-02 |
| Launches Xfce window manager (xfwm4, xfsettingsd, xfce4-panel) | Yes | Expected for TurboVNC desktop app |
| Runs `xfce4-terminal` with SAS inside | Yes | Expected |
| Manages `/proc/self/oom_score_adj` | Yes | Legitimate OOM protection; scoped to own process |
| Outbound network calls in ERB | No | Expected absence |
| Writes to dotfiles or SSH keys | No | Expected absence |
| Installs cron jobs or systemd services | No | Expected absence |
| Binary files in `template/` | No | Expected absence |

Profile matches the expected narrow Batch Connect baseline. The only anomaly noted is the absolute `/scratch/` path (portability, not security).

### Portability
- Rating: **Partially portable** — form.yml attributes (`cluster`, `bc_queue`, `sas_version`) are documented in the README configuration table; the `/scratch/` absolute path in `template/script.sh.erb` is hardcoded and not mentioned in the README.

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| QUA-02 | `check: hardcoded-site-paths` | WARN | medium | Absolute path `/scratch/` hardcoded in job script; not documented in README configuration section; a deployer at a site using `/scratch1/`, `/tmp/`, or an HPC-managed `$TMPDIR` must find and patch this manually | template/script.sh.erb:21 |
| QUA-02 | `check: portability-rating` | PASS | info | Partially portable — cluster, partition, and SAS module version documented in README form.yml table; `/scratch/` path requires out-of-README discovery | README.md:99 |

### Documentation
- Rating: **Adequate** — overview, prerequisites, installation, configuration, and known limitations all substantiated; troubleshooting section exists but contains unfilled template placeholders, preventing a Strong rating.
- Evidence per rung (from readme.json):
  what it launches: "Appverse overview", README.md:21; prerequisites: "Requirements", README.md:63; installation: "App Installation", README.md:84; configuration: "2. Configure for your site", README.md:99; known limitations: "Known Limitations", README.md:196; troubleshooting: "Troubleshooting", README.md:159 — placeholder (section content includes `YOUR-APP`, `module load software/1.0`, and other unfilled template phrases); screenshots: "Screenshots", README.md:37 — two real images (`images/sas_desktop.png`, `images/sas_plot_example.png`); environment variables: none; info panel: none; architecture: none

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| QUA-01 | `check: documentation-rating` | PASS | info | Adequate — overview through known limitations all met; Strong not met because troubleshooting section contains unfilled template placeholders | README.md:21 |

### Code Quality

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| QUA-03 | `check: error-handling` | WARN | low | `template/script.sh.erb` has no `set -e`; errors in `module purge`, `mkdir`, `cd`, `module load`, and window manager launch proceed silently | template/script.sh.erb:1 |
| QUA-07 | `check: numeric-field-bounds` | WARN | low | `custom_memory_per_node` (number_field, min=4) and `custom_num_cores` (number_field, min=1) have no upper bound; a user could request unbounded memory or core counts limited only by the scheduler | form.yml:30,38 |
| QUA-07 | `check: numeric-field-bounds` | WARN | low | Text fields `custom_time`, `custom_email_address`, `custom_reservation`, and `extra_slurm` reach the scheduler without a `pattern` constraint; `custom_num_gpus` is bounded correctly | form.yml:15,27,65,72 |
| QUA-08 | `check: magic-numbers` | WARN | info | Hex color `#D3D3D3` used as Xfce desktop background is an undocumented literal | template/script.sh.erb:46 |
| QUA-09 | `check: duplicated-blocks` | PASS | info | No significant duplicated code blocks found | template/script.sh.erb:1 |
| QUA-04 | `check: dead-code` | WARN | low | Three blocks of commented-out code remain from an older heredoc/Singularity container approach: lines 33–37 (heredoc preamble), 39–42 (XDG env exports), 78–94 (Singularity invocation including a `SINGULARITYENV_MATLAB_PREFDIR` reference) | template/script.sh.erb:33,39,78 |
| QUA-10 | `check: erb-missing-value` | PASS | info | Optional text fields that render as YAML null when blank are handled gracefully by OOD and the scheduler; number fields with `.to_i`/`.to_s` conversions and blank-guards cover all remaining cases | submit.yml.erb:6,7,9,10,11,12,15 |
| QUA-06 | `check: icon-matches-target-os` | WARN | low | Xfce panel button icon references `fedora-logo-icon` but README Testing table documents Rocky 8.10 as the target OS; a Fedora icon may not be present on Rocky 8 nodes | template/config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml:40 |
| QUA-05 | | WARN | low | CHANGELOG.md contains MATLAB version history (`Added MATLAB version 2018a`, `Added MATLAB versions R2017a and R2015b`) and links to `https://github.com/OSC/bc_osc_matlab/` — copied from the source app without being updated for SAS | CHANGELOG.md:11 |
| QUA-05 | | WARN | low | `sas_version` help text reads "Loading the Matlab module for requested version" — copy-paste artifact from a MATLAB app; should reference SAS | form.yml:61 |
| QUA-06 | | WARN | low | `custom_num_cores` has two `help:` keys (lines 44 and 45); last-wins in most YAML parsers; the first help string ("Number of Cpus to allocate") is silently discarded | form.yml:44,45 |
| QUA-06 | | WARN | low | `custom_num_gpus` has two `help:` keys (lines 54 and 55); same last-wins issue | form.yml:54,55 |
| QUA-06 | | WARN | info | README.md line 136 column 2 says `` `forml.yml` `` instead of `` `form.yml` `` | README.md:136 |

## Review scope

**Examined:** `README.md`, `LICENSE.txt`, `CHANGELOG.md`, `manifest.yml`, `form.yml`, `submit.yml.erb`, `template/script.sh.erb`, `template/before.sh.erb`, `template/config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml`, `template/config/menus/xfce-applications.menu`, `template/config/xfce4/terminal/terminalrc`, `icon.png` (presence only); pre-review security candidates, form attributes, template scan, README rungs, syntax check results.

**Not examined:** `images/` (binary; existence confirmed), runtime behavior (Tier 3; no isolated execution environment), GitHub releases page (GitHub API not queried), contributor history (GitHub API not queried), open issues (GitHub API not queried).

**Tools:** shellcheck (ran, 5 findings), semgrep (ran, 0 findings), bandit (skipped — no Python files), trivy (skipped — no applicable files); syntax check (ran, 2 files, both pass); form, template, security, and readme facts all ran.

## Catalog checks

- Duplicate check against the existing catalog — **No duplicate found** on the first 100 published apps (JSON:API queried anonymously). A second page of results exists (offset 100); the reviewer should verify.
  - **Duplicate-check rationale:** _No app titled "SAS" appears in the first 100 catalog listings. SAS is a distinct statistical software suite not served by any other currently visible entry. If a second-page SAS listing exists, evaluate whether it is the same app (same site config) or a meaningfully different approach. As reviewed this is a module-based TurboVNC desktop submission._
- `software` value matches a catalog Software entry — **Not applicable** (inferred repo; `manifest.yml` only; no `software` field). A Software entry titled "SAS" already exists in the catalog (UUID `cfb88e77-2fa2-4dca-b8f2-6eaa568d8cb5`). When a contributor declares this app via `appverse.yml`, the `software` value should reference this existing entry.
- `app_type` and `implementation_tags` are in the catalog vocabularies — **Not applicable** (inferred repo; no `appverse.yml`; app type is derived from `manifest.yml` `role: batch_connect`). The catalog vocabulary includes `Batch-Connect-VNC` which would be appropriate for this app if it is later declared.

## Overall recommendation

**Accept with suggestions** — pending verification of the second catalog page for duplicates. The app passes all gate criteria: README is substantive, LICENSE is MIT, `manifest.yml` is valid with all required fields, the standard Batch Connect layout is present, and all template scripts pass syntax checks. Documentation rates Adequate (at the target for inclusion) and portability rates Partially portable (at the target). No security finding is tagged potentially malicious and no gate criterion fails. The quality findings — most notably the CHANGELOG describing MATLAB rather than SAS, the "Loading the Matlab module" help text in the SAS version selector, duplicate `help:` YAML keys in `form.yml`, commented-out dead code from an earlier Singularity approach, and the undocumented `/scratch/` absolute path — are all fixable suggestions, not blockers. The reviewer should ask the contributor to address these before or after listing.

---

## Draft feedback — edit before sending

Thank you for submitting **Open OnDemand SAS** to the Appverse. The app is well-structured, clearly documented, and ready for listing with a few clean-up items we'd ask you to address.

**Security notes** — Four text fields in `submit.yml.erb` reach the scheduler without sanitisation: `custom_reservation` (line 6), `custom_email_address` (line 7), `custom_time` (line 10), and `extra_slurm` (line 17). The blast radius is limited to the submitting user's own job in a Batch Connect app, but consider adding `pattern` validation in `form.yml` for at least `custom_time` and `custom_reservation`, and document the intentional pass-through nature of `extra_slurm`. The script uses `set -x` debug tracing at lines 19, 44, and 54 of `template/script.sh.erb`; on clusters with world-readable job directories this could expose environment variable values in `output.log`. These are low-to-medium-severity advisory items.

**Copy-paste artifacts** — The `CHANGELOG.md` currently contains MATLAB version history and links to `https://github.com/OSC/bc_osc_matlab/` (`CHANGELOG.md` lines 11 onwards). Please replace it with a changelog for this SAS app (even a single `[0.1.0]` entry is fine). On the same note, the `sas_version` attribute's help text in `form.yml` (line 61) reads "Loading the Matlab module for requested version" — please update it to describe SAS. There is also a commented-out reference to `SINGULARITYENV_MATLAB_PREFDIR` in `template/script.sh.erb` (line 93) inside a larger block of commented-out Singularity container code (lines 78–94); and an older commented-out heredoc preamble at lines 33–37 and 39–42. We recommend removing all three commented-out blocks — they no longer reflect the app's approach and add noise for future maintainers.

**Duplicate YAML keys** — `form.yml` has two `help:` entries for both `custom_num_cores` (lines 44–45) and `custom_num_gpus` (lines 54–55). Most YAML parsers silently use the last value, so the first help strings ("Number of Cpus to allocate" and "Number of GPUs to allocate. Available only on GPU enabled partitions") are discarded. Please remove the first `help:` line in each case.

**Portability gap** — `template/script.sh.erb` line 21 sets `WORKDIR=/scratch/$USER/$SLURM_JOBID`. This path is site-specific and not mentioned in the README configuration section. Please add it to the `form.yml` or `submit.yml.erb` attributes table in the README (§ "Configure for your site"), or consider making it a configurable variable, so deployers at sites that use a different scratch path (e.g. `$TMPDIR`, `/scratch1/`) know where to look.

**Error handling** — `template/script.sh.erb` does not have `set -e`. If `module load` fails, `mkdir -p $WORKDIR` fails, or the window manager fails to start, the script continues and the user sees an opaque OOD connection timeout instead of a clear error in `output.log`. Adding `set -e` near the top (after the `set -x`) would make failures visible immediately. See the [Appverse Best Practices guide](https://openondemand.connectci.org/appverse-best-practices) for recommended patterns.

**Input validation** — `custom_memory_per_node` (line 30) and `custom_num_cores` (line 38) in `form.yml` have a `min` but no `max`. Adding a `max` prevents users from accidentally requesting more resources than the cluster can provide. The text fields `custom_time` (line 15), `custom_reservation` (line 65), and `custom_email_address` (line 27) reach the scheduler without a `pattern` constraint; adding a `pattern` for at least `custom_time` (e.g. `^\d{1,2}:\d{2}:\d{2}$`) would provide early feedback on malformed inputs.

**Icon mismatch** — `template/config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml` line 40 references `fedora-logo-icon` for the panel button, but the README Testing table shows the app is tested on Rocky 8. The `fedora-logo-icon` may not be present on Rocky 8 nodes. Please update to an icon available on Rocky 8 (e.g. `start-here` or a generic application icon), or confirm whether the Fedora icon package is installed at your site and document it.

**Minor:** README.md line 136 says `` `forml.yml` `` instead of `` `form.yml` ``. The troubleshooting section still contains placeholder text such as `YOUR-APP` (line 163) and `module load software/1.0` (line 164) — please update these to reflect the actual SAS app paths and module name.

<!-- feedback-covers: submit.yml.erb:unsanitized-user-input, template/script.sh.erb:debug-tracing-enabled, template/script.sh.erb:host-path-mount, template/script.sh.erb:hardcoded-path, template/script.sh.erb:no-set-e, template/script.sh.erb:commented-out-code, CHANGELOG.md:wrong-app-changelog, form.yml:wrong-app-reference, form.yml:duplicate-yaml-key:custom_num_cores.help, form.yml:duplicate-yaml-key:custom_num_gpus.help, form.yml:missing-min-max, form.yml:missing-pattern, template/config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml:icon-os-mismatch, README.md:readme-typo -->
