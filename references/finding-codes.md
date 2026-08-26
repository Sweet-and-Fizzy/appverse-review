# Finding Codes and Stable Identity

Rule codes and defect-key vocabularies for structured findings with stable,
position-independent IDs. Every finding from every aspect gets a rule code;
together with `app_id` and `defect_key`, this produces a stable ID that
survives line shifts, LLM rewording, and aspect reclassification.

## Stable finding ID

```
id = sha256(app_id + rule + defect_key)[:16]
```

| Component | In hash | Why |
|---|---|---|
| `app_id` | **Yes** | `"root"` for single-app repos, subpath for monorepos |
| `rule` | **Yes** | Canonicalized code from the tables below |
| `defect_key` | **Yes** | `{primary_file}:{mechanism_tag}` — see vocabularies |
| `aspect` | No | Findings move between aspects during calibration |
| `line` | No | Shifts on every edit |
| `summary` | No | LLM rewording across runs |
| `severity` | No | Calibration shifts across runs |

### Defect key

```
defect_key = "{primary_file}:{mechanism_tag}"
```

- **`primary_file`**: the file where the finding is anchored — deterministic,
  shifts only on file renames
- **`mechanism_tag`**: selected from the vocabulary for the finding's rule code
  (see tables below). Novel findings not in the vocabulary use
  `other:{short-description}`; recurring novel tags get promoted to the
  vocabulary

### Edge cases

- **File renames** break the ID. Rare, arguably correct. Accept the break.
- **Same mechanism in multiple files** produces different IDs. Correct behavior.
- **Multiple findings with the same mechanism in one file** (e.g., 7 unquoted
  variables in `script.sh.erb`): treat as one finding with multiple evidence
  locations. `line` is mutable metadata carrying the list.
- **Prior finding disappears but code unchanged**: flag as "prior finding not
  reproduced — verify manually" rather than auto-marking "fixed."

---

## Security — OODT codes

Security uses the existing OODT-01..08 taxonomy from
`security-rubric.md`. Canonicalize any legacy OAT-XX references to
OODT-XX before hashing.

| Code | Threat |
|---|---|
| OODT-01 | Shell Injection / Arbitrary Code Execution |
| OODT-02 | Credential Exposure |
| OODT-03 | Unauthorized Access |
| OODT-04 | Data Exfiltration |
| OODT-05 | Network Exposure |
| OODT-06 | Container Security |
| OODT-07 | Persistence |
| OODT-08 | Insecure Configuration |

### Mechanism tags — security

**OODT-01:**
`unsanitized-user-input`, `unquoted-variable`, `eval-exec`,
`command-injection`, `curl-pipe-exec`

**OODT-02:**
`hardcoded-credential`, `credential-file-predictable-path`,
`token-cli-visible`, `token-in-url`, `secret-in-log`

**OODT-03:**
`permissive-file-mode`, `path-traversal`, `other-user-files`

**OODT-04:**
`unexpected-network-call`, `data-to-external-server`

**OODT-05:**
`bind-all-interfaces`, `cors-wildcard`, `disabled-auth`,
`disabled-xsrf`, `unescaped-output-html`, `unescaped-output-javascript`,
`token-in-process-list`, `cdn-without-sri`

**OODT-06:**
`missing-cleanenv`, `fakeroot-misuse`, `privileged-container`,
`host-path-mount`

**OODT-07:**
`dotfile-write`, `cron-install`, `ssh-key-write`, `path-injection`

**OODT-08:**
`debug-tracing-enabled`, `overly-broad-permissions`, `disabled-ssl`,
`default-password`, `framework-protection-disabled`,
`dns-rebinding-relaxed`, `supply-chain-untrusted-index`

---

## Structure — STR codes

| Code | Criterion |
|---|---|
| STR-01 | Missing required file (`LICENSE`, `README.md`, `manifest.yml`, `appverse.yml`) |
| STR-02 | Missing or invalid required metadata field |
| STR-03 | YAML parse error |
| STR-04 | Broken reference (variable, attribute, or module not defined where expected) |
| STR-05 | Unbalanced or malformed ERB tags |
| STR-06 | Shell script syntax error (`bash -n` failure) |
| STR-07 | Non-standard app layout (missing expected directories or entry point) |

### Mechanism tags — structure

**STR-01:**
`missing-license`, `missing-readme`, `missing-manifest`,
`missing-appverse-yml`, `missing-form`, `missing-template-dir`

**STR-02:**
`missing-field:{field_name}` (e.g., `missing-field:software`,
`missing-field:app_type`, `missing-field:role`)

**STR-03:**
`yaml-parse-error`

**STR-04:**
`undefined-variable:{var_name}`, `undefined-attribute:{attr_name}`,
`form-submit-mismatch`

**STR-05:**
`unbalanced-erb-tags`

**STR-06:**
`bash-syntax-error`

**STR-07:**
`missing-entry-point`, `missing-submit-yml`, `layout-mismatch`

---

## Quality — QUA codes

| Code | Criterion |
|---|---|
| QUA-01 | Documentation below threshold |
| QUA-02 | Portability below threshold |
| QUA-03 | Missing error handling |
| QUA-04 | Dead code (unused attributes, commented-out blocks, unreachable branches) |
| QUA-05 | Copy-paste artifact (wrong-app reference, template placeholder left in) |
| QUA-06 | Correctness defect (duplicate YAML key, broken help text, wrong value) |
| QUA-07 | Missing input validation |
| QUA-08 | Magic number or undocumented literal |

### Mechanism tags — quality

**QUA-01:**
`docs-minimal`, `docs-stub`, `missing-section:{section_name}`

**QUA-02:**
`hardcoded-path`, `hardcoded-cluster`, `hardcoded-module-version`,
`hardcoded-account`, `hardcoded-partition`, `site-specific-mixin`

**QUA-03:**
`no-set-e`, `no-error-check`

**QUA-04:**
`unused-attribute:{attr_name}`, `dead-branch`, `commented-out-code`,
`unreachable-lookup-entry`

**QUA-05:**
`wrong-app-reference`, `template-placeholder`, `wrong-app-changelog`

**QUA-06:**
`duplicate-yaml-key:{key_name}`, `wrong-help-text`,
`incorrect-default`, `readme-inconsistency`

**QUA-07:**
`missing-min-max`, `missing-required`, `zero-minimum`

**QUA-08:**
`magic-number`, `undocumented-resource-limit`, `undocumented-hex-color`

---

## Maintenance — MNT codes

| Code | Criterion |
|---|---|
| MNT-01 | Activity below threshold (last commit > 12 months) |
| MNT-02 | No tagged releases |
| MNT-03 | No CHANGELOG |
| MNT-04 | No CI configuration |
| MNT-05 | Single contributor with no recent activity |
| MNT-06 | Open issues with no response |

### Mechanism tags — maintenance

**MNT-01:**
`stale-repo`

**MNT-02:**
`no-releases`

**MNT-03:**
`no-changelog`

**MNT-04:**
`no-ci`

**MNT-05:**
`single-contributor`

**MNT-06:**
`unresponsive-issues`
