# AppVerse Review Skill — What We're Proposing

Today, reviewing an AppVerse app submission means manually working through a detailed checklist — inspecting the repo's structure, reading code for security concerns, rating documentation quality, and checking maintenance signals. We're proposing to build an AI-assisted review tool that automates this process. Packaged as a Claude Code plugin, the tool runs the full checklist against any app repo and produces an evidence-backed report with a recommended decision. The AI recommends; a human always makes the final call.

The review covers four areas, each run as an independent check:

- **Structure** — Required files, metadata fields, YAML validity, standard OOD layout, broken references
- **Security** — Capability profiling against per-app-type baselines, unsafe-pattern detection, OAT threat classification
- **Quality** — Documentation rating, configuration portability, code quality
- **Maintenance** — Commit recency, releases, issue responsiveness, CI, CHANGELOG

In practice, a reviewer would type a single command in Claude Code with the submitted repo's GitHub URL — `/appverse-review:review-app https://github.com/owner/some-app` — and get back a structured report: pass/fail tables with file-and-line evidence, quality ratings with justifications, security findings classified by threat type and severity, and an overall recommended decision (accept, accept with suggestions, request changes, or reject). The report ends with a draft feedback message ready to paste into a Drupal comment or GitHub issue. Contributors can also run the same command inside their own app repo (no URL needed) to get a prioritized fix-before-submitting list. Monorepos with multiple apps get per-app sections and per-app decisions.
