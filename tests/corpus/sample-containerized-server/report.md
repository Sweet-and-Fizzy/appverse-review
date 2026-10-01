# Appverse Review: containerized-server

**Repository:** tests/fixtures/containerized-server  **Mode:** submitter  **Date:** 2026-09-30

## App: MLflow Tracking Server (root)

### Signals

| Dimension | Level | Evidence |
|---|---|---|
| Portability | High | /appl site paths throughout template/ |
| Documentation | High | Requirements only |

### Structure
| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| STR-02 | `check: str-02-metadata` | PASS | info | Required metadata fields present | manifest.yml:1 |
| STR-03 | `check: str-03-yaml-valid` | PASS | info | YAML validity | manifest.yml:1 |
| STR-06 | `check: str-06-syntax` | PASS | info | Template scripts syntactically correct: 4 files pass | template/script.sh.erb:1 |
| STR-07 | `check: str-07-layout` | PASS | info | Standard OOD structure | submit.yml.erb:1 |
| STR-04 | `check: str-04-references` | PASS | info | No broken references | submit.yml.erb:7 |

### Security

#### Findings

| Rule | Check | Result | Severity | Tag | Summary | Evidence |
|---|---|---|---|---|---|---|
| OODT-01 | `check: sec-interpolation` | PASS | info | — | csc_cores is a site-mixin field quoted as one scheduler argument | submit.yml.erb:7 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | csc_time quoted as one scheduler argument | submit.yml.erb:9 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | csc_memory quoted inside --mem | submit.yml.erb:10 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | csc_nvme guarded by to_i > 0 and quoted | submit.yml.erb:12 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | mlflow_version is a select whose options the app defines | template/script.sh.erb:9 |
| OODT-01 | `check: sec-interpolation` | WARN | low | unintentional | tracking_uri free text reaches the mlflow command line; quoted, but no pattern | template/script.sh.erb:22 |
| OODT-01 | `check: sec-interpolation` | PASS | info | — | artifact_root from a path selector, quoted | template/script.sh.erb:23 |
| OODT-05 | `check: sec-config-flag` | FAIL | high | unintentional | nginx sends Access-Control-Allow-Origin * | template/create_nginx_conf.sh.erb:17 |
| OODT-05 | `check: sec-config-flag` | FAIL | medium | unintentional | MLflow bound to 0.0.0.0:5000, reachable by other users on the node | template/script.sh.erb:24 |

#### Additional observations (review)

No findings.

**Capability profile:** runs nginx and MLflow in Singularity containers; no network calls out, no writes outside the job directory.

### Portability
- Rating: Not portable — /appl paths in three template files, none documented

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | CSC environment profile path | template/before.sh.erb:2 |
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | /appl/opt/ood binary path | template/bin/nginx:2 |
| QUA-02 | `check: hardcoded-site-paths` | WARN | low | /appl/opt/ood image and patch paths | template/script.sh.erb:4-6 |
| QUA-02 | `check: portability-rating` | FAIL | low | Not portable, below Partially portable; set by the hardcoded-path records | template/before.sh.erb:2; template/bin/nginx:2; template/script.sh.erb:4-6 |

### Documentation
- Rating: Minimal — intro and Requirements only; no installation or configuration
- Evidence per rung (from readme.json rungs; a placeholder heading counts as none):
  what it launches: "Run MLflow's experiment tracking UI" (intro), README.md:3; prerequisites: "Requirements", README.md:5; installation: none;
  configuration: none; known limitations: none;
  troubleshooting: none; screenshots: none; environment variables: none;
  info panel: none; architecture: none

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| QUA-01 | `check: documentation-rating` | FAIL | low | Minimal, below Adequate | README.md:5 |

### Code Quality

| Rule | Check | Result | Severity | Summary | Evidence |
|---|---|---|---|---|---|
| QUA-03 | `check: error-handling` | PASS | info | set -e in the job script | template/script.sh.erb:2 |
| QUA-07 | `check: numeric-field-bounds` | PASS | info | No unbounded field reaches the scheduler; the csc_ fields are site-mixin built-ins | form.yml.erb:6 |
| QUA-08 | `check: magic-numbers` | PASS | info | 300 s is the wait_until_port_used timeout, self-describing | template/after.sh:4 |
| QUA-08 | `check: magic-numbers` | WARN | low | worker_connections 128 unexplained | template/create_nginx_conf.sh.erb:4 |
| QUA-08 | `check: magic-numbers` | PASS | info | 403 is the HTTP status for a bad cookie and needs no comment | template/create_nginx_conf.sh.erb:11 |
| QUA-08 | `check: magic-numbers` | WARN | low | MLflow port 5000 hardcoded instead of the OOD-assigned port | template/script.sh.erb:25 |
| QUA-09 | `check: duplicated-blocks` | PASS | info | No duplicated blocks | template/script.sh.erb:15-25 |
| QUA-04 | `check: dead-code` | PASS | info | No commented-out code | template/script.sh.erb:1 |
| QUA-10 | `check: erb-missing-value` | PASS | info | Only csc_nvme is conditional and it is guarded | submit.yml.erb:11 |
| QUA-06 | `check: icon-matches-target-os` | PASS | info | No desktop or panel icon in template/ | template/script.sh.erb:1 |
