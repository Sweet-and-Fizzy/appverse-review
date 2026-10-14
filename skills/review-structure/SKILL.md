---
name: review-structure
description: Check an Appverse app repo's structure — required files, required metadata fields, YAML validity, standard OOD layout, broken references. Use for the structure aspect of an Appverse review, or when asked to check an OOD app repo's structure or metadata.
argument-hint: "[github-url]"
---

# Structure Review (aspect)

Criteria: `${CLAUDE_PLUGIN_ROOT}/references/review-rubric.md` — sections
"Repo shapes" and "Structure (gate criteria)". The substantive-README gate is
yours; README depth is review-quality's job.

**Setup:** Use the orchestrator's prepared target if provided; otherwise follow
`${CLAUDE_PLUGIN_ROOT}/references/target-setup.md` first. The orchestrator (or
target-setup.md) names the pre-review directory; if it is absent, every STR-06
record is NOT CHECKED with the note "pre-review facts not found".

## Repo-level checks

- Repository is public and accessible: the clone in setup succeeded. If it did
  not, this is the failed gate to report (see target-setup.md) and no other
  check can run.
- `README.md` exists and is substantive. Substantive is a fact, not your
  judgment: it is `stub` false in the pre-review `readme.json` whose `file`
  is the root `README.md` (`<pre-review>/root/readme.json` for a single-app
  repo). `stub` is true for fewer than 100 characters of content (the
  summed length of its content lines, so hard-wrapping does not change it;
  a title and a contact line have none) or when every section body is
  template placeholder text and there is no real text above the first
  heading.
  Record STR-01 `readme-not-substantive` FAIL when `stub` is true and PASS
  when it is false; with no such `readme.json`, NOT CHECKED with the
  reason.
- `LICENSE` exists and contains an open-source license.
- Repo shape identifiable: `appverse.yml` or `manifest.yml` at root.
- Repo is not archived on GitHub.

## Per-app checks (use the resolved field set from setup)

The per-app checks are the manifest entries with `dimension: structure` in
`${CLAUDE_PLUGIN_ROOT}/references/checks.json` whose `app_types` include the
app's type (`app_type` in `<pre-review>/apps.json`): `str-02-metadata`,
`str-03-yaml-valid`, `str-06-syntax` and `str-07-layout` for Batch Connect,
`entry-point-parses` in place of the last two for Passenger and companion
apps, and `str-04-references`. Every one gets at least one row in the
Structure table with its `` `check: <id>` `` marker, in manifest order: FAIL,
WARN or PASS with evidence, NOT CHECKED with the reason. A check whose fact
file lists candidates (`syntax.json` entries with `ok` false,
`entry_point.json` with `parses` false) must cite each one in a row's
Evidence as `path:N` or the bare path. Finding records use the manifest
entry's `tag` in `defect_key` where it has one; where it is null, the tag
the bullet below names. A FAIL record takes the entry's
`default_severity` (High for every structure check, as a gate failure)
unless the evidence clearly warrants another, and the row summary then
says why. A WARN (an unknown implementation tag, a missing `role`) is not
a gate failure: rate it on the rubric's severity scale. NOT CHECKED and
PASS records are Info. Anything else you notice goes after the checks, as
its own finding with the vocabulary tag that fits or `other:`.

- Required metadata fields for the repo shape, per the rubric's "Repository
  structure" section. For declared repos that includes `description`,
  `software`, `app_type`, `maintainer.name`, and `maintainer.support_url`; a
  missing field is a gate failure (STR-02, `missing-field:<name>`).
- `app_type` and `implementation_tags` are known values. Read the result from
  `<pre-review>/catalog.json` (per app, `checks.app_type` and
  `checks.implementation_tags`, compared with the live vocabularies, ignoring
  case); do not query the catalog yourself. An `app_type` outside the
  published vocabulary is an STR-02 FAIL (the value must be a term from the
  catalog's app_type vocabulary, so a near miss such as a misspelling still
  fails), worded as "not in the published
  vocabulary" (an unpublished term is invisible here); when
  `checks.app_type.closest` lists terms, the summary ends "did you mean
  `<term>`?" naming each, joined with "or"; an unknown
  implementation tag is a WARN. If `catalog.json` is absent
  (the catalog was not read), record the check as NOT CHECKED with that reason.
- Every `manifest.yml`, `appverse.yml`, and `form.yml` parses; report parse
  errors verbatim. A `form.yml.erb` cannot be YAML-parsed directly (unrendered
  ERB is not valid YAML) — check that it exists and has balanced ERB tags
  instead.
- ERB templates look renderable (balanced `<%= %>` tags). STR-06 comes from
  the pre-review facts, never from running `bash -n` yourself: read
  `<pre-review>/syntax.json` and record one STR-06 record per shell file,
  with `defect_key` `<path>:bash-syntax-error`, by these rules in order:
  - `summary.json`'s `syntax` check did not run (status other than `ran`):
    every entry is NOT CHECKED (severity info, evidence `<path>:1` plus the
    check's `note`), except refused symlinks as below.
  - `ok` is true: PASS.
  - `stderr` begins with "symlink outside target" or "dangling symlink": a
    refused symlink. Give it no findings record at all, since check-keys
    resolves the anchor and a symlink leading outside the target or nowhere
    has no valid key; name it only in the STR-06 row summary.
  - `stderr` begins with "not a regular file" (a FIFO or device): NOT
    CHECKED (severity info, evidence `<path>:1` plus the reason).
  - `stderr` begins with "bash <ver> rejected this file" (the bash on PATH
    is older than 4, and the file may use bash 4 syntax such as `;;&`): NOT
    CHECKED (severity info, evidence `<path>:1` plus that stderr text), not
    FAIL.
  - `stderr` is a bash message and `erb_control_line` is a number (the
    failure is within 3 lines of a stripped ERB control tag such as
    `<% else %>` or `<% end %>`; stripping both branches of a conditional
    can leave an orphan line that no rendered template contains): WARN
    (severity low, evidence `<path>:<N>` with the line from stderr, plus
    the first stderr line and "may come from stripping the template (ERB
    control tag at line `<erb_control_line>`); check it"). It is not a
    gate failure; the reviewer reads both branches.
  - `stderr` is a bash message (it starts with the file path followed by
    `: line N:`): FAIL (severity high, evidence `<path>:<N>` using that line
    number, or `<path>:1` when no `line N` is present, plus the first stderr
    line).
  - Anything else (a binary file, a permission error, a timeout, a file too
    large to check): NOT CHECKED (severity info, evidence `<path>:1` plus the
    stderr text).
  The per-app Structure table's STR-06 row summarises them: "N files pass; M fail:
  `<paths>`; W may come from stripping the template: `<paths>`; K not
  checked: `<path>` (`<reason>`)", the row's Result the worst of them, with refused symlinks
  listed among the not-checked paths. Its Evidence column cites every
  entry whose `ok` is false (failed, not checked, or refused), each as
  `path:N` with the line from stderr or as the bare path; one row may cite
  them all.
- No broken references: variables and attributes used in `submit.yml.erb` and
  `template/` files exist in `form.yml` or `form.yml.erb`.
- Batch Connect apps have the standard layout: `form.yml` or `form.yml.erb`,
  `submit.yml.erb`, `template/`. OOD renders `form.yml.erb` at request time,
  so an app shipping only the `.erb` variant is complete.
- Passenger / companion apps — substitute checks for Batch Connect structure.
  Detect by `manifest.yml` role (`passenger_app`) or by the presence of a
  recognized entry point (`config.ru` for Ruby/Rack, `passenger_wsgi.py` for
  Python/WSGI):
  - Entry point exists and parses (`check: entry-point-parses`, STR-07),
    from `<pre-review>/<app_id>/entry_point.json`, never by running an
    interpreter yourself. It has no candidate list; the row keys on its
    fields. `parses` true: PASS, evidence the entry `file`. `parses` false:
    FAIL (severity high), evidence the `file` (and the line from `error`
    when it names one, as `path:N`) plus the first line of `error`,
    `defect_key` `<file>:entry-point-parse-error` (STR-07, not
    `other:entry-point-parse-error`). `parses`
    `"not_checked"` (the interpreter is not on PATH): NOT CHECKED with the
    `note`. When `entry_point.json` is absent, key on
    `summary.json`'s `facts` record for `entry_point`, its `per_app` status
    for this app: `skipped` (no entry point found) is FAIL, STR-07
    `missing-entry-point` (anchor `root`, or the app subpath);
    `not_applicable` means the scanner does not cover this app type, so
    list the app's files, look for the entry point yourself, and make the
    row NOT CHECKED for parsing with that reason; a pre-review directory
    that is absent altogether is NOT CHECKED, "pre-review facts not
    found". The rule is the same for Passenger and companion apps. `consistent` false is a separate STR-08 row and record
    (`<dependency_manifest>:dependency-manifest-inconsistent`, with the
    `note`); `consistent` null means not judged (Ruby, Node, or a Python
    manifest other than `requirements.txt`): read the manifest yourself and
    say so in the row.
  - If `manifest.yml` has a `role` field, it matches the layout (e.g.,
    `passenger_app` with an entry point, not a Batch Connect tree). A missing
    `role` is a WARN, not a FAIL — the app may still work
  - Dependency manifest (`Gemfile.lock`, `package-lock.json`, `requirements.txt`)
    present and consistent with the dependency file (STR-08,
    `dependency-manifest-inconsistent`); `entry_point.json`'s
    `dependency_manifest` and `consistent` are the facts to start from
  - If the repo ships a test suite, note whether it passes. When execution is
    restricted (CI, untrusted repo), report as
    `NOT CHECKED — execution restricted`

## Output

The Structure table (orchestrator template): Rule / Check / Result /
Severity / Summary / Evidence, one row per manifest check with its
`` `check: <id>` `` marker, then any other structure rows without a marker.
Evidence is `path:N`, `path:N-M` or `path:N,M`, never prose.

**Structured findings** per target-setup.md §4: one repo-level set, one per app.
Each finding uses an STR-XX rule code and a `defect_key` from the structure
mechanism-tag vocabulary in
`${CLAUDE_PLUGIN_ROOT}/references/finding-codes.md`.
