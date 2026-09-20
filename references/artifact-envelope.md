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

Two scripts then process these:

| Script | Input | Output |
|---|---|---|
| `compute-ids.py` | findings JSON | findings JSON with stable `id` fields |
| `assemble-artifact.py` | meta JSON + findings JSON + file paths | **artifact JSON** (this contract) |

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
        "security": "Low | Medium | High",
        "portability": "Low | Medium | High",
        "documentation": "Low | Medium | High"
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
  `issues_responded: null` means the repo has no open issues to respond to, and
  counts in the repo's favor. `waiver_brand_new` marks an app too new to have a
  history worth judging.
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
  "schema_version": "1.1",

  "reviewed": {
    "repo_url":     "https://github.com/owner/app",
    "sha":          "6a4183c…",
    "ref":          "main",
    "at":           "2026-08-27T14:00:00Z",
    "tool_version": "appverse-review@0.3.0",
    "repo_shape":   "inferred_single | declared_monorepo | declared_single"
  },

  "recommendation": {
    "decision": "accept | accept_with_suggestions | request_changes | reject",
    "note":     "One-paragraph rationale"
  },

  "repo_level": {
    "findings": [ /* maintenance findings (MNT-XX) and repo-wide findings */ ],
    "criteria": {
      "license": "pass | fail",
      "readme_substantive": "pass | fail",
      "not_archived": "pass | fail"
    },
    "indicators": {
      "maintenance": {
        "level":   "solid | some_notes | needs_attention",
        "summary": "Active, 3 releases, CI green",
        "anchor":  "#maintenance-signals"
      }
    }
  },

  "apps": [
    {
      "app_id":   "root | <subpath>",
      "name":     "App Name",
      "decision": "accept | accept_with_suggestions | request_changes | reject",
      "findings": [ /* structure + security + quality findings */ ],
      "criteria": {
        "metadata":   "pass | fail",
        "yaml_valid": "pass | fail",
        "structure":  "pass | fail",
        "references": "pass | fail"
      },
      "indicators": {
        "security":      { "level": "needs_attention", "summary": "1 Medium, 1 Low", "anchor": "#security" },
        "portability":   { "level": "solid", "summary": "All site values in form.yml", "anchor": "#portability" },
        "documentation": { "level": "some_notes", "summary": "README covers install and config", "anchor": "#documentation" }
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
  An unmatched `app_id` other than `root` also lands here, with a stderr
  warning, since it is probably a typo. Every finding in `findings.json` appears
  in the artifact exactly once.
- **`apps[].findings`** contains structure, security, and quality findings,
  filtered by `app_id`.
- **`artifacts`** holds filenames, not paths. The reports travel beside the
  artifact; the directory they were written to during the run is dropped.
- **`apps[].criteria`** is derived from findings by `assemble-artifact.py` —
  an STR-03 FAIL sets `yaml_valid: "fail"`, etc. The orchestrator does not
  produce criteria directly.
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
| `security` | No `OODT-` findings | Low or Info severity only | Any Medium, High, or Critical |
| `portability` | `portable` | `partially_portable` | `not_portable` |
| `documentation` | `strong`, `exemplary` | `adequate` | `minimal` |
| `maintenance` | Active within 12 months and two or more good-practice signals | Active within 12 months; or the brand-new-app waiver | An MNT-01 finding; or inactive |

- **Security keys on the `OODT-` rule prefix**, not on severity alone: a
  high-severity structure finding (a missing LICENSE) does not move the security
  level. The summary is a mechanical count in severity order, e.g.
  `1 Medium, 1 Low`, or `No security findings`.
- **Maintenance precedence:** an MNT-01 finding wins over the waiver (and warns,
  since the two contradict each other). When the waiver applies, the summary
  names it.
- **Indicators are optional.** An app without `assessments` has no `indicators`
  key at all, rather than a partial set — a lone security level would read as a
  complete assessment. Likewise `repo_level` without `maintenance_assessment`.
  An unrecognized grade omits that one indicator. Consumers must tolerate a
  missing key; a 1.0-shaped meta still assembles.
- **Display labels.** The report's Signals block shows the same levels as
  Low / Medium / High: `solid` = Low, `some_notes` = Medium,
  `needs_attention` = High. The enum is the machine value and the words differ
  on purpose: findings already carry a low/medium/high `severity`, and a
  Medium-severity finding produces a High signal, so sharing one vocabulary
  would put two different scales side by side under the same names.
- **`level` is the tool's default.** It is what the rules produce. A consumer
  may let a human reviewer override it; the artifact records only the tool's
  value.
- **Anchors.** Per-app anchors are `#security`, `#portability`, and
  `#documentation`; the repo-level anchor is `#maintenance-signals`. Every app
  section repeats the same headings and pandoc de-duplicates repeats by
  appending `-1`, `-2`, …, so the app at index *n* in `apps[]` gets
  `#security-n` (no suffix for the first). This holds under pandoc's `markdown`
  and `gfm` readers, and rests on two properties of the report: apps appear in
  the same order as in `meta.json`, and every app section includes all of the
  dimension headings.

`assemble-artifact.py` warns on stderr, and still emits the artifact, when:
indicator inputs are missing; a grade is not in the vocabulary; a QUA-01 or
QUA-02 finding sits beside a grade that maps to `solid`; an MNT-01 finding
accompanies the waiver; or a `reported_signals` level disagrees with the
computed one.

## Versioning

The `schema_version` field is semver. Consumers pin to a major version.
Breaking changes (field removals, type changes) bump the major. Additive
changes (new optional fields like `indicators`) bump the minor.

| Version | Change |
|---|---|
| 1.0 | Initial envelope: reviewed, recommendation, findings, criteria, report paths. |
| 1.1 | Adds the optional `indicators` on `repo_level` and each `apps[]` entry. |
