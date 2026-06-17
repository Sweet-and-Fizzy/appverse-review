# AppVerse Review & Audit — What We're Proposing

Today, reviewing an AppVerse app submission means manually working through a detailed checklist — inspecting the repo's structure, reading code for security concerns, rating documentation quality, and checking maintenance signals. It's thorough but slow, it depends on the reviewer's time and expertise, and it only happens at submission. Once an app is in the catalog, nothing re-checks it as it changes. We're proposing to build an AI-assisted engine that automates this analysis, used two ways: on demand by reviewers and contributors, and continuously across the whole catalog.

## What it analyzes

The engine evaluates an app repo across four areas, each an independent check:

- **Structure** — Required files, metadata fields, YAML validity, standard OOD layout, broken references
- **Security** — A capability profile of what the app actually does (what it accesses, what it runs, what it sends over the network), checked against per-app-type baselines, with unsafe patterns flagged and classified by threat type
- **Quality** — Documentation rating, configuration portability, code quality
- **Maintenance** — Commit recency, releases, issue responsiveness, CI, CHANGELOG

It produces an evidence-backed report with file-and-line findings, quality ratings with justifications, security findings classified by threat type and severity, and a recommended decision. The engine recommends; a human always makes the final call.

## Two ways to use it

**On demand.** A reviewer types a single command in Claude Code with a submitted repo's GitHub URL — `/appverse-review:review-app https://github.com/owner/some-app` — and gets back the full report, ending with a draft feedback message ready to paste into a Drupal comment or GitHub issue. Contributors can run the same command inside their own app repo, with no URL, to get a prioritized fix-before-submitting list. Monorepos with multiple apps get per-app sections and per-app decisions.

**Automatically, across the catalog.** The same engine runs on every app as it changes, building a current security and quality profile for each one — exactly what it does, and anything it does unsafely. Apps carry a badge in the catalog reflecting their latest audit, so deployers can see at a glance what they're installing before they put it on their system. We can run the first pass across all of the existing apps at once.

The on-demand command and the automated audit are the same analysis applied two ways: a person running it deliberately, and the catalog running it continuously in the background. Both draw on one shared rubric, so a contributor checking their own repo, a reviewer deciding on a submission, and the catalog badge all reflect the same standard.

## What we're asking

Approval to start building. The on-demand reviewer and contributor tool is the first usable piece and proves out the engine; the automated catalog-wide auditing and badges build on the same foundation. It's a relatively light build — the analysis is configuration and prompts rather than a large new application — and the security analysis in particular is something we'll refine over time with input from the security folks.
