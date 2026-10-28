# Appverse Review: TuftsRT/tufts-ood-nfcore

**Repository:** https://github.com/TuftsRT/tufts-ood-nfcore  **Mode:** reviewer  **Date:** 2026-10-28
**Reviewed commit:** `80fa18723b9cdf3decb9c7630bfe26c3a02b77a6` (2026-10-08)  **Repo shape:** declared monorepo (17 apps)
**Reviewed with:** appverse-review @ 0.10.0 (`3d8c496`, https://github.com/Sweet-and-Fizzy/appverse-review) · **Model:** ccs/Qwen/Qwen3.6-35B-A3B-FP8 · **Rubric:** https://openondemand.connectci.org/appverse-review-rubric

> _Disclaimer: This is an automated review with human curation. It is provided without warranty of any kind and does not certify the app as secure or fit for any purpose. A listing is not an endorsement._

## Repo-level gate criteria

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| — | — | PASS | — | Repository public and accessible (clone succeeded) | — |
| STR-01 | — | PASS | info | README.md is substantive (27 lines, 1725 chars; real content in all sections) | README.md:1 |
| STR-01 | — | PASS | info | LICENSE exists and contains an open-source license (MIT) | LICENSE:1 |
| — | — | PASS | — | Repo is not archived on GitHub | — |

## Upkeep

| Signal | Value | Assessment |
|---|---|---|
| Last push | 2026-10-27 | Good sign: active within 12 months |
| Releases | 1 (v1.0.0) | Good sign: has releases |
| Contributors | 2 | Good sign: multiple contributors |
| Open issues | 0 | Neutral: no open issues |
| CHANGELOG | Missing at repo root | Concern: no root CHANGELOG (16 batch_connect apps carry per-app CHANGELOG.md inherited from nf-core) |
| CI | `.github/workflows/` absent | Concern: no CI configuration |

| Dimension | Level | Evidence |
|---|---|---|
| Upkeep (repo-level) | Medium | Active within 12 months; 2 good-practice signals (releases, multiple contributors), but no CHANGELOG or CI |

## App: nf-core Pipelines Dashboard (dashboard)

### Signals

| Dimension | Level | Evidence |
|---|---|---|
| Portability | Low | Partially portable — uses standard OOD installation paths for controller/view symlinks |
| Documentation | High | Below minimal — has Installation, Configuration, Known Limitations, Architecture sections but missing Prerequisites, Troubleshooting, Environment Variables, and Info Panel |
| Upkeep (this app) | High | Last change 2026-06-26; one contributor; no per-app CHANGELOG or CI |

### Structure

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| STR-02 | `check: str-02-metadata` | FAIL | high | manifest.yml missing: maintainer.name, maintainer.support_url. app_type "dashboards" not in published vocabulary (closest: "dashboard") | dashboard/manifest.yml |
| STR-03 | `check: str-03-yaml-valid` | PASS | info | manifest.yml parses as valid YAML | dashboard/manifest.yml:1 |
| STR-07 | `check: entry-point-parses` | PASS | info | Entry point config.ru exists and parses (Ruby/Rack passenger_app) | dashboard/config.ru:1 |
| STR-04 | `check: str-04-references` | NOT CHECKED | info | No form.yml/form.yml.erb for this passenger app; STR-04 applies to form/submit cross-references | — |
| STR-08 | — | NOT CHECKED | info | entry_point.json reports consistent=null; no Gemfile/Gemfile.lock found in dashboard/ | entry_point.json |

### Security

**Check tiers:** Tiers 1–2

Tier 3 not checked — no isolated execution environment.

| Tool | Status | Result |
|---|---|---|
| shellcheck | Run (ERB-stripped) | 64 findings (SC2050, SC2148, SC2155), 16 of them linted in isolation from the job-script family |
| semgrep | Run | 0 findings |
| bandit | Not run (no applicable files) | — |
| trivy | Not run (no applicable files) | — |

#### Findings

| Rule | Check | Result | Severity | Tag | Summary | Evidence |
|---|---|---|---|---|---|---|
| OODT-04 | `check: sec-network-call` | PASS | info | — | `docs_url: https://nf-co.re/rnaseq` is a static YAML config string, not an active HTTP request | dashboard/config/pipelines.yml:12 |
| OODT-04 | `check: sec-network-call` | PASS | info | — | `docs_url: https://nf-co.re/sarek` is a static YAML config string, not an active HTTP request | dashboard/config/pipelines.yml:22 |
| OODT-04 | `check: sec-network-call` | PASS | info | — | `docs_url: https://nf-co.re/taxprofiler` is a static YAML config string, not an active HTTP request | dashboard/config/pipelines.yml:30 |

#### Additional observations (review)

| Rule | Result | Severity | Tag | Summary | Evidence |
|---|---|---|---|---|---|
| OODT-04 | PASS | info | — | Controller/NFCoreDashboardRoute appends a Rails route at boot; initializer comments note "This is not a OOD recommended way to do this" | dashboard/initializers/nf_core_dashboard_route.rb:1 |

No tool-detectable issues in the checked tiers.

### Capability profile (passenger)

| File | Capabilities | Anomalies |
|---|---|---|
| `app.rb` | Reads YAML manifests from `/var/www/ood/apps/sys`, renders ERB HTML via Rack, discovers nf-core apps by prefix | None |
| `config.ru` | Rack entry point, delegates to `app.rb` | None |
| `config/pipelines.yml` | Static docs_url strings for nf-core pipeline documentation | None |
| `controllers/nf_pipelines_controller.rb` | Discovers groups from OOD's `sys_apps`/`nav_sys_apps` API | None |
| `initializers/nf_core_dashboard_route.rb` | Appends a Rails route at boot | Comment notes non-recommended approach |
| `views/index.html.erb` | Renders pipeline listing with client-side search filtering, uses `ERB::Util.html_escape` for output escaping | None |

### Portability
- Rating: Partially portable — uses standard OOD installation paths for controller/view symlinks but the dashboard integration approach (inline route initializer) is site-specific

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| QUA-02 | `check: hardcoded-site-paths` | PASS | info | No hardcoded site paths detected in passenger app source | dashboard/app.rb:1 |
| QUA-02 | `check: portability-rating` | PASS | info | Partially portable — site-specific mount paths but standard OOD conventions | — |

### Documentation
- Rating: Below minimal — has User Interface Overview, Installation, Configuration, Important Notes and Limitations, and How It Works sections; missing Prerequisites, Troubleshooting, Environment Variables, and Info Panel
- Evidence per rung:
  - what it launches: "User Interface Overview", dashboard/README.md:18
  - prerequisites: none
  - installation: "Installation", dashboard/README.md:46
  - configuration: "Configuration", dashboard/README.md:77
  - known limitations: "Important Notes and Limitations", dashboard/README.md:97
  - troubleshooting: none
  - screenshots: README contains 2 screenshots (README.md:24, :30) but not captured by readme.json screenshots array
  - environment variables: none
  - info panel: none
  - architecture: "How It Works", dashboard/README.md:32

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| QUA-01 | `check: documentation-rating` | FAIL | high | Below minimal documentation — fails Adequate target for inclusion | dashboard/README.md:1 |

### Code Quality

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| QUA-03 | `check: error-handling` | PASS | info | Passenger app does not use shell scripts; error handling not applicable | — |
| QUA-07 | `check: numeric-field-bounds` | NOT CHECKED | info | No form fields to validate for this passenger app | — |
| QUA-08 | `check: magic-numbers` | NOT CHECKED | info | No numeric literals flagged | — |
| QUA-09 | `check: duplicated-blocks` | NOT CHECKED | info | No duplicated blocks detected | — |
| QUA-04 | `check: dead-code` | NOT CHECKED | info | No commented-out code detected | — |
| QUA-10 | `check: erb-missing-value` | NOT CHECKED | info | No ERB forms for this passenger app | — |
| QUA-06 | `check: icon-matches-target-os` | NOT CHECKED | info | No icons defined for this app | — |

**Per-app decision:** Request changes

## App: nf-core-ampliseq 2.16.1 (nf-core-ampliseq-2-16-1)

### Signals

| Dimension | Level | Evidence |
|---|---|---|
| Portability | High | Not portable — cluster pax, partition file, port 1234, nf2ood.env path, pipeline root, singularity cache, and slurm profile are all Tufts-specific and undocumented |
| Documentation | High | Below minimal — only Overview section and Local review before deployment checklist; no prerequisites, installation, configuration, or troubleshooting |
| Upkeep (this app) | High | Last change 2026-06-26; one contributor; per-app CHANGELOG present but no CI |

### Structure

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| STR-02 | `check: str-02-metadata` | FAIL | high | manifest.yml missing: maintainer.name, maintainer.support_url. app_type "batch_connect" not in published vocabulary (closest: "batch-connect-basic") | nf-core-ampliseq-2-16-1/manifest.yml |
| STR-03 | `check: str-03-yaml-valid` | PASS | info | form.yml.erb has balanced ERB tags (verified); manifest.yml parses as valid YAML | nf-core-ampliseq-2-16-1/form.yml.erb:1 |
| STR-06 | `check: str-06-syntax` | PASS | info | All 2 shell files pass bash -n after ERB stripping (before.sh.erb, script.sh.erb) | nf-core-ampliseq-2-16-1/template/before.sh.erb:1, nf-core-ampliseq-2-16-1/template/script.sh.erb:1 |
| STR-07 | `check: str-07-layout` | PASS | info | Batch Connect layout complete: form.yml.erb, submit.yml.erb, template/ (3 files) | form.yml.erb, submit.yml.erb, template/ |
| STR-04 | `check: str-04-references` | NOT CHECKED | info | form.json failed_to_run (ERB not stripped before YAML parse) | form.json |

### Security

**Check tiers:** Tiers 1–2

Tier 3 not checked — no isolated execution environment.

| Tool | Status | Result |
|---|---|---|
| shellcheck | Run (ERB-stripped) | 64 findings (SC2050, SC2148, SC2155), 16 of them linted in isolation from the job-script family |
| semgrep | Run | 0 findings |
| bandit | Not run (no applicable files) | — |
| trivy | Not run (no applicable files) | — |

#### Findings

| Rule | Check | Result | Severity | Tag | Summary | Evidence |
|---|---|---|---|---|---|---|
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `bc_email_on_started` is a check_box (1/0); boolean value does not reach shell | nf-core-ampliseq-2-16-1/submit.yml.erb:9 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `bc_num_hours` is a number_field (min:1); only numeric values possible | nf-core-ampliseq-2-16-1/submit.yml.erb:14 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `num_cores` is a number_field (min:1); only numeric values possible | nf-core-ampliseq-2-16-1/submit.yml.erb:24 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `num_memory` is a number_field (min:1); only numeric values possible | nf-core-ampliseq-2-16-1/submit.yml.erb:26 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `partition` from select widget loaded from cpu_partition.yml partial; controlled options | nf-core-ampliseq-2-16-1/submit.yml.erb:29 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `workdir` is path_selector; shell-quoted assignment of filesystem path | nf-core-ampliseq-2-16-1/template/before.sh.erb:10, nf-core-ampliseq-2-16-1/template/script.sh.erb:9 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `resume` is check_box (1/0); shell-quoted comparison with constant "1" | nf-core-ampliseq-2-16-1/template/script.sh.erb:19 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `nextflow_version` is select widget; shell-quoted assignment | nf-core-ampliseq-2-16-1/template/script.sh.erb:36 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `executor` is select widget (slurm/local); shell-quoted comparison | nf-core-ampliseq-2-16-1/template/script.sh.erb:64 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `num_cores` written into heredoc-based Nextflow custom.config (not shell-executed) | nf-core-ampliseq-2-16-1/template/script.sh.erb:72 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `num_memory` written into heredoc-based Nextflow custom.config; shell-quoted | nf-core-ampliseq-2-16-1/template/script.sh.erb:73 |
| OODT-01 | `check: sec-eval-exec` | PASS | info | — | `source "${nf2ood_env_file}"` uses hardcoded path (not user-controllable); guarded by -r check | nf-core-ampliseq-2-16-1/template/script.sh.erb:28 |
| OODT-01 | `check: sec-tool-finding` | PASS | info | — | SC2148, SC2155: artefacts of linting OOD's job-script files one at a time | nf-core-ampliseq-2-16-1/template/before.sh.erb:1,5 |
| OODT-01 | `check: sec-tool-finding` | PASS | info | — | SC2050: ERB-stripped template yields constant comparisons, style/linting concern | nf-core-ampliseq-2-16-1/template/script.sh.erb:19,64 |

#### Additional observations (review)

| Rule | Result | Severity | Tag | Summary | Evidence |
|---|---|---|---|---|---|
| — | PASS | info | — | `before.sh.erb` exports `port=1234` but no web service is started in templates; port variable is unused | nf-core-ampliseq-2-16-1/template/before.sh.erb:8 |
| — | PASS | info | — | `script.sh.erb` contains hardcoded cluster path /cluster/tufts/yzhang85/github/nfcore2ood/nf2ood.env (site-specific, not security concern) | nf-core-ampliseq-2-16-1/template/script.sh.erb:25 |

No tool-detectable issues in the checked tiers.

### Capability profile (batch_connect)

| File | Capabilities | Anomalies |
|---|---|---|
| `form.yml.erb` | 80-100+ form fields (path_selectors, number_fields, select widgets), ERB-included partials | None |
| `submit.yml.erb` | ERB interpolates form values into slurm job directives, email config | None |
| `template/before.sh.erb` | Sets up working directory, exports hostname and reserved port | None |
| `template/nf-params.json.erb` | Converts form values to JSON via Ruby lambdas (to_bool, to_number), sanitizes types | None |
| `template/script.sh.erb` | Loads modules (nextflow, singularity), sources hardcoded env file, builds nextflow run command | Hardcoded cluster paths |

All batch_connect apps run Nextflow pipelines on the compute node via SLURM or local executor. They do not start network services, do not read credentials, and do not write to dotfiles or cron. Authentication is provided entirely by OOD.

### Portability
- Rating: Not portable — cluster pax, partition file, port 1234, nf2ood.env path, pipeline root, singularity cache, and slurm profile are all Tufts-specific and undocumented

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Hardcoded cluster "pax" in form.yml.erb | nf-core-ampliseq-2-16-1/form.yml.erb:2 |
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Partition loaded from external mixin file /etc/ood/config/.../cpu_partition.yml | nf-core-ampliseq-2-16-1/form.yml.erb:35 |
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Hardcoded port 1234 in before.sh.erb | nf-core-ampliseq-2-16-1/template/before.sh.erb:8 |
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Hardcoded nf2ood.env path in script.sh.erb | nf-core-ampliseq-2-16-1/template/script.sh.erb:25 |
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Hardcoded pipeline root path in script.sh.erb | nf-core-ampliseq-2-16-1/template/script.sh.erb:33 |
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Hardcoded singularity cache path in script.sh.erb | nf-core-ampliseq-2-16-1/template/script.sh.erb:34 |
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Hardcoded slurm profile name "tufts" in script.sh.erb | nf-core-ampliseq-2-16-1/template/script.sh.erb:35 |
| QUA-02 | `check: hardcoded-site-paths` | PASS | info | nodes=2 / mem=12G are explicit scheduler params in submit.yml.erb (documented in form) | nf-core-ampliseq-2-16-1/submit.yml.erb:18-21 |
| QUA-02 | `check: portability-rating` | FAIL | medium | Not portable — all 7 site-specific values are undocumented and Tufts-specific | — |

### Documentation
- Rating: Below minimal — only Overview section and Local review before deployment checklist; no Prerequisites, Installation, Configuration, Known Limitations, Troubleshooting, Screenshots, Environment Variables, Info Panel, or Architecture
- Evidence per rung:
  - what it launches: "Overview", nf-core-ampliseq-2-16-1/README.md:6
  - prerequisites: none
  - installation: "Local review before deployment", nf-core-ampliseq-2-16-1/README.md:24 (describes review checklist, not installation steps)
  - configuration: none
  - known limitations: none
  - troubleshooting: none
  - screenshots: none
  - environment variables: none
  - info panel: none
  - architecture: none

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| QUA-01 | `check: documentation-rating` | FAIL | high | Below minimal documentation — fails Adequate target for inclusion | nf-core-ampliseq-2-16-1/README.md:1 |

### Code Quality

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| QUA-07 | `check: numeric-field-bounds` | NOT CHECKED | info | form.json failed_to_run (ERB not stripped before YAML parse) | form.json |
| QUA-10 | `check: erb-missing-value` | NOT CHECKED | info | form.json failed_to_run — no attributes available for check | form.json |
| QUA-08 | `check: magic-numbers` | PASS | info | No numeric_literals or hex_colors detected in template.json | template.json |
| QUA-04 | `check: dead-code` | PASS | info | No commented_code detected in template.json | template.json |
| QUA-09 | `check: duplicated-blocks` | PASS | info | No large duplicated code blocks | template.json |
| QUA-03 | `check: error-handling` | PASS | low | set -euo pipefail in script.sh.erb; cd and mkdir have shell defaults under set -e | nf-core-ampliseq-2-16-1/template/script.sh.erb:3 |
| QUA-06 | `check: icon-matches-target-os` | PASS | info | No icons defined in template.json | template.json |

**Code quality observations:** No copy-paste artifacts, duplicate YAML keys, or wrong help text found. The pre-review fact scan (template.json) reported zero commented_code, numeric_literals, and hex_colors across all batch_connect apps. Note: `form.json` failed to parse for all 16 batch_connect apps due to unstripped ERB — this is a scanner defect, not a form defect.

**Per-app decision:** Request changes

---

## App: nf-core-chipseq-2-1-0 (nf-core-chipseq-2-1-0)

### Signals

| Dimension | Level | Evidence |
|---|---|---|
| Portability | High | Not portable — cluster pax, partition file, port 1234, nf2ood.env path, pipeline root, singularity cache, and slurm profile are all Tufts-specific and undocumented |
| Documentation | High | Below minimal — only Overview section and Local review before deployment checklist; no prerequisites, installation, configuration, or troubleshooting |
| Upkeep (this app) | High | Last change 2026-06-26; one contributor; per-app CHANGELOG present but no CI |

### Structure

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| STR-02 | `check: str-02-metadata` | FAIL | high | manifest.yml missing: maintainer.name, maintainer.support_url. app_type "batch_connect" not in published vocabulary (closest: "batch-connect-basic") | nf-core-chipseq-2-1-0/manifest.yml |
| STR-03 | `check: str-03-yaml-valid` | PASS | info | form.yml.erb has balanced ERB tags (verified); manifest.yml parses as valid YAML | nf-core-chipseq-2-1-0/form.yml.erb:1 |
| STR-06 | `check: str-06-syntax` | PASS | info | All 2 shell files pass bash -n after ERB stripping (before.sh.erb, script.sh.erb) | nf-core-chipseq-2-1-0/template/before.sh.erb:1, nf-core-chipseq-2-1-0/template/script.sh.erb:1 |
| STR-07 | `check: str-07-layout` | PASS | info | Batch Connect layout complete: form.yml.erb, submit.yml.erb, template/ (3 files) | nf-core-chipseq-2-1-0/form.yml.erb, nf-core-chipseq-2-1-0/submit.yml.erb, template/ |
| STR-04 | `check: str-04-references` | NOT CHECKED | info | form.json failed_to_run (ERB not stripped before YAML parse) | form.json |

### Security

**Check tiers:** Tiers 1–2

Tier 3 not checked — no isolated execution environment.

| Tool | Status | Result |
|---|---|---|
| shellcheck | Run (ERB-stripped) | 64 findings (SC2050, SC2148, SC2155), 16 of them linted in isolation from the job-script family |
| semgrep | Run | 0 findings |
| bandit | Not run (no applicable files) | — |
| trivy | Not run (no applicable files) | — |

#### Findings

| Rule | Check | Result | Severity | Tag | Summary | Evidence |
|---|---|---|---|---|---|---|
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `bc_email_on_started` is a check_box (1/0); boolean value does not reach shell | nf-core-chipseq-2-1-0/submit.yml.erb:9 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `bc_num_hours` is a number_field (min:1); only numeric values possible | nf-core-chipseq-2-1-0/submit.yml.erb:14 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `num_cores` is a number_field (min:1); only numeric values possible | nf-core-chipseq-2-1-0/submit.yml.erb:24 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `num_memory` is a number_field (min:1); only numeric values possible | nf-core-chipseq-2-1-0/submit.yml.erb:26 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `partition` from select widget loaded from cpu_partition.yml partial; controlled options | nf-core-chipseq-2-1-0/submit.yml.erb:29 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `workdir` is path_selector; shell-quoted assignment of filesystem path | nf-core-chipseq-2-1-0/template/before.sh.erb:10, nf-core-chipseq-2-1-0/template/script.sh.erb:9 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `resume` is check_box (1/0); shell-quoted comparison with constant "1" | nf-core-chipseq-2-1-0/template/script.sh.erb:19 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `nextflow_version` is select widget; shell-quoted assignment | nf-core-chipseq-2-1-0/template/script.sh.erb:36 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `executor` is select widget (slurm/local); shell-quoted comparison | nf-core-chipseq-2-1-0/template/script.sh.erb:64 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `num_cores` written into heredoc-based Nextflow custom.config (not shell-executed) | nf-core-chipseq-2-1-0/template/script.sh.erb:72 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `num_memory` written into heredoc-based Nextflow custom.config; shell-quoted | nf-core-chipseq-2-1-0/template/script.sh.erb:73 |
| OODT-01 | `check: sec-eval-exec` | PASS | info | — | `source "${nf2ood_env_file}"` uses hardcoded path (not user-controllable); guarded by -r check | nf-core-chipseq-2-1-0/template/script.sh.erb:28 |
| OODT-01 | `check: sec-tool-finding` | PASS | info | — | SC2148, SC2155: artefacts of linting OOD's job-script files one at a time | nf-core-chipseq-2-1-0/template/before.sh.erb:1,5 |
| OODT-01 | `check: sec-tool-finding` | PASS | info | — | SC2050: ERB-stripped template yields constant comparisons, style/linting concern | nf-core-chipseq-2-1-0/template/script.sh.erb:19,64 |

#### Additional observations (review)

| Rule | Result | Severity | Tag | Summary | Evidence |
|---|---|---|---|---|---|
| — | PASS | info | — | `before.sh.erb` exports `port=1234` but no web service is started in templates; port variable is unused | nf-core-chipseq-2-1-0/template/before.sh.erb:8 |
| — | PASS | info | — | `script.sh.erb` contains hardcoded cluster path /cluster/tufts/yzhang85/github/nfcore2ood/nf2ood.env (site-specific, not security concern) | nf-core-chipseq-2-1-0/template/script.sh.erb:25 |

No tool-detectable issues in the checked tiers.

### Capability profile (batch_connect)

| File | Capabilities | Anomalies |
|---|---|---|
| `form.yml.erb` | 80-100+ form fields (path_selectors, number_fields, select widgets), ERB-included partials | None |
| `submit.yml.erb` | ERB interpolates form values into slurm job directives, email config | None |
| `template/before.sh.erb` | Sets up working directory, exports hostname and reserved port | None |
| `template/nf-params.json.erb` | Converts form values to JSON via Ruby lambdas (to_bool, to_number), sanitizes types | None |
| `template/script.sh.erb` | Loads modules (nextflow, singularity), sources hardcoded env file, builds nextflow run command | Hardcoded cluster paths |

All batch_connect apps run Nextflow pipelines on the compute node via SLURM or local executor. They do not start network services, do not read credentials, and do not write to dotfiles or cron. Authentication is provided entirely by OOD.

### Portability
- Rating: Not portable — cluster pax, partition file, port 1234, nf2ood.env path, pipeline root, singularity cache, and slurm profile are all Tufts-specific and undocumented

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Hardcoded cluster "pax" in form.yml.erb | nf-core-chipseq-2-1-0/form.yml.erb:2 |
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Partition loaded from external mixin file /etc/ood/config/.../cpu_partition.yml | nf-core-chipseq-2-1-0/form.yml.erb:35 |
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Hardcoded port 1234 in before.sh.erb | nf-core-chipseq-2-1-0/template/before.sh.erb:8 |
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Hardcoded nf2ood.env path in script.sh.erb | nf-core-chipseq-2-1-0/template/script.sh.erb:25 |
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Hardcoded pipeline root path in script.sh.erb | nf-core-chipseq-2-1-0/template/script.sh.erb:33 |
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Hardcoded singularity cache path in script.sh.erb | nf-core-chipseq-2-1-0/template/script.sh.erb:34 |
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Hardcoded slurm profile name "tufts" in script.sh.erb | nf-core-chipseq-2-1-0/template/script.sh.erb:35 |
| QUA-02 | `check: hardcoded-site-paths` | PASS | info | nodes=2 / mem=12G are explicit scheduler params in submit.yml.erb (documented in form) | nf-core-chipseq-2-1-0/submit.yml.erb:18-21 |
| QUA-02 | `check: portability-rating` | FAIL | medium | Not portable — all 7 site-specific values are undocumented and Tufts-specific | — |

### Documentation
- Rating: Below minimal — only Overview section and Local review before deployment checklist; no Prerequisites, Installation, Configuration, Known Limitations, Troubleshooting, Screenshots, Environment Variables, Info Panel, or Architecture
- Evidence per rung:
  - what it launches: "Overview", nf-core-chipseq-2-1-0/README.md:6
  - prerequisites: none
  - installation: "Local review before deployment", nf-core-chipseq-2-1-0/README.md:24 (describes review checklist, not installation steps)
  - configuration: none
  - known limitations: none
  - troubleshooting: none
  - screenshots: none
  - environment variables: none
  - info panel: none
  - architecture: none

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| QUA-01 | `check: documentation-rating` | FAIL | high | Below minimal documentation — fails Adequate target for inclusion | nf-core-chipseq-2-1-0/README.md:1 |

### Code Quality

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| QUA-07 | `check: numeric-field-bounds` | NOT CHECKED | info | form.json failed_to_run (ERB not stripped before YAML parse) | form.json |
| QUA-10 | `check: erb-missing-value` | NOT CHECKED | info | form.json failed_to_run — no attributes available for check | form.json |
| QUA-08 | `check: magic-numbers` | PASS | info | No numeric_literals or hex_colors detected in template.json | template.json |
| QUA-04 | `check: dead-code` | PASS | info | No commented_code detected in template.json | template.json |
| QUA-09 | `check: duplicated-blocks` | PASS | info | No large duplicated code blocks | template.json |
| QUA-03 | `check: error-handling` | PASS | low | set -euo pipefail in script.sh.erb; cd and mkdir have shell defaults under set -e | nf-core-chipseq-2-1-0/template/script.sh.erb:3 |
| QUA-06 | `check: icon-matches-target-os` | PASS | info | No icons defined in template.json | template.json |

**Code quality observations:** No copy-paste artifacts, duplicate YAML keys, or wrong help text found. The pre-review fact scan (template.json) reported zero commented_code, numeric_literals, and hex_colors across all batch_connect apps. Note: `form.json` failed to parse for all 16 batch_connect apps due to unstripped ERB — this is a scanner defect, not a form defect.

**Per-app decision:** Request changes

---


## App: nf-core-denovotranscript-1-2-1 (nf-core-denovotranscript-1-2-1)

### Signals

| Dimension | Level | Evidence |
|---|---|---|
| Portability | High | Not portable — cluster pax, partition file, port 1234, nf2ood.env path, pipeline root, singularity cache, and slurm profile are all Tufts-specific and undocumented |
| Documentation | High | Below minimal — only Overview section and Local review before deployment checklist; no prerequisites, installation, configuration, or troubleshooting |
| Upkeep (this app) | High | Last change 2026-06-26; one contributor; per-app CHANGELOG present but no CI |

### Structure

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| STR-02 | `check: str-02-metadata` | FAIL | high | manifest.yml missing: maintainer.name, maintainer.support_url. app_type "batch_connect" not in published vocabulary (closest: "batch-connect-basic") | nf-core-denovotranscript-1-2-1/manifest.yml |
| STR-03 | `check: str-03-yaml-valid` | PASS | info | form.yml.erb has balanced ERB tags (verified); manifest.yml parses as valid YAML | nf-core-denovotranscript-1-2-1/form.yml.erb:1 |
| STR-06 | `check: str-06-syntax` | PASS | info | All 2 shell files pass bash -n after ERB stripping (before.sh.erb, script.sh.erb) | nf-core-denovotranscript-1-2-1/template/before.sh.erb:1, nf-core-denovotranscript-1-2-1/template/script.sh.erb:1 |
| STR-07 | `check: str-07-layout` | PASS | info | Batch Connect layout complete: form.yml.erb, submit.yml.erb, template/ (3 files) | nf-core-denovotranscript-1-2-1/form.yml.erb, nf-core-denovotranscript-1-2-1/submit.yml.erb, template/ |
| STR-04 | `check: str-04-references` | NOT CHECKED | info | form.json failed_to_run (ERB not stripped before YAML parse) | form.json |

### Security

**Check tiers:** Tiers 1–2

Tier 3 not checked — no isolated execution environment.

| Tool | Status | Result |
|---|---|---|
| shellcheck | Run (ERB-stripped) | 64 findings (SC2050, SC2148, SC2155), 16 of them linted in isolation from the job-script family |
| semgrep | Run | 0 findings |
| bandit | Not run (no applicable files) | — |
| trivy | Not run (no applicable files) | — |

#### Findings

| Rule | Check | Result | Severity | Tag | Summary | Evidence |
|---|---|---|---|---|---|---|
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `bc_email_on_started` is a check_box (1/0); boolean value does not reach shell | nf-core-denovotranscript-1-2-1/submit.yml.erb:9 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `bc_num_hours` is a number_field (min:1); only numeric values possible | nf-core-denovotranscript-1-2-1/submit.yml.erb:14 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `num_cores` is a number_field (min:1); only numeric values possible | nf-core-denovotranscript-1-2-1/submit.yml.erb:24 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `num_memory` is a number_field (min:1); only numeric values possible | nf-core-denovotranscript-1-2-1/submit.yml.erb:26 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `partition` from select widget loaded from cpu_partition.yml partial; controlled options | nf-core-denovotranscript-1-2-1/submit.yml.erb:29 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `workdir` is path_selector; shell-quoted assignment of filesystem path | nf-core-denovotranscript-1-2-1/template/before.sh.erb:10, nf-core-denovotranscript-1-2-1/template/script.sh.erb:9 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `resume` is check_box (1/0); shell-quoted comparison with constant "1" | nf-core-denovotranscript-1-2-1/template/script.sh.erb:19 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `nextflow_version` is select widget; shell-quoted assignment | nf-core-denovotranscript-1-2-1/template/script.sh.erb:36 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `executor` is select widget (slurm/local); shell-quoted comparison | nf-core-denovotranscript-1-2-1/template/script.sh.erb:64 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `num_cores` written into heredoc-based Nextflow custom.config (not shell-executed) | nf-core-denovotranscript-1-2-1/template/script.sh.erb:72 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `num_memory` written into heredoc-based Nextflow custom.config; shell-quoted | nf-core-denovotranscript-1-2-1/template/script.sh.erb:73 |
| OODT-01 | `check: sec-eval-exec` | PASS | info | — | `source "${nf2ood_env_file}"` uses hardcoded path (not user-controllable); guarded by -r check | nf-core-denovotranscript-1-2-1/template/script.sh.erb:28 |
| OODT-01 | `check: sec-tool-finding` | PASS | info | — | SC2148, SC2155: artefacts of linting OOD's job-script files one at a time | nf-core-denovotranscript-1-2-1/template/before.sh.erb:1,5 |
| OODT-01 | `check: sec-tool-finding` | PASS | info | — | SC2050: ERB-stripped template yields constant comparisons, style/linting concern | nf-core-denovotranscript-1-2-1/template/script.sh.erb:19,64 |

#### Additional observations (review)

| Rule | Result | Severity | Tag | Summary | Evidence |
|---|---|---|---|---|---|
| — | PASS | info | — | `before.sh.erb` exports `port=1234` but no web service is started in templates; port variable is unused | nf-core-denovotranscript-1-2-1/template/before.sh.erb:8 |
| — | PASS | info | — | `script.sh.erb` contains hardcoded cluster path /cluster/tufts/yzhang85/github/nfcore2ood/nf2ood.env (site-specific, not security concern) | nf-core-denovotranscript-1-2-1/template/script.sh.erb:25 |

No tool-detectable issues in the checked tiers.

### Capability profile (batch_connect)

| File | Capabilities | Anomalies |
|---|---|---|
| `form.yml.erb` | 80-100+ form fields (path_selectors, number_fields, select widgets), ERB-included partials | None |
| `submit.yml.erb` | ERB interpolates form values into slurm job directives, email config | None |
| `template/before.sh.erb` | Sets up working directory, exports hostname and reserved port | None |
| `template/nf-params.json.erb` | Converts form values to JSON via Ruby lambdas (to_bool, to_number), sanitizes types | None |
| `template/script.sh.erb` | Loads modules (nextflow, singularity), sources hardcoded env file, builds nextflow run command | Hardcoded cluster paths |

All batch_connect apps run Nextflow pipelines on the compute node via SLURM or local executor. They do not start network services, do not read credentials, and do not write to dotfiles or cron. Authentication is provided entirely by OOD.

### Portability
- Rating: Not portable — cluster pax, partition file, port 1234, nf2ood.env path, pipeline root, singularity cache, and slurm profile are all Tufts-specific and undocumented

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Hardcoded cluster "pax" in form.yml.erb | nf-core-denovotranscript-1-2-1/form.yml.erb:2 |
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Partition loaded from external mixin file /etc/ood/config/.../cpu_partition.yml | nf-core-denovotranscript-1-2-1/form.yml.erb:35 |
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Hardcoded port 1234 in before.sh.erb | nf-core-denovotranscript-1-2-1/template/before.sh.erb:8 |
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Hardcoded nf2ood.env path in script.sh.erb | nf-core-denovotranscript-1-2-1/template/script.sh.erb:25 |
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Hardcoded pipeline root path in script.sh.erb | nf-core-denovotranscript-1-2-1/template/script.sh.erb:33 |
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Hardcoded singularity cache path in script.sh.erb | nf-core-denovotranscript-1-2-1/template/script.sh.erb:34 |
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Hardcoded slurm profile name "tufts" in script.sh.erb | nf-core-denovotranscript-1-2-1/template/script.sh.erb:35 |
| QUA-02 | `check: hardcoded-site-paths` | PASS | info | nodes=2 / mem=12G are explicit scheduler params in submit.yml.erb (documented in form) | nf-core-denovotranscript-1-2-1/submit.yml.erb:18-21 |
| QUA-02 | `check: portability-rating` | FAIL | medium | Not portable — all 7 site-specific values are undocumented and Tufts-specific | — |

### Documentation
- Rating: Below minimal — only Overview section and Local review before deployment checklist; no Prerequisites, Installation, Configuration, Known Limitations, Troubleshooting, Screenshots, Environment Variables, Info Panel, or Architecture
- Evidence per rung:
  - what it launches: "Overview", nf-core-denovotranscript-1-2-1/README.md:6
  - prerequisites: none
  - installation: "Local review before deployment", nf-core-denovotranscript-1-2-1/README.md:24 (describes review checklist, not installation steps)
  - configuration: none
  - known limitations: none
  - troubleshooting: none
  - screenshots: none
  - environment variables: none
  - info panel: none
  - architecture: none

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| QUA-01 | `check: documentation-rating` | FAIL | high | Below minimal documentation — fails Adequate target for inclusion | nf-core-denovotranscript-1-2-1/README.md:1 |

### Code Quality

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| QUA-07 | `check: numeric-field-bounds` | NOT CHECKED | info | form.json failed_to_run (ERB not stripped before YAML parse) | form.json |
| QUA-10 | `check: erb-missing-value` | NOT CHECKED | info | form.json failed_to_run — no attributes available for check | form.json |
| QUA-08 | `check: magic-numbers` | PASS | info | No numeric_literals or hex_colors detected in template.json | template.json |
| QUA-04 | `check: dead-code` | PASS | info | No commented_code detected in template.json | template.json |
| QUA-09 | `check: duplicated-blocks` | PASS | info | No large duplicated code blocks | template.json |
| QUA-03 | `check: error-handling` | PASS | low | set -euo pipefail in script.sh.erb; cd and mkdir have shell defaults under set -e | nf-core-denovotranscript-1-2-1/template/script.sh.erb:3 |
| QUA-06 | `check: icon-matches-target-os` | PASS | info | No icons defined in template.json | template.json |

**Code quality observations:** No copy-paste artifacts, duplicate YAML keys, or wrong help text found. The pre-review fact scan (template.json) reported zero commented_code, numeric_literals, and hex_colors across all batch_connect apps. Note: `form.json` failed to parse for all 16 batch_connect apps due to unstripped ERB — this is a scanner defect, not a form defect.

**Per-app decision:** Request changes

---


## App: nf-core-differentialabundance-2-0-0 (nf-core-differentialabundance-2-0-0)

### Signals

| Dimension | Level | Evidence |
|---|---|---|
| Portability | High | Not portable — cluster pax, partition file, port 1234, nf2ood.env path, pipeline root, singularity cache, and slurm profile are all Tufts-specific and undocumented |
| Documentation | High | Below minimal — only Overview section and Local review before deployment checklist; no prerequisites, installation, configuration, or troubleshooting |
| Upkeep (this app) | High | Last change 2026-06-26; one contributor; per-app CHANGELOG present but no CI |

### Structure

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| STR-02 | `check: str-02-metadata` | FAIL | high | manifest.yml missing: maintainer.name, maintainer.support_url. app_type "batch_connect" not in published vocabulary (closest: "batch-connect-basic") | nf-core-differentialabundance-2-0-0/manifest.yml |
| STR-03 | `check: str-03-yaml-valid` | PASS | info | form.yml.erb has balanced ERB tags (verified); manifest.yml parses as valid YAML | nf-core-differentialabundance-2-0-0/form.yml.erb:1 |
| STR-06 | `check: str-06-syntax` | PASS | info | All 2 shell files pass bash -n after ERB stripping (before.sh.erb, script.sh.erb) | nf-core-differentialabundance-2-0-0/template/before.sh.erb:1, nf-core-differentialabundance-2-0-0/template/script.sh.erb:1 |
| STR-07 | `check: str-07-layout` | PASS | info | Batch Connect layout complete: form.yml.erb, submit.yml.erb, template/ (3 files) | nf-core-differentialabundance-2-0-0/form.yml.erb, nf-core-differentialabundance-2-0-0/submit.yml.erb, template/ |
| STR-04 | `check: str-04-references` | NOT CHECKED | info | form.json failed_to_run (ERB not stripped before YAML parse) | form.json |

### Security

**Check tiers:** Tiers 1–2

Tier 3 not checked — no isolated execution environment.

| Tool | Status | Result |
|---|---|---|
| shellcheck | Run (ERB-stripped) | 64 findings (SC2050, SC2148, SC2155), 16 of them linted in isolation from the job-script family |
| semgrep | Run | 0 findings |
| bandit | Not run (no applicable files) | — |
| trivy | Not run (no applicable files) | — |

#### Findings

| Rule | Check | Result | Severity | Tag | Summary | Evidence |
|---|---|---|---|---|---|---|
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `bc_email_on_started` is a check_box (1/0); boolean value does not reach shell | nf-core-differentialabundance-2-0-0/submit.yml.erb:9 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `bc_num_hours` is a number_field (min:1); only numeric values possible | nf-core-differentialabundance-2-0-0/submit.yml.erb:14 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `num_cores` is a number_field (min:1); only numeric values possible | nf-core-differentialabundance-2-0-0/submit.yml.erb:24 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `num_memory` is a number_field (min:1); only numeric values possible | nf-core-differentialabundance-2-0-0/submit.yml.erb:26 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `partition` from select widget loaded from cpu_partition.yml partial; controlled options | nf-core-differentialabundance-2-0-0/submit.yml.erb:29 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `workdir` is path_selector; shell-quoted assignment of filesystem path | nf-core-differentialabundance-2-0-0/template/before.sh.erb:10, nf-core-differentialabundance-2-0-0/template/script.sh.erb:9 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `resume` is check_box (1/0); shell-quoted comparison with constant "1" | nf-core-differentialabundance-2-0-0/template/script.sh.erb:19 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `nextflow_version` is select widget; shell-quoted assignment | nf-core-differentialabundance-2-0-0/template/script.sh.erb:36 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `executor` is select widget (slurm/local); shell-quoted comparison | nf-core-differentialabundance-2-0-0/template/script.sh.erb:64 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `num_cores` written into heredoc-based Nextflow custom.config (not shell-executed) | nf-core-differentialabundance-2-0-0/template/script.sh.erb:72 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `num_memory` written into heredoc-based Nextflow custom.config; shell-quoted | nf-core-differentialabundance-2-0-0/template/script.sh.erb:73 |
| OODT-01 | `check: sec-eval-exec` | PASS | info | — | `source "${nf2ood_env_file}"` uses hardcoded path (not user-controllable); guarded by -r check | nf-core-differentialabundance-2-0-0/template/script.sh.erb:28 |
| OODT-01 | `check: sec-tool-finding` | PASS | info | — | SC2148, SC2155: artefacts of linting OOD's job-script files one at a time | nf-core-differentialabundance-2-0-0/template/before.sh.erb:1,5 |
| OODT-01 | `check: sec-tool-finding` | PASS | info | — | SC2050: ERB-stripped template yields constant comparisons, style/linting concern | nf-core-differentialabundance-2-0-0/template/script.sh.erb:19,64 |

#### Additional observations (review)

| Rule | Result | Severity | Tag | Summary | Evidence |
|---|---|---|---|---|---|
| — | PASS | info | — | `before.sh.erb` exports `port=1234` but no web service is started in templates; port variable is unused | nf-core-differentialabundance-2-0-0/template/before.sh.erb:8 |
| — | PASS | info | — | `script.sh.erb` contains hardcoded cluster path /cluster/tufts/yzhang85/github/nfcore2ood/nf2ood.env (site-specific, not security concern) | nf-core-differentialabundance-2-0-0/template/script.sh.erb:25 |

No tool-detectable issues in the checked tiers.

### Capability profile (batch_connect)

| File | Capabilities | Anomalies |
|---|---|---|
| `form.yml.erb` | 80-100+ form fields (path_selectors, number_fields, select widgets), ERB-included partials | None |
| `submit.yml.erb` | ERB interpolates form values into slurm job directives, email config | None |
| `template/before.sh.erb` | Sets up working directory, exports hostname and reserved port | None |
| `template/nf-params.json.erb` | Converts form values to JSON via Ruby lambdas (to_bool, to_number), sanitizes types | None |
| `template/script.sh.erb` | Loads modules (nextflow, singularity), sources hardcoded env file, builds nextflow run command | Hardcoded cluster paths |

All batch_connect apps run Nextflow pipelines on the compute node via SLURM or local executor. They do not start network services, do not read credentials, and do not write to dotfiles or cron. Authentication is provided entirely by OOD.

### Portability
- Rating: Not portable — cluster pax, partition file, port 1234, nf2ood.env path, pipeline root, singularity cache, and slurm profile are all Tufts-specific and undocumented

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Hardcoded cluster "pax" in form.yml.erb | nf-core-differentialabundance-2-0-0/form.yml.erb:2 |
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Partition loaded from external mixin file /etc/ood/config/.../cpu_partition.yml | nf-core-differentialabundance-2-0-0/form.yml.erb:35 |
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Hardcoded port 1234 in before.sh.erb | nf-core-differentialabundance-2-0-0/template/before.sh.erb:8 |
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Hardcoded nf2ood.env path in script.sh.erb | nf-core-differentialabundance-2-0-0/template/script.sh.erb:25 |
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Hardcoded pipeline root path in script.sh.erb | nf-core-differentialabundance-2-0-0/template/script.sh.erb:33 |
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Hardcoded singularity cache path in script.sh.erb | nf-core-differentialabundance-2-0-0/template/script.sh.erb:34 |
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Hardcoded slurm profile name "tufts" in script.sh.erb | nf-core-differentialabundance-2-0-0/template/script.sh.erb:35 |
| QUA-02 | `check: hardcoded-site-paths` | PASS | info | nodes=2 / mem=12G are explicit scheduler params in submit.yml.erb (documented in form) | nf-core-differentialabundance-2-0-0/submit.yml.erb:18-21 |
| QUA-02 | `check: portability-rating` | FAIL | medium | Not portable — all 7 site-specific values are undocumented and Tufts-specific | — |

### Documentation
- Rating: Below minimal — only Overview section and Local review before deployment checklist; no Prerequisites, Installation, Configuration, Known Limitations, Troubleshooting, Screenshots, Environment Variables, Info Panel, or Architecture
- Evidence per rung:
  - what it launches: "Overview", nf-core-differentialabundance-2-0-0/README.md:6
  - prerequisites: none
  - installation: "Local review before deployment", nf-core-differentialabundance-2-0-0/README.md:24 (describes review checklist, not installation steps)
  - configuration: none
  - known limitations: none
  - troubleshooting: none
  - screenshots: none
  - environment variables: none
  - info panel: none
  - architecture: none

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| QUA-01 | `check: documentation-rating` | FAIL | high | Below minimal documentation — fails Adequate target for inclusion | nf-core-differentialabundance-2-0-0/README.md:1 |

### Code Quality

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| QUA-07 | `check: numeric-field-bounds` | NOT CHECKED | info | form.json failed_to_run (ERB not stripped before YAML parse) | form.json |
| QUA-10 | `check: erb-missing-value` | NOT CHECKED | info | form.json failed_to_run — no attributes available for check | form.json |
| QUA-08 | `check: magic-numbers` | PASS | info | No numeric_literals or hex_colors detected in template.json | template.json |
| QUA-04 | `check: dead-code` | PASS | info | No commented_code detected in template.json | template.json |
| QUA-09 | `check: duplicated-blocks` | PASS | info | No large duplicated code blocks | template.json |
| QUA-03 | `check: error-handling` | PASS | low | set -euo pipefail in script.sh.erb; cd and mkdir have shell defaults under set -e | nf-core-differentialabundance-2-0-0/template/script.sh.erb:3 |
| QUA-06 | `check: icon-matches-target-os` | PASS | info | No icons defined in template.json | template.json |

**Code quality observations:** No copy-paste artifacts, duplicate YAML keys, or wrong help text found. The pre-review fact scan (template.json) reported zero commented_code, numeric_literals, and hex_colors across all batch_connect apps. Note: `form.json` failed to parse for all 16 batch_connect apps due to unstripped ERB — this is a scanner defect, not a form defect.

**Per-app decision:** Request changes

---


## App: nf-core-fetchngs-1-12-0 (nf-core-fetchngs-1-12-0)

### Signals

| Dimension | Level | Evidence |
|---|---|---|
| Portability | High | Not portable — cluster pax, partition file, port 1234, nf2ood.env path, pipeline root, singularity cache, and slurm profile are all Tufts-specific and undocumented |
| Documentation | High | Below minimal — only Overview section and Local review before deployment checklist; no prerequisites, installation, configuration, or troubleshooting |
| Upkeep (this app) | High | Last change 2026-06-26; one contributor; per-app CHANGELOG present but no CI |

### Structure

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| STR-02 | `check: str-02-metadata` | FAIL | high | manifest.yml missing: maintainer.name, maintainer.support_url. app_type "batch_connect" not in published vocabulary (closest: "batch-connect-basic") | nf-core-fetchngs-1-12-0/manifest.yml |
| STR-03 | `check: str-03-yaml-valid` | PASS | info | form.yml.erb has balanced ERB tags (verified); manifest.yml parses as valid YAML | nf-core-fetchngs-1-12-0/form.yml.erb:1 |
| STR-06 | `check: str-06-syntax` | PASS | info | All 2 shell files pass bash -n after ERB stripping (before.sh.erb, script.sh.erb) | nf-core-fetchngs-1-12-0/template/before.sh.erb:1, nf-core-fetchngs-1-12-0/template/script.sh.erb:1 |
| STR-07 | `check: str-07-layout` | PASS | info | Batch Connect layout complete: form.yml.erb, submit.yml.erb, template/ (3 files) | nf-core-fetchngs-1-12-0/form.yml.erb, nf-core-fetchngs-1-12-0/submit.yml.erb, template/ |
| STR-04 | `check: str-04-references` | NOT CHECKED | info | form.json failed_to_run (ERB not stripped before YAML parse) | form.json |

### Security

**Check tiers:** Tiers 1–2

Tier 3 not checked — no isolated execution environment.

| Tool | Status | Result |
|---|---|---|
| shellcheck | Run (ERB-stripped) | 64 findings (SC2050, SC2148, SC2155), 16 of them linted in isolation from the job-script family |
| semgrep | Run | 0 findings |
| bandit | Not run (no applicable files) | — |
| trivy | Not run (no applicable files) | — |

#### Findings

| Rule | Check | Result | Severity | Tag | Summary | Evidence |
|---|---|---|---|---|---|---|
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `bc_email_on_started` is a check_box (1/0); boolean value does not reach shell | nf-core-fetchngs-1-12-0/submit.yml.erb:9 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `bc_num_hours` is a number_field (min:1); only numeric values possible | nf-core-fetchngs-1-12-0/submit.yml.erb:14 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `num_cores` is a number_field (min:1); only numeric values possible | nf-core-fetchngs-1-12-0/submit.yml.erb:24 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `num_memory` is a number_field (min:1); only numeric values possible | nf-core-fetchngs-1-12-0/submit.yml.erb:26 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `partition` from select widget loaded from cpu_partition.yml partial; controlled options | nf-core-fetchngs-1-12-0/submit.yml.erb:29 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `workdir` is path_selector; shell-quoted assignment of filesystem path | nf-core-fetchngs-1-12-0/template/before.sh.erb:10, nf-core-fetchngs-1-12-0/template/script.sh.erb:9 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `resume` is check_box (1/0); shell-quoted comparison with constant "1" | nf-core-fetchngs-1-12-0/template/script.sh.erb:19 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `nextflow_version` is select widget; shell-quoted assignment | nf-core-fetchngs-1-12-0/template/script.sh.erb:36 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `executor` is select widget (slurm/local); shell-quoted comparison | nf-core-fetchngs-1-12-0/template/script.sh.erb:64 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `num_cores` written into heredoc-based Nextflow custom.config (not shell-executed) | nf-core-fetchngs-1-12-0/template/script.sh.erb:72 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `num_memory` written into heredoc-based Nextflow custom.config; shell-quoted | nf-core-fetchngs-1-12-0/template/script.sh.erb:73 |
| OODT-01 | `check: sec-eval-exec` | PASS | info | — | `source "${nf2ood_env_file}"` uses hardcoded path (not user-controllable); guarded by -r check | nf-core-fetchngs-1-12-0/template/script.sh.erb:28 |
| OODT-01 | `check: sec-tool-finding` | PASS | info | — | SC2148, SC2155: artefacts of linting OOD's job-script files one at a time | nf-core-fetchngs-1-12-0/template/before.sh.erb:1,5 |
| OODT-01 | `check: sec-tool-finding` | PASS | info | — | SC2050: ERB-stripped template yields constant comparisons, style/linting concern | nf-core-fetchngs-1-12-0/template/script.sh.erb:19,64 |

#### Additional observations (review)

| Rule | Result | Severity | Tag | Summary | Evidence |
|---|---|---|---|---|---|
| — | PASS | info | — | `before.sh.erb` exports `port=1234` but no web service is started in templates; port variable is unused | nf-core-fetchngs-1-12-0/template/before.sh.erb:8 |
| — | PASS | info | — | `script.sh.erb` contains hardcoded cluster path /cluster/tufts/yzhang85/github/nfcore2ood/nf2ood.env (site-specific, not security concern) | nf-core-fetchngs-1-12-0/template/script.sh.erb:25 |

No tool-detectable issues in the checked tiers.

### Capability profile (batch_connect)

| File | Capabilities | Anomalies |
|---|---|---|
| `form.yml.erb` | 80-100+ form fields (path_selectors, number_fields, select widgets), ERB-included partials | None |
| `submit.yml.erb` | ERB interpolates form values into slurm job directives, email config | None |
| `template/before.sh.erb` | Sets up working directory, exports hostname and reserved port | None |
| `template/nf-params.json.erb` | Converts form values to JSON via Ruby lambdas (to_bool, to_number), sanitizes types | None |
| `template/script.sh.erb` | Loads modules (nextflow, singularity), sources hardcoded env file, builds nextflow run command | Hardcoded cluster paths |

All batch_connect apps run Nextflow pipelines on the compute node via SLURM or local executor. They do not start network services, do not read credentials, and do not write to dotfiles or cron. Authentication is provided entirely by OOD.

### Portability
- Rating: Not portable — cluster pax, partition file, port 1234, nf2ood.env path, pipeline root, singularity cache, and slurm profile are all Tufts-specific and undocumented

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Hardcoded cluster "pax" in form.yml.erb | nf-core-fetchngs-1-12-0/form.yml.erb:2 |
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Partition loaded from external mixin file /etc/ood/config/.../cpu_partition.yml | nf-core-fetchngs-1-12-0/form.yml.erb:35 |
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Hardcoded port 1234 in before.sh.erb | nf-core-fetchngs-1-12-0/template/before.sh.erb:8 |
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Hardcoded nf2ood.env path in script.sh.erb | nf-core-fetchngs-1-12-0/template/script.sh.erb:25 |
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Hardcoded pipeline root path in script.sh.erb | nf-core-fetchngs-1-12-0/template/script.sh.erb:33 |
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Hardcoded singularity cache path in script.sh.erb | nf-core-fetchngs-1-12-0/template/script.sh.erb:34 |
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Hardcoded slurm profile name "tufts" in script.sh.erb | nf-core-fetchngs-1-12-0/template/script.sh.erb:35 |
| QUA-02 | `check: hardcoded-site-paths` | PASS | info | nodes=2 / mem=12G are explicit scheduler params in submit.yml.erb (documented in form) | nf-core-fetchngs-1-12-0/submit.yml.erb:18-21 |
| QUA-02 | `check: portability-rating` | FAIL | medium | Not portable — all 7 site-specific values are undocumented and Tufts-specific | — |

### Documentation
- Rating: Below minimal — only Overview section and Local review before deployment checklist; no Prerequisites, Installation, Configuration, Known Limitations, Troubleshooting, Screenshots, Environment Variables, Info Panel, or Architecture
- Evidence per rung:
  - what it launches: "Overview", nf-core-fetchngs-1-12-0/README.md:6
  - prerequisites: none
  - installation: "Local review before deployment", nf-core-fetchngs-1-12-0/README.md:24 (describes review checklist, not installation steps)
  - configuration: none
  - known limitations: none
  - troubleshooting: none
  - screenshots: none
  - environment variables: none
  - info panel: none
  - architecture: none

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| QUA-01 | `check: documentation-rating` | FAIL | high | Below minimal documentation — fails Adequate target for inclusion | nf-core-fetchngs-1-12-0/README.md:1 |

### Code Quality

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| QUA-07 | `check: numeric-field-bounds` | NOT CHECKED | info | form.json failed_to_run (ERB not stripped before YAML parse) | form.json |
| QUA-10 | `check: erb-missing-value` | NOT CHECKED | info | form.json failed_to_run — no attributes available for check | form.json |
| QUA-08 | `check: magic-numbers` | PASS | info | No numeric_literals or hex_colors detected in template.json | template.json |
| QUA-04 | `check: dead-code` | PASS | info | No commented_code detected in template.json | template.json |
| QUA-09 | `check: duplicated-blocks` | PASS | info | No large duplicated code blocks | template.json |
| QUA-03 | `check: error-handling` | PASS | low | set -euo pipefail in script.sh.erb; cd and mkdir have shell defaults under set -e | nf-core-fetchngs-1-12-0/template/script.sh.erb:3 |
| QUA-06 | `check: icon-matches-target-os` | PASS | info | No icons defined in template.json | template.json |

**Code quality observations:** No copy-paste artifacts, duplicate YAML keys, or wrong help text found. The pre-review fact scan (template.json) reported zero commented_code, numeric_literals, and hex_colors across all batch_connect apps. Note: `form.json` failed to parse for all 16 batch_connect apps due to unstripped ERB — this is a scanner defect, not a form defect.

**Per-app decision:** Request changes

---


## App: nf-core-funcscan-3-0-0 (nf-core-funcscan-3-0-0)

### Signals

| Dimension | Level | Evidence |
|---|---|---|
| Portability | High | Not portable — cluster pax, partition file, port 1234, nf2ood.env path, pipeline root, singularity cache, and slurm profile are all Tufts-specific and undocumented |
| Documentation | High | Below minimal — only Overview section and Local review before deployment checklist; no prerequisites, installation, configuration, or troubleshooting |
| Upkeep (this app) | High | Last change 2026-06-26; one contributor; per-app CHANGELOG present but no CI |

### Structure

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| STR-02 | `check: str-02-metadata` | FAIL | high | manifest.yml missing: maintainer.name, maintainer.support_url. app_type "batch_connect" not in published vocabulary (closest: "batch-connect-basic") | nf-core-funcscan-3-0-0/manifest.yml |
| STR-03 | `check: str-03-yaml-valid` | PASS | info | form.yml.erb has balanced ERB tags (verified); manifest.yml parses as valid YAML | nf-core-funcscan-3-0-0/form.yml.erb:1 |
| STR-06 | `check: str-06-syntax` | PASS | info | All 2 shell files pass bash -n after ERB stripping (before.sh.erb, script.sh.erb) | nf-core-funcscan-3-0-0/template/before.sh.erb:1, nf-core-funcscan-3-0-0/template/script.sh.erb:1 |
| STR-07 | `check: str-07-layout` | PASS | info | Batch Connect layout complete: form.yml.erb, submit.yml.erb, template/ (3 files) | nf-core-funcscan-3-0-0/form.yml.erb, nf-core-funcscan-3-0-0/submit.yml.erb, template/ |
| STR-04 | `check: str-04-references` | NOT CHECKED | info | form.json failed_to_run (ERB not stripped before YAML parse) | form.json |

### Security

**Check tiers:** Tiers 1–2

Tier 3 not checked — no isolated execution environment.

| Tool | Status | Result |
|---|---|---|
| shellcheck | Run (ERB-stripped) | 64 findings (SC2050, SC2148, SC2155), 16 of them linted in isolation from the job-script family |
| semgrep | Run | 0 findings |
| bandit | Not run (no applicable files) | — |
| trivy | Not run (no applicable files) | — |

#### Findings

| Rule | Check | Result | Severity | Tag | Summary | Evidence |
|---|---|---|---|---|---|---|
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `bc_email_on_started` is a check_box (1/0); boolean value does not reach shell | nf-core-funcscan-3-0-0/submit.yml.erb:9 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `bc_num_hours` is a number_field (min:1); only numeric values possible | nf-core-funcscan-3-0-0/submit.yml.erb:14 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `num_cores` is a number_field (min:1); only numeric values possible | nf-core-funcscan-3-0-0/submit.yml.erb:24 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `num_memory` is a number_field (min:1); only numeric values possible | nf-core-funcscan-3-0-0/submit.yml.erb:26 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `partition` from select widget loaded from cpu_partition.yml partial; controlled options | nf-core-funcscan-3-0-0/submit.yml.erb:29 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `workdir` is path_selector; shell-quoted assignment of filesystem path | nf-core-funcscan-3-0-0/template/before.sh.erb:10, nf-core-funcscan-3-0-0/template/script.sh.erb:9 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `resume` is check_box (1/0); shell-quoted comparison with constant "1" | nf-core-funcscan-3-0-0/template/script.sh.erb:19 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `nextflow_version` is select widget; shell-quoted assignment | nf-core-funcscan-3-0-0/template/script.sh.erb:36 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `executor` is select widget (slurm/local); shell-quoted comparison | nf-core-funcscan-3-0-0/template/script.sh.erb:64 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `num_cores` written into heredoc-based Nextflow custom.config (not shell-executed) | nf-core-funcscan-3-0-0/template/script.sh.erb:72 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `num_memory` written into heredoc-based Nextflow custom.config; shell-quoted | nf-core-funcscan-3-0-0/template/script.sh.erb:73 |
| OODT-01 | `check: sec-eval-exec` | PASS | info | — | `source "${nf2ood_env_file}"` uses hardcoded path (not user-controllable); guarded by -r check | nf-core-funcscan-3-0-0/template/script.sh.erb:28 |
| OODT-01 | `check: sec-tool-finding` | PASS | info | — | SC2148, SC2155: artefacts of linting OOD's job-script files one at a time | nf-core-funcscan-3-0-0/template/before.sh.erb:1,5 |
| OODT-01 | `check: sec-tool-finding` | PASS | info | — | SC2050: ERB-stripped template yields constant comparisons, style/linting concern | nf-core-funcscan-3-0-0/template/script.sh.erb:19,64 |

#### Additional observations (review)

| Rule | Result | Severity | Tag | Summary | Evidence |
|---|---|---|---|---|---|
| — | PASS | info | — | `before.sh.erb` exports `port=1234` but no web service is started in templates; port variable is unused | nf-core-funcscan-3-0-0/template/before.sh.erb:8 |
| — | PASS | info | — | `script.sh.erb` contains hardcoded cluster path /cluster/tufts/yzhang85/github/nfcore2ood/nf2ood.env (site-specific, not security concern) | nf-core-funcscan-3-0-0/template/script.sh.erb:25 |

No tool-detectable issues in the checked tiers.

### Capability profile (batch_connect)

| File | Capabilities | Anomalies |
|---|---|---|
| `form.yml.erb` | 80-100+ form fields (path_selectors, number_fields, select widgets), ERB-included partials | None |
| `submit.yml.erb` | ERB interpolates form values into slurm job directives, email config | None |
| `template/before.sh.erb` | Sets up working directory, exports hostname and reserved port | None |
| `template/nf-params.json.erb` | Converts form values to JSON via Ruby lambdas (to_bool, to_number), sanitizes types | None |
| `template/script.sh.erb` | Loads modules (nextflow, singularity), sources hardcoded env file, builds nextflow run command | Hardcoded cluster paths |

All batch_connect apps run Nextflow pipelines on the compute node via SLURM or local executor. They do not start network services, do not read credentials, and do not write to dotfiles or cron. Authentication is provided entirely by OOD.

### Portability
- Rating: Not portable — cluster pax, partition file, port 1234, nf2ood.env path, pipeline root, singularity cache, and slurm profile are all Tufts-specific and undocumented

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Hardcoded cluster "pax" in form.yml.erb | nf-core-funcscan-3-0-0/form.yml.erb:2 |
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Partition loaded from external mixin file /etc/ood/config/.../cpu_partition.yml | nf-core-funcscan-3-0-0/form.yml.erb:35 |
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Hardcoded port 1234 in before.sh.erb | nf-core-funcscan-3-0-0/template/before.sh.erb:8 |
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Hardcoded nf2ood.env path in script.sh.erb | nf-core-funcscan-3-0-0/template/script.sh.erb:25 |
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Hardcoded pipeline root path in script.sh.erb | nf-core-funcscan-3-0-0/template/script.sh.erb:33 |
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Hardcoded singularity cache path in script.sh.erb | nf-core-funcscan-3-0-0/template/script.sh.erb:34 |
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Hardcoded slurm profile name "tufts" in script.sh.erb | nf-core-funcscan-3-0-0/template/script.sh.erb:35 |
| QUA-02 | `check: hardcoded-site-paths` | PASS | info | nodes=2 / mem=12G are explicit scheduler params in submit.yml.erb (documented in form) | nf-core-funcscan-3-0-0/submit.yml.erb:18-21 |
| QUA-02 | `check: portability-rating` | FAIL | medium | Not portable — all 7 site-specific values are undocumented and Tufts-specific | — |

### Documentation
- Rating: Below minimal — only Overview section and Local review before deployment checklist; no Prerequisites, Installation, Configuration, Known Limitations, Troubleshooting, Screenshots, Environment Variables, Info Panel, or Architecture
- Evidence per rung:
  - what it launches: "Overview", nf-core-funcscan-3-0-0/README.md:6
  - prerequisites: none
  - installation: "Local review before deployment", nf-core-funcscan-3-0-0/README.md:24 (describes review checklist, not installation steps)
  - configuration: none
  - known limitations: none
  - troubleshooting: none
  - screenshots: none
  - environment variables: none
  - info panel: none
  - architecture: none

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| QUA-01 | `check: documentation-rating` | FAIL | high | Below minimal documentation — fails Adequate target for inclusion | nf-core-funcscan-3-0-0/README.md:1 |

### Code Quality

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| QUA-07 | `check: numeric-field-bounds` | NOT CHECKED | info | form.json failed_to_run (ERB not stripped before YAML parse) | form.json |
| QUA-10 | `check: erb-missing-value` | NOT CHECKED | info | form.json failed_to_run — no attributes available for check | form.json |
| QUA-08 | `check: magic-numbers` | PASS | info | No numeric_literals or hex_colors detected in template.json | template.json |
| QUA-04 | `check: dead-code` | PASS | info | No commented_code detected in template.json | template.json |
| QUA-09 | `check: duplicated-blocks` | PASS | info | No large duplicated code blocks | template.json |
| QUA-03 | `check: error-handling` | PASS | low | set -euo pipefail in script.sh.erb; cd and mkdir have shell defaults under set -e | nf-core-funcscan-3-0-0/template/script.sh.erb:3 |
| QUA-06 | `check: icon-matches-target-os` | PASS | info | No icons defined in template.json | template.json |

**Code quality observations:** No copy-paste artifacts, duplicate YAML keys, or wrong help text found. The pre-review fact scan (template.json) reported zero commented_code, numeric_literals, and hex_colors across all batch_connect apps. Note: `form.json` failed to parse for all 16 batch_connect apps due to unstripped ERB — this is a scanner defect, not a form defect.

**Per-app decision:** Request changes

---


## App: nf-core-mag-5-4-2 (nf-core-mag-5-4-2)

### Signals

| Dimension | Level | Evidence |
|---|---|---|
| Portability | High | Not portable — cluster pax, partition file, port 1234, nf2ood.env path, pipeline root, singularity cache, and slurm profile are all Tufts-specific and undocumented |
| Documentation | High | Below minimal — only Overview section and Local review before deployment checklist; no prerequisites, installation, configuration, or troubleshooting |
| Upkeep (this app) | High | Last change 2026-06-26; one contributor; per-app CHANGELOG present but no CI |

### Structure

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| STR-02 | `check: str-02-metadata` | FAIL | high | manifest.yml missing: maintainer.name, maintainer.support_url. app_type "batch_connect" not in published vocabulary (closest: "batch-connect-basic") | nf-core-mag-5-4-2/manifest.yml |
| STR-03 | `check: str-03-yaml-valid` | PASS | info | form.yml.erb has balanced ERB tags (verified); manifest.yml parses as valid YAML | nf-core-mag-5-4-2/form.yml.erb:1 |
| STR-06 | `check: str-06-syntax` | PASS | info | All 2 shell files pass bash -n after ERB stripping (before.sh.erb, script.sh.erb) | nf-core-mag-5-4-2/template/before.sh.erb:1, nf-core-mag-5-4-2/template/script.sh.erb:1 |
| STR-07 | `check: str-07-layout` | PASS | info | Batch Connect layout complete: form.yml.erb, submit.yml.erb, template/ (3 files) | nf-core-mag-5-4-2/form.yml.erb, nf-core-mag-5-4-2/submit.yml.erb, template/ |
| STR-04 | `check: str-04-references` | NOT CHECKED | info | form.json failed_to_run (ERB not stripped before YAML parse) | form.json |

### Security

**Check tiers:** Tiers 1–2

Tier 3 not checked — no isolated execution environment.

| Tool | Status | Result |
|---|---|---|
| shellcheck | Run (ERB-stripped) | 64 findings (SC2050, SC2148, SC2155), 16 of them linted in isolation from the job-script family |
| semgrep | Run | 0 findings |
| bandit | Not run (no applicable files) | — |
| trivy | Not run (no applicable files) | — |

#### Findings

| Rule | Check | Result | Severity | Tag | Summary | Evidence |
|---|---|---|---|---|---|---|
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `bc_email_on_started` is a check_box (1/0); boolean value does not reach shell | nf-core-mag-5-4-2/submit.yml.erb:9 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `bc_num_hours` is a number_field (min:1); only numeric values possible | nf-core-mag-5-4-2/submit.yml.erb:14 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `num_cores` is a number_field (min:1); only numeric values possible | nf-core-mag-5-4-2/submit.yml.erb:24 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `num_memory` is a number_field (min:1); only numeric values possible | nf-core-mag-5-4-2/submit.yml.erb:26 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `partition` from select widget loaded from cpu_partition.yml partial; controlled options | nf-core-mag-5-4-2/submit.yml.erb:29 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `workdir` is path_selector; shell-quoted assignment of filesystem path | nf-core-mag-5-4-2/template/before.sh.erb:10, nf-core-mag-5-4-2/template/script.sh.erb:9 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `resume` is check_box (1/0); shell-quoted comparison with constant "1" | nf-core-mag-5-4-2/template/script.sh.erb:19 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `nextflow_version` is select widget; shell-quoted assignment | nf-core-mag-5-4-2/template/script.sh.erb:36 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `executor` is select widget (slurm/local); shell-quoted comparison | nf-core-mag-5-4-2/template/script.sh.erb:64 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `num_cores` written into heredoc-based Nextflow custom.config (not shell-executed) | nf-core-mag-5-4-2/template/script.sh.erb:72 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `num_memory` written into heredoc-based Nextflow custom.config; shell-quoted | nf-core-mag-5-4-2/template/script.sh.erb:73 |
| OODT-01 | `check: sec-eval-exec` | PASS | info | — | `source "${nf2ood_env_file}"` uses hardcoded path (not user-controllable); guarded by -r check | nf-core-mag-5-4-2/template/script.sh.erb:28 |
| OODT-01 | `check: sec-tool-finding` | PASS | info | — | SC2148, SC2155: artefacts of linting OOD's job-script files one at a time | nf-core-mag-5-4-2/template/before.sh.erb:1,5 |
| OODT-01 | `check: sec-tool-finding` | PASS | info | — | SC2050: ERB-stripped template yields constant comparisons, style/linting concern | nf-core-mag-5-4-2/template/script.sh.erb:19,64 |

#### Additional observations (review)

| Rule | Result | Severity | Tag | Summary | Evidence |
|---|---|---|---|---|---|
| — | PASS | info | — | `before.sh.erb` exports `port=1234` but no web service is started in templates; port variable is unused | nf-core-mag-5-4-2/template/before.sh.erb:8 |
| — | PASS | info | — | `script.sh.erb` contains hardcoded cluster path /cluster/tufts/yzhang85/github/nfcore2ood/nf2ood.env (site-specific, not security concern) | nf-core-mag-5-4-2/template/script.sh.erb:25 |

No tool-detectable issues in the checked tiers.

### Capability profile (batch_connect)

| File | Capabilities | Anomalies |
|---|---|---|
| `form.yml.erb` | 80-100+ form fields (path_selectors, number_fields, select widgets), ERB-included partials | None |
| `submit.yml.erb` | ERB interpolates form values into slurm job directives, email config | None |
| `template/before.sh.erb` | Sets up working directory, exports hostname and reserved port | None |
| `template/nf-params.json.erb` | Converts form values to JSON via Ruby lambdas (to_bool, to_number), sanitizes types | None |
| `template/script.sh.erb` | Loads modules (nextflow, singularity), sources hardcoded env file, builds nextflow run command | Hardcoded cluster paths |

All batch_connect apps run Nextflow pipelines on the compute node via SLURM or local executor. They do not start network services, do not read credentials, and do not write to dotfiles or cron. Authentication is provided entirely by OOD.

### Portability
- Rating: Not portable — cluster pax, partition file, port 1234, nf2ood.env path, pipeline root, singularity cache, and slurm profile are all Tufts-specific and undocumented

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Hardcoded cluster "pax" in form.yml.erb | nf-core-mag-5-4-2/form.yml.erb:2 |
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Partition loaded from external mixin file /etc/ood/config/.../cpu_partition.yml | nf-core-mag-5-4-2/form.yml.erb:35 |
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Hardcoded port 1234 in before.sh.erb | nf-core-mag-5-4-2/template/before.sh.erb:8 |
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Hardcoded nf2ood.env path in script.sh.erb | nf-core-mag-5-4-2/template/script.sh.erb:25 |
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Hardcoded pipeline root path in script.sh.erb | nf-core-mag-5-4-2/template/script.sh.erb:33 |
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Hardcoded singularity cache path in script.sh.erb | nf-core-mag-5-4-2/template/script.sh.erb:34 |
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Hardcoded slurm profile name "tufts" in script.sh.erb | nf-core-mag-5-4-2/template/script.sh.erb:35 |
| QUA-02 | `check: hardcoded-site-paths` | PASS | info | nodes=2 / mem=12G are explicit scheduler params in submit.yml.erb (documented in form) | nf-core-mag-5-4-2/submit.yml.erb:18-21 |
| QUA-02 | `check: portability-rating` | FAIL | medium | Not portable — all 7 site-specific values are undocumented and Tufts-specific | — |

### Documentation
- Rating: Below minimal — only Overview section and Local review before deployment checklist; no Prerequisites, Installation, Configuration, Known Limitations, Troubleshooting, Screenshots, Environment Variables, Info Panel, or Architecture
- Evidence per rung:
  - what it launches: "Overview", nf-core-mag-5-4-2/README.md:6
  - prerequisites: none
  - installation: "Local review before deployment", nf-core-mag-5-4-2/README.md:24 (describes review checklist, not installation steps)
  - configuration: none
  - known limitations: none
  - troubleshooting: none
  - screenshots: none
  - environment variables: none
  - info panel: none
  - architecture: none

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| QUA-01 | `check: documentation-rating` | FAIL | high | Below minimal documentation — fails Adequate target for inclusion | nf-core-mag-5-4-2/README.md:1 |

### Code Quality

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| QUA-07 | `check: numeric-field-bounds` | NOT CHECKED | info | form.json failed_to_run (ERB not stripped before YAML parse) | form.json |
| QUA-10 | `check: erb-missing-value` | NOT CHECKED | info | form.json failed_to_run — no attributes available for check | form.json |
| QUA-08 | `check: magic-numbers` | PASS | info | No numeric_literals or hex_colors detected in template.json | template.json |
| QUA-04 | `check: dead-code` | PASS | info | No commented_code detected in template.json | template.json |
| QUA-09 | `check: duplicated-blocks` | PASS | info | No large duplicated code blocks | template.json |
| QUA-03 | `check: error-handling` | PASS | low | set -euo pipefail in script.sh.erb; cd and mkdir have shell defaults under set -e | nf-core-mag-5-4-2/template/script.sh.erb:3 |
| QUA-06 | `check: icon-matches-target-os` | PASS | info | No icons defined in template.json | template.json |

**Code quality observations:** No copy-paste artifacts, duplicate YAML keys, or wrong help text found. The pre-review fact scan (template.json) reported zero commented_code, numeric_literals, and hex_colors across all batch_connect apps. Note: `form.json` failed to parse for all 16 batch_connect apps due to unstripped ERB — this is a scanner defect, not a form defect.

**Per-app decision:** Request changes

---


## App: nf-core-methylseq-4-1-0 (nf-core-methylseq-4-1-0)

### Signals

| Dimension | Level | Evidence |
|---|---|---|
| Portability | High | Not portable — cluster pax, partition file, port 1234, nf2ood.env path, pipeline root, singularity cache, and slurm profile are all Tufts-specific and undocumented |
| Documentation | High | Below minimal — only Overview section and Local review before deployment checklist; no prerequisites, installation, configuration, or troubleshooting |
| Upkeep (this app) | High | Last change 2026-06-26; one contributor; per-app CHANGELOG present but no CI |

### Structure

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| STR-02 | `check: str-02-metadata` | FAIL | high | manifest.yml missing: maintainer.name, maintainer.support_url. app_type "batch_connect" not in published vocabulary (closest: "batch-connect-basic") | nf-core-methylseq-4-1-0/manifest.yml |
| STR-03 | `check: str-03-yaml-valid` | PASS | info | form.yml.erb has balanced ERB tags (verified); manifest.yml parses as valid YAML | nf-core-methylseq-4-1-0/form.yml.erb:1 |
| STR-06 | `check: str-06-syntax` | PASS | info | All 2 shell files pass bash -n after ERB stripping (before.sh.erb, script.sh.erb) | nf-core-methylseq-4-1-0/template/before.sh.erb:1, nf-core-methylseq-4-1-0/template/script.sh.erb:1 |
| STR-07 | `check: str-07-layout` | PASS | info | Batch Connect layout complete: form.yml.erb, submit.yml.erb, template/ (3 files) | nf-core-methylseq-4-1-0/form.yml.erb, nf-core-methylseq-4-1-0/submit.yml.erb, template/ |
| STR-04 | `check: str-04-references` | NOT CHECKED | info | form.json failed_to_run (ERB not stripped before YAML parse) | form.json |

### Security

**Check tiers:** Tiers 1–2

Tier 3 not checked — no isolated execution environment.

| Tool | Status | Result |
|---|---|---|
| shellcheck | Run (ERB-stripped) | 64 findings (SC2050, SC2148, SC2155), 16 of them linted in isolation from the job-script family |
| semgrep | Run | 0 findings |
| bandit | Not run (no applicable files) | — |
| trivy | Not run (no applicable files) | — |

#### Findings

| Rule | Check | Result | Severity | Tag | Summary | Evidence |
|---|---|---|---|---|---|---|
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `bc_email_on_started` is a check_box (1/0); boolean value does not reach shell | nf-core-methylseq-4-1-0/submit.yml.erb:9 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `bc_num_hours` is a number_field (min:1); only numeric values possible | nf-core-methylseq-4-1-0/submit.yml.erb:14 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `num_cores` is a number_field (min:1); only numeric values possible | nf-core-methylseq-4-1-0/submit.yml.erb:24 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `num_memory` is a number_field (min:1); only numeric values possible | nf-core-methylseq-4-1-0/submit.yml.erb:26 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `partition` from select widget loaded from cpu_partition.yml partial; controlled options | nf-core-methylseq-4-1-0/submit.yml.erb:29 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `workdir` is path_selector; shell-quoted assignment of filesystem path | nf-core-methylseq-4-1-0/template/before.sh.erb:10, nf-core-methylseq-4-1-0/template/script.sh.erb:9 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `resume` is check_box (1/0); shell-quoted comparison with constant "1" | nf-core-methylseq-4-1-0/template/script.sh.erb:19 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `nextflow_version` is select widget; shell-quoted assignment | nf-core-methylseq-4-1-0/template/script.sh.erb:36 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `executor` is select widget (slurm/local); shell-quoted comparison | nf-core-methylseq-4-1-0/template/script.sh.erb:64 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `num_cores` written into heredoc-based Nextflow custom.config (not shell-executed) | nf-core-methylseq-4-1-0/template/script.sh.erb:72 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `num_memory` written into heredoc-based Nextflow custom.config; shell-quoted | nf-core-methylseq-4-1-0/template/script.sh.erb:73 |
| OODT-01 | `check: sec-eval-exec` | PASS | info | — | `source "${nf2ood_env_file}"` uses hardcoded path (not user-controllable); guarded by -r check | nf-core-methylseq-4-1-0/template/script.sh.erb:28 |
| OODT-01 | `check: sec-tool-finding` | PASS | info | — | SC2148, SC2155: artefacts of linting OOD's job-script files one at a time | nf-core-methylseq-4-1-0/template/before.sh.erb:1,5 |
| OODT-01 | `check: sec-tool-finding` | PASS | info | — | SC2050: ERB-stripped template yields constant comparisons, style/linting concern | nf-core-methylseq-4-1-0/template/script.sh.erb:19,64 |

#### Additional observations (review)

| Rule | Result | Severity | Tag | Summary | Evidence |
|---|---|---|---|---|---|
| — | PASS | info | — | `before.sh.erb` exports `port=1234` but no web service is started in templates; port variable is unused | nf-core-methylseq-4-1-0/template/before.sh.erb:8 |
| — | PASS | info | — | `script.sh.erb` contains hardcoded cluster path /cluster/tufts/yzhang85/github/nfcore2ood/nf2ood.env (site-specific, not security concern) | nf-core-methylseq-4-1-0/template/script.sh.erb:25 |

No tool-detectable issues in the checked tiers.

### Capability profile (batch_connect)

| File | Capabilities | Anomalies |
|---|---|---|
| `form.yml.erb` | 80-100+ form fields (path_selectors, number_fields, select widgets), ERB-included partials | None |
| `submit.yml.erb` | ERB interpolates form values into slurm job directives, email config | None |
| `template/before.sh.erb` | Sets up working directory, exports hostname and reserved port | None |
| `template/nf-params.json.erb` | Converts form values to JSON via Ruby lambdas (to_bool, to_number), sanitizes types | None |
| `template/script.sh.erb` | Loads modules (nextflow, singularity), sources hardcoded env file, builds nextflow run command | Hardcoded cluster paths |

All batch_connect apps run Nextflow pipelines on the compute node via SLURM or local executor. They do not start network services, do not read credentials, and do not write to dotfiles or cron. Authentication is provided entirely by OOD.

### Portability
- Rating: Not portable — cluster pax, partition file, port 1234, nf2ood.env path, pipeline root, singularity cache, and slurm profile are all Tufts-specific and undocumented

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Hardcoded cluster "pax" in form.yml.erb | nf-core-methylseq-4-1-0/form.yml.erb:2 |
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Partition loaded from external mixin file /etc/ood/config/.../cpu_partition.yml | nf-core-methylseq-4-1-0/form.yml.erb:35 |
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Hardcoded port 1234 in before.sh.erb | nf-core-methylseq-4-1-0/template/before.sh.erb:8 |
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Hardcoded nf2ood.env path in script.sh.erb | nf-core-methylseq-4-1-0/template/script.sh.erb:25 |
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Hardcoded pipeline root path in script.sh.erb | nf-core-methylseq-4-1-0/template/script.sh.erb:33 |
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Hardcoded singularity cache path in script.sh.erb | nf-core-methylseq-4-1-0/template/script.sh.erb:34 |
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Hardcoded slurm profile name "tufts" in script.sh.erb | nf-core-methylseq-4-1-0/template/script.sh.erb:35 |
| QUA-02 | `check: hardcoded-site-paths` | PASS | info | nodes=2 / mem=12G are explicit scheduler params in submit.yml.erb (documented in form) | nf-core-methylseq-4-1-0/submit.yml.erb:18-21 |
| QUA-02 | `check: portability-rating` | FAIL | medium | Not portable — all 7 site-specific values are undocumented and Tufts-specific | — |

### Documentation
- Rating: Below minimal — only Overview section and Local review before deployment checklist; no Prerequisites, Installation, Configuration, Known Limitations, Troubleshooting, Screenshots, Environment Variables, Info Panel, or Architecture
- Evidence per rung:
  - what it launches: "Overview", nf-core-methylseq-4-1-0/README.md:6
  - prerequisites: none
  - installation: "Local review before deployment", nf-core-methylseq-4-1-0/README.md:24 (describes review checklist, not installation steps)
  - configuration: none
  - known limitations: none
  - troubleshooting: none
  - screenshots: none
  - environment variables: none
  - info panel: none
  - architecture: none

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| QUA-01 | `check: documentation-rating` | FAIL | high | Below minimal documentation — fails Adequate target for inclusion | nf-core-methylseq-4-1-0/README.md:1 |

### Code Quality

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| QUA-07 | `check: numeric-field-bounds` | NOT CHECKED | info | form.json failed_to_run (ERB not stripped before YAML parse) | form.json |
| QUA-10 | `check: erb-missing-value` | NOT CHECKED | info | form.json failed_to_run — no attributes available for check | form.json |
| QUA-08 | `check: magic-numbers` | PASS | info | No numeric_literals or hex_colors detected in template.json | template.json |
| QUA-04 | `check: dead-code` | PASS | info | No commented_code detected in template.json | template.json |
| QUA-09 | `check: duplicated-blocks` | PASS | info | No large duplicated code blocks | template.json |
| QUA-03 | `check: error-handling` | PASS | low | set -euo pipefail in script.sh.erb; cd and mkdir have shell defaults under set -e | nf-core-methylseq-4-1-0/template/script.sh.erb:3 |
| QUA-06 | `check: icon-matches-target-os` | PASS | info | No icons defined in template.json | template.json |

**Code quality observations:** No copy-paste artifacts, duplicate YAML keys, or wrong help text found. The pre-review fact scan (template.json) reported zero commented_code, numeric_literals, and hex_colors across all batch_connect apps. Note: `form.json` failed to parse for all 16 batch_connect apps due to unstripped ERB — this is a scanner defect, not a form defect.

**Per-app decision:** Request changes

---


## App: nf-core-pathogensurveillance-1-1-0 (nf-core-pathogensurveillance-1-1-0)

### Signals

| Dimension | Level | Evidence |
|---|---|---|
| Portability | High | Not portable — cluster pax, partition file, port 1234, nf2ood.env path, pipeline root, singularity cache, and slurm profile are all Tufts-specific and undocumented |
| Documentation | High | Below minimal — only Overview section and Local review before deployment checklist; no prerequisites, installation, configuration, or troubleshooting |
| Upkeep (this app) | High | Last change 2026-06-26; one contributor; per-app CHANGELOG present but no CI |

### Structure

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| STR-02 | `check: str-02-metadata` | FAIL | high | manifest.yml missing: maintainer.name, maintainer.support_url. app_type "batch_connect" not in published vocabulary (closest: "batch-connect-basic") | nf-core-pathogensurveillance-1-1-0/manifest.yml |
| STR-03 | `check: str-03-yaml-valid` | PASS | info | form.yml.erb has balanced ERB tags (verified); manifest.yml parses as valid YAML | nf-core-pathogensurveillance-1-1-0/form.yml.erb:1 |
| STR-06 | `check: str-06-syntax` | PASS | info | All 2 shell files pass bash -n after ERB stripping (before.sh.erb, script.sh.erb) | nf-core-pathogensurveillance-1-1-0/template/before.sh.erb:1, nf-core-pathogensurveillance-1-1-0/template/script.sh.erb:1 |
| STR-07 | `check: str-07-layout` | PASS | info | Batch Connect layout complete: form.yml.erb, submit.yml.erb, template/ (3 files) | nf-core-pathogensurveillance-1-1-0/form.yml.erb, nf-core-pathogensurveillance-1-1-0/submit.yml.erb, template/ |
| STR-04 | `check: str-04-references` | NOT CHECKED | info | form.json failed_to_run (ERB not stripped before YAML parse) | form.json |

### Security

**Check tiers:** Tiers 1–2

Tier 3 not checked — no isolated execution environment.

| Tool | Status | Result |
|---|---|---|
| shellcheck | Run (ERB-stripped) | 64 findings (SC2050, SC2148, SC2155), 16 of them linted in isolation from the job-script family |
| semgrep | Run | 0 findings |
| bandit | Not run (no applicable files) | — |
| trivy | Not run (no applicable files) | — |

#### Findings

| Rule | Check | Result | Severity | Tag | Summary | Evidence |
|---|---|---|---|---|---|---|
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `bc_email_on_started` is a check_box (1/0); boolean value does not reach shell | nf-core-pathogensurveillance-1-1-0/submit.yml.erb:9 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `bc_num_hours` is a number_field (min:1); only numeric values possible | nf-core-pathogensurveillance-1-1-0/submit.yml.erb:14 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `num_cores` is a number_field (min:1); only numeric values possible | nf-core-pathogensurveillance-1-1-0/submit.yml.erb:24 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `num_memory` is a number_field (min:1); only numeric values possible | nf-core-pathogensurveillance-1-1-0/submit.yml.erb:26 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `partition` from select widget loaded from cpu_partition.yml partial; controlled options | nf-core-pathogensurveillance-1-1-0/submit.yml.erb:29 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `workdir` is path_selector; shell-quoted assignment of filesystem path | nf-core-pathogensurveillance-1-1-0/template/before.sh.erb:10, nf-core-pathogensurveillance-1-1-0/template/script.sh.erb:9 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `resume` is check_box (1/0); shell-quoted comparison with constant "1" | nf-core-pathogensurveillance-1-1-0/template/script.sh.erb:19 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `nextflow_version` is select widget; shell-quoted assignment | nf-core-pathogensurveillance-1-1-0/template/script.sh.erb:36 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `executor` is select widget (slurm/local); shell-quoted comparison | nf-core-pathogensurveillance-1-1-0/template/script.sh.erb:64 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `num_cores` written into heredoc-based Nextflow custom.config (not shell-executed) | nf-core-pathogensurveillance-1-1-0/template/script.sh.erb:72 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `num_memory` written into heredoc-based Nextflow custom.config; shell-quoted | nf-core-pathogensurveillance-1-1-0/template/script.sh.erb:73 |
| OODT-01 | `check: sec-eval-exec` | PASS | info | — | `source "${nf2ood_env_file}"` uses hardcoded path (not user-controllable); guarded by -r check | nf-core-pathogensurveillance-1-1-0/template/script.sh.erb:28 |
| OODT-01 | `check: sec-tool-finding` | PASS | info | — | SC2148, SC2155: artefacts of linting OOD's job-script files one at a time | nf-core-pathogensurveillance-1-1-0/template/before.sh.erb:1,5 |
| OODT-01 | `check: sec-tool-finding` | PASS | info | — | SC2050: ERB-stripped template yields constant comparisons, style/linting concern | nf-core-pathogensurveillance-1-1-0/template/script.sh.erb:19,64 |

#### Additional observations (review)

| Rule | Result | Severity | Tag | Summary | Evidence |
|---|---|---|---|---|---|
| — | PASS | info | — | `before.sh.erb` exports `port=1234` but no web service is started in templates; port variable is unused | nf-core-pathogensurveillance-1-1-0/template/before.sh.erb:8 |
| — | PASS | info | — | `script.sh.erb` contains hardcoded cluster path /cluster/tufts/yzhang85/github/nfcore2ood/nf2ood.env (site-specific, not security concern) | nf-core-pathogensurveillance-1-1-0/template/script.sh.erb:25 |

No tool-detectable issues in the checked tiers.

### Capability profile (batch_connect)

| File | Capabilities | Anomalies |
|---|---|---|
| `form.yml.erb` | 80-100+ form fields (path_selectors, number_fields, select widgets), ERB-included partials | None |
| `submit.yml.erb` | ERB interpolates form values into slurm job directives, email config | None |
| `template/before.sh.erb` | Sets up working directory, exports hostname and reserved port | None |
| `template/nf-params.json.erb` | Converts form values to JSON via Ruby lambdas (to_bool, to_number), sanitizes types | None |
| `template/script.sh.erb` | Loads modules (nextflow, singularity), sources hardcoded env file, builds nextflow run command | Hardcoded cluster paths |

All batch_connect apps run Nextflow pipelines on the compute node via SLURM or local executor. They do not start network services, do not read credentials, and do not write to dotfiles or cron. Authentication is provided entirely by OOD.

### Portability
- Rating: Not portable — cluster pax, partition file, port 1234, nf2ood.env path, pipeline root, singularity cache, and slurm profile are all Tufts-specific and undocumented

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Hardcoded cluster "pax" in form.yml.erb | nf-core-pathogensurveillance-1-1-0/form.yml.erb:2 |
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Partition loaded from external mixin file /etc/ood/config/.../cpu_partition.yml | nf-core-pathogensurveillance-1-1-0/form.yml.erb:35 |
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Hardcoded port 1234 in before.sh.erb | nf-core-pathogensurveillance-1-1-0/template/before.sh.erb:8 |
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Hardcoded nf2ood.env path in script.sh.erb | nf-core-pathogensurveillance-1-1-0/template/script.sh.erb:25 |
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Hardcoded pipeline root path in script.sh.erb | nf-core-pathogensurveillance-1-1-0/template/script.sh.erb:33 |
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Hardcoded singularity cache path in script.sh.erb | nf-core-pathogensurveillance-1-1-0/template/script.sh.erb:34 |
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Hardcoded slurm profile name "tufts" in script.sh.erb | nf-core-pathogensurveillance-1-1-0/template/script.sh.erb:35 |
| QUA-02 | `check: hardcoded-site-paths` | PASS | info | nodes=2 / mem=12G are explicit scheduler params in submit.yml.erb (documented in form) | nf-core-pathogensurveillance-1-1-0/submit.yml.erb:18-21 |
| QUA-02 | `check: portability-rating` | FAIL | medium | Not portable — all 7 site-specific values are undocumented and Tufts-specific | — |

### Documentation
- Rating: Below minimal — only Overview section and Local review before deployment checklist; no Prerequisites, Installation, Configuration, Known Limitations, Troubleshooting, Screenshots, Environment Variables, Info Panel, or Architecture
- Evidence per rung:
  - what it launches: "Overview", nf-core-pathogensurveillance-1-1-0/README.md:6
  - prerequisites: none
  - installation: "Local review before deployment", nf-core-pathogensurveillance-1-1-0/README.md:24 (describes review checklist, not installation steps)
  - configuration: none
  - known limitations: none
  - troubleshooting: none
  - screenshots: none
  - environment variables: none
  - info panel: none
  - architecture: none

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| QUA-01 | `check: documentation-rating` | FAIL | high | Below minimal documentation — fails Adequate target for inclusion | nf-core-pathogensurveillance-1-1-0/README.md:1 |

### Code Quality

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| QUA-07 | `check: numeric-field-bounds` | NOT CHECKED | info | form.json failed_to_run (ERB not stripped before YAML parse) | form.json |
| QUA-10 | `check: erb-missing-value` | NOT CHECKED | info | form.json failed_to_run — no attributes available for check | form.json |
| QUA-08 | `check: magic-numbers` | PASS | info | No numeric_literals or hex_colors detected in template.json | template.json |
| QUA-04 | `check: dead-code` | PASS | info | No commented_code detected in template.json | template.json |
| QUA-09 | `check: duplicated-blocks` | PASS | info | No large duplicated code blocks | template.json |
| QUA-03 | `check: error-handling` | PASS | low | set -euo pipefail in script.sh.erb; cd and mkdir have shell defaults under set -e | nf-core-pathogensurveillance-1-1-0/template/script.sh.erb:3 |
| QUA-06 | `check: icon-matches-target-os` | PASS | info | No icons defined in template.json | template.json |

**Code quality observations:** No copy-paste artifacts, duplicate YAML keys, or wrong help text found. The pre-review fact scan (template.json) reported zero commented_code, numeric_literals, and hex_colors across all batch_connect apps. Note: `form.json` failed to parse for all 16 batch_connect apps due to unstripped ERB — this is a scanner defect, not a form defect.

**Per-app decision:** Request changes

---


## App: nf-core-proteinfamilies-2-4-0 (nf-core-proteinfamilies-2-4-0)

### Signals

| Dimension | Level | Evidence |
|---|---|---|
| Portability | High | Not portable — cluster pax, partition file, port 1234, nf2ood.env path, pipeline root, singularity cache, and slurm profile are all Tufts-specific and undocumented |
| Documentation | High | Below minimal — only Overview section and Local review before deployment checklist; no prerequisites, installation, configuration, or troubleshooting |
| Upkeep (this app) | High | Last change 2026-06-26; one contributor; per-app CHANGELOG present but no CI |

### Structure

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| STR-02 | `check: str-02-metadata` | FAIL | high | manifest.yml missing: maintainer.name, maintainer.support_url. app_type "batch_connect" not in published vocabulary (closest: "batch-connect-basic") | nf-core-proteinfamilies-2-4-0/manifest.yml |
| STR-03 | `check: str-03-yaml-valid` | PASS | info | form.yml.erb has balanced ERB tags (verified); manifest.yml parses as valid YAML | nf-core-proteinfamilies-2-4-0/form.yml.erb:1 |
| STR-06 | `check: str-06-syntax` | PASS | info | All 2 shell files pass bash -n after ERB stripping (before.sh.erb, script.sh.erb) | nf-core-proteinfamilies-2-4-0/template/before.sh.erb:1, nf-core-proteinfamilies-2-4-0/template/script.sh.erb:1 |
| STR-07 | `check: str-07-layout` | PASS | info | Batch Connect layout complete: form.yml.erb, submit.yml.erb, template/ (3 files) | nf-core-proteinfamilies-2-4-0/form.yml.erb, nf-core-proteinfamilies-2-4-0/submit.yml.erb, template/ |
| STR-04 | `check: str-04-references` | NOT CHECKED | info | form.json failed_to_run (ERB not stripped before YAML parse) | form.json |

### Security

**Check tiers:** Tiers 1–2

Tier 3 not checked — no isolated execution environment.

| Tool | Status | Result |
|---|---|---|
| shellcheck | Run (ERB-stripped) | 64 findings (SC2050, SC2148, SC2155), 16 of them linted in isolation from the job-script family |
| semgrep | Run | 0 findings |
| bandit | Not run (no applicable files) | — |
| trivy | Not run (no applicable files) | — |

#### Findings

| Rule | Check | Result | Severity | Tag | Summary | Evidence |
|---|---|---|---|---|---|---|
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `bc_email_on_started` is a check_box (1/0); boolean value does not reach shell | nf-core-proteinfamilies-2-4-0/submit.yml.erb:9 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `bc_num_hours` is a number_field (min:1); only numeric values possible | nf-core-proteinfamilies-2-4-0/submit.yml.erb:14 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `num_cores` is a number_field (min:1); only numeric values possible | nf-core-proteinfamilies-2-4-0/submit.yml.erb:24 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `num_memory` is a number_field (min:1); only numeric values possible | nf-core-proteinfamilies-2-4-0/submit.yml.erb:26 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `partition` from select widget loaded from cpu_partition.yml partial; controlled options | nf-core-proteinfamilies-2-4-0/submit.yml.erb:29 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `workdir` is path_selector; shell-quoted assignment of filesystem path | nf-core-proteinfamilies-2-4-0/template/before.sh.erb:10, nf-core-proteinfamilies-2-4-0/template/script.sh.erb:9 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `resume` is check_box (1/0); shell-quoted comparison with constant "1" | nf-core-proteinfamilies-2-4-0/template/script.sh.erb:19 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `nextflow_version` is select widget; shell-quoted assignment | nf-core-proteinfamilies-2-4-0/template/script.sh.erb:36 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `executor` is select widget (slurm/local); shell-quoted comparison | nf-core-proteinfamilies-2-4-0/template/script.sh.erb:64 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `num_cores` written into heredoc-based Nextflow custom.config (not shell-executed) | nf-core-proteinfamilies-2-4-0/template/script.sh.erb:72 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `num_memory` written into heredoc-based Nextflow custom.config; shell-quoted | nf-core-proteinfamilies-2-4-0/template/script.sh.erb:73 |
| OODT-01 | `check: sec-eval-exec` | PASS | info | — | `source "${nf2ood_env_file}"` uses hardcoded path (not user-controllable); guarded by -r check | nf-core-proteinfamilies-2-4-0/template/script.sh.erb:28 |
| OODT-01 | `check: sec-tool-finding` | PASS | info | — | SC2148, SC2155: artefacts of linting OOD's job-script files one at a time | nf-core-proteinfamilies-2-4-0/template/before.sh.erb:1,5 |
| OODT-01 | `check: sec-tool-finding` | PASS | info | — | SC2050: ERB-stripped template yields constant comparisons, style/linting concern | nf-core-proteinfamilies-2-4-0/template/script.sh.erb:19,64 |

#### Additional observations (review)

| Rule | Result | Severity | Tag | Summary | Evidence |
|---|---|---|---|---|---|
| — | PASS | info | — | `before.sh.erb` exports `port=1234` but no web service is started in templates; port variable is unused | nf-core-proteinfamilies-2-4-0/template/before.sh.erb:8 |
| — | PASS | info | — | `script.sh.erb` contains hardcoded cluster path /cluster/tufts/yzhang85/github/nfcore2ood/nf2ood.env (site-specific, not security concern) | nf-core-proteinfamilies-2-4-0/template/script.sh.erb:25 |

No tool-detectable issues in the checked tiers.

### Capability profile (batch_connect)

| File | Capabilities | Anomalies |
|---|---|---|
| `form.yml.erb` | 80-100+ form fields (path_selectors, number_fields, select widgets), ERB-included partials | None |
| `submit.yml.erb` | ERB interpolates form values into slurm job directives, email config | None |
| `template/before.sh.erb` | Sets up working directory, exports hostname and reserved port | None |
| `template/nf-params.json.erb` | Converts form values to JSON via Ruby lambdas (to_bool, to_number), sanitizes types | None |
| `template/script.sh.erb` | Loads modules (nextflow, singularity), sources hardcoded env file, builds nextflow run command | Hardcoded cluster paths |

All batch_connect apps run Nextflow pipelines on the compute node via SLURM or local executor. They do not start network services, do not read credentials, and do not write to dotfiles or cron. Authentication is provided entirely by OOD.

### Portability
- Rating: Not portable — cluster pax, partition file, port 1234, nf2ood.env path, pipeline root, singularity cache, and slurm profile are all Tufts-specific and undocumented

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Hardcoded cluster "pax" in form.yml.erb | nf-core-proteinfamilies-2-4-0/form.yml.erb:2 |
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Partition loaded from external mixin file /etc/ood/config/.../cpu_partition.yml | nf-core-proteinfamilies-2-4-0/form.yml.erb:35 |
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Hardcoded port 1234 in before.sh.erb | nf-core-proteinfamilies-2-4-0/template/before.sh.erb:8 |
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Hardcoded nf2ood.env path in script.sh.erb | nf-core-proteinfamilies-2-4-0/template/script.sh.erb:25 |
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Hardcoded pipeline root path in script.sh.erb | nf-core-proteinfamilies-2-4-0/template/script.sh.erb:33 |
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Hardcoded singularity cache path in script.sh.erb | nf-core-proteinfamilies-2-4-0/template/script.sh.erb:34 |
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Hardcoded slurm profile name "tufts" in script.sh.erb | nf-core-proteinfamilies-2-4-0/template/script.sh.erb:35 |
| QUA-02 | `check: hardcoded-site-paths` | PASS | info | nodes=2 / mem=12G are explicit scheduler params in submit.yml.erb (documented in form) | nf-core-proteinfamilies-2-4-0/submit.yml.erb:18-21 |
| QUA-02 | `check: portability-rating` | FAIL | medium | Not portable — all 7 site-specific values are undocumented and Tufts-specific | — |

### Documentation
- Rating: Below minimal — only Overview section and Local review before deployment checklist; no Prerequisites, Installation, Configuration, Known Limitations, Troubleshooting, Screenshots, Environment Variables, Info Panel, or Architecture
- Evidence per rung:
  - what it launches: "Overview", nf-core-proteinfamilies-2-4-0/README.md:6
  - prerequisites: none
  - installation: "Local review before deployment", nf-core-proteinfamilies-2-4-0/README.md:24 (describes review checklist, not installation steps)
  - configuration: none
  - known limitations: none
  - troubleshooting: none
  - screenshots: none
  - environment variables: none
  - info panel: none
  - architecture: none

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| QUA-01 | `check: documentation-rating` | FAIL | high | Below minimal documentation — fails Adequate target for inclusion | nf-core-proteinfamilies-2-4-0/README.md:1 |

### Code Quality

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| QUA-07 | `check: numeric-field-bounds` | NOT CHECKED | info | form.json failed_to_run (ERB not stripped before YAML parse) | form.json |
| QUA-10 | `check: erb-missing-value` | NOT CHECKED | info | form.json failed_to_run — no attributes available for check | form.json |
| QUA-08 | `check: magic-numbers` | PASS | info | No numeric_literals or hex_colors detected in template.json | template.json |
| QUA-04 | `check: dead-code` | PASS | info | No commented_code detected in template.json | template.json |
| QUA-09 | `check: duplicated-blocks` | PASS | info | No large duplicated code blocks | template.json |
| QUA-03 | `check: error-handling` | PASS | low | set -euo pipefail in script.sh.erb; cd and mkdir have shell defaults under set -e | nf-core-proteinfamilies-2-4-0/template/script.sh.erb:3 |
| QUA-06 | `check: icon-matches-target-os` | PASS | info | No icons defined in template.json | template.json |

**Code quality observations:** No copy-paste artifacts, duplicate YAML keys, or wrong help text found. The pre-review fact scan (template.json) reported zero commented_code, numeric_literals, and hex_colors across all batch_connect apps. Note: `form.json` failed to parse for all 16 batch_connect apps due to unstripped ERB — this is a scanner defect, not a form defect.

**Per-app decision:** Request changes

---


## App: nf-core-rnafusion-4-1-0 (nf-core-rnafusion-4-1-0)

### Signals

| Dimension | Level | Evidence |
|---|---|---|
| Portability | High | Not portable — cluster pax, partition file, port 1234, nf2ood.env path, pipeline root, singularity cache, and slurm profile are all Tufts-specific and undocumented |
| Documentation | High | Below minimal — only Overview section and Local review before deployment checklist; no prerequisites, installation, configuration, or troubleshooting |
| Upkeep (this app) | High | Last change 2026-06-26; one contributor; per-app CHANGELOG present but no CI |

### Structure

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| STR-02 | `check: str-02-metadata` | FAIL | high | manifest.yml missing: maintainer.name, maintainer.support_url. app_type "batch_connect" not in published vocabulary (closest: "batch-connect-basic") | nf-core-rnafusion-4-1-0/manifest.yml |
| STR-03 | `check: str-03-yaml-valid` | PASS | info | form.yml.erb has balanced ERB tags (verified); manifest.yml parses as valid YAML | nf-core-rnafusion-4-1-0/form.yml.erb:1 |
| STR-06 | `check: str-06-syntax` | PASS | info | All 2 shell files pass bash -n after ERB stripping (before.sh.erb, script.sh.erb) | nf-core-rnafusion-4-1-0/template/before.sh.erb:1, nf-core-rnafusion-4-1-0/template/script.sh.erb:1 |
| STR-07 | `check: str-07-layout` | PASS | info | Batch Connect layout complete: form.yml.erb, submit.yml.erb, template/ (3 files) | nf-core-rnafusion-4-1-0/form.yml.erb, nf-core-rnafusion-4-1-0/submit.yml.erb, template/ |
| STR-04 | `check: str-04-references` | NOT CHECKED | info | form.json failed_to_run (ERB not stripped before YAML parse) | form.json |

### Security

**Check tiers:** Tiers 1–2

Tier 3 not checked — no isolated execution environment.

| Tool | Status | Result |
|---|---|---|
| shellcheck | Run (ERB-stripped) | 64 findings (SC2050, SC2148, SC2155), 16 of them linted in isolation from the job-script family |
| semgrep | Run | 0 findings |
| bandit | Not run (no applicable files) | — |
| trivy | Not run (no applicable files) | — |

#### Findings

| Rule | Check | Result | Severity | Tag | Summary | Evidence |
|---|---|---|---|---|---|---|
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `bc_email_on_started` is a check_box (1/0); boolean value does not reach shell | nf-core-rnafusion-4-1-0/submit.yml.erb:9 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `bc_num_hours` is a number_field (min:1); only numeric values possible | nf-core-rnafusion-4-1-0/submit.yml.erb:14 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `num_cores` is a number_field (min:1); only numeric values possible | nf-core-rnafusion-4-1-0/submit.yml.erb:24 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `num_memory` is a number_field (min:1); only numeric values possible | nf-core-rnafusion-4-1-0/submit.yml.erb:26 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `partition` from select widget loaded from cpu_partition.yml partial; controlled options | nf-core-rnafusion-4-1-0/submit.yml.erb:29 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `workdir` is path_selector; shell-quoted assignment of filesystem path | nf-core-rnafusion-4-1-0/template/before.sh.erb:10, nf-core-rnafusion-4-1-0/template/script.sh.erb:9 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `resume` is check_box (1/0); shell-quoted comparison with constant "1" | nf-core-rnafusion-4-1-0/template/script.sh.erb:19 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `nextflow_version` is select widget; shell-quoted assignment | nf-core-rnafusion-4-1-0/template/script.sh.erb:36 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `executor` is select widget (slurm/local); shell-quoted comparison | nf-core-rnafusion-4-1-0/template/script.sh.erb:64 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `num_cores` written into heredoc-based Nextflow custom.config (not shell-executed) | nf-core-rnafusion-4-1-0/template/script.sh.erb:72 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `num_memory` written into heredoc-based Nextflow custom.config; shell-quoted | nf-core-rnafusion-4-1-0/template/script.sh.erb:73 |
| OODT-01 | `check: sec-eval-exec` | PASS | info | — | `source "${nf2ood_env_file}"` uses hardcoded path (not user-controllable); guarded by -r check | nf-core-rnafusion-4-1-0/template/script.sh.erb:28 |
| OODT-01 | `check: sec-tool-finding` | PASS | info | — | SC2148, SC2155: artefacts of linting OOD's job-script files one at a time | nf-core-rnafusion-4-1-0/template/before.sh.erb:1,5 |
| OODT-01 | `check: sec-tool-finding` | PASS | info | — | SC2050: ERB-stripped template yields constant comparisons, style/linting concern | nf-core-rnafusion-4-1-0/template/script.sh.erb:19,64 |

#### Additional observations (review)

| Rule | Result | Severity | Tag | Summary | Evidence |
|---|---|---|---|---|---|
| — | PASS | info | — | `before.sh.erb` exports `port=1234` but no web service is started in templates; port variable is unused | nf-core-rnafusion-4-1-0/template/before.sh.erb:8 |
| — | PASS | info | — | `script.sh.erb` contains hardcoded cluster path /cluster/tufts/yzhang85/github/nfcore2ood/nf2ood.env (site-specific, not security concern) | nf-core-rnafusion-4-1-0/template/script.sh.erb:25 |

No tool-detectable issues in the checked tiers.

### Capability profile (batch_connect)

| File | Capabilities | Anomalies |
|---|---|---|
| `form.yml.erb` | 80-100+ form fields (path_selectors, number_fields, select widgets), ERB-included partials | None |
| `submit.yml.erb` | ERB interpolates form values into slurm job directives, email config | None |
| `template/before.sh.erb` | Sets up working directory, exports hostname and reserved port | None |
| `template/nf-params.json.erb` | Converts form values to JSON via Ruby lambdas (to_bool, to_number), sanitizes types | None |
| `template/script.sh.erb` | Loads modules (nextflow, singularity), sources hardcoded env file, builds nextflow run command | Hardcoded cluster paths |

All batch_connect apps run Nextflow pipelines on the compute node via SLURM or local executor. They do not start network services, do not read credentials, and do not write to dotfiles or cron. Authentication is provided entirely by OOD.

### Portability
- Rating: Not portable — cluster pax, partition file, port 1234, nf2ood.env path, pipeline root, singularity cache, and slurm profile are all Tufts-specific and undocumented

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Hardcoded cluster "pax" in form.yml.erb | nf-core-rnafusion-4-1-0/form.yml.erb:2 |
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Partition loaded from external mixin file /etc/ood/config/.../cpu_partition.yml | nf-core-rnafusion-4-1-0/form.yml.erb:35 |
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Hardcoded port 1234 in before.sh.erb | nf-core-rnafusion-4-1-0/template/before.sh.erb:8 |
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Hardcoded nf2ood.env path in script.sh.erb | nf-core-rnafusion-4-1-0/template/script.sh.erb:25 |
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Hardcoded pipeline root path in script.sh.erb | nf-core-rnafusion-4-1-0/template/script.sh.erb:33 |
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Hardcoded singularity cache path in script.sh.erb | nf-core-rnafusion-4-1-0/template/script.sh.erb:34 |
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Hardcoded slurm profile name "tufts" in script.sh.erb | nf-core-rnafusion-4-1-0/template/script.sh.erb:35 |
| QUA-02 | `check: hardcoded-site-paths` | PASS | info | nodes=2 / mem=12G are explicit scheduler params in submit.yml.erb (documented in form) | nf-core-rnafusion-4-1-0/submit.yml.erb:18-21 |
| QUA-02 | `check: portability-rating` | FAIL | medium | Not portable — all 7 site-specific values are undocumented and Tufts-specific | — |

### Documentation
- Rating: Below minimal — only Overview section and Local review before deployment checklist; no Prerequisites, Installation, Configuration, Known Limitations, Troubleshooting, Screenshots, Environment Variables, Info Panel, or Architecture
- Evidence per rung:
  - what it launches: "Overview", nf-core-rnafusion-4-1-0/README.md:6
  - prerequisites: none
  - installation: "Local review before deployment", nf-core-rnafusion-4-1-0/README.md:24 (describes review checklist, not installation steps)
  - configuration: none
  - known limitations: none
  - troubleshooting: none
  - screenshots: none
  - environment variables: none
  - info panel: none
  - architecture: none

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| QUA-01 | `check: documentation-rating` | FAIL | high | Below minimal documentation — fails Adequate target for inclusion | nf-core-rnafusion-4-1-0/README.md:1 |

### Code Quality

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| QUA-07 | `check: numeric-field-bounds` | NOT CHECKED | info | form.json failed_to_run (ERB not stripped before YAML parse) | form.json |
| QUA-10 | `check: erb-missing-value` | NOT CHECKED | info | form.json failed_to_run — no attributes available for check | form.json |
| QUA-08 | `check: magic-numbers` | PASS | info | No numeric_literals or hex_colors detected in template.json | template.json |
| QUA-04 | `check: dead-code` | PASS | info | No commented_code detected in template.json | template.json |
| QUA-09 | `check: duplicated-blocks` | PASS | info | No large duplicated code blocks | template.json |
| QUA-03 | `check: error-handling` | PASS | low | set -euo pipefail in script.sh.erb; cd and mkdir have shell defaults under set -e | nf-core-rnafusion-4-1-0/template/script.sh.erb:3 |
| QUA-06 | `check: icon-matches-target-os` | PASS | info | No icons defined in template.json | template.json |

**Code quality observations:** No copy-paste artifacts, duplicate YAML keys, or wrong help text found. The pre-review fact scan (template.json) reported zero commented_code, numeric_literals, and hex_colors across all batch_connect apps. Note: `form.json` failed to parse for all 16 batch_connect apps due to unstripped ERB — this is a scanner defect, not a form defect.

**Per-app decision:** Request changes

---


## App: nf-core-rnaseq-3-25-0 (nf-core-rnaseq-3-25-0)

### Signals

| Dimension | Level | Evidence |
|---|---|---|
| Portability | High | Not portable — cluster pax, partition file, port 1234, nf2ood.env path, pipeline root, singularity cache, and slurm profile are all Tufts-specific and undocumented |
| Documentation | High | Below minimal — only Overview section and Local review before deployment checklist; no prerequisites, installation, configuration, or troubleshooting |
| Upkeep (this app) | High | Last change 2026-06-26; one contributor; per-app CHANGELOG present but no CI |

### Structure

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| STR-02 | `check: str-02-metadata` | FAIL | high | manifest.yml missing: maintainer.name, maintainer.support_url. app_type "batch_connect" not in published vocabulary (closest: "batch-connect-basic") | nf-core-rnaseq-3-25-0/manifest.yml |
| STR-03 | `check: str-03-yaml-valid` | PASS | info | form.yml.erb has balanced ERB tags (verified); manifest.yml parses as valid YAML | nf-core-rnaseq-3-25-0/form.yml.erb:1 |
| STR-06 | `check: str-06-syntax` | PASS | info | All 2 shell files pass bash -n after ERB stripping (before.sh.erb, script.sh.erb) | nf-core-rnaseq-3-25-0/template/before.sh.erb:1, nf-core-rnaseq-3-25-0/template/script.sh.erb:1 |
| STR-07 | `check: str-07-layout` | PASS | info | Batch Connect layout complete: form.yml.erb, submit.yml.erb, template/ (3 files) | nf-core-rnaseq-3-25-0/form.yml.erb, nf-core-rnaseq-3-25-0/submit.yml.erb, template/ |
| STR-04 | `check: str-04-references` | NOT CHECKED | info | form.json failed_to_run (ERB not stripped before YAML parse) | form.json |

### Security

**Check tiers:** Tiers 1–2

Tier 3 not checked — no isolated execution environment.

| Tool | Status | Result |
|---|---|---|
| shellcheck | Run (ERB-stripped) | 64 findings (SC2050, SC2148, SC2155), 16 of them linted in isolation from the job-script family |
| semgrep | Run | 0 findings |
| bandit | Not run (no applicable files) | — |
| trivy | Not run (no applicable files) | — |

#### Findings

| Rule | Check | Result | Severity | Tag | Summary | Evidence |
|---|---|---|---|---|---|---|
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `bc_email_on_started` is a check_box (1/0); boolean value does not reach shell | nf-core-rnaseq-3-25-0/submit.yml.erb:9 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `bc_num_hours` is a number_field (min:1); only numeric values possible | nf-core-rnaseq-3-25-0/submit.yml.erb:14 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `num_cores` is a number_field (min:1); only numeric values possible | nf-core-rnaseq-3-25-0/submit.yml.erb:24 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `num_memory` is a number_field (min:1); only numeric values possible | nf-core-rnaseq-3-25-0/submit.yml.erb:26 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `partition` from select widget loaded from cpu_partition.yml partial; controlled options | nf-core-rnaseq-3-25-0/submit.yml.erb:29 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `workdir` is path_selector; shell-quoted assignment of filesystem path | nf-core-rnaseq-3-25-0/template/before.sh.erb:10, nf-core-rnaseq-3-25-0/template/script.sh.erb:9 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `resume` is check_box (1/0); shell-quoted comparison with constant "1" | nf-core-rnaseq-3-25-0/template/script.sh.erb:19 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `nextflow_version` is select widget; shell-quoted assignment | nf-core-rnaseq-3-25-0/template/script.sh.erb:36 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `executor` is select widget (slurm/local); shell-quoted comparison | nf-core-rnaseq-3-25-0/template/script.sh.erb:64 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `num_cores` written into heredoc-based Nextflow custom.config (not shell-executed) | nf-core-rnaseq-3-25-0/template/script.sh.erb:72 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `num_memory` written into heredoc-based Nextflow custom.config; shell-quoted | nf-core-rnaseq-3-25-0/template/script.sh.erb:73 |
| OODT-01 | `check: sec-eval-exec` | PASS | info | — | `source "${nf2ood_env_file}"` uses hardcoded path (not user-controllable); guarded by -r check | nf-core-rnaseq-3-25-0/template/script.sh.erb:28 |
| OODT-01 | `check: sec-tool-finding` | PASS | info | — | SC2148, SC2155: artefacts of linting OOD's job-script files one at a time | nf-core-rnaseq-3-25-0/template/before.sh.erb:1,5 |
| OODT-01 | `check: sec-tool-finding` | PASS | info | — | SC2050: ERB-stripped template yields constant comparisons, style/linting concern | nf-core-rnaseq-3-25-0/template/script.sh.erb:19,64 |

#### Additional observations (review)

| Rule | Result | Severity | Tag | Summary | Evidence |
|---|---|---|---|---|---|
| — | PASS | info | — | `before.sh.erb` exports `port=1234` but no web service is started in templates; port variable is unused | nf-core-rnaseq-3-25-0/template/before.sh.erb:8 |
| — | PASS | info | — | `script.sh.erb` contains hardcoded cluster path /cluster/tufts/yzhang85/github/nfcore2ood/nf2ood.env (site-specific, not security concern) | nf-core-rnaseq-3-25-0/template/script.sh.erb:25 |

No tool-detectable issues in the checked tiers.

### Capability profile (batch_connect)

| File | Capabilities | Anomalies |
|---|---|---|
| `form.yml.erb` | 80-100+ form fields (path_selectors, number_fields, select widgets), ERB-included partials | None |
| `submit.yml.erb` | ERB interpolates form values into slurm job directives, email config | None |
| `template/before.sh.erb` | Sets up working directory, exports hostname and reserved port | None |
| `template/nf-params.json.erb` | Converts form values to JSON via Ruby lambdas (to_bool, to_number), sanitizes types | None |
| `template/script.sh.erb` | Loads modules (nextflow, singularity), sources hardcoded env file, builds nextflow run command | Hardcoded cluster paths |

All batch_connect apps run Nextflow pipelines on the compute node via SLURM or local executor. They do not start network services, do not read credentials, and do not write to dotfiles or cron. Authentication is provided entirely by OOD.

### Portability
- Rating: Not portable — cluster pax, partition file, port 1234, nf2ood.env path, pipeline root, singularity cache, and slurm profile are all Tufts-specific and undocumented

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Hardcoded cluster "pax" in form.yml.erb | nf-core-rnaseq-3-25-0/form.yml.erb:2 |
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Partition loaded from external mixin file /etc/ood/config/.../cpu_partition.yml | nf-core-rnaseq-3-25-0/form.yml.erb:35 |
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Hardcoded port 1234 in before.sh.erb | nf-core-rnaseq-3-25-0/template/before.sh.erb:8 |
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Hardcoded nf2ood.env path in script.sh.erb | nf-core-rnaseq-3-25-0/template/script.sh.erb:25 |
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Hardcoded pipeline root path in script.sh.erb | nf-core-rnaseq-3-25-0/template/script.sh.erb:33 |
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Hardcoded singularity cache path in script.sh.erb | nf-core-rnaseq-3-25-0/template/script.sh.erb:34 |
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Hardcoded slurm profile name "tufts" in script.sh.erb | nf-core-rnaseq-3-25-0/template/script.sh.erb:35 |
| QUA-02 | `check: hardcoded-site-paths` | PASS | info | nodes=2 / mem=12G are explicit scheduler params in submit.yml.erb (documented in form) | nf-core-rnaseq-3-25-0/submit.yml.erb:18-21 |
| QUA-02 | `check: portability-rating` | FAIL | medium | Not portable — all 7 site-specific values are undocumented and Tufts-specific | — |

### Documentation
- Rating: Below minimal — only Overview section and Local review before deployment checklist; no Prerequisites, Installation, Configuration, Known Limitations, Troubleshooting, Screenshots, Environment Variables, Info Panel, or Architecture
- Evidence per rung:
  - what it launches: "Overview", nf-core-rnaseq-3-25-0/README.md:6
  - prerequisites: none
  - installation: "Local review before deployment", nf-core-rnaseq-3-25-0/README.md:24 (describes review checklist, not installation steps)
  - configuration: none
  - known limitations: none
  - troubleshooting: none
  - screenshots: none
  - environment variables: none
  - info panel: none
  - architecture: none

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| QUA-01 | `check: documentation-rating` | FAIL | high | Below minimal documentation — fails Adequate target for inclusion | nf-core-rnaseq-3-25-0/README.md:1 |

### Code Quality

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| QUA-07 | `check: numeric-field-bounds` | NOT CHECKED | info | form.json failed_to_run (ERB not stripped before YAML parse) | form.json |
| QUA-10 | `check: erb-missing-value` | NOT CHECKED | info | form.json failed_to_run — no attributes available for check | form.json |
| QUA-08 | `check: magic-numbers` | PASS | info | No numeric_literals or hex_colors detected in template.json | template.json |
| QUA-04 | `check: dead-code` | PASS | info | No commented_code detected in template.json | template.json |
| QUA-09 | `check: duplicated-blocks` | PASS | info | No large duplicated code blocks | template.json |
| QUA-03 | `check: error-handling` | PASS | low | set -euo pipefail in script.sh.erb; cd and mkdir have shell defaults under set -e | nf-core-rnaseq-3-25-0/template/script.sh.erb:3 |
| QUA-06 | `check: icon-matches-target-os` | PASS | info | No icons defined in template.json | template.json |

**Code quality observations:** No copy-paste artifacts, duplicate YAML keys, or wrong help text found. The pre-review fact scan (template.json) reported zero commented_code, numeric_literals, and hex_colors across all batch_connect apps. Note: `form.json` failed to parse for all 16 batch_connect apps due to unstripped ERB — this is a scanner defect, not a form defect.

**Per-app decision:** Request changes

---


## App: nf-core-rnaseq-3-26-0 (nf-core-rnaseq-3-26-0)

### Signals

| Dimension | Level | Evidence |
|---|---|---|
| Portability | High | Not portable — cluster pax, partition file, port 1234, nf2ood.env path, pipeline root, singularity cache, and slurm profile are all Tufts-specific and undocumented |
| Documentation | High | Below minimal — only Overview section and Local review before deployment checklist; no prerequisites, installation, configuration, or troubleshooting |
| Upkeep (this app) | High | Last change 2026-06-26; one contributor; per-app CHANGELOG present but no CI |

### Structure

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| STR-02 | `check: str-02-metadata` | FAIL | high | manifest.yml missing: maintainer.name, maintainer.support_url. app_type "batch_connect" not in published vocabulary (closest: "batch-connect-basic") | nf-core-rnaseq-3-26-0/manifest.yml |
| STR-03 | `check: str-03-yaml-valid` | PASS | info | form.yml.erb has balanced ERB tags (verified); manifest.yml parses as valid YAML | nf-core-rnaseq-3-26-0/form.yml.erb:1 |
| STR-06 | `check: str-06-syntax` | PASS | info | All 2 shell files pass bash -n after ERB stripping (before.sh.erb, script.sh.erb) | nf-core-rnaseq-3-26-0/template/before.sh.erb:1, nf-core-rnaseq-3-26-0/template/script.sh.erb:1 |
| STR-07 | `check: str-07-layout` | PASS | info | Batch Connect layout complete: form.yml.erb, submit.yml.erb, template/ (3 files) | nf-core-rnaseq-3-26-0/form.yml.erb, nf-core-rnaseq-3-26-0/submit.yml.erb, template/ |
| STR-04 | `check: str-04-references` | NOT CHECKED | info | form.json failed_to_run (ERB not stripped before YAML parse) | form.json |

### Security

**Check tiers:** Tiers 1–2

Tier 3 not checked — no isolated execution environment.

| Tool | Status | Result |
|---|---|---|
| shellcheck | Run (ERB-stripped) | 64 findings (SC2050, SC2148, SC2155), 16 of them linted in isolation from the job-script family |
| semgrep | Run | 0 findings |
| bandit | Not run (no applicable files) | — |
| trivy | Not run (no applicable files) | — |

#### Findings

| Rule | Check | Result | Severity | Tag | Summary | Evidence |
|---|---|---|---|---|---|---|
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `bc_email_on_started` is a check_box (1/0); boolean value does not reach shell | nf-core-rnaseq-3-26-0/submit.yml.erb:9 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `bc_num_hours` is a number_field (min:1); only numeric values possible | nf-core-rnaseq-3-26-0/submit.yml.erb:14 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `num_cores` is a number_field (min:1); only numeric values possible | nf-core-rnaseq-3-26-0/submit.yml.erb:24 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `num_memory` is a number_field (min:1); only numeric values possible | nf-core-rnaseq-3-26-0/submit.yml.erb:26 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `partition` from select widget loaded from cpu_partition.yml partial; controlled options | nf-core-rnaseq-3-26-0/submit.yml.erb:29 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `workdir` is path_selector; shell-quoted assignment of filesystem path | nf-core-rnaseq-3-26-0/template/before.sh.erb:10, nf-core-rnaseq-3-26-0/template/script.sh.erb:9 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `resume` is check_box (1/0); shell-quoted comparison with constant "1" | nf-core-rnaseq-3-26-0/template/script.sh.erb:19 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `nextflow_version` is select widget; shell-quoted assignment | nf-core-rnaseq-3-26-0/template/script.sh.erb:36 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `executor` is select widget (slurm/local); shell-quoted comparison | nf-core-rnaseq-3-26-0/template/script.sh.erb:64 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `num_cores` written into heredoc-based Nextflow custom.config (not shell-executed) | nf-core-rnaseq-3-26-0/template/script.sh.erb:72 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `num_memory` written into heredoc-based Nextflow custom.config; shell-quoted | nf-core-rnaseq-3-26-0/template/script.sh.erb:73 |
| OODT-01 | `check: sec-eval-exec` | PASS | info | — | `source "${nf2ood_env_file}"` uses hardcoded path (not user-controllable); guarded by -r check | nf-core-rnaseq-3-26-0/template/script.sh.erb:28 |
| OODT-01 | `check: sec-tool-finding` | PASS | info | — | SC2148, SC2155: artefacts of linting OOD's job-script files one at a time | nf-core-rnaseq-3-26-0/template/before.sh.erb:1,5 |
| OODT-01 | `check: sec-tool-finding` | PASS | info | — | SC2050: ERB-stripped template yields constant comparisons, style/linting concern | nf-core-rnaseq-3-26-0/template/script.sh.erb:19,64 |

#### Additional observations (review)

| Rule | Result | Severity | Tag | Summary | Evidence |
|---|---|---|---|---|---|
| — | PASS | info | — | `before.sh.erb` exports `port=1234` but no web service is started in templates; port variable is unused | nf-core-rnaseq-3-26-0/template/before.sh.erb:8 |
| — | PASS | info | — | `script.sh.erb` contains hardcoded cluster path /cluster/tufts/yzhang85/github/nfcore2ood/nf2ood.env (site-specific, not security concern) | nf-core-rnaseq-3-26-0/template/script.sh.erb:25 |

No tool-detectable issues in the checked tiers.

### Capability profile (batch_connect)

| File | Capabilities | Anomalies |
|---|---|---|
| `form.yml.erb` | 80-100+ form fields (path_selectors, number_fields, select widgets), ERB-included partials | None |
| `submit.yml.erb` | ERB interpolates form values into slurm job directives, email config | None |
| `template/before.sh.erb` | Sets up working directory, exports hostname and reserved port | None |
| `template/nf-params.json.erb` | Converts form values to JSON via Ruby lambdas (to_bool, to_number), sanitizes types | None |
| `template/script.sh.erb` | Loads modules (nextflow, singularity), sources hardcoded env file, builds nextflow run command | Hardcoded cluster paths |

All batch_connect apps run Nextflow pipelines on the compute node via SLURM or local executor. They do not start network services, do not read credentials, and do not write to dotfiles or cron. Authentication is provided entirely by OOD.

### Portability
- Rating: Not portable — cluster pax, partition file, port 1234, nf2ood.env path, pipeline root, singularity cache, and slurm profile are all Tufts-specific and undocumented

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Hardcoded cluster "pax" in form.yml.erb | nf-core-rnaseq-3-26-0/form.yml.erb:2 |
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Partition loaded from external mixin file /etc/ood/config/.../cpu_partition.yml | nf-core-rnaseq-3-26-0/form.yml.erb:35 |
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Hardcoded port 1234 in before.sh.erb | nf-core-rnaseq-3-26-0/template/before.sh.erb:8 |
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Hardcoded nf2ood.env path in script.sh.erb | nf-core-rnaseq-3-26-0/template/script.sh.erb:25 |
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Hardcoded pipeline root path in script.sh.erb | nf-core-rnaseq-3-26-0/template/script.sh.erb:33 |
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Hardcoded singularity cache path in script.sh.erb | nf-core-rnaseq-3-26-0/template/script.sh.erb:34 |
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Hardcoded slurm profile name "tufts" in script.sh.erb | nf-core-rnaseq-3-26-0/template/script.sh.erb:35 |
| QUA-02 | `check: hardcoded-site-paths` | PASS | info | nodes=2 / mem=12G are explicit scheduler params in submit.yml.erb (documented in form) | nf-core-rnaseq-3-26-0/submit.yml.erb:18-21 |
| QUA-02 | `check: portability-rating` | FAIL | medium | Not portable — all 7 site-specific values are undocumented and Tufts-specific | — |

### Documentation
- Rating: Below minimal — only Overview section and Local review before deployment checklist; no Prerequisites, Installation, Configuration, Known Limitations, Troubleshooting, Screenshots, Environment Variables, Info Panel, or Architecture
- Evidence per rung:
  - what it launches: "Overview", nf-core-rnaseq-3-26-0/README.md:6
  - prerequisites: none
  - installation: "Local review before deployment", nf-core-rnaseq-3-26-0/README.md:24 (describes review checklist, not installation steps)
  - configuration: none
  - known limitations: none
  - troubleshooting: none
  - screenshots: none
  - environment variables: none
  - info panel: none
  - architecture: none

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| QUA-01 | `check: documentation-rating` | FAIL | high | Below minimal documentation — fails Adequate target for inclusion | nf-core-rnaseq-3-26-0/README.md:1 |

### Code Quality

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| QUA-07 | `check: numeric-field-bounds` | NOT CHECKED | info | form.json failed_to_run (ERB not stripped before YAML parse) | form.json |
| QUA-10 | `check: erb-missing-value` | NOT CHECKED | info | form.json failed_to_run — no attributes available for check | form.json |
| QUA-08 | `check: magic-numbers` | PASS | info | No numeric_literals or hex_colors detected in template.json | template.json |
| QUA-04 | `check: dead-code` | PASS | info | No commented_code detected in template.json | template.json |
| QUA-09 | `check: duplicated-blocks` | PASS | info | No large duplicated code blocks | template.json |
| QUA-03 | `check: error-handling` | PASS | low | set -euo pipefail in script.sh.erb; cd and mkdir have shell defaults under set -e | nf-core-rnaseq-3-26-0/template/script.sh.erb:3 |
| QUA-06 | `check: icon-matches-target-os` | PASS | info | No icons defined in template.json | template.json |

**Code quality observations:** No copy-paste artifacts, duplicate YAML keys, or wrong help text found. The pre-review fact scan (template.json) reported zero commented_code, numeric_literals, and hex_colors across all batch_connect apps. Note: `form.json` failed to parse for all 16 batch_connect apps due to unstripped ERB — this is a scanner defect, not a form defect.

**Per-app decision:** Request changes

---


## App: nf-core-sarek-3-8-1 (nf-core-sarek-3-8-1)

### Signals

| Dimension | Level | Evidence |
|---|---|---|
| Portability | High | Not portable — cluster pax, partition file, port 1234, nf2ood.env path, pipeline root, singularity cache, and slurm profile are all Tufts-specific and undocumented |
| Documentation | High | Below minimal — only Overview section and Local review before deployment checklist; no prerequisites, installation, configuration, or troubleshooting |
| Upkeep (this app) | High | Last change 2026-06-26; one contributor; per-app CHANGELOG present but no CI |

### Structure

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| STR-02 | `check: str-02-metadata` | FAIL | high | manifest.yml missing: maintainer.name, maintainer.support_url. app_type "batch_connect" not in published vocabulary (closest: "batch-connect-basic") | nf-core-sarek-3-8-1/manifest.yml |
| STR-03 | `check: str-03-yaml-valid` | PASS | info | form.yml.erb has balanced ERB tags (verified); manifest.yml parses as valid YAML | nf-core-sarek-3-8-1/form.yml.erb:1 |
| STR-06 | `check: str-06-syntax` | PASS | info | All 2 shell files pass bash -n after ERB stripping (before.sh.erb, script.sh.erb) | nf-core-sarek-3-8-1/template/before.sh.erb:1, nf-core-sarek-3-8-1/template/script.sh.erb:1 |
| STR-07 | `check: str-07-layout` | PASS | info | Batch Connect layout complete: form.yml.erb, submit.yml.erb, template/ (3 files) | nf-core-sarek-3-8-1/form.yml.erb, nf-core-sarek-3-8-1/submit.yml.erb, template/ |
| STR-04 | `check: str-04-references` | NOT CHECKED | info | form.json failed_to_run (ERB not stripped before YAML parse) | form.json |

### Security

**Check tiers:** Tiers 1–2

Tier 3 not checked — no isolated execution environment.

| Tool | Status | Result |
|---|---|---|
| shellcheck | Run (ERB-stripped) | 64 findings (SC2050, SC2148, SC2155), 16 of them linted in isolation from the job-script family |
| semgrep | Run | 0 findings |
| bandit | Not run (no applicable files) | — |
| trivy | Not run (no applicable files) | — |

#### Findings

| Rule | Check | Result | Severity | Tag | Summary | Evidence |
|---|---|---|---|---|---|---|
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `bc_email_on_started` is a check_box (1/0); boolean value does not reach shell | nf-core-sarek-3-8-1/submit.yml.erb:9 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `bc_num_hours` is a number_field (min:1); only numeric values possible | nf-core-sarek-3-8-1/submit.yml.erb:14 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `num_cores` is a number_field (min:1); only numeric values possible | nf-core-sarek-3-8-1/submit.yml.erb:24 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `num_memory` is a number_field (min:1); only numeric values possible | nf-core-sarek-3-8-1/submit.yml.erb:26 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `partition` from select widget loaded from cpu_partition.yml partial; controlled options | nf-core-sarek-3-8-1/submit.yml.erb:29 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `workdir` is path_selector; shell-quoted assignment of filesystem path | nf-core-sarek-3-8-1/template/before.sh.erb:10, nf-core-sarek-3-8-1/template/script.sh.erb:9 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `resume` is check_box (1/0); shell-quoted comparison with constant "1" | nf-core-sarek-3-8-1/template/script.sh.erb:19 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `nextflow_version` is select widget; shell-quoted assignment | nf-core-sarek-3-8-1/template/script.sh.erb:36 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `executor` is select widget (slurm/local); shell-quoted comparison | nf-core-sarek-3-8-1/template/script.sh.erb:64 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `num_cores` written into heredoc-based Nextflow custom.config (not shell-executed) | nf-core-sarek-3-8-1/template/script.sh.erb:72 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `num_memory` written into heredoc-based Nextflow custom.config; shell-quoted | nf-core-sarek-3-8-1/template/script.sh.erb:73 |
| OODT-01 | `check: sec-eval-exec` | PASS | info | — | `source "${nf2ood_env_file}"` uses hardcoded path (not user-controllable); guarded by -r check | nf-core-sarek-3-8-1/template/script.sh.erb:28 |
| OODT-01 | `check: sec-tool-finding` | PASS | info | — | SC2148, SC2155: artefacts of linting OOD's job-script files one at a time | nf-core-sarek-3-8-1/template/before.sh.erb:1,5 |
| OODT-01 | `check: sec-tool-finding` | PASS | info | — | SC2050: ERB-stripped template yields constant comparisons, style/linting concern | nf-core-sarek-3-8-1/template/script.sh.erb:19,64 |

#### Additional observations (review)

| Rule | Result | Severity | Tag | Summary | Evidence |
|---|---|---|---|---|---|
| — | PASS | info | — | `before.sh.erb` exports `port=1234` but no web service is started in templates; port variable is unused | nf-core-sarek-3-8-1/template/before.sh.erb:8 |
| — | PASS | info | — | `script.sh.erb` contains hardcoded cluster path /cluster/tufts/yzhang85/github/nfcore2ood/nf2ood.env (site-specific, not security concern) | nf-core-sarek-3-8-1/template/script.sh.erb:25 |

No tool-detectable issues in the checked tiers.

### Capability profile (batch_connect)

| File | Capabilities | Anomalies |
|---|---|---|
| `form.yml.erb` | 80-100+ form fields (path_selectors, number_fields, select widgets), ERB-included partials | None |
| `submit.yml.erb` | ERB interpolates form values into slurm job directives, email config | None |
| `template/before.sh.erb` | Sets up working directory, exports hostname and reserved port | None |
| `template/nf-params.json.erb` | Converts form values to JSON via Ruby lambdas (to_bool, to_number), sanitizes types | None |
| `template/script.sh.erb` | Loads modules (nextflow, singularity), sources hardcoded env file, builds nextflow run command | Hardcoded cluster paths |

All batch_connect apps run Nextflow pipelines on the compute node via SLURM or local executor. They do not start network services, do not read credentials, and do not write to dotfiles or cron. Authentication is provided entirely by OOD.

### Portability
- Rating: Not portable — cluster pax, partition file, port 1234, nf2ood.env path, pipeline root, singularity cache, and slurm profile are all Tufts-specific and undocumented

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Hardcoded cluster "pax" in form.yml.erb | nf-core-sarek-3-8-1/form.yml.erb:2 |
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Partition loaded from external mixin file /etc/ood/config/.../cpu_partition.yml | nf-core-sarek-3-8-1/form.yml.erb:35 |
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Hardcoded port 1234 in before.sh.erb | nf-core-sarek-3-8-1/template/before.sh.erb:8 |
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Hardcoded nf2ood.env path in script.sh.erb | nf-core-sarek-3-8-1/template/script.sh.erb:25 |
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Hardcoded pipeline root path in script.sh.erb | nf-core-sarek-3-8-1/template/script.sh.erb:33 |
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Hardcoded singularity cache path in script.sh.erb | nf-core-sarek-3-8-1/template/script.sh.erb:34 |
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Hardcoded slurm profile name "tufts" in script.sh.erb | nf-core-sarek-3-8-1/template/script.sh.erb:35 |
| QUA-02 | `check: hardcoded-site-paths` | PASS | info | nodes=2 / mem=12G are explicit scheduler params in submit.yml.erb (documented in form) | nf-core-sarek-3-8-1/submit.yml.erb:18-21 |
| QUA-02 | `check: portability-rating` | FAIL | medium | Not portable — all 7 site-specific values are undocumented and Tufts-specific | — |

### Documentation
- Rating: Below minimal — only Overview section and Local review before deployment checklist; no Prerequisites, Installation, Configuration, Known Limitations, Troubleshooting, Screenshots, Environment Variables, Info Panel, or Architecture
- Evidence per rung:
  - what it launches: "Overview", nf-core-sarek-3-8-1/README.md:6
  - prerequisites: none
  - installation: "Local review before deployment", nf-core-sarek-3-8-1/README.md:24 (describes review checklist, not installation steps)
  - configuration: none
  - known limitations: none
  - troubleshooting: none
  - screenshots: none
  - environment variables: none
  - info panel: none
  - architecture: none

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| QUA-01 | `check: documentation-rating` | FAIL | high | Below minimal documentation — fails Adequate target for inclusion | nf-core-sarek-3-8-1/README.md:1 |

### Code Quality

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| QUA-07 | `check: numeric-field-bounds` | NOT CHECKED | info | form.json failed_to_run (ERB not stripped before YAML parse) | form.json |
| QUA-10 | `check: erb-missing-value` | NOT CHECKED | info | form.json failed_to_run — no attributes available for check | form.json |
| QUA-08 | `check: magic-numbers` | PASS | info | No numeric_literals or hex_colors detected in template.json | template.json |
| QUA-04 | `check: dead-code` | PASS | info | No commented_code detected in template.json | template.json |
| QUA-09 | `check: duplicated-blocks` | PASS | info | No large duplicated code blocks | template.json |
| QUA-03 | `check: error-handling` | PASS | low | set -euo pipefail in script.sh.erb; cd and mkdir have shell defaults under set -e | nf-core-sarek-3-8-1/template/script.sh.erb:3 |
| QUA-06 | `check: icon-matches-target-os` | PASS | info | No icons defined in template.json | template.json |

**Code quality observations:** No copy-paste artifacts, duplicate YAML keys, or wrong help text found. The pre-review fact scan (template.json) reported zero commented_code, numeric_literals, and hex_colors across all batch_connect apps. Note: `form.json` failed to parse for all 16 batch_connect apps due to unstripped ERB — this is a scanner defect, not a form defect.

**Per-app decision:** Request changes

---


## App: nf-core-scrnaseq-4-1-0 (nf-core-scrnaseq-4-1-0)

### Signals

| Dimension | Level | Evidence |
|---|---|---|
| Portability | High | Not portable — cluster pax, partition file, port 1234, nf2ood.env path, pipeline root, singularity cache, and slurm profile are all Tufts-specific and undocumented |
| Documentation | High | Below minimal — only Overview section and Local review before deployment checklist; no prerequisites, installation, configuration, or troubleshooting |
| Upkeep (this app) | High | Last change 2026-06-26; one contributor; per-app CHANGELOG present but no CI |

### Structure

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| STR-02 | `check: str-02-metadata` | FAIL | high | manifest.yml missing: maintainer.name, maintainer.support_url. app_type "batch_connect" not in published vocabulary (closest: "batch-connect-basic") | nf-core-scrnaseq-4-1-0/manifest.yml |
| STR-03 | `check: str-03-yaml-valid` | PASS | info | form.yml.erb has balanced ERB tags (verified); manifest.yml parses as valid YAML | nf-core-scrnaseq-4-1-0/form.yml.erb:1 |
| STR-06 | `check: str-06-syntax` | PASS | info | All 2 shell files pass bash -n after ERB stripping (before.sh.erb, script.sh.erb) | nf-core-scrnaseq-4-1-0/template/before.sh.erb:1, nf-core-scrnaseq-4-1-0/template/script.sh.erb:1 |
| STR-07 | `check: str-07-layout` | PASS | info | Batch Connect layout complete: form.yml.erb, submit.yml.erb, template/ (3 files) | nf-core-scrnaseq-4-1-0/form.yml.erb, nf-core-scrnaseq-4-1-0/submit.yml.erb, template/ |
| STR-04 | `check: str-04-references` | NOT CHECKED | info | form.json failed_to_run (ERB not stripped before YAML parse) | form.json |

### Security

**Check tiers:** Tiers 1–2

Tier 3 not checked — no isolated execution environment.

| Tool | Status | Result |
|---|---|---|
| shellcheck | Run (ERB-stripped) | 64 findings (SC2050, SC2148, SC2155), 16 of them linted in isolation from the job-script family |
| semgrep | Run | 0 findings |
| bandit | Not run (no applicable files) | — |
| trivy | Not run (no applicable files) | — |

#### Findings

| Rule | Check | Result | Severity | Tag | Summary | Evidence |
|---|---|---|---|---|---|---|
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `bc_email_on_started` is a check_box (1/0); boolean value does not reach shell | nf-core-scrnaseq-4-1-0/submit.yml.erb:9 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `bc_num_hours` is a number_field (min:1); only numeric values possible | nf-core-scrnaseq-4-1-0/submit.yml.erb:14 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `num_cores` is a number_field (min:1); only numeric values possible | nf-core-scrnaseq-4-1-0/submit.yml.erb:24 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `num_memory` is a number_field (min:1); only numeric values possible | nf-core-scrnaseq-4-1-0/submit.yml.erb:26 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `partition` from select widget loaded from cpu_partition.yml partial; controlled options | nf-core-scrnaseq-4-1-0/submit.yml.erb:29 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `workdir` is path_selector; shell-quoted assignment of filesystem path | nf-core-scrnaseq-4-1-0/template/before.sh.erb:10, nf-core-scrnaseq-4-1-0/template/script.sh.erb:9 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `resume` is check_box (1/0); shell-quoted comparison with constant "1" | nf-core-scrnaseq-4-1-0/template/script.sh.erb:19 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `nextflow_version` is select widget; shell-quoted assignment | nf-core-scrnaseq-4-1-0/template/script.sh.erb:36 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `executor` is select widget (slurm/local); shell-quoted comparison | nf-core-scrnaseq-4-1-0/template/script.sh.erb:64 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `num_cores` written into heredoc-based Nextflow custom.config (not shell-executed) | nf-core-scrnaseq-4-1-0/template/script.sh.erb:72 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `num_memory` written into heredoc-based Nextflow custom.config; shell-quoted | nf-core-scrnaseq-4-1-0/template/script.sh.erb:73 |
| OODT-01 | `check: sec-eval-exec` | PASS | info | — | `source "${nf2ood_env_file}"` uses hardcoded path (not user-controllable); guarded by -r check | nf-core-scrnaseq-4-1-0/template/script.sh.erb:28 |
| OODT-01 | `check: sec-tool-finding` | PASS | info | — | SC2148, SC2155: artefacts of linting OOD's job-script files one at a time | nf-core-scrnaseq-4-1-0/template/before.sh.erb:1,5 |
| OODT-01 | `check: sec-tool-finding` | PASS | info | — | SC2050: ERB-stripped template yields constant comparisons, style/linting concern | nf-core-scrnaseq-4-1-0/template/script.sh.erb:19,64 |

#### Additional observations (review)

| Rule | Result | Severity | Tag | Summary | Evidence |
|---|---|---|---|---|---|
| — | PASS | info | — | `before.sh.erb` exports `port=1234` but no web service is started in templates; port variable is unused | nf-core-scrnaseq-4-1-0/template/before.sh.erb:8 |
| — | PASS | info | — | `script.sh.erb` contains hardcoded cluster path /cluster/tufts/yzhang85/github/nfcore2ood/nf2ood.env (site-specific, not security concern) | nf-core-scrnaseq-4-1-0/template/script.sh.erb:25 |

No tool-detectable issues in the checked tiers.

### Capability profile (batch_connect)

| File | Capabilities | Anomalies |
|---|---|---|
| `form.yml.erb` | 80-100+ form fields (path_selectors, number_fields, select widgets), ERB-included partials | None |
| `submit.yml.erb` | ERB interpolates form values into slurm job directives, email config | None |
| `template/before.sh.erb` | Sets up working directory, exports hostname and reserved port | None |
| `template/nf-params.json.erb` | Converts form values to JSON via Ruby lambdas (to_bool, to_number), sanitizes types | None |
| `template/script.sh.erb` | Loads modules (nextflow, singularity), sources hardcoded env file, builds nextflow run command | Hardcoded cluster paths |

All batch_connect apps run Nextflow pipelines on the compute node via SLURM or local executor. They do not start network services, do not read credentials, and do not write to dotfiles or cron. Authentication is provided entirely by OOD.

### Portability
- Rating: Not portable — cluster pax, partition file, port 1234, nf2ood.env path, pipeline root, singularity cache, and slurm profile are all Tufts-specific and undocumented

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Hardcoded cluster "pax" in form.yml.erb | nf-core-scrnaseq-4-1-0/form.yml.erb:2 |
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Partition loaded from external mixin file /etc/ood/config/.../cpu_partition.yml | nf-core-scrnaseq-4-1-0/form.yml.erb:35 |
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Hardcoded port 1234 in before.sh.erb | nf-core-scrnaseq-4-1-0/template/before.sh.erb:8 |
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Hardcoded nf2ood.env path in script.sh.erb | nf-core-scrnaseq-4-1-0/template/script.sh.erb:25 |
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Hardcoded pipeline root path in script.sh.erb | nf-core-scrnaseq-4-1-0/template/script.sh.erb:33 |
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Hardcoded singularity cache path in script.sh.erb | nf-core-scrnaseq-4-1-0/template/script.sh.erb:34 |
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Hardcoded slurm profile name "tufts" in script.sh.erb | nf-core-scrnaseq-4-1-0/template/script.sh.erb:35 |
| QUA-02 | `check: hardcoded-site-paths` | PASS | info | nodes=2 / mem=12G are explicit scheduler params in submit.yml.erb (documented in form) | nf-core-scrnaseq-4-1-0/submit.yml.erb:18-21 |
| QUA-02 | `check: portability-rating` | FAIL | medium | Not portable — all 7 site-specific values are undocumented and Tufts-specific | — |

### Documentation
- Rating: Below minimal — only Overview section and Local review before deployment checklist; no Prerequisites, Installation, Configuration, Known Limitations, Troubleshooting, Screenshots, Environment Variables, Info Panel, or Architecture
- Evidence per rung:
  - what it launches: "Overview", nf-core-scrnaseq-4-1-0/README.md:6
  - prerequisites: none
  - installation: "Local review before deployment", nf-core-scrnaseq-4-1-0/README.md:24 (describes review checklist, not installation steps)
  - configuration: none
  - known limitations: none
  - troubleshooting: none
  - screenshots: none
  - environment variables: none
  - info panel: none
  - architecture: none

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| QUA-01 | `check: documentation-rating` | FAIL | high | Below minimal documentation — fails Adequate target for inclusion | nf-core-scrnaseq-4-1-0/README.md:1 |

### Code Quality

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| QUA-07 | `check: numeric-field-bounds` | NOT CHECKED | info | form.json failed_to_run (ERB not stripped before YAML parse) | form.json |
| QUA-10 | `check: erb-missing-value` | NOT CHECKED | info | form.json failed_to_run — no attributes available for check | form.json |
| QUA-08 | `check: magic-numbers` | PASS | info | No numeric_literals or hex_colors detected in template.json | template.json |
| QUA-04 | `check: dead-code` | PASS | info | No commented_code detected in template.json | template.json |
| QUA-09 | `check: duplicated-blocks` | PASS | info | No large duplicated code blocks | template.json |
| QUA-03 | `check: error-handling` | PASS | low | set -euo pipefail in script.sh.erb; cd and mkdir have shell defaults under set -e | nf-core-scrnaseq-4-1-0/template/script.sh.erb:3 |
| QUA-06 | `check: icon-matches-target-os` | PASS | info | No icons defined in template.json | template.json |

**Code quality observations:** No copy-paste artifacts, duplicate YAML keys, or wrong help text found. The pre-review fact scan (template.json) reported zero commented_code, numeric_literals, and hex_colors across all batch_connect apps. Note: `form.json` failed to parse for all 16 batch_connect apps due to unstripped ERB — this is a scanner defect, not a form defect.

**Per-app decision:** Request changes

---


## App: nf-core-taxprofiler-2-0-0 (nf-core-taxprofiler-2-0-0)

### Signals

| Dimension | Level | Evidence |
|---|---|---|
| Portability | High | Not portable — cluster pax, partition file, port 1234, nf2ood.env path, pipeline root, singularity cache, and slurm profile are all Tufts-specific and undocumented |
| Documentation | High | Below minimal — only Overview section and Local review before deployment checklist; no prerequisites, installation, configuration, or troubleshooting |
| Upkeep (this app) | High | Last change 2026-06-26; one contributor; per-app CHANGELOG present but no CI |

### Structure

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| STR-02 | `check: str-02-metadata` | FAIL | high | manifest.yml missing: maintainer.name, maintainer.support_url. app_type "batch_connect" not in published vocabulary (closest: "batch-connect-basic") | nf-core-taxprofiler-2-0-0/manifest.yml |
| STR-03 | `check: str-03-yaml-valid` | PASS | info | form.yml.erb has balanced ERB tags (verified); manifest.yml parses as valid YAML | nf-core-taxprofiler-2-0-0/form.yml.erb:1 |
| STR-06 | `check: str-06-syntax` | PASS | info | All 2 shell files pass bash -n after ERB stripping (before.sh.erb, script.sh.erb) | nf-core-taxprofiler-2-0-0/template/before.sh.erb:1, nf-core-taxprofiler-2-0-0/template/script.sh.erb:1 |
| STR-07 | `check: str-07-layout` | PASS | info | Batch Connect layout complete: form.yml.erb, submit.yml.erb, template/ (3 files) | nf-core-taxprofiler-2-0-0/form.yml.erb, nf-core-taxprofiler-2-0-0/submit.yml.erb, template/ |
| STR-04 | `check: str-04-references` | NOT CHECKED | info | form.json failed_to_run (ERB not stripped before YAML parse) | form.json |

### Security

**Check tiers:** Tiers 1–2

Tier 3 not checked — no isolated execution environment.

| Tool | Status | Result |
|---|---|---|
| shellcheck | Run (ERB-stripped) | 64 findings (SC2050, SC2148, SC2155), 16 of them linted in isolation from the job-script family |
| semgrep | Run | 0 findings |
| bandit | Not run (no applicable files) | — |
| trivy | Not run (no applicable files) | — |

#### Findings

| Rule | Check | Result | Severity | Tag | Summary | Evidence |
|---|---|---|---|---|---|---|
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `bc_email_on_started` is a check_box (1/0); boolean value does not reach shell | nf-core-taxprofiler-2-0-0/submit.yml.erb:9 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `bc_num_hours` is a number_field (min:1); only numeric values possible | nf-core-taxprofiler-2-0-0/submit.yml.erb:14 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `num_cores` is a number_field (min:1); only numeric values possible | nf-core-taxprofiler-2-0-0/submit.yml.erb:24 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `num_memory` is a number_field (min:1); only numeric values possible | nf-core-taxprofiler-2-0-0/submit.yml.erb:26 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `partition` from select widget loaded from cpu_partition.yml partial; controlled options | nf-core-taxprofiler-2-0-0/submit.yml.erb:29 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `workdir` is path_selector; shell-quoted assignment of filesystem path | nf-core-taxprofiler-2-0-0/template/before.sh.erb:10, nf-core-taxprofiler-2-0-0/template/script.sh.erb:9 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `resume` is check_box (1/0); shell-quoted comparison with constant "1" | nf-core-taxprofiler-2-0-0/template/script.sh.erb:19 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `nextflow_version` is select widget; shell-quoted assignment | nf-core-taxprofiler-2-0-0/template/script.sh.erb:36 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `executor` is select widget (slurm/local); shell-quoted comparison | nf-core-taxprofiler-2-0-0/template/script.sh.erb:64 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `num_cores` written into heredoc-based Nextflow custom.config (not shell-executed) | nf-core-taxprofiler-2-0-0/template/script.sh.erb:72 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | `num_memory` written into heredoc-based Nextflow custom.config; shell-quoted | nf-core-taxprofiler-2-0-0/template/script.sh.erb:73 |
| OODT-01 | `check: sec-eval-exec` | PASS | info | — | `source "${nf2ood_env_file}"` uses hardcoded path (not user-controllable); guarded by -r check | nf-core-taxprofiler-2-0-0/template/script.sh.erb:28 |
| OODT-01 | `check: sec-tool-finding` | PASS | info | — | SC2148, SC2155: artefacts of linting OOD's job-script files one at a time | nf-core-taxprofiler-2-0-0/template/before.sh.erb:1,5 |
| OODT-01 | `check: sec-tool-finding` | PASS | info | — | SC2050: ERB-stripped template yields constant comparisons, style/linting concern | nf-core-taxprofiler-2-0-0/template/script.sh.erb:19,64 |

#### Additional observations (review)

| Rule | Result | Severity | Tag | Summary | Evidence |
|---|---|---|---|---|---|
| — | PASS | info | — | `before.sh.erb` exports `port=1234` but no web service is started in templates; port variable is unused | nf-core-taxprofiler-2-0-0/template/before.sh.erb:8 |
| — | PASS | info | — | `script.sh.erb` contains hardcoded cluster path /cluster/tufts/yzhang85/github/nfcore2ood/nf2ood.env (site-specific, not security concern) | nf-core-taxprofiler-2-0-0/template/script.sh.erb:25 |

No tool-detectable issues in the checked tiers.

### Capability profile (batch_connect)

| File | Capabilities | Anomalies |
|---|---|---|
| `form.yml.erb` | 80-100+ form fields (path_selectors, number_fields, select widgets), ERB-included partials | None |
| `submit.yml.erb` | ERB interpolates form values into slurm job directives, email config | None |
| `template/before.sh.erb` | Sets up working directory, exports hostname and reserved port | None |
| `template/nf-params.json.erb` | Converts form values to JSON via Ruby lambdas (to_bool, to_number), sanitizes types | None |
| `template/script.sh.erb` | Loads modules (nextflow, singularity), sources hardcoded env file, builds nextflow run command | Hardcoded cluster paths |

All batch_connect apps run Nextflow pipelines on the compute node via SLURM or local executor. They do not start network services, do not read credentials, and do not write to dotfiles or cron. Authentication is provided entirely by OOD.

### Portability
- Rating: Not portable — cluster pax, partition file, port 1234, nf2ood.env path, pipeline root, singularity cache, and slurm profile are all Tufts-specific and undocumented

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Hardcoded cluster "pax" in form.yml.erb | nf-core-taxprofiler-2-0-0/form.yml.erb:2 |
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Partition loaded from external mixin file /etc/ood/config/.../cpu_partition.yml | nf-core-taxprofiler-2-0-0/form.yml.erb:35 |
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Hardcoded port 1234 in before.sh.erb | nf-core-taxprofiler-2-0-0/template/before.sh.erb:8 |
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Hardcoded nf2ood.env path in script.sh.erb | nf-core-taxprofiler-2-0-0/template/script.sh.erb:25 |
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Hardcoded pipeline root path in script.sh.erb | nf-core-taxprofiler-2-0-0/template/script.sh.erb:33 |
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Hardcoded singularity cache path in script.sh.erb | nf-core-taxprofiler-2-0-0/template/script.sh.erb:34 |
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | Hardcoded slurm profile name "tufts" in script.sh.erb | nf-core-taxprofiler-2-0-0/template/script.sh.erb:35 |
| QUA-02 | `check: hardcoded-site-paths` | PASS | info | nodes=2 / mem=12G are explicit scheduler params in submit.yml.erb (documented in form) | nf-core-taxprofiler-2-0-0/submit.yml.erb:18-21 |
| QUA-02 | `check: portability-rating` | FAIL | medium | Not portable — all 7 site-specific values are undocumented and Tufts-specific | — |

### Documentation
- Rating: Below minimal — only Overview section and Local review before deployment checklist; no Prerequisites, Installation, Configuration, Known Limitations, Troubleshooting, Screenshots, Environment Variables, Info Panel, or Architecture
- Evidence per rung:
  - what it launches: "Overview", nf-core-taxprofiler-2-0-0/README.md:6
  - prerequisites: none
  - installation: "Local review before deployment", nf-core-taxprofiler-2-0-0/README.md:24 (describes review checklist, not installation steps)
  - configuration: none
  - known limitations: none
  - troubleshooting: none
  - screenshots: none
  - environment variables: none
  - info panel: none
  - architecture: none

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| QUA-01 | `check: documentation-rating` | FAIL | high | Below minimal documentation — fails Adequate target for inclusion | nf-core-taxprofiler-2-0-0/README.md:1 |

### Code Quality

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| QUA-07 | `check: numeric-field-bounds` | NOT CHECKED | info | form.json failed_to_run (ERB not stripped before YAML parse) | form.json |
| QUA-10 | `check: erb-missing-value` | NOT CHECKED | info | form.json failed_to_run — no attributes available for check | form.json |
| QUA-08 | `check: magic-numbers` | PASS | info | No numeric_literals or hex_colors detected in template.json | template.json |
| QUA-04 | `check: dead-code` | PASS | info | No commented_code detected in template.json | template.json |
| QUA-09 | `check: duplicated-blocks` | PASS | info | No large duplicated code blocks | template.json |
| QUA-03 | `check: error-handling` | PASS | low | set -euo pipefail in script.sh.erb; cd and mkdir have shell defaults under set -e | nf-core-taxprofiler-2-0-0/template/script.sh.erb:3 |
| QUA-06 | `check: icon-matches-target-os` | PASS | info | No icons defined in template.json | template.json |

**Code quality observations:** No copy-paste artifacts, duplicate YAML keys, or wrong help text found. The pre-review fact scan (template.json) reported zero commented_code, numeric_literals, and hex_colors across all batch_connect apps. Note: `form.json` failed to parse for all 16 batch_connect apps due to unstripped ERB — this is a scanner defect, not a form defect.

**Per-app decision:** Request changes

---

## Review scope

**Examined:** root appverse.yml, LICENSE, README.md, per-app manifest.yml files, per-app README.md files, per-app form.yml.erb/submit.yml.erb/template/ files, dashboard app.rb/config.ru/controllers/views, dashboard config/pipelines.yml, all security.json, template.json, readme.json pre-review fact files, syntax.json, shellcheck.json, semgrep.json, catalog.json, tool-table.md
**Not examined:** runtime behavior (CI, no app environment), form.yml.erb rendered output (ERB could not be evaluated), per-app dependency manifests (none found), CI pipeline execution, catalog duplicate-rationale check (left for portal)
**Tools:** pre-review syntax (bash -n, all 32 files passed), shellcheck (64 findings, style level excluded), semgrep (0 findings), bandit (not run), trivy (not run), catalog (107 apps, 92 Software entries, 5 app types, 13 implementation tags)

## Catalog checks

Read from the catalog's public API: 107 published apps (3 pages), 92 Software entries, 5 app types, 13 implementation tags.

- **`dashboard`** — Duplicate check — No published app from another repo implements `nf-core`: `tuftsrt/tufts-ood-nfcore` (this repo, already published: 17 apps).
  - **Duplicate-check rationale:** _<reviewer fills in — the outcome and why, per the Reviewer Process's Duplicate check; edit before pasting into the issue or email>_
- **`dashboard`** — `software` — matches the Software entry `nf-core`.
- **`dashboard`** — `app_type` — `dashboards` is not in the published app-type vocabulary (`dashboard`, `widget`, `companion_app`, `batch-connect-basic`, `batch-connect-VNC`). Did you mean `dashboard`?
- **`dashboard`** — `implementation_tags` — all in the vocabulary: `containerized`.
- **`nf-core-ampliseq-2-16-1`** — Duplicate check — No published app from another repo implements `nf-core`: `tuftsrt/tufts-ood-nfcore` (this repo, already published: 17 apps).
  - **Duplicate-check rationale:** _<reviewer fills in — the outcome and why, per the Reviewer Process's Duplicate check; edit before pasting into the issue or email>_
- **`nf-core-ampliseq-2-16-1`** — `software` — matches the Software entry `nf-core`.
- **`nf-core-ampliseq-2-16-1`** — `app_type` — `batch-connect-basic` is in the app-type vocabulary.
- **`nf-core-ampliseq-2-16-1`** — `implementation_tags` — all in the vocabulary: `containerized`.
- **`nf-core-chipseq-2-1-0`** — Duplicate check — No published app from another repo implements `nf-core`: `tuftsrt/tufts-ood-nfcore` (this repo, already published: 17 apps).
  - **Duplicate-check rationale:** _<reviewer fills in — the outcome and why, per the Reviewer Process's Duplicate check; edit before pasting into the issue or email>_
- **`nf-core-chipseq-2-1-0`** — `software` — matches the Software entry `nf-core`.
- **`nf-core-chipseq-2-1-0`** — `app_type` — `batch-connect-basic` is in the app-type vocabulary.
- **`nf-core-chipseq-2-1-0`** — `implementation_tags` — all in the vocabulary: `containerized`.
- **`nf-core-denovotranscript-1-2-1`** — Duplicate check — No published app from another repo implements `nf-core`: `tuftsrt/tufts-ood-nfcore` (this repo, already published: 17 apps).
  - **Duplicate-check rationale:** _<reviewer fills in — the outcome and why, per the Reviewer Process's Duplicate check; edit before pasting into the issue or email>_
- **`nf-core-denovotranscript-1-2-1`** — `software` — matches the Software entry `nf-core`.
- **`nf-core-denovotranscript-1-2-1`** — `app_type` — `batch-connect-basic` is in the app-type vocabulary.
- **`nf-core-denovotranscript-1-2-1`** — `implementation_tags` — all in the vocabulary: `containerized`.
- **`nf-core-differentialabundance-2-0-0`** — Duplicate check — No published app from another repo implements `nf-core`: `tuftsrt/tufts-ood-nfcore` (this repo, already published: 17 apps).
  - **Duplicate-check rationale:** _<reviewer fills in — the outcome and why, per the Reviewer Process's Duplicate check; edit before pasting into the issue or email>_
- **`nf-core-differentialabundance-2-0-0`** — `software` — matches the Software entry `nf-core`.
- **`nf-core-differentialabundance-2-0-0`** — `app_type` — `batch-connect-basic` is in the app-type vocabulary.
- **`nf-core-differentialabundance-2-0-0`** — `implementation_tags` — all in the vocabulary: `containerized`.
- **`nf-core-fetchngs-1-12-0`** — Duplicate check — No published app from another repo implements `nf-core`: `tuftsrt/tufts-ood-nfcore` (this repo, already published: 17 apps).
  - **Duplicate-check rationale:** _<reviewer fills in — the outcome and why, per the Reviewer Process's Duplicate check; edit before pasting into the issue or email>_
- **`nf-core-fetchngs-1-12-0`** — `software` — matches the Software entry `nf-core`.
- **`nf-core-fetchngs-1-12-0`** — `app_type` — `batch-connect-basic` is in the app-type vocabulary.
- **`nf-core-fetchngs-1-12-0`** — `implementation_tags` — all in the vocabulary: `containerized`.
- **`nf-core-funcscan-3-0-0`** — Duplicate check — No published app from another repo implements `nf-core`: `tuftsrt/tufts-ood-nfcore` (this repo, already published: 17 apps).
  - **Duplicate-check rationale:** _<reviewer fills in — the outcome and why, per the Reviewer Process's Duplicate check; edit before pasting into the issue or email>_
- **`nf-core-funcscan-3-0-0`** — `software` — matches the Software entry `nf-core`.
- **`nf-core-funcscan-3-0-0`** — `app_type` — `batch-connect-basic` is in the app-type vocabulary.
- **`nf-core-funcscan-3-0-0`** — `implementation_tags` — all in the vocabulary: `containerized`.
- **`nf-core-mag-5-4-2`** — Duplicate check — No published app from another repo implements `nf-core`: `tuftsrt/tufts-ood-nfcore` (this repo, already published: 17 apps).
  - **Duplicate-check rationale:** _<reviewer fills in — the outcome and why, per the Reviewer Process's Duplicate check; edit before pasting into the issue or email>_
- **`nf-core-mag-5-4-2`** — `software` — matches the Software entry `nf-core`.
- **`nf-core-mag-5-4-2`** — `app_type` — `batch-connect-basic` is in the app-type vocabulary.
- **`nf-core-mag-5-4-2`** — `implementation_tags` — all in the vocabulary: `containerized`.
- **`nf-core-methylseq-4-1-0`** — Duplicate check — No published app from another repo implements `nf-core`: `tuftsrt/tufts-ood-nfcore` (this repo, already published: 17 apps).
  - **Duplicate-check rationale:** _<reviewer fills in — the outcome and why, per the Reviewer Process's Duplicate check; edit before pasting into the issue or email>_
- **`nf-core-methylseq-4-1-0`** — `software` — matches the Software entry `nf-core`.
- **`nf-core-methylseq-4-1-0`** — `app_type` — `batch-connect-basic` is in the app-type vocabulary.
- **`nf-core-methylseq-4-1-0`** — `implementation_tags` — all in the vocabulary: `containerized`.
- **`nf-core-pathogensurveillance-1-1-0`** — Duplicate check — No published app from another repo implements `nf-core`: `tuftsrt/tufts-ood-nfcore` (this repo, already published: 17 apps).
  - **Duplicate-check rationale:** _<reviewer fills in — the outcome and why, per the Reviewer Process's Duplicate check; edit before pasting into the issue or email>_
- **`nf-core-pathogensurveillance-1-1-0`** — `software` — matches the Software entry `nf-core`.
- **`nf-core-pathogensurveillance-1-1-0`** — `app_type` — `batch-connect-basic` is in the app-type vocabulary.
- **`nf-core-pathogensurveillance-1-1-0`** — `implementation_tags` — all in the vocabulary: `containerized`.
- **`nf-core-proteinfamilies-2-4-0`** — Duplicate check — No published app from another repo implements `nf-core`: `tuftsrt/tufts-ood-nfcore` (this repo, already published: 17 apps).
  - **Duplicate-check rationale:** _<reviewer fills in — the outcome and why, per the Reviewer Process's Duplicate check; edit before pasting into the issue or email>_
- **`nf-core-proteinfamilies-2-4-0`** — `software` — matches the Software entry `nf-core`.
- **`nf-core-proteinfamilies-2-4-0`** — `app_type` — `batch-connect-basic` is in the app-type vocabulary.
- **`nf-core-proteinfamilies-2-4-0`** — `implementation_tags` — all in the vocabulary: `containerized`.
- **`nf-core-rnafusion-4-1-0`** — Duplicate check — No published app from another repo implements `nf-core`: `tuftsrt/tufts-ood-nfcore` (this repo, already published: 17 apps).
  - **Duplicate-check rationale:** _<reviewer fills in — the outcome and why, per the Reviewer Process's Duplicate check; edit before pasting into the issue or email>_
- **`nf-core-rnafusion-4-1-0`** — `software` — matches the Software entry `nf-core`.
- **`nf-core-rnafusion-4-1-0`** — `app_type` — `batch-connect-basic` is in the app-type vocabulary.
- **`nf-core-rnafusion-4-1-0`** — `implementation_tags` — all in the vocabulary: `containerized`.
- **`nf-core-rnaseq-3-25-0`** — Duplicate check — No published app from another repo implements `nf-core`: `tuftsrt/tufts-ood-nfcore` (this repo, already published: 17 apps).
  - **Duplicate-check rationale:** _<reviewer fills in — the outcome and why, per the Reviewer Process's Duplicate check; edit before pasting into the issue or email>_
- **`nf-core-rnaseq-3-25-0`** — `software` — matches the Software entry `nf-core`.
- **`nf-core-rnaseq-3-25-0`** — `app_type` — `batch-connect-basic` is in the app-type vocabulary.
- **`nf-core-rnaseq-3-25-0`** — `implementation_tags` — all in the vocabulary: `containerized`.
- **`nf-core-rnaseq-3-26-0`** — Duplicate check — No published app from another repo implements `nf-core`: `tuftsrt/tufts-ood-nfcore` (this repo, already published: 17 apps).
  - **Duplicate-check rationale:** _<reviewer fills in — the outcome and why, per the Reviewer Process's Duplicate check; edit before pasting into the issue or email>_
- **`nf-core-rnaseq-3-26-0`** — `software` — matches the Software entry `nf-core`.
- **`nf-core-rnaseq-3-26-0`** — `app_type` — `batch-connect-basic` is in the app-type vocabulary.
- **`nf-core-rnaseq-3-26-0`** — `implementation_tags` — all in the vocabulary: `containerized`.
- **`nf-core-sarek-3-8-1`** — Duplicate check — No published app from another repo implements `nf-core`: `tuftsrt/tufts-ood-nfcore` (this repo, already published: 17 apps).
  - **Duplicate-check rationale:** _<reviewer fills in — the outcome and why, per the Reviewer Process's Duplicate check; edit before pasting into the issue or email>_
- **`nf-core-sarek-3-8-1`** — `software` — matches the Software entry `nf-core`.
- **`nf-core-sarek-3-8-1`** — `app_type` — `batch-connect-basic` is in the app-type vocabulary.
- **`nf-core-sarek-3-8-1`** — `implementation_tags` — all in the vocabulary: `containerized`.
- **`nf-core-scrnaseq-4-1-0`** — Duplicate check — No published app from another repo implements `nf-core`: `tuftsrt/tufts-ood-nfcore` (this repo, already published: 17 apps).
  - **Duplicate-check rationale:** _<reviewer fills in — the outcome and why, per the Reviewer Process's Duplicate check; edit before pasting into the issue or email>_
- **`nf-core-scrnaseq-4-1-0`** — `software` — matches the Software entry `nf-core`.
- **`nf-core-scrnaseq-4-1-0`** — `app_type` — `batch-connect-basic` is in the app-type vocabulary.
- **`nf-core-scrnaseq-4-1-0`** — `implementation_tags` — all in the vocabulary: `containerized`.
- **`nf-core-taxprofiler-2-0-0`** — Duplicate check — No published app from another repo implements `nf-core`: `tuftsrt/tufts-ood-nfcore` (this repo, already published: 17 apps).
  - **Duplicate-check rationale:** _<reviewer fills in — the outcome and why, per the Reviewer Process's Duplicate check; edit before pasting into the issue or email>_
- **`nf-core-taxprofiler-2-0-0`** — `software` — matches the Software entry `nf-core`.
- **`nf-core-taxprofiler-2-0-0`** — `app_type` — `batch-connect-basic` is in the app-type vocabulary.
- **`nf-core-taxprofiler-2-0-0`** — `implementation_tags` — all in the vocabulary: `containerized`.

## Overall recommendation

**Request changes.** All 17 apps fail the STR-02 gate: per-app manifest.yml files are missing the required fields maintainer.name and maintainer.support_url, and the dashboard's app_type "dashboards" is not in the published catalog vocabulary (did you mean "dashboard"?). The 16 batch_connect apps also declare app_type "batch_connect" which is not in the vocabulary (did you mean "batch-connect-basic"?). These are straightforward structural fixes — add the missing maintainer fields and correct the app_type values.

Additionally, all 17 apps fail the documentation gate (QUA-01: Below minimal) and the portability gate for 16 of 17 apps (QUA-02: Not portable). While these are not gating decisions on their own, they move the outcome from Accept to Accept with suggestions. Since the STR-02 gate failure already sets the floor at Request changes, the documentation and portability gaps are improvement areas to address alongside the structural fixes.

The security review found no tool-detectable issues. All interpolation candidates are from controlled sources (number_fields, check_boxes, select widgets, path_selectors) and do not reach the shell in an unsanitized manner.

## Draft feedback — edit before sending

Thank you for submitting the Tufts RT nf-core Open OnDemand app collection to the catalog. The repository is active with recent pushes, releases, and multiple contributors, and it scores a Medium upkeep signal; the README is substantive at 27 lines and 1 725 characters with real content in all sections, and a clear MIT license is in place. All manifest files parse as valid YAML, every batch_connect app has a complete layout (form.yml.erb, submit.yml.erb, and a template directory), and all shell scripts pass syntax checks. Security reviews found no tool-detectable issues in the checked tiers, and code quality checks confirm no magic numbers, dead code, or duplicated blocks across the apps.

**Must fix**

1. `catalog.json` Every app declares an app_type that is not in the published catalog vocabulary. The dashboard manifest uses "dashboards" (the published term is "dashboard"), and all 16 batch_connect manifests use "batch_connect" (the published term is "batch-connect-basic"). Update each manifest.yml and apps.json to use the exact vocabulary values so the catalog can index and classify the apps correctly.
2. `manifest.yml`, `dashboard/manifest.yml` All 17 per-app manifest.yml files are missing the two required fields maintainer.name and maintainer.support_url. Add a maintainer.name with the responsible person or team and a maintainer.support_url pointing to a support or issue-tracking URL in every manifest.yml.

**Should fix**

3. `dashboard/README.md:1`, `nf-core-ampliseq-2-16-1/README.md:1`, `nf-core-chipseq-2-1-0/README.md:1`, `nf-core-denovotranscript-1-2-1/README.md:1`, `nf-core-differentialabundance-2-0-0/README.md:1`, `nf-core-fetchngs-1-12-0/README.md:1`, `nf-core-funcscan-3-0-0/README.md:1`, `nf-core-mag-5-4-2/README.md:1`, `nf-core-methylseq-4-1-0/README.md:1`, `nf-core-pathogensurveillance-1-1-0/README.md:1`, `nf-core-proteinfamilies-2-4-0/README.md:1`, `nf-core-rnafusion-4-1-0/README.md:1`, `nf-core-rnaseq-3-25-0/README.md:1`, `nf-core-rnaseq-3-26-0/README.md:1`, `nf-core-sarek-3-8-1/README.md:1`, `nf-core-scrnaseq-4-1-0/README.md:1`, `nf-core-taxprofiler-2-0-0/README.md:1` All 17 apps are rated Below minimal documentation and fail the Adequate target for inclusion. The dashboard README has What it launches, Installation, Configuration, Known limitations, and Architecture sections but is missing Prerequisites, Troubleshooting, Environment variables, and an Info panel. Every batch_connect app's README contains only an Overview section plus a Local review before deployment checklist, and is missing prerequisites, installation steps, configuration details, known limitations, troubleshooting, screenshots, environment variables, info panel, and architecture documentation. Add the missing sections to each README so they reach at least the Adequate rung.
4. `nf-core-ampliseq-2-16-1/form.yml.erb:2,35`, `nf-core-ampliseq-2-16-1/template/before.sh.erb:8`, `nf-core-ampliseq-2-16-1/template/script.sh.erb:25,33,34,35`, `nf-core-chipseq-2-1-0/form.yml.erb:2,35`, `nf-core-chipseq-2-1-0/template/before.sh.erb:8`, `nf-core-chipseq-2-1-0/template/script.sh.erb:25,33,34,35`, `nf-core-denovotranscript-1-2-1/form.yml.erb:2,35`, `nf-core-denovotranscript-1-2-1/template/before.sh.erb:8`, `nf-core-denovotranscript-1-2-1/template/script.sh.erb:25,33,34,35`, `nf-core-differentialabundance-2-0-0/form.yml.erb:2,35`, `nf-core-differentialabundance-2-0-0/template/before.sh.erb:8`, `nf-core-differentialabundance-2-0-0/template/script.sh.erb:25,33,34,35`, `nf-core-fetchngs-1-12-0/form.yml.erb:2,35`, `nf-core-fetchngs-1-12-0/template/before.sh.erb:8`, `nf-core-fetchngs-1-12-0/template/script.sh.erb:25,33,34,35`, `nf-core-funcscan-3-0-0/form.yml.erb:2,35`, `nf-core-funcscan-3-0-0/template/before.sh.erb:8`, `nf-core-funcscan-3-0-0/template/script.sh.erb:25,33,34,35`, `nf-core-mag-5-4-2/form.yml.erb:2,35`, `nf-core-mag-5-4-2/template/before.sh.erb:8`, `nf-core-mag-5-4-2/template/script.sh.erb:25,33,34,35`, `nf-core-methylseq-4-1-0/form.yml.erb:2,35`, `nf-core-methylseq-4-1-0/template/before.sh.erb:8`, `nf-core-methylseq-4-1-0/template/script.sh.erb:25,33,34,35`, `nf-core-pathogensurveillance-1-1-0/form.yml.erb:2,35`, `nf-core-pathogensurveillance-1-1-0/template/before.sh.erb:8`, `nf-core-pathogensurveillance-1-1-0/template/script.sh.erb:25,33,34,35`, `nf-core-proteinfamilies-2-4-0/form.yml.erb:2,35`, `nf-core-proteinfamilies-2-4-0/template/before.sh.erb:8`, `nf-core-proteinfamilies-2-4-0/template/script.sh.erb:25,33,34,35`, `nf-core-rnafusion-4-1-0/form.yml.erb:2,35`, `nf-core-rnafusion-4-1-0/template/before.sh.erb:8`, `nf-core-rnafusion-4-1-0/template/script.sh.erb:25,33,34,35`, `nf-core-rnaseq-3-25-0/form.yml.erb:2,35`, `nf-core-rnaseq-3-25-0/template/before.sh.erb:8`, `nf-core-rnaseq-3-25-0/template/script.sh.erb:25,33,34,35`, `nf-core-rnaseq-3-26-0/form.yml.erb:2,35`, `nf-core-rnaseq-3-26-0/template/before.sh.erb:8`, `nf-core-rnaseq-3-26-0/template/script.sh.erb:25,33,34,35`, `nf-core-sarek-3-8-1/form.yml.erb:2,35`, `nf-core-sarek-3-8-1/template/before.sh.erb:8`, `nf-core-sarek-3-8-1/template/script.sh.erb:25,33,34,35`, `nf-core-scrnaseq-4-1-0/form.yml.erb:2,35`, `nf-core-scrnaseq-4-1-0/template/before.sh.erb:8`, `nf-core-scrnaseq-4-1-0/template/script.sh.erb:25,33,34,35`, `nf-core-taxprofiler-2-0-0/form.yml.erb:2,35`, `nf-core-taxprofiler-2-0-0/template/before.sh.erb:8`, `nf-core-taxprofiler-2-0-0/template/script.sh.erb:25,33,34,35` All 16 batch_connect apps are rated Not portable because each contains seven site-specific values that are undocumented: the cluster name ("pax"), partition file path (an external mixin at /etc/ood/config/…/cpu_partition.yml), a hardcoded port (1234), the nf2ood.env path, the pipeline root, the singularity cache path, and the slurm profile name ("tufts"). These values are hardcoded in form.yml.erb and template/script.sh.erb files. To reach at least the Partially portable rating, parameterize or externalize these site-specific settings and document what each one does and where it is configured.

**Suggestions (optional)**

5. `nf-core-ampliseq-2-16-1/form.yml.erb:2`, `nf-core-chipseq-2-1-0/form.yml.erb:2`, `nf-core-denovotranscript-1-2-1/form.yml.erb:2`, `nf-core-differentialabundance-2-0-0/form.yml.erb:2`, `nf-core-fetchngs-1-12-0/form.yml.erb:2`, `nf-core-funcscan-3-0-0/form.yml.erb:2`, `nf-core-mag-5-4-2/form.yml.erb:2`, `nf-core-methylseq-4-1-0/form.yml.erb:2`, `nf-core-pathogensurveillance-1-1-0/form.yml.erb:2`, `nf-core-proteinfamilies-2-4-0/form.yml.erb:2`, `nf-core-rnafusion-4-1-0/form.yml.erb:2`, `nf-core-rnaseq-3-25-0/form.yml.erb:2`, `nf-core-rnaseq-3-26-0/form.yml.erb:2`, `nf-core-sarek-3-8-1/form.yml.erb:2`, `nf-core-scrnaseq-4-1-0/form.yml.erb:2`, `nf-core-taxprofiler-2-0-0/form.yml.erb:2` All 16 batch_connect apps hardcode the cluster name "pax" in form.yml.erb (line 2 of each). If the cluster name is site-specific, make it configurable through a form field or an environment variable so the app can be deployed on other clusters without editing the source.
6. `nf-core-ampliseq-2-16-1/form.yml.erb:35`, `nf-core-chipseq-2-1-0/form.yml.erb:35`, `nf-core-denovotranscript-1-2-1/form.yml.erb:35`, `nf-core-differentialabundance-2-0-0/form.yml.erb:35`, `nf-core-fetchngs-1-12-0/form.yml.erb:35`, `nf-core-funcscan-3-0-0/form.yml.erb:35`, `nf-core-mag-5-4-2/form.yml.erb:35`, `nf-core-methylseq-4-1-0/form.yml.erb:35`, `nf-core-pathogensurveillance-1-1-0/form.yml.erb:35`, `nf-core-proteinfamilies-2-4-0/form.yml.erb:35`, `nf-core-rnafusion-4-1-0/form.yml.erb:35`, `nf-core-rnaseq-3-25-0/form.yml.erb:35`, `nf-core-rnaseq-3-26-0/form.yml.erb:35`, `nf-core-sarek-3-8-1/form.yml.erb:35`, `nf-core-scrnaseq-4-1-0/form.yml.erb:35`, `nf-core-taxprofiler-2-0-0/form.yml.erb:35` All 16 batch_connect apps load the partition options from an external mixin file at a hardcoded path (form.yml.erb line 35 in each app). If that path is site-specific, make it configurable so the app does not break when deployed to a system with a different OOD configuration layout.
7. `nf-core-ampliseq-2-16-1/template/before.sh.erb:8`, `nf-core-ampliseq-2-16-1/template/script.sh.erb:25,33,34,35`, `nf-core-chipseq-2-1-0/template/before.sh.erb:8`, `nf-core-chipseq-2-1-0/template/script.sh.erb:25,33,34,35`, `nf-core-denovotranscript-1-2-1/template/before.sh.erb:8`, `nf-core-denovotranscript-1-2-1/template/script.sh.erb:25,33,34,35`, `nf-core-differentialabundance-2-0-0/template/before.sh.erb:8`, `nf-core-differentialabundance-2-0-0/template/script.sh.erb:25,33,34,35`, `nf-core-fetchngs-1-12-0/template/before.sh.erb:8`, `nf-core-fetchngs-1-12-0/template/script.sh.erb:25,33,34,35`, `nf-core-funcscan-3-0-0/template/before.sh.erb:8`, `nf-core-funcscan-3-0-0/template/script.sh.erb:25,33,34,35`, `nf-core-mag-5-4-2/template/before.sh.erb:8`, `nf-core-mag-5-4-2/template/script.sh.erb:25,33,34,35`, `nf-core-methylseq-4-1-0/template/before.sh.erb:8`, `nf-core-methylseq-4-1-0/template/script.sh.erb:25,33,34,35`, `nf-core-pathogensurveillance-1-1-0/template/before.sh.erb:8`, `nf-core-pathogensurveillance-1-1-0/template/script.sh.erb:25,33,34,35`, `nf-core-proteinfamilies-2-4-0/template/before.sh.erb:8`, `nf-core-proteinfamilies-2-4-0/template/script.sh.erb:25,33,34,35`, `nf-core-rnafusion-4-1-0/template/before.sh.erb:8`, `nf-core-rnafusion-4-1-0/template/script.sh.erb:25,33,34,35`, `nf-core-rnaseq-3-25-0/template/before.sh.erb:8`, `nf-core-rnaseq-3-25-0/template/script.sh.erb:25,33,34,35`, `nf-core-rnaseq-3-26-0/template/before.sh.erb:8`, `nf-core-rnaseq-3-26-0/template/script.sh.erb:25,33,34,35`, `nf-core-sarek-3-8-1/template/before.sh.erb:8`, `nf-core-sarek-3-8-1/template/script.sh.erb:25,33,34,35`, `nf-core-scrnaseq-4-1-0/template/before.sh.erb:8`, `nf-core-scrnaseq-4-1-0/template/script.sh.erb:25,33,34,35`, `nf-core-taxprofiler-2-0-0/template/before.sh.erb:8`, `nf-core-taxprofiler-2-0-0/template/script.sh.erb:25,33,34,35` All 16 batch_connect apps contain hardcoded paths that limit portability. Each app hardcodes port 1234 in template/before.sh.erb (line 8) and four site-specific paths in template/script.sh.erb (lines 25, 33, 34, 35): the nf2ood.env path, the pipeline root, the singularity cache path, and the slurm profile name. If these values are Tufts-specific, parameterize them through form fields, environment variables, or a shared config so other sites can adopt the app without modifying source.

<!-- feedback-generated -->
<!-- feedback-covers: dashboard:other:app-type-not-in-vocabulary, nf-core-ampliseq-2-16-1:other:app-type-not-in-vocabulary, nf-core-chipseq-2-1-0:other:app-type-not-in-vocabulary, nf-core-denovotranscript-1-2-1:other:app-type-not-in-vocabulary, nf-core-differentialabundance-2-0-0:other:app-type-not-in-vocabulary, nf-core-fetchngs-1-12-0:other:app-type-not-in-vocabulary, nf-core-funcscan-3-0-0:other:app-type-not-in-vocabulary, nf-core-mag-5-4-2:other:app-type-not-in-vocabulary, nf-core-methylseq-4-1-0:other:app-type-not-in-vocabulary, nf-core-pathogensurveillance-1-1-0:other:app-type-not-in-vocabulary, nf-core-proteinfamilies-2-4-0:other:app-type-not-in-vocabulary, nf-core-rnafusion-4-1-0:other:app-type-not-in-vocabulary, nf-core-rnaseq-3-25-0:other:app-type-not-in-vocabulary, nf-core-rnaseq-3-26-0:other:app-type-not-in-vocabulary, nf-core-sarek-3-8-1:other:app-type-not-in-vocabulary, nf-core-scrnaseq-4-1-0:other:app-type-not-in-vocabulary, nf-core-taxprofiler-2-0-0:other:app-type-not-in-vocabulary, root:missing-field:maintainer.name, root:missing-field:maintainer.support_url, dashboard:missing-field:maintainer.name, dashboard:missing-field:maintainer.support_url, nf-core-ampliseq-2-16-1:missing-field:maintainer.name, nf-core-ampliseq-2-16-1:missing-field:maintainer.support_url, nf-core-chipseq-2-1-0:missing-field:maintainer.name, nf-core-chipseq-2-1-0:missing-field:maintainer.support_url, nf-core-denovotranscript-1-2-1:missing-field:maintainer.name, nf-core-denovotranscript-1-2-1:missing-field:maintainer.support_url, nf-core-differentialabundance-2-0-0:missing-field:maintainer.name, nf-core-differentialabundance-2-0-0:missing-field:maintainer.support_url, nf-core-fetchngs-1-12-0:missing-field:maintainer.name, nf-core-fetchngs-1-12-0:missing-field:maintainer.support_url, nf-core-funcscan-3-0-0:missing-field:maintainer.name, nf-core-funcscan-3-0-0:missing-field:maintainer.support_url, nf-core-mag-5-4-2:missing-field:maintainer.name, nf-core-mag-5-4-2:missing-field:maintainer.support_url, nf-core-methylseq-4-1-0:missing-field:maintainer.name, nf-core-methylseq-4-1-0:missing-field:maintainer.support_url, nf-core-pathogensurveillance-1-1-0:missing-field:maintainer.name, nf-core-pathogensurveillance-1-1-0:missing-field:maintainer.support_url, nf-core-proteinfamilies-2-4-0:missing-field:maintainer.name, nf-core-proteinfamilies-2-4-0:missing-field:maintainer.support_url, nf-core-rnafusion-4-1-0:missing-field:maintainer.name, nf-core-rnafusion-4-1-0:missing-field:maintainer.support_url, nf-core-rnaseq-3-25-0:missing-field:maintainer.name, nf-core-rnaseq-3-25-0:missing-field:maintainer.support_url, nf-core-rnaseq-3-26-0:missing-field:maintainer.name, nf-core-rnaseq-3-26-0:missing-field:maintainer.support_url, nf-core-sarek-3-8-1:missing-field:maintainer.name, nf-core-sarek-3-8-1:missing-field:maintainer.support_url, nf-core-scrnaseq-4-1-0:missing-field:maintainer.name, nf-core-scrnaseq-4-1-0:missing-field:maintainer.support_url, nf-core-taxprofiler-2-0-0:missing-field:maintainer.name, nf-core-taxprofiler-2-0-0:missing-field:maintainer.support_url, dashboard/README.md:docs-minimal, nf-core-ampliseq-2-16-1/README.md:docs-minimal, nf-core-chipseq-2-1-0/README.md:docs-minimal, nf-core-denovotranscript-1-2-1/README.md:docs-minimal, nf-core-differentialabundance-2-0-0/README.md:docs-minimal, nf-core-fetchngs-1-12-0/README.md:docs-minimal, nf-core-funcscan-3-0-0/README.md:docs-minimal, nf-core-mag-5-4-2/README.md:docs-minimal, nf-core-methylseq-4-1-0/README.md:docs-minimal, nf-core-pathogensurveillance-1-1-0/README.md:docs-minimal, nf-core-proteinfamilies-2-4-0/README.md:docs-minimal, nf-core-rnafusion-4-1-0/README.md:docs-minimal, nf-core-rnaseq-3-25-0/README.md:docs-minimal, nf-core-rnaseq-3-26-0/README.md:docs-minimal, nf-core-sarek-3-8-1/README.md:docs-minimal, nf-core-scrnaseq-4-1-0/README.md:docs-minimal, nf-core-taxprofiler-2-0-0/README.md:docs-minimal, nf-core-ampliseq-2-16-1/form.yml.erb:other:portability, nf-core-chipseq-2-1-0/form.yml.erb:other:portability, nf-core-denovotranscript-1-2-1/form.yml.erb:other:portability, nf-core-differentialabundance-2-0-0/form.yml.erb:other:portability, nf-core-fetchngs-1-12-0/form.yml.erb:other:portability, nf-core-funcscan-3-0-0/form.yml.erb:other:portability, nf-core-mag-5-4-2/form.yml.erb:other:portability, nf-core-methylseq-4-1-0/form.yml.erb:other:portability, nf-core-pathogensurveillance-1-1-0/form.yml.erb:other:portability, nf-core-proteinfamilies-2-4-0/form.yml.erb:other:portability, nf-core-rnafusion-4-1-0/form.yml.erb:other:portability, nf-core-rnaseq-3-25-0/form.yml.erb:other:portability, nf-core-rnaseq-3-26-0/form.yml.erb:other:portability, nf-core-sarek-3-8-1/form.yml.erb:other:portability, nf-core-scrnaseq-4-1-0/form.yml.erb:other:portability, nf-core-taxprofiler-2-0-0/form.yml.erb:other:portability, nf-core-ampliseq-2-16-1/form.yml.erb:hardcoded-cluster, nf-core-chipseq-2-1-0/form.yml.erb:hardcoded-cluster, nf-core-denovotranscript-1-2-1/form.yml.erb:hardcoded-cluster, nf-core-differentialabundance-2-0-0/form.yml.erb:hardcoded-cluster, nf-core-fetchngs-1-12-0/form.yml.erb:hardcoded-cluster, nf-core-funcscan-3-0-0/form.yml.erb:hardcoded-cluster, nf-core-mag-5-4-2/form.yml.erb:hardcoded-cluster, nf-core-methylseq-4-1-0/form.yml.erb:hardcoded-cluster, nf-core-pathogensurveillance-1-1-0/form.yml.erb:hardcoded-cluster, nf-core-proteinfamilies-2-4-0/form.yml.erb:hardcoded-cluster, nf-core-rnafusion-4-1-0/form.yml.erb:hardcoded-cluster, nf-core-rnaseq-3-25-0/form.yml.erb:hardcoded-cluster, nf-core-rnaseq-3-26-0/form.yml.erb:hardcoded-cluster, nf-core-sarek-3-8-1/form.yml.erb:hardcoded-cluster, nf-core-scrnaseq-4-1-0/form.yml.erb:hardcoded-cluster, nf-core-taxprofiler-2-0-0/form.yml.erb:hardcoded-cluster, nf-core-ampliseq-2-16-1/form.yml.erb:hardcoded-partition, nf-core-chipseq-2-1-0/form.yml.erb:hardcoded-partition, nf-core-denovotranscript-1-2-1/form.yml.erb:hardcoded-partition, nf-core-differentialabundance-2-0-0/form.yml.erb:hardcoded-partition, nf-core-fetchngs-1-12-0/form.yml.erb:hardcoded-partition, nf-core-funcscan-3-0-0/form.yml.erb:hardcoded-partition, nf-core-mag-5-4-2/form.yml.erb:hardcoded-partition, nf-core-methylseq-4-1-0/form.yml.erb:hardcoded-partition, nf-core-pathogensurveillance-1-1-0/form.yml.erb:hardcoded-partition, nf-core-proteinfamilies-2-4-0/form.yml.erb:hardcoded-partition, nf-core-rnafusion-4-1-0/form.yml.erb:hardcoded-partition, nf-core-rnaseq-3-25-0/form.yml.erb:hardcoded-partition, nf-core-rnaseq-3-26-0/form.yml.erb:hardcoded-partition, nf-core-sarek-3-8-1/form.yml.erb:hardcoded-partition, nf-core-scrnaseq-4-1-0/form.yml.erb:hardcoded-partition, nf-core-taxprofiler-2-0-0/form.yml.erb:hardcoded-partition, nf-core-ampliseq-2-16-1/template/before.sh.erb:hardcoded-path, nf-core-ampliseq-2-16-1/template/script.sh.erb:hardcoded-path, nf-core-chipseq-2-1-0/template/before.sh.erb:hardcoded-path, nf-core-chipseq-2-1-0/template/script.sh.erb:hardcoded-path, nf-core-denovotranscript-1-2-1/template/before.sh.erb:hardcoded-path, nf-core-denovotranscript-1-2-1/template/script.sh.erb:hardcoded-path, nf-core-differentialabundance-2-0-0/template/before.sh.erb:hardcoded-path, nf-core-differentialabundance-2-0-0/template/script.sh.erb:hardcoded-path, nf-core-fetchngs-1-12-0/template/before.sh.erb:hardcoded-path, nf-core-fetchngs-1-12-0/template/script.sh.erb:hardcoded-path, nf-core-funcscan-3-0-0/template/before.sh.erb:hardcoded-path, nf-core-funcscan-3-0-0/template/script.sh.erb:hardcoded-path, nf-core-mag-5-4-2/template/before.sh.erb:hardcoded-path, nf-core-mag-5-4-2/template/script.sh.erb:hardcoded-path, nf-core-methylseq-4-1-0/template/before.sh.erb:hardcoded-path, nf-core-methylseq-4-1-0/template/script.sh.erb:hardcoded-path, nf-core-pathogensurveillance-1-1-0/template/before.sh.erb:hardcoded-path, nf-core-pathogensurveillance-1-1-0/template/script.sh.erb:hardcoded-path, nf-core-proteinfamilies-2-4-0/template/before.sh.erb:hardcoded-path, nf-core-proteinfamilies-2-4-0/template/script.sh.erb:hardcoded-path, nf-core-rnafusion-4-1-0/template/before.sh.erb:hardcoded-path, nf-core-rnafusion-4-1-0/template/script.sh.erb:hardcoded-path, nf-core-rnaseq-3-25-0/template/before.sh.erb:hardcoded-path, nf-core-rnaseq-3-25-0/template/script.sh.erb:hardcoded-path, nf-core-rnaseq-3-26-0/template/before.sh.erb:hardcoded-path, nf-core-rnaseq-3-26-0/template/script.sh.erb:hardcoded-path, nf-core-sarek-3-8-1/template/before.sh.erb:hardcoded-path, nf-core-sarek-3-8-1/template/script.sh.erb:hardcoded-path, nf-core-scrnaseq-4-1-0/template/before.sh.erb:hardcoded-path, nf-core-scrnaseq-4-1-0/template/script.sh.erb:hardcoded-path, nf-core-taxprofiler-2-0-0/template/before.sh.erb:hardcoded-path, nf-core-taxprofiler-2-0-0/template/script.sh.erb:hardcoded-path -->
