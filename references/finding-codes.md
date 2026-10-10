# Finding Codes and Stable Identity

Rule codes and defect-key vocabularies for structured findings with stable,
position-independent IDs. Every finding from every aspect gets a rule code;
together with `app_id` and `defect_key`, this produces a stable ID that
survives line shifts, LLM rewording, and aspect reclassification.

## Severity levels

`critical` · `high` · `medium` · `low` · `info`

- **Critical** — unfixable without redesigning the feature, or tagged
  potentially malicious. Reserved for findings that warrant a Reject
  recommendation (e.g., `curl|bash` on user-supplied URLs, arbitrary code
  execution by design).
- **High** — a real vulnerability or gate-criterion failure, fixable with
  targeted changes. Warrants Request changes.
- **Medium** — a genuine concern but lower blast radius or harder to exploit.
- **Low** — defensive-coding gap or minor hygiene issue.
- **Info** — maintenance signals, suggestions, positive observations.

## Stable finding ID

```
id = sha256("root\0OODT-05\0template/script.sh.erb:bind-all-interfaces")[:16]
                ↑        ↑
          NUL separator  NUL separator
```

The input is the three identity fields joined by NUL (`\0`) bytes, preventing
collisions from field-boundary ambiguity. The output is the **first 16 hex
characters** (64 bits) of the SHA-256 digest — unique within one review, never
globally.

**The review skill does not compute IDs.** It emits the three identity fields
(`app_id`, `rule`, `defect_key`) in each finding record. The `id` is computed
by `compute-ids.py` (in this directory) or by the Drupal ingestion layer. This
keeps the LLM out of cryptographic computation it cannot do reliably.

```bash
python3 references/compute-ids.py < findings.json > findings-with-ids.json
```

| Component | In hash | Why |
|---|---|---|
| `app_id` | **Yes** | `"root"` for single-app repos, subpath for monorepos |
| `rule` | **Yes** | Canonicalized code from the tables below |
| `defect_key` | **Yes** | `{anchor}:{mechanism_tag}` — see below |
| `aspect` | No | Findings move between aspects during calibration |
| `line` | No | Shifts on every edit |
| `summary` | No | LLM rewording across runs |
| `severity` | No | Calibration shifts across runs |

### Defect key

```
defect_key = "{anchor}:{mechanism_tag}"
```

- **`anchor`**: the file or resource the finding is about — deterministic,
  shifts only on renames. For findings in existing files, this is the
  repo-relative path (e.g., `template/script.sh.erb`). Anchors are always
  relative to the repo root, never to the app: in a monorepo the anchor
  includes the app subpath (`app_id` `apps/good-app` →
  `apps/good-app/form.yml:missing-min`, not `form.yml:missing-min`).
  For findings about absent files or repo-level resources, the anchor is
  fixed: see the absent-file tag → anchor pairs and the pseudo-anchor list
  under Edge cases below.
- **`mechanism_tag`**: selected from the vocabulary for the finding's rule code
  (see tables below). Novel findings not in the vocabulary use
  `other:{short-description}`; recurring novel tags get promoted to the
  vocabulary. **Watch `other:` as a drift source** — two runs may pick
  different `other:` tags for the same defect, producing different IDs.
  When reviewing findings with `other:` tags, check whether an existing
  vocabulary term fits; if a novel tag recurs across reviews, promote it
  to the vocabulary.
- **Enumerated candidates.** A finding on a candidate the pre-review facts
  list (a `security.json`, `form.json` or `template.json` entry) takes its
  tag from the checks manifest (`references/checks.yml`): the `tag` of the
  entry whose `check` the candidate answers, with the candidate's file as
  the anchor. Those manifest tags are all in the vocabularies below, so two
  runs that record the same candidate produce the same key. A security
  candidate that carries its own `tag` (the scanner's more exact term under
  the same threat, such as `curl-pipe-exec` or `cors-wildcard`) uses that
  one instead. The only other exceptions are fixed: a `form.json` free-text
  field without a `pattern` is QUA-07 `missing-pattern`, a `number_field`
  with neither `min` nor `required` is QUA-07 `missing-min`, and a
  `template.json` `hex_colors` entry is QUA-08 `undocumented-hex-color`.
  Where the manifest tag is null, the aspect skill names the tag. One
  record per file per tag: candidates sharing a file and a tag share one
  record, whose `evidence` may carry several citations
  (`path:22; reviewed OK: path:9,23`).
- **Qualified tags.** Where the vocabulary shows a `{qualifier}` (e.g.
  `duplicate-yaml-key:{key_name}`, `readme-inconsistency:{topic}`), the
  qualifier is required and is the full dotted attribute path or the topic
  word or hyphenated phrase (e.g. `testing-table`), lower-case;
  `duplicate-yaml-key:custom_num_cores.help`, never
  `duplicate-yaml-key:help`. For tags with a `{qualifier}`, two defects of
  that kind in one file produce two distinct keys; tags without a qualifier
  keep the existing rule (one finding per file per mechanism, with multiple
  evidence locations).

### Edge cases

- **File renames** break the ID. Rare, arguably correct. Accept the break.
- **Same mechanism in multiple files** produces different IDs. Correct behavior.
- **Multiple findings with the same mechanism in one file** (e.g., 7 unquoted
  variables in `script.sh.erb`): treat as one finding with multiple evidence
  locations. `line` is mutable metadata carrying the list.
- **Absent-file and repo-level findings** use a fixed anchor, never a
  free-text one. `check-keys.py` enforces both lists below.
  - Absent-file tags (STR-01, STR-07, MNT-03) take this expected anchor,
    whether or not the file exists: `missing-manifest` → `manifest.yml`,
    `missing-appverse-yml` → `appverse.yml`, `missing-form` → `form.yml`,
    `missing-template-dir` → `template`, `missing-submit-yml` →
    `submit.yml.erb`, `no-changelog` → `CHANGELOG.md`. `missing-entry-point`
    → `root` (the app subpath in a monorepo), whichever Batch Connect or
    Passenger entry point the app lacks. In a monorepo
    (`app_id` not `root`) the app subpath prefix is required:
    `apps/bad-app/form.yml:missing-form`, never the bare
    `form.yml:missing-form`; `missing-entry-point` instead takes the app
    subpath alone, `apps/bad-app:missing-entry-point`. Any other anchor with
    one of these tags is invalid.
  - Repo-level findings use a pseudo-anchor. The allowed set is exactly:
    `LICENSE`, `README.md`, `CHANGELOG.md`, `.github/workflows`,
    `releases`, `issues`, `contributors`, `commits`, `root`. Case-sensitive:
    `RELEASES` and `github/commits` are invalid. `missing-license` and
    `missing-readme` use `LICENSE` and `README.md` from this set, or the path
    of an insufficient file that exists under another name (`LICENSE.txt`).
    `missing-readme` is repo-level only, even in a monorepo: a per-app README
    is never a finding on its own, since a subpath app falls back to the root
    README and the Documentation rating covers what it lacks, so the anchor
    is always the bare `README.md`, never `<app_id>/README.md`.
  - Anything else must be a repo-relative path that exists in the reviewed
    tree.
- **Prior finding disappears but code unchanged**: flag as "prior finding not
  reproduced — verify manually" rather than auto-marking "fixed."

---

## Security — OODT codes

Security uses the existing OODT-01..08 taxonomy from
the Security section of `review-rubric.md`. Canonicalize any legacy OAT-XX references to
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
`unexpected-network-call`, `data-to-external-server`, `binary-in-template`

**OODT-05:**
`bind-all-interfaces`, `cors-wildcard`, `disabled-auth`,
`disabled-xsrf`, `unescaped-output-html`, `unescaped-output-javascript`,
`token-in-process-list`, `cdn-without-sri`, `partial-auth-coverage`

`bind-all-interfaces` names a service bound to a non-loopback interface
(`0.0.0.0`, `::`, `INADDR_ANY`) that answers without authentication. OOD's
node proxy (`/node/`, `/rnode/`) reaches the service on the compute node, so
the bind alone is not exposure: a bind whose service requires a password or
token (OOD's per-session `password`, a `--NotebookApp.token=<%= password %>`,
a proxy in front that checks a cookie and no direct port) is PASS.

**OODT-06:**
`missing-cleanenv`, `fakeroot-misuse`, `privileged-container`,
`host-path-mount`

**OODT-07:**
`dotfile-write`, `cron-install`, `ssh-key-write`, `path-injection`,
`write-outside-job`

**OODT-08:**
`debug-tracing-enabled`, `overly-broad-permissions`, `disabled-ssl`,
`default-password`, `framework-protection-disabled`,
`dns-rebinding-relaxed`, `supply-chain-untrusted-index`

---

## Structure — STR codes

| Code | Criterion |
|---|---|
| STR-01 | Missing or insufficient required file (`LICENSE`, `README.md`, `manifest.yml`, `appverse.yml`) |
| STR-02 | Missing or invalid required metadata field |
| STR-03 | YAML parse error |
| STR-04 | Broken reference (variable, attribute, or module not defined where expected) |
| STR-05 | Unbalanced or malformed ERB tags |
| STR-06 | Shell script syntax error (`bash -n` failure) |
| STR-07 | Non-standard app layout (missing expected directories or entry point) |
| STR-08 | Passenger dependency manifest missing or inconsistent with the dependency file |

### Mechanism tags — structure

**STR-01:**
`missing-license`, `missing-readme`, `readme-not-substantive`,
`missing-manifest`, `missing-appverse-yml`, `missing-form`,
`missing-template-dir`

**STR-02:**
`missing-field:{field_name}` (e.g., `missing-field:software`,
`missing-field:app_type`, `missing-field:role`,
`missing-field:maintainer.support_url`)

**STR-03:**
`yaml-parse-error`

**STR-04:**
`undefined-variable:{var_name}`, `undefined-attribute:{attr_name}`,
`form-submit-mismatch`

**STR-05:**
`unbalanced-erb-tags`

**STR-06:**
`bash-syntax-error`

STR-06 is recorded for every shell file, with result PASS, FAIL, WARN or
NOT CHECKED, so the gate can distinguish "all scripts parse" from "not checked".
A refused file (see `syntax.json`'s `stderr`) was never syntax-checked and is
never FAIL. A refused symlink, whether it leads outside the target or
nowhere, gets no findings record at all, because check-keys resolves the
anchor and such a path has no valid key; it is named only in the STR-06 row
summary. A FIFO or device is NOT CHECKED. An entry that is not ok and whose
`stderr` is neither a bash `line N` message nor a refusal reason (a binary
file, a permission error, a timeout, an oversized file) is NOT CHECKED with
the stderr text as evidence. A bash failure in a `.sh.erb` whose
`syntax.json` entry has an `erb_control_line` (within 3 lines of a stripped
ERB control tag) is WARN low, not FAIL: stripping both branches of an
`<% if %>/<% else %>` can leave an orphan line no rendered template has.

**STR-07:**
`missing-entry-point`, `missing-submit-yml`, `layout-mismatch`,
`entry-point-parse-error`

**STR-08:**
`dependency-manifest-inconsistent`

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
| QUA-09 | Large duplicated code block |
| QUA-10 | ERB template does not handle a missing or nil value |

### Mechanism tags — quality

**QUA-01:**
`docs-minimal`, `docs-stub`, `missing-section:{section_name}`

**QUA-02:**
`hardcoded-path`, `hardcoded-cluster`, `hardcoded-module-version`,
`hardcoded-account`, `hardcoded-partition`, `site-specific-mixin`

**QUA-03:**
`no-error-check`, `no-set-e`

`no-error-check` is the QUA-03 tag: a command whose failure matters runs
unchecked. `no-set-e` is kept so records filed before 2026-10 still
validate; a missing `set -e` alone is not a finding, so do not use it for
new findings.

**QUA-04:**
`unused-attribute:{attr_name}`, `dead-branch`, `commented-out-code`,
`unreachable-lookup-entry`

**QUA-05:**
`wrong-app-reference`, `template-placeholder`, `wrong-app-changelog`

**QUA-06:**
`duplicate-yaml-key:{key_name}`, `wrong-help-text`,
`incorrect-default`, `readme-inconsistency:{topic}`, `readme-typo`, `icon-os-mismatch`

**QUA-07:**
`missing-min`, `missing-required`, `zero-minimum`, `missing-pattern`, `missing-min-max`

`missing-min` is a numeric field with neither a `min` nor `required`.
`missing-min-max` is kept so records filed before 2026-10 still validate;
a missing `max` alone is not a finding (a `max` is site policy and may come
from site config), so do not use it for new findings.

**QUA-08:**
`magic-number`, `undocumented-resource-limit`, `undocumented-hex-color`

**QUA-09:**
`duplicated-block`

**QUA-10:**
`erb-missing-value-unhandled`

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
