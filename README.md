# appverse-review

AI-assisted review of [Appverse](https://github.com/Sweet-and-Fizzy/ood-appverse)
app submissions, packaged as a [Claude Code](https://claude.ai/code) plugin.
Evaluates structure, security, quality, and maintenance against a shared rubric
and produces an evidence-backed report with a recommended decision.

This repo is also the canonical home of the Appverse
[review checklist](references/review-checklist.md) and
[security rubric](references/security-rubric.md).

## Who this is for

- **Reviewers** — run a complete checklist review of a submitted repo and get a
  structured report, a recommended decision, and a draft feedback message.
- **Contributors** — check your own app repo before submitting and get a
  prioritized fix list.

The skills recommend; a human always makes the final call. Two checks require
catalog access and are always left to the human reviewer: the duplicate check
and whether the `software` value matches a catalog entry.

## Prerequisites

- **[Claude Code](https://claude.ai/code)** — the plugin runs inside Claude Code
  on macOS, Linux, or Windows (via WSL)
- **git** — required for cloning repos in reviewer mode
- **gh** CLI (optional) — enables maintenance signals (commit recency, releases,
  issue responsiveness). Without it, those signals are marked "not checked" and
  the review still completes.
- **Static analysis tools** (optional) — the security review probes for and runs
  any of these that are installed: shellcheck (shell), bandit (Python), semgrep
  (multi-language), npm audit (Node.js), trivy (dependencies/containers), rubocop
  (Ruby). See [references/security-tools.md](references/security-tools.md) for
  install instructions per platform. If none are installed the review still
  completes normally.

## Install

In [Claude Code](https://claude.ai/code):

```
/plugin marketplace add Sweet-and-Fizzy/appverse-review
/plugin install appverse-review@appverse-review
```

## Usage

**Full review** of a submission (reviewer):

```
/appverse-review:review-app https://github.com/owner/some-ood-app
```

**Self-check** before submitting (contributor) — run inside your app repo:

```
/appverse-review:review-app
```

**Single aspect** on its own:

```
/appverse-review:review-structure   [github-url]
/appverse-review:review-security    [github-url]
/appverse-review:review-quality     [github-url]
/appverse-review:review-maintenance [github-url]
```

Maintenance signals use the `gh` CLI if available; without it the review still
runs and marks those signals "not checked".

## How it works

`review-app` sets up the target once (clone or current directory, repo-shape
detection — monorepos are reviewed per app), then runs the four aspects as
parallel subagents and synthesizes the report and recommended decision.

### Review aspects

| Aspect | What it checks |
|--------|---------------|
| **Structure** | Required files, metadata fields, YAML validity, OOD layout, broken references |
| **Security** | Capability profiling, unsafe-pattern checks, OODT threat classification, static analysis |
| **Quality** | Documentation rating, portability rating, code quality checklist |
| **Maintenance** | Commit recency, releases, issues, contributors, CHANGELOG, CI |

### Security approach

The security aspect builds a **capability profile** of what the app actually
does, runs unsafe-pattern checks, and classifies findings under the OODT (Open
OnDemand Threat) taxonomy — narrow-baseline anomaly detection for Batch
Connect apps, transparency profiling for Passenger apps. When static analysis
tools are installed (shellcheck, bandit, semgrep, etc.), the security review
runs them automatically and folds their findings into the OODT-classified report
as corroborating or additional evidence.

## CI / GitHub Actions

A GitHub Actions workflow is included for running reviews in CI. It uses
[claude-code-action](https://github.com/anthropics/claude-code-action) to run
the review plugin, produces both Markdown and PDF reports, and uploads them as
artifacts.

See [`.github/workflows/appverse-review.yaml`](.github/workflows/appverse-review.yaml)
for the workflow definition. It supports:
- `workflow_dispatch` with configurable inputs (target repo, branch, aspects, model)
- Dry-run mode for pipeline testing without API costs
- PDF generation via pandoc + typst
- Machine-readable `review-summary.json` output for downstream integration

## Project layout

```
.claude-plugin/          Plugin metadata (plugin.json, marketplace.json)
skills/
  review-app/            Orchestrator: runs all aspects, synthesizes report
  review-structure/      Required files, metadata, YAML validity, layout
  review-security/       Capability profile, pattern checks, OODT classification
  review-quality/        Documentation rating, portability, code quality
  review-maintenance/    Commit recency, releases, CI, CHANGELOG
references/
  review-checklist.md    Canonical review rubric
  security-rubric.md     OODT taxonomy
  security-tools.md      Static analysis tool lookup
  target-setup.md        Shared setup procedure (mode detection, schema load)
  appverse.yml           Cached schema reference (offline fallback)
tests/
  fixtures/              6 deliberately broken app repos for calibration
  TESTING.md             Expected findings per fixture, coverage matrix
.github/workflows/       CI workflow for running reviews via GitHub Actions
```

## Test fixtures

Six fixture repos with planted defects for calibrating review accuracy:

| Fixture | Primary defect area | Defect count |
|---------|-------------------|--------------|
| `broken-app` | Missing LICENSE, broken YAML, committed secret | 6 |
| `monorepo` | Declared monorepo with mixed outcomes | 2 |
| `vnc-stale-debugger` | Subtle quality issues | 8 |
| `passenger-flask-app` | Command injection, shell injection, /tmp token storage | 10 |
| `containerized-server` | CORS wildcard, 0.0.0.0 bind, portability failures | 10 |
| `curl-pipe-installer` | Polished exterior hiding curl\|bash, eval injection | 9 |

See [tests/TESTING.md](tests/TESTING.md) for the full defect matrix and
calibration procedure.

## Roadmap

- **Phase 1 — Plugin & rubric**: Skills, references, test fixtures, and
  calibration. *(Complete)*
- **Phase 2 — GitHub Actions CI**: Workflow for running reviews in CI with
  PDF report generation and artifact upload. *(Complete)*
- **Phase 3 — Drupal integration**: The Appverse portal triggers a review
  when a submission reaches moderation and attaches the report for the
  human reviewer. *(In progress)*
- **Phase 4 — Badges & self-service**: Review badges (shields.io or custom
  SVG), reusable workflow for contributors, and a submitter-mode prompt
  variant with prioritized fix lists.
- **Phase 5 — Compliance**: NIST 800-223 control mapping, security baseline
  profiles, and compliance report variants.

## Contributing

Contributions are welcome. The review rubric and security taxonomy are
designed to evolve as the Appverse catalog grows:

- **Rubric changes** — edit [references/review-checklist.md](references/review-checklist.md)
  and update the corresponding skill files
- **Security taxonomy** — edit [references/security-rubric.md](references/security-rubric.md)
  and update OODT references in skill files and [tests/TESTING.md](tests/TESTING.md)
- **New fixtures** — add to [tests/fixtures/](tests/fixtures/) and document
  expected findings in [tests/TESTING.md](tests/TESTING.md)

See [CLAUDE.md](CLAUDE.md) for development conventions.

## License

Licensed under the [MIT License](LICENSE).
