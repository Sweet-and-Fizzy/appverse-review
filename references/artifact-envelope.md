# Review Artifact Envelope

The review artifact is the single data contract the plugin emits — the seam
between the plugin and every consumer (solo dev, CI, Drupal catalog). It is
Drupal-agnostic: the plugin never knows a catalog exists.

## How it's produced

The orchestrator (`review-app/SKILL.md`) emits three files:

| File | Producer | Contents |
|---|---|---|
| `review-<slug>.md` | Orchestrator (LLM) | Human-readable Markdown report |
| `review-<slug>.findings.json` | Aspect skills (LLM) | Structured finding records |
| `review-<slug>.meta.json` | Orchestrator (LLM) | Review context, recommendation, and indicator inputs |

Scripts then process these:

| Script | Input | Output |
|---|---|---|
| `compute-ids.py` | findings JSON | findings JSON with stable `id` fields |
| `assemble-artifact.py` | meta JSON + findings JSON + file paths | **artifact JSON** (this contract) |
| `check-feedback-floor.py` | findings JSON + report MD | exit status: every Low+ fix-item named in the Draft Feedback (key in `feedback-covers`, file or repo-wide subject named, defect described in the sentence window) |
| `check-keys.py` | findings JSON (+ target checkout) | exit status: every `defect_key` is `{anchor}:{tag}` with a real or allowed anchor and a vocabulary tag, and a FAIL/WARN record whose evidence cites files cites its anchor file |
| `check-rating.py` | report MD + findings JSON + pre-review dir | exit status: the rating follows its evidence lines (a ceiling) and the Documentation signal follows the rating; no `content:` line serves two rungs; `Below minimal` needs a QUA-01 `docs-minimal` FAIL record and a README that is not a stub; the stub-README line needs a QUA-01 `docs-stub` FAIL record and `readme.json` `stub` true (with no stub fact, a STR-01 `readme-not-substantive` FAIL record); no suggestion-class check or MNT-02..06 signal is FAIL; the no-tool-detectable-issues sentence never sits under a FAIL/WARN Security row; the repo-level gate table's STR-01 README row is FAIL iff `readme.json`'s `stub` is true; exit 2 when `checks.json` cannot be read |
| `compare-runs.py` | findings JSON + report MD + pre-review facts, two or more runs | pairwise Jaccard of fix-item keys, and a per-candidate table: each run's verdict (F/W/P/- with severity) from the report row of the candidate's check, recorded (FAIL or WARN) in n of N, answered in n of N; Jaccard only when no run has fact files |
| `check-rows.py` | report MD + findings JSON + checks JSON + pre-review dir | exit status: every applicable manifest check has a row, and every pre-review candidate is cited (`MISSING`/`UNCITED` lines) |
| `check-evidence.py` | findings JSON (+ target checkout, report MD, pre-review dir) | exit status: every finding's `file:line` evidence citation names a real file and an in-range line (`BAD` lines), and every `content: README.md:N` citation names a README content line; a literal value the summary asserts but the cited line lacks is a `NOTE` line that does not change the exit status |
| `check-all.py` | report MD + findings JSON + checks JSON + pre-review dir + target checkout | runs the five checkers above in one pass, each block prefixed with its name; exit 1 when any failed or the report lacks a section a checker needs, 2 when any could not run or crashed |

The LLM produces the judgment; the scripts produce the structure.

## Indicator inputs (meta.json)

`assemble-artifact.py` derives indicator levels from the findings plus three
inputs the orchestrator writes into `meta.json`. These shapes are canonical —
the skills that produce them refer here.

```json
{
  "apps": [
    {
      "app_id": "root | <subpath>",
      "name": "App Name",
      "decision": "Accept | Accept with suggestions | Request changes | Reject",
      "assessments": {
        "documentation": "minimal | adequate | strong | exemplary",
        "documentation_summary": "one-line evidence phrase",
        "portability": "not_portable | partially_portable | portable",
        "portability_summary": "one-line evidence phrase"
      },
      "reported_signals": {
        "portability": "Low | Medium | High",
        "documentation": "Low | Medium | High",
        "maintenance": "Low | Medium | High"
      },
      "maintenance_assessment": {
        "active_within_12mo": true,
        "signals": { "releases": true, "changelog": false, "ci": true,
                     "multiple_contributors": false, "issues_responded": null },
        "summary": "one-line evidence phrase"
      }
    }
  ],
  "maintenance_assessment": {
    "active_within_12mo": true,
    "waiver_brand_new": false,
    "signals": {
      "releases": true,
      "changelog": false,
      "ci": true,
      "multiple_contributors": true,
      "issues_responded": null
    },
    "summary": "one-line evidence phrase",
    "reported_signal": "Low | Medium | High"
  }
}
```

- **`assessments`** (per app, from the quality aspect) carries the grades the
  review already states in prose. It is needed because meeting a target
  produces no finding: QUA-01 and QUA-02 fire only below threshold, so findings
  alone cannot tell `strong` from `adequate`. Grades are normalized for case,
  spaces, and hyphens (`"Partially portable"` is accepted).
- **`maintenance_assessment`** (repo-level, from the maintenance aspect).
  `issues_responded: null` means the repo has no open issues to respond to. That
  is no evidence of responsiveness either way, so it counts neither for nor
  against: a quiet repo needs two of the other four signals to reach `solid`.
  `waiver_brand_new` marks an app too new to have a history worth judging.
- **`apps[].maintenance_assessment`** (1.3, declared monorepos only, from the
  maintenance aspect's `app_maintenance` block): the same shape for one app,
  read from the app's own folder (its last commit and contributors, a
  CHANGELOG inside it), with releases, CI and issues taken from the repo
  unless tags are per app. It has no waiver, and since MNT- findings are filed
  at repo level its level follows its activity alone. Absent for a single-app
  repo, or when the aspect could not read the history; a consumer then shows
  the repo's upkeep for the app.
- **`reported_signals`** / **`reported_signal`** are optional: the Low / Medium /
  High levels the report's Signals block states. They are used only to
  cross-check the report against the computed levels and are never copied into
  the artifact.

An app with no `assessments` gets no indicators; a meta with no
`maintenance_assessment` gets no repo-level indicators. Both cases warn on
stderr and still assemble.

## Artifact shape

```json
{
  "schema_version": "1.3",

  "reviewed": {
    "repo_url":     "https://github.com/owner/app",
    "sha":          "6a4183c…",
    "ref":          "main",
    "at":           "2026-08-27T14:00:00Z",
    "tool_version": "appverse-review@0.5.0",
    "repo_shape":   "inferred_single | declared_monorepo | declared_single"
  },

  "recommendation": {
    "decision": "accept | accept_with_suggestions | request_changes | reject",
    "note":     "One-paragraph rationale"
  },

  "repo_level": {
    "findings": [ /* maintenance findings (MNT-XX) and repo-wide findings */ ],
    "criteria": {
      "license": "pass | fail | warn | not_checked",
      "readme_substantive": "pass | fail | warn | not_checked",
      "not_archived": "pass | fail | warn | not_checked",
      "public": "pass | fail | warn | not_checked"
    },
    "indicators": {
      "maintenance": {
        "level":   "solid | some_notes | needs_attention",
        "summary": "Active, 3 releases, CI green",
        "anchor":  "#upkeep"
      }
    }
  },

  "apps": [
    {
      "app_id":   "root | <subpath>",
      "name":     "App Name",
      "decision": "accept | accept_with_suggestions | request_changes | reject",
      "findings": [ /* structure + OODT (security) + quality findings */ ],
      "criteria": {
        "metadata":   "pass | fail | warn | not_checked",
        "yaml_valid": "pass | fail | warn | not_checked",
        "structure":  "pass | fail | warn | not_checked",
        "references": "pass | fail | warn | not_checked"
      },
      "indicators": {
        "portability":   { "level": "solid", "summary": "All site values in form.yml", "anchor": "#portability" },
        "documentation": { "level": "some_notes", "summary": "README covers install and config", "anchor": "#documentation" },
        "maintenance":   { "level": "some_notes", "summary": "Last change 2025-03; one contributor", "anchor": "#signals" }
      }
    }
  ],

  "artifacts": {
    "report_md":   "review-owner-app.md",
    "report_pdf":  "review-owner-app.pdf",
    "report_html": "review-owner-app.html"
  },

  "run_meta": {
    "model": "claude-sonnet-4-6"
  }
}
```

## Field notes

- **`recommendation`** is the tool's suggestion, never the human verdict. The
  `decision` is normalized to snake_case by `assemble-artifact.py`.
- **`repo_level.findings`** contains the maintenance findings (maintenance is a
  repo-level signal, not per-app) and any finding whose `app_id` names no app in
  `apps[]`. In a monorepo the apps are subpaths, so a repo-wide finding filed
  under `root` — a `shared_paths` entry that does not exist, say — lands here.
  Any other `app_id` that matches no app is a spelling mismatch between
  `findings.json` and `meta.apps` (`apps/foo/` against `apps/foo`); the
  assembler refuses it (exit 1, the ids named on stderr) rather than file the
  findings elsewhere, which would leave their real app with all-pass criteria
  it did not earn. Every finding in `findings.json` appears in the artifact
  exactly once.
- **`apps[].findings`** contains structure, OODT (security), and quality
  findings, filtered by `app_id`. There is no security indicator; a consumer
  reads security from these records directly (see Indicators below).
- **`artifacts`** holds filenames, not paths. The reports travel beside the
  artifact; the directory they were written to during the run is dropped.
- **`apps[].criteria`** is derived from findings by `assemble-artifact.py` —
  an STR-03 FAIL sets `yaml_valid: "fail"`, etc. The orchestrator does not
  produce criteria directly. Values follow the record's result: FAIL → fail,
  WARN → warn (the tool could not confirm the gate; the reviewer settles it),
  NOT CHECKED → not_checked, PASS → pass. The worst result wins when several
  records map to one criterion.
- **`repo_level.criteria.not_archived`** and **`repo_level.criteria.public`**
  are meta-sourced, not findings-sourced — the orchestrator writes them
  directly into `not_archived` / `public` in meta.json (`pass | fail`), and
  `assemble-artifact.py` normalizes each through the same enum as findings
  (`pass | fail | warn | not_checked`, case-insensitive, whitespace-stripped;
  unrecognized counts as `fail` with a stderr warning). `public` is the
  clone succeeded; fail when the repo is private or unreachable. `public`
  is omitted from `criteria` when meta.json doesn't set it.
- **`run_meta.model`** is the Claude model ID reported by the orchestrator.
  Token counts and USD cost are not available from the review session (the
  CI action sanitizes usage data); they are tracked externally by the API
  provider. The `run_meta` object may gain `tokens` and `usd` fields if
  a reliable source becomes available.
- **`report_html`** is the deep-link target. Heading `id` attributes are
  generated by pandoc from heading text (lowercase, hyphens for spaces) and
  are stable across runs for the same heading. Indicator `anchor` fields are
  fragments into this file.

## Indicators

Each indicator is `level` / `summary` / `anchor`. `assemble-artifact.py`
derives the level by table lookup; the LLM never assigns one. It supplies the
observations (findings, grades, evidence phrases) and the script applies the
rules, the same split as stable IDs and criteria.

| Indicator | `solid` | `some_notes` | `needs_attention` |
|---|---|---|---|
| `portability` | `portable` | `partially_portable` | `not_portable` |
| `documentation` | `strong`, `exemplary` | `adequate` | `minimal` (a Below minimal or stub README is also `minimal`) |
| `maintenance` | Active within 12 months and two or more good-practice signals | Active within 12 months; or the brand-new-app waiver | An MNT-01 finding; or inactive |

There is no security indicator (schema 1.2). Security is the app's OODT-
findings in `apps[].findings`, each with its severity and result; the portal
shows the findings, not a level. An app with none is described as having no
tool-detectable issues in the checked tiers, never as `safe`.

A consumer that counts security findings counts `OODT-` records whose
`result` is FAIL or WARN. A PASS record confirms a check and may be dropped.
A NOT CHECKED record reports a skipped tier and is not a finding to review,
but it is the only trace that the tier was skipped now that the security
summary is gone: a consumer shows it as a scope note beside the findings
("tier 3 not checked", from the record's summary), so "no tool-detectable
issues in the checked tiers" never reads as "all tiers checked".

**Portal.** The portal's `indicator_security` field and the reviewer's
security-level override are retired with 1.2; the seeder tolerates the
missing key, and the curation form's security level widget should be removed.

- **Levels follow the record's `result`.** Only `FAIL` and `WARN` records assert
  a defect. A `PASS` record confirms a check and a `NOT CHECKED` record reports
  a skipped one (the security skill files tier 3 that way); neither moves a
  level, whatever its severity. An MNT-01 record with result `PASS` does not
  mark the repo stale. A record with no `result` counts as asserted, as it
  always has.
- **Maintenance precedence:** an MNT-01 finding wins over the waiver (and warns,
  since the two contradict each other). When the waiver applies, the summary
  names it.
- **Indicators are optional.** An app without `assessments` has no `indicators`
  key at all, rather than a partial set — a lone level would read as a
  complete assessment. Likewise `repo_level` without `maintenance_assessment`.
  An unrecognized grade omits that one indicator. Consumers must tolerate a
  missing key; a 1.0-shaped meta still assembles.
- **Display labels.** The report's Signals block shows the same levels as
  Low / Medium / High: `solid` = Low, `some_notes` = Medium,
  `needs_attention` = High. The enum is the machine value and the words differ
  on purpose: findings already carry a low/medium/high `severity`, which is
  per finding, while a signal level is per axis. They are different scales,
  and sharing one vocabulary would put them side by side under the same names.
- **`level` is the tool's default.** It is what the rules produce. A consumer
  may let a human reviewer override it; the artifact records only the tool's
  value.
- **Anchors.** Per-app anchors are `#portability` and `#documentation`; the
  repo-level anchor is `#upkeep` (the report's `## Upkeep` heading). Every app
  section repeats the same headings and pandoc de-duplicates repeats by
  appending `-1`, `-2`, …, so the app at index *n* in `apps[]` gets
  `#portability-n` (no suffix for the first). An app's own upkeep (1.3) links
  to its Signals block the same way: `#signals`, `#signals-1`, … This holds under pandoc's
  `markdown` and `gfm` readers, and rests on two properties of the report: apps
  appear in the same order as in `meta.json`, and every app section includes
  all of the dimension headings.

`assemble-artifact.py` warns on stderr, and still emits the artifact, when:
indicator inputs are missing; a grade is not in the vocabulary; a QUA-01 or
QUA-02 record with result FAIL or WARN sits beside a grade that maps to `solid`
(a PASS record is agreement, not contradiction); an MNT-01 finding
accompanies the waiver; a `reported_signals` level (`portability` or
`documentation`) disagrees with the computed one — a stale `security` key in
`reported_signals` is simply ignored, since schema 1.2 has no security
indicator to cross-check it against; or an optional input has the wrong shape
(a `signals` block or `reported_signals` that is not an object), which is
skipped.

It exits 1 and emits nothing when the input cannot be trusted: a `--findings`
file that is missing or will not parse (assembling without it would claim
clean findings for every app), or a finding whose `app_id` matches no app.

## Versioning

The `schema_version` field is semver. Consumers pin to a major version.
Breaking changes (field removals, type changes) bump the major. Additive
changes (new optional fields like `indicators`) bump the minor.
Removing an optional indicator key is a minor bump: since 1.1, consumers must
tolerate a missing indicator key (see Indicators), so 1.2's removal of
`indicators.security` breaks no conforming consumer.

| Version | Change |
|---|---|
| 1.0 | Initial envelope: reviewed, recommendation, findings, criteria, report paths. |
| 1.0.1 | criteria values gain warn and not_checked; PASS records no longer flip a criterion to fail. |
| 1.1 | Adds the optional `indicators` on `repo_level` and each `apps[]` entry. |
| 1.2 | Removes `indicators.security`. Security is the app's OODT- findings in `apps[].findings`; there is no computed security level. |
| 1.3 | Adds the optional `apps[].indicators.maintenance`: in a declared monorepo, each app's own upkeep from its folder's activity. `repo_level.indicators.maintenance` stays. |
