---
name: review-quality
description: Quality review of an Appverse app repo — documentation rating, configuration portability, code-quality checklist. Use for the quality aspect of an Appverse review, or when asked to assess an OOD app's documentation or code quality.
argument-hint: "[github-url]"
---

# Quality Review (aspect)

Criteria: `${CLAUDE_PLUGIN_ROOT}/references/review-rubric.md` — sections
"Portability", "Documentation", and "Code Quality", including the
target-for-inclusion thresholds and the named checks (`check: …`) in each.

The checks themselves come from the manifest,
`${CLAUDE_PLUGIN_ROOT}/references/checks.json` (human copy `checks.yml`):
the entries with `dimension` `portability`, `documentation` or
`code_quality` whose `app_types` include the app's type. The manifest is the
list; do not add or drop a check from memory of the rubric.

**Setup:** Use the orchestrator's prepared target if provided; otherwise follow
`${CLAUDE_PLUGIN_ROOT}/references/target-setup.md` first. The pre-review
directory holds `apps.json` (each app's `app_id`, `path`, `app_type`,
`readme`) and, per app, `<app_id>/readme.json`, `form.json` and
`template.json`. `apps.json`'s `app_id` is the same `app_id` a finding
record uses ("root" for a single-app repo, the normalised subpath for a
monorepo app), and the per-app fact directory is `<pre-review>/<app_id>/`. A
fact file is absent when the pre-review directory is absent or the app was
skipped (`summary.json`'s `facts` record says why); then read the files
yourself and say in the row that the facts were absent.

## Per-app loop

For each app, and for each manifest entry above in manifest order:

1. **Read the candidates** from the fact file named by the entry's
   `fact_source` (`none`: there are no candidates, only your reading):

   | Check | Candidates |
   |---|---|
   | `hardcoded-site-paths` | `template.json` `absolute_paths` |
   | `magic-numbers` | `template.json` `numeric_literals` and `hex_colors` |
   | `dead-code` | `template.json` `commented_code` (a block of `count` lines from `line`) |
   | `icon-matches-target-os` | `template.json` `icons`, against the OS the README (`readme.json`) says the app was tested on |
   | `numeric-field-bounds` | `form.json` attributes with `in_form` true, `defined` not false, `reaches_scheduler` true, and no bound: a `number_field` without both `min` and `max`, or a free-text widget (anything but select, radio button, check box, hidden field) without a `pattern` and without both bounds |
   | `erb-missing-value` | `form.json` attributes with `in_form` true, `defined` not false and `interpolated_in_submit` true (at `submit_lines`) |
   | `documentation-rating` | `readme.json` `rungs` (see Documentation below) |

   An attribute with `defined: false` is an OOD built-in or a site mixin
   (`bc_num_hours`); OOD bounds it, so it is not a candidate. `template.json`
   paths are repo-relative; `form.json`'s `file` and `submit_file` are
   app-relative, so prefix the app `path` for a monorepo anchor.
2. **Answer every candidate**: FAIL, WARN or PASS with a one-line reason.
   Judgment stays yours at every candidate: a self-describing timeout
   (`wait_until_port_used "$port" 300`) or a port the README documents is
   PASS with that reason; an OOM score or a panel size
   nobody explains is a finding. Candidates of one check in one file with
   the same result and the same reason may share a row citing each line
   (`path:N,M`); otherwise one row per candidate. Never group candidates
   with different results in one row. A check with no candidates gets one
   row: PASS with evidence. Any defect your own reading finds for a check
   whose `fact_source` names a fact file, whether or not that file listed
   candidates, is recorded as a finding whose row summary says the facts
   step missed it ("not in template.json"); that note is the signal for
   improving the scanner. A `fact_source: none` check has no facts to
   miss, so its rows never carry the note.
3. **Write the rows** in the dimension's table (see Output): Check
   `` `check: <id>` ``, Rule from the manifest, Result, Severity, Summary,
   Evidence citing each candidate the row answers as `path:N`,
   `path:N-M` or `path:N,M`, never prose, with the repo-relative path
   (`template.json` gives it; prefix `form.json`'s app-relative paths with
   the app `path`). A row answers exactly the candidates its
   Evidence cites, so a PASS row must cite every candidate it clears; a
   plain PASS with no citation is only for a check with no candidates.
   Unexaminable is NOT CHECKED with the reason (for example QUA-07 and QUA-10
   when `form.json` has an `error`).
4. **Write the records: one record per file per tag.** `defect_key` is
   `{anchor}:{tag}`, the anchor being the candidate's file, and a key
   appears once per app. `erb-missing-value` (QUA-10 `erb-missing-value-unhandled`)
   anchors on the submit file (`submit.yml.erb`, where `submit_lines` cites
   the interpolation), never on `form.yml`; `numeric-field-bounds`'s QUA-07
   tags anchor on `form.yml` (the candidate's `file`), never on the submit
   file. The tag is fixed, not chosen:

   | Candidate | Tag |
   |---|---|
   | `numeric-field-bounds`: a free-text field without a `pattern` | QUA-07 `missing-pattern` |
   | `numeric-field-bounds`: a `number_field` without `min` and `max` | QUA-07 `missing-min-max` |
   | `magic-numbers`: a `hex_colors` entry | QUA-08 `undocumented-hex-color` |
   | any other candidate | the manifest entry's `tag` |

   The candidates in one file that share a tag share one record, whose
   `evidence` may carry several citations: the FAIL and WARN lines first
   (`path:N,M` plus a short quote), then, after a semicolon, the PASS lines
   in that file as `reviewed OK: path:N,M` (for example
   `template/script.sh.erb:25 port 5000; reviewed OK:
   template/script.sh.erb:9`). A file whose candidates for a check are all
   PASS gets one PASS record for that check, with `evidence` listing every
   PASS line in the file as `path:N,M`. **The record merge rule:** when
   several candidates merge into one record this way, the record's
   `result` is the worst among them (FAIL > WARN > PASS) and its `severity`
   the highest; the report's rows stay per candidate regardless. A check
   with no candidates that
   passes gets one PASS record keyed on the file it examined (the form file
   for the form checks, the main template script otherwise, or `root` / the
   app subpath when no single file fits) with the manifest tag. The two
   rating checks (manifest tag null) get no record of their own: the
   assessments block carries a rating that meets its target, and below
   target see "What each check asks".

After the loop, the **open-ended pass**: anything else worth fixing that no
check above covers, recorded as its own finding with `file:line` evidence,
under the vocabulary tag where one fits and `other:{short-description}`
otherwise. **Correctness & polish** defects belong here: copy-paste
artifacts from a template the app was cloned from (e.g. a MATLAB reference
left in a SAS app's `form.yml`, a CHANGELOG describing a different app),
duplicate YAML keys (valid YAML but last-wins, so `form.yml`/`manifest.yml`
parsing does not catch them), broken or wrong help text, and README typos.
These rows carry no `check:` marker.

## What each check asks

- **Configuration portability** (`check: hardcoded-site-paths`,
  `check: portability-rating`): each `absolute_paths` candidate is WARN
  (QUA-02 `hardcoded-path`) unless it is documented in the README's
  configuration table or comes from a form attribute, which is PASS citing
  where. Also read `submit.yml.erb`, `form.yml`, `form.yml.erb`, and
  `template/` scripts for cluster names, partitions, accounts and module
  versions, which the facts do not enumerate; each is a
  `hardcoded-site-paths` row with the tag that names it
  (`hardcoded-cluster`, `hardcoded-partition`, `hardcoded-account`,
  `hardcoded-module-version`, `site-specific-mixin`) and the missed-by-facts
  note. Then rate Not portable / Partially portable / Portable in the
  `portability-rating` row: PASS when Partially portable or above, FAIL
  below. A FAIL row cites the `hardcoded-*` records that set it and adds
  no record of its own. Documented site-specific
  values count toward Partially portable; undocumented ones count against
  it.
- **Documentation** (`check: documentation-rating`): rate Minimal /
  Adequate / Strong / Exemplary against the rubric's Documentation table and
  its four README questions. Before rating, write one evidence line per rung
  requirement (what it launches, prerequisites, installation,
  configuration, known limitations, troubleshooting, screenshots,
  environment variables, info panel, architecture) from `readme.json`:
  - A rung `readme.json` maps to a heading: the heading text and its line,
    `"Installation", README.md:12` (the README path from `apps.json`).
  - What it launches, when `readme.json` shows no Overview-type heading for
    it: a descriptive paragraph under the H1 satisfies it (`readme.json`
    records it with `match: "intro"`), cited as
    `"<first words>" (intro), README.md:N`.
  - A rung that is `null`: `none`.
  - A rung whose `placeholder` is true: `none (placeholder)`, whatever the
    heading says.
  - Screenshots and environment variables also have content lists.
    An image link in `screenshots`, or an `assignment` or `phrase` entry in
    `env_vars`, is the evidence to cite (`README.md:N`). A rung whose only
    evidence is its heading, with no such content entry, is weaker: write
    `"Screenshots", README.md:40, heading only`, read the section, and write
    `none (heading only)` if it does not deliver what the rung asks.
  You may argue a section does not really satisfy its rung, and write
  `none` with the reason; you may never claim a rung `readme.json` shows no
  heading or content entry for. Rungs are cumulative: the rating is the
  highest rung whose requirements, and every lower rung's, all have
  evidence; never claim a rung with a `none` line. The
  `documentation-rating` row is PASS at Adequate or above and FAIL below,
  with a QUA-01 record (`docs-minimal`, anchored at the README path, its
  evidence citing `README.md:N`). When even Minimal is unsupported (no
  what-it-launches or no prerequisites evidence), the README is a stub:
  that is the Structure gate failure, recorded as QUA-01 `docs-stub`, and
  the rating line reads `Minimal — not supported (stub README; see
  QUA-01)`. `check-rating.py` accepts that report as long as a QUA-01
  `docs-stub` FAIL record is present. Flag
  as QUA-01 a README that references another institution's paths, cluster
  names, or module names without saying they must change.
- **Code quality** (the `code_quality` entries): error handling
  (`check: error-handling`, QUA-03: `set -e` or explicit checks), form input
  validation (`check: numeric-field-bounds`, QUA-07), no uncommented magic
  numbers / undocumented literals (`check: magic-numbers`, QUA-08), no large
  duplicated blocks (`check: duplicated-blocks`, QUA-09), no commented-out
  dead code (`check: dead-code`, QUA-04), ERB templates handle missing or
  empty values gracefully (`check: erb-missing-value`, QUA-10: an unguarded
  interpolation is `erb-missing-value-unhandled`), desktop/panel icon exists
  on the README's target OS (`check: icon-matches-target-os`, QUA-06
  `icon-os-mismatch`). A blank form field arrives as `nil` (YAML null), not
  an empty string; `.to_s` turns it into `""`. An unguarded `<%= context.x
  %>` therefore writes nothing (or `nil` under `.inspect`) into the YAML,
  which is why a guard or default is needed.

  An unmet target for inclusion — error handling, input validation — is
  recorded as FAIL, not WARN; suggestions that are unmet are WARN. The
  rubric's Code Quality section says which of these are
  targets for inclusion and which are improvement suggestions — weight each
  finding the way the rubric frames it, rather than applying your own
  severity scale, and keep the labels consistent with findings you record
  elsewhere in the review.

  **Magic numbers / undocumented literals** — the facts list bare integers
  and hex colours in template files; judge each. Also look beyond them. In
  OOD apps, undocumented hardcoded values commonly appear as:
  - Resource limits and tunables: OOM score adjustments, timeouts, memory
    limits, CPU counts (e.g., `echo 1000 > /proc/self/oom_score_adj`)
  - UI/desktop config: hex colors, resolution strings, panel sizes in Xfce/VNC
    configs
  - Ports and network addresses (especially when not the obvious default)
  - Module versions without a comment explaining why that version
  - Scheduler parameters: partition names, QOS values, walltime limits

  A hardcoded value is fine when it is the obvious default or is explained by
  its context (a `sleep 1` needs no comment). Flag values that a deployer at
  another site would need to understand or change, and that have no inline
  comment or README documentation explaining them.

## Output

Per app, in the orchestrator's template order: the Portability table, the
Documentation rating with its evidence lines and table, and the Code
Quality table, each row carrying its `check:` marker, then the open-ended
rows; then **structured findings** per target-setup.md §4 covering every
FAIL/WARN row and the PASS records. Each finding uses a QUA-XX rule code and
a `defect_key` from the quality mechanism-tag vocabulary in
`${CLAUDE_PLUGIN_ROOT}/references/finding-codes.md`.

Result values are exactly FAIL, WARN, PASS, NOT CHECKED; "Info" is a severity, never a result.

Note which target-for-inclusion thresholds (Adequate+ docs, Partially portable+)
are not met — as findings (QUA-01 / QUA-02), not decisions.

Then one **assessments block** per app, as a fenced JSON block:

```json
{
  "app_id": "<app_id>",
  "assessments": {
    "documentation": "minimal | adequate | strong | exemplary",
    "documentation_summary": "<the one-line justification>",
    "portability": "not_portable | partially_portable | portable",
    "portability_summary": "<the one-line justification>"
  }
}
```

These are the two ratings above restated — same rating, same justification.
The block exists because a rating that meets its target produces no finding, so
the findings array alone cannot tell Strong from Adequate. Field definitions:
`${CLAUDE_PLUGIN_ROOT}/references/artifact-envelope.md` ("Indicator inputs").
