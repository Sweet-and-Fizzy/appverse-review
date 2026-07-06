# appverse-review

AI-assisted review of [AppVerse](https://github.com/Sweet-and-Fizzy/ood-appverse)
app submissions, packaged as a Claude Code plugin. This repo is also the
canonical home of the AppVerse [review
checklist](references/review-checklist.md) and [security
rubric](references/security-rubric.md).

## Who this is for

- **Reviewers**: run a complete checklist review of a submitted repo and get an
  evidence-backed report, a recommended decision, and a draft feedback message.
- **Contributors**: check your own app repo before submitting and get a
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

## Use

Full review of a submission (reviewer):

```
/appverse-review:review-app https://github.com/owner/some-ood-app
```

Check your own repo before submitting (contributor) — run inside your app repo:

```
/appverse-review:review-app
```

Run a single aspect on its own:

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

The security aspect builds a **capability profile** of what the app actually
does, runs unsafe-pattern checks, and classifies findings under the OAT (Open
OnDemand App Threats) taxonomy — narrow-baseline anomaly detection for Batch
Connect apps, transparency profiling for Passenger apps. When static analysis
tools are installed (shellcheck, bandit, semgrep, etc.), the security review
runs them automatically and folds their findings into the OAT-classified report
as corroborating or additional evidence.

## Roadmap

- **Phase 2 — GitHub Action**: a workflow contributors can drop into their app
  repos so the review runs in CI on every push.
- **Phase 3 — Drupal integration**: the AppVerse site calls the Claude API when
  a submission reaches review and attaches the report for the human reviewer.
- **Automated security audits**: the per-commit audit pipeline, numeric risk
  scoring, and catalog badges described in the AppVerse security-audit proposal
  consume the same [security rubric](references/security-rubric.md).
