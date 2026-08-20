# Appverse Review Skill — Testing Guide

This document describes the test fixtures, what each one targets, and the
expected findings when the review skill runs against them. Use it to verify
that the skill catches the right issues and calibrate its detection.

## How to run

Install the plugin locally, then run in submitter mode from inside each
fixture directory:

```bash
cd tests/fixtures/<fixture-name>
# In a Claude Code session:
/appverse-review:review-app
```

Or run a single aspect:

```
/appverse-review:review-security
/appverse-review:review-structure
```

Maintenance signals (GitHub API queries) will report NOT CHECKED for local
fixtures since they have no remote origin. That is expected.

---

## Fixture inventory

| Fixture | App type | Primary test target | Expected decision |
|---------|----------|-------------------|-------------------|
| [broken-app](#1-broken-app) | Batch Connect (inferred) | Basic required-criteria failures + planted secrets | Request changes or Reject |
| [monorepo](#2-monorepo) | Declared monorepo (2 apps) | Per-app review with mixed outcomes | Mixed: Accept (good-app), Request changes (bad-app) |
| [vnc-stale-debugger](#3-vnc-stale-debugger) | Batch Connect VNC (inferred) | Subtle quality issues + correctness-&-polish defects behind a passing structure | Accept with suggestions or Request changes |
| [passenger-flask-app](#4-passenger-flask-app) | Passenger/Flask (inferred) | Command injection in a non-Batch-Connect app | Reject or Request changes |
| [containerized-server](#5-containerized-server) | Batch Connect basic (inferred) | Portability failures + container security | Request changes |
| [curl-pipe-installer](#6-curl-pipe-installer) | Batch Connect basic (inferred) | Critical security behind polished documentation | Reject |

---

## 1. broken-app

**What it is:** A minimal Batch Connect app with no LICENSE, broken YAML, a
committed secret, and a stub README. The most basic failure case — tests that
the skill catches the obvious.

**Planted defects:**

| # | Defect | File | Expected aspect | Expected finding |
|---|--------|------|-----------------|-----------------|
| 1 | Missing LICENSE | (absent) | Structure | FAIL — LICENSE not present |
| 2 | Invalid YAML (unclosed bracket) | `form.yml:3` | Structure | FAIL — YAML parse error quoted verbatim |
| 3 | Committed API secret | `template/script.sh.erb:2` | Security | FAIL — OODT-02 Credential Exposure, High |
| 4 | Service bound to `0.0.0.0` | `template/script.sh.erb:4` | Security | FAIL — OODT-05 Network Exposure, Medium–High |
| 5 | Hardcoded account + partition + absolute path | `submit.yml.erb:5–6`, `template/script.sh.erb:3` | Quality | Not portable |
| 6 | Stub README (title + contact only) | `README.md` | Structure + Quality | FAIL — not substantive; Documentation: Minimal |

**Verify:** All 6 findings appear with evidence. Submitter-mode output ends
with a prioritized fix list, security items first.

---

## 2. monorepo

**What it is:** A declared monorepo (`appverse.yml` with `apps[]`) containing
two Batch Connect apps — one complete (good-app) and one missing required
declared-repo metadata (bad-app). Tests per-app review and field-precedence
resolution.

**Planted defects:**

| # | Defect | File | Expected aspect | Expected finding |
|---|--------|------|-----------------|-----------------|
| 1 | bad-app missing `software` | `appverse.yml` apps[1] | Structure | FAIL — required declared-repo field missing |
| 2 | bad-app missing `app_type` | `appverse.yml` apps[1] | Structure | FAIL — required declared-repo field missing |

**Key behavior to verify:**

- Repo shape reported as "declared monorepo (2 apps)"
- Two app sections in the report: `Good App (apps/good-app)` and `Bad App (apps/bad-app)`
- `maintainer.name` and `maintainer.support_url` are **inherited** from the
  root `appverse.yml` for both apps — bad-app must NOT be flagged for missing
  maintainer info
- `shared/common.sh` reviewed once at repo level and included in security pass
- Per-app decisions differ; overall recommendation summarizes both

---

## 3. vnc-stale-debugger

**What it is:** A VNC Batch Connect debugger app (inspired by real ARM Forge
and Lumerical FDTD apps) that passes basic structural checks — LICENSE, README,
valid manifest — but has subtle quality and consistency issues that require
deeper inspection.

**Planted defects:**

| # | Defect | File | Expected aspect | Expected finding |
|---|--------|------|-----------------|-----------------|
| 1 | Site-specific Ruby mixin (`require "account_cache"`) | `form.yml.erb:3` | Quality | Not portable — requires site-specific code |
| 2 | `input_file` attribute defined but not in `form:` list | `form.yml.erb:37–40` | Quality | WARN — dead code / unused attribute |
| 3 | `num_cores` allows min 0 | `form.yml.erb:33` | Quality | WARN — can submit a 0-core job |
| 4 | Form node_type values (`:gpu:gpus=1`, `:hugemem`) don't match submit.yml.erb case branches (`"gpu"`, `"hugemem"`) | `form.yml.erb:27–28` vs `submit.yml.erb:24–30` | Structure | WARN — broken reference; GPU/hugemem resources will never be requested |
| 5 | `cores_lookup` has entries for `k80_gpu` and `p100_gpu` not in form options | `submit.yml.erb:8–9` | Quality | WARN — dead code |
| 6 | Hardcoded module versions (`intel/18.0.2`, `mvapich2/2.3`) | `template/script.sh.erb:7–8` | Quality | Not portable |
| 7 | Uses `$PBS_NODEFILE` (PBS var on a Slurm cluster) | `template/script.sh.erb:18–19` | Quality | WARN — depends on Slurm PBS compatibility shim |
| 8 | Hardcoded path `/usr/share/Modules/init/bash` | `template/script.sh.erb:4` | Quality | Not portable |
| 9 | Copy-paste artifact: MATLAB help text in a debugger app | `form.yml.erb:32` | Quality | Correctness & polish — wrong-app reference (`"Number of cores for your MATLAB session"` in an HPC Debugger app) |
| 10 | Duplicate YAML key: `help:` appears twice on `num_cores` | `form.yml.erb:32,35` | Quality | Correctness & polish — last-wins parsing silently drops the first `help:` value |
| 11 | CHANGELOG describes a different app (MATLAB, not HPC Debugger) | `CHANGELOG.md` | Quality | Correctness & polish — entire changelog is from a MATLAB app template |

**Key behavior to verify:**

- Basic structure checks PASS (LICENSE, README, manifest, valid YAML all present)
- The skill digs deeper to find the form/submit mismatch — this is the most
  important finding since it means GPU and hugemem jobs silently get standard
  resources
- Portability rated "Not portable" due to hardcoded cluster, modules, and paths
- README rated "Adequate" or better (it has all four required sections)

---

## 4. passenger-flask-app

**What it is:** A Passenger/Flask web app for monitoring HPC jobs (inspired by
ood-cloud-storage-conf). Not a Batch Connect app — no `form.yml`, no
`submit.yml.erb`, no `template/`. Tests that the security skill correctly
profiles Passenger apps and catches command injection.

**Planted defects:**

| # | Defect | File | Expected aspect | Expected finding |
|---|--------|------|-----------------|-----------------|
| 1 | Command injection via `job_id` in `cancel_job` | `app.py:37` | Security | FAIL — OODT-01, High — `f"scancel {job_id}"` with `shell=True`, job_id comes from URL path |
| 2 | Command injection via `job_id` in `job_detail` | `app.py:47–48` | Security | WARN — uses list form (safer) but job_id is still unvalidated |
| 3 | Shell script injection via `email` and `job_id` in `set_alert` | `app.py:58–63` | Security | FAIL — OODT-01, Critical — user-provided values interpolated directly into a shell script that gets executed in a loop |
| 4 | Command injection via `days` query param in `job_history` | `app.py:81` | Security | FAIL — OODT-01, High — `f"sacct -u {user} -S now-{days}days"` with `shell=True`, `days` from query string |
| 5 | Secret/token storage in `/tmp` | `app.py:11`, `cloud_auth/utils.py:5` | Security | WARN — OODT-02, Medium — `/tmp/$USER` is world-readable parent; scripts contain job context |
| 6 | Mutable default argument | `cloud_auth/utils.py:8` | Quality | WARN — `errors=[]` is a classic Python bug |
| 7 | Hardcoded Slurm binary path | `app.py:9` | Quality | Not portable |
| 8 | Hardcoded SMTP relay | `app.py:10` | Quality | Not portable |
| 9 | Minimal README (no install/config sections) | `README.md` | Quality | Documentation: Minimal |
| 10 | No `form.yml` or `appverse.yml`, no `role` in manifest | (absent / `manifest.yml`) | Structure | Repo shape: inferred (manifest.yml present). WARN — `manifest.yml` missing `role` field; app detected as Passenger via `passenger_wsgi.py` entry point |

**Key behavior to verify:**

- The security skill profiles this as a Passenger app (detected via
  `passenger_wsgi.py` entry point; `manifest.yml` has no `role` field — WARN)
- subprocess usage is *reported* in the capability profile but not flagged on
  its own — a job management tool is expected to call Slurm commands
- The *way* subprocess is used (unvalidated user input + `shell=True`) IS
  flagged as command injection
- The `set_alert` route is the worst offender — it's essentially arbitrary
  code execution via crafted email/job_id values

---

## 5. containerized-server

**What it is:** A Batch Connect basic app running MLflow behind an nginx
reverse proxy in Singularity containers (inspired by ood-tensorboard). Tests
portability detection, undefined variables, and container-related security.

**Planted defects:**

| # | Defect | File | Expected aspect | Expected finding |
|---|--------|------|-----------------|-----------------|
| 1 | Undefined `csc_*` form attributes (6 of them) referenced but not defined locally | `form.yml.erb:4–9` | Structure | WARN — form references attributes from external framework |
| 2 | `${app_port}` undefined in echo statements | `template/after.sh:3,5` | Quality | WARN — variable will expand to empty string |
| 3 | Uses `${port}` (correct) for actual check but `${app_port}` (undefined) for logging | `template/after.sh:3–5` | Quality | WARN — inconsistency |
| 4 | CORS set to `*` in nginx config | `template/create_nginx_conf.sh.erb:17` | Security | FAIL — OODT-05 Network Exposure, High |
| 5 | MLflow bound to `0.0.0.0:5000` | `template/script.sh.erb:24` | Security | FAIL — OODT-05 Network Exposure, Medium |
| 6 | Hardcoded Singularity image paths (3 locations) | `template/script.sh.erb:4–6`, `template/bin/nginx:2` | Quality | Not portable |
| 7 | Hardcoded CSC environment path | `template/before.sh.erb:2` | Quality | Not portable |
| 8 | Depends on external functions (`find_port`, `create_passwd`, `singularity_wrapper`) | `template/before.sh.erb:4–5`, `template/script.sh.erb:15,20` | Quality | Not portable — requires CSC OOD utilities |
| 9 | Incomplete README (no install/config sections) | `README.md` | Quality | Documentation: Minimal |
| 10 | `tracking_uri` interpolated into server command | `template/script.sh.erb:22` | Security | WARN — user form value reaches command line (low risk since SQLite URI, but worth noting) |

**Key behavior to verify:**

- The skill recognizes the nginx reverse proxy architecture and profiles it
  correctly — nginx + MLflow behind it
- CORS `*` is flagged as a finding, not as a design capability
- The `0.0.0.0` bind is redundant with the nginx proxy (MLflow should bind to
  localhost or a Unix socket) — the skill should catch this
- Portability rating should be "Not portable" — the app cannot function outside
  the CSC environment

---

## 6. curl-pipe-installer

**What it is:** A Batch Connect Jupyter app with on-the-fly Conda environment
setup (inspired by bc_osc_jupyter). The most dangerous fixture — well-written
README, clean structure, valid YAML, but the template script contains critical
security vulnerabilities. Tests whether the skill can see past a polished
exterior.

**Planted defects:**

| # | Defect | File | Expected aspect | Expected finding |
|---|--------|------|-----------------|-----------------|
| 1 | `curl -fsSL <user-url> \| bash` — arbitrary remote code execution | `template/script.sh.erb:26` | Security | FAIL — OODT-01 Arbitrary Code Execution, Critical — user provides the URL via a form field |
| 2 | `eval "pip install <user-packages>"` — command injection via package list | `template/script.sh.erb:15` | Security | FAIL — OODT-01 Arbitrary Code Execution, High — user can inject shell commands as "package names" |
| 3 | `conda activate <user-env-name>` — unquoted user input in shell | `template/script.sh.erb:7` | Security | WARN — OODT-01, Medium — env name with spaces or metacharacters could cause issues |
| 4 | Jupyter auth disabled (`--token=''`, `--password=''`) | `template/script.sh.erb:34–35` | Security | FAIL — OODT-05 Network Exposure, High — any user on the compute node can access the notebook |
| 5 | CORS set to `*` (`--allow_origin='*'`) | `template/script.sh.erb:36` | Security | FAIL — OODT-05 Network Exposure, High |
| 6 | XSRF protection disabled (`--disable_check_xsrf=True`) | `template/script.sh.erb:37` | Security | FAIL — OODT-05 Network Exposure, High |
| 7 | Jupyter bound to `0.0.0.0` | `template/script.sh.erb:32` | Security | FAIL — OODT-05 Network Exposure, Medium |
| 8 | No `set -e` — errors in setup silently ignored | `template/script.sh.erb` | Quality | FAIL — no error handling |
| 9 | Custom PyPI index URL accepted without validation | `form.yml:21–24`, `template/script.sh.erb:19–20` | Security | WARN — OODT-08 Supply Chain, Medium — user can point pip at an arbitrary package index |

**Key behavior to verify:**

- Structure checks mostly PASS — README is "Adequate" or "Strong" (has all
  sections including Known Limitations), LICENSE present, valid YAML
- Security findings dominate — the curl|bash and eval are critical
- The skill should recognize that defects 1 and 2 are **potentially malicious**
  patterns, not just misconfiguration — a form field that feeds `curl|bash` is
  a backdoor by design
- Expected decision: **Reject** — the curl|bash + eval + disabled auth
  combination represents fundamental design issues, not fixable misconfig
- This fixture is the key calibration case: if the skill recommends anything
  less severe than Reject, the security aspect needs tuning

---

## Coverage matrix

Each fixture targets a different combination of aspects and severity levels.
Together they ensure the skill exercises all four aspects and all major OODT
categories.

| Aspect | broken-app | monorepo | vnc-stale | passenger | container | curl-pipe |
|--------|-----------|----------|-----------|-----------|-----------|-----------|
| **Structure** | FAIL (LICENSE, YAML) | FAIL (metadata) | PASS | FAIL (no form) | WARN (ext attrs) | PASS |
| **Security** | High (secret, 0.0.0.0) | PASS | PASS | Critical (injection) | High (CORS, 0.0.0.0) | Critical (curl\|bash, eval) |
| **Quality** | Minimal docs, Not portable | PASS / mixed | Adequate docs, Not portable, copy-paste artifacts | Minimal docs, Not portable | Minimal docs, Not portable | Strong docs, meh quality |
| **Maintenance** | NOT CHECKED | NOT CHECKED | NOT CHECKED | NOT CHECKED | NOT CHECKED | NOT CHECKED |

| OODT Category | Covered by |
|-------------|-----------|
| OODT-01 Arbitrary Code Execution | curl-pipe-installer (curl\|bash, eval), passenger-flask-app (subprocess injection) |
| OODT-02 Credential Exposure | broken-app (committed API key), passenger-flask-app (/tmp tokens) |
| OODT-03 Unauthorized Persistence | (not explicitly planted — stretch goal for future fixtures) |
| OODT-04 Data Exfiltration | (not explicitly planted) |
| OODT-05 Network Exposure | broken-app (0.0.0.0), containerized-server (CORS, 0.0.0.0), curl-pipe-installer (CORS, disabled auth, 0.0.0.0) |
| OODT-06 Isolation Weakening | (not explicitly planted) |
| OODT-07 Resource Abuse | (not explicitly planted) |
| OODT-08 Supply Chain | curl-pipe-installer (custom PyPI index) |

---

## Calibration procedure

1. Run `/appverse-review:review-app` in submitter mode inside each fixture
2. Compare findings against the tables above — every planted defect should appear
3. Check that severity ratings are reasonable (see Expected finding columns)
4. Check that recommended decisions match the Expected decision column
5. If a defect is missed or a decision is wrong, tune the relevant aspect skill
   — not the orchestrator — then re-run

When tuning against real previously-reviewed repos (see the design spec's
calibration section), use these fixtures as regression tests to make sure
calibration changes don't cause the skill to miss known planted defects.
