# AppVerse Review Skill — Design

**Date:** 2026-06-10
**Status:** Draft for team review (implementation plan exists at
`docs/superpowers/plans/2026-06-10-appverse-review-skill.md` but execution is on
hold pending this review)

## Orientation: repos and documents

For readers new to the project:

- **[Sweet-and-Fizzy/ood-appverse](https://github.com/Sweet-and-Fizzy/ood-appverse)** —
  the AppVerse Browser (embeddable React catalog UI) and the project's public docs.
  Relevant docs there:
  [contributor guide](https://github.com/Sweet-and-Fizzy/ood-appverse/blob/main/docs/appverse-contributor-guide.md),
  [current review checklist](https://github.com/Sweet-and-Fizzy/ood-appverse/blob/main/docs/app-review-checklist.md),
  [annotated appverse.yml reference](https://github.com/Sweet-and-Fizzy/ood-appverse/blob/main/docs/appverse.yml).
- **[necyberteam/cyberteam_drupal](https://github.com/necyberteam/cyberteam_drupal)** —
  the Drupal backend. `web/modules/custom/ood_software` implements the submission
  form, the GitHub sync (`GitHubService`; `RepoSyncService` on the
  [Collections branch (md-2724)](https://github.com/necyberteam/cyberteam_drupal/tree/md-2724/web/modules/custom/ood_software)
  — the future state this design targets, not yet on main), and the
  `appverse_editorial` moderation workflow this review process feeds into.
- **Sweet-and-Fizzy/appverse-review** — the new plugin repo this design creates.
  Does not exist yet.
- **`appverse-security-audit-proposal.md`** — the automated security-audit proposal
  whose methodology this design's security aspect adopts. Currently a local doc in
  ood-appverse's `docs/`, not yet committed to the repo — if you received this spec
  on its own, ask for that document alongside it. It should be committed (to
  ood-appverse or the new repo) before links to it can work.
- **Implementation plan** — `docs/superpowers/plans/2026-06-10-appverse-review-skill.md`
  in ood-appverse (alongside this spec). Contains the full task-by-task build,
  including the complete text of every skill file. This spec is the *what and why*;
  the plan is the *how*.

## Background

AppVerse app submissions are reviewed by humans against `docs/app-review-checklist.md`
(required pass/fail criteria, quality scales, maintenance signals, decision outcomes).
Submissions arrive via the Drupal form as a GitHub URL, land in the `appverse_editorial`
moderation workflow (`draft` → `ready_for_review` → `published` / `needs_adjustment`),
and a reviewer applies the checklist manually. Nothing automates the checklist today;
submission-time validation only covers required files (README, LICENSE, manifest.yml),
YAML parseability of manifest.yml, and the repo not being archived.

This design adds an AI-assisted review that implements the checklist. Version 1 targets
reviewers running it in Claude Code; the same tool serves submitters checking their own
repo before submitting. Later phases (GitHub Action, Drupal-integrated API review) reuse
the same rubric.

## Goals

- A reviewer can run one command against a submitted GitHub URL and get a complete,
  evidence-backed checklist review with a recommended decision and a draft feedback
  message ready to send.
- A submitter can run the same command with no arguments inside their own app repo and
  get a prioritized fix-before-submitting list.
- Monorepos (declared repos with root `appverse.yml` and `apps[]`) are reviewed
  first-class: every app gets its own review section and its own recommendation.
- The review rubric has a single canonical home that humans and the skill share.

## Non-goals (v1)

- Duplicate-vs-catalog check and software-name-matches-catalog check (need catalog
  access; the report states these were not checked).
- Posting results anywhere (GitHub issues, Drupal comments). Output is local text.
- GitHub Action / CI integration (phase 2).
- Drupal-triggered API review on `ready_for_review` (phase 3).
- The AI deciding alone. Every output is labeled a recommendation for a human to confirm.

## Architecture

### New repo: `appverse-review`

Standalone repo (proposed under the Sweet-and-Fizzy org, alongside ood-appverse),
packaged as a Claude Code plugin so install is:

```
/plugin marketplace add Sweet-and-Fizzy/appverse-review
/plugin install appverse-review
```

Layout:

```
appverse-review/
├── .claude-plugin/
│   ├── plugin.json          # plugin metadata; "name" MUST be exactly "appverse-review"
│   │                        # (it produces the /appverse-review: skill namespace and
│   │                        # must match the marketplace install name)
│   └── marketplace.json     # lets the repo serve as its own marketplace
├── references/              # shared by all skills
│   ├── review-checklist.md  # canonical rubric (moved + updated, see below)
│   ├── security-rubric.md   # OAT taxonomy, pattern checks, capability baselines
│   │                        # (extracted from the security-audit proposal)
│   ├── appverse.yml         # cached copy of the annotated schema reference
│   └── target-setup.md      # shared setup: target/mode, schema load, repo-shape
│                            # detection, findings format
├── skills/
│   ├── review-app/SKILL.md          # orchestrator: runs all aspects, synthesizes,
│   │                                # recommends the decision
│   ├── review-structure/SKILL.md    # aspect: required files, metadata, YAML, layout
│   ├── review-security/SKILL.md     # aspect: secrets, curl|bash, unvalidated input
│   ├── review-quality/SKILL.md      # aspect: docs rating, portability, code quality
│   └── review-maintenance/SKILL.md  # aspect: gh signals, CHANGELOG, CI
└── README.md                # audience, install, usage, future-phase roadmap
```

### Rubric source of truth

- `ood-appverse/docs/app-review-checklist.md` **moves** to
  `appverse-review/references/review-checklist.md` and becomes canonical. The
  ood-appverse copy is replaced by a short pointer to the new home.
- The annotated schema reference `ood-appverse/docs/appverse.yml` **stays** in
  ood-appverse (it is contributor-facing documentation, linked from the contributor
  guide). At run time the skill fetches the live version from
  `https://raw.githubusercontent.com/Sweet-and-Fizzy/ood-appverse/main/docs/appverse.yml`
  and falls back to its cached `references/appverse.yml` copy (a verbatim copy of
  that file) when offline. Schema changes therefore do not require a plugin release;
  the cached copy is refreshed when the plugin is updated.

### Checklist updates required as part of the move

The current checklist predates the appverse.yml / declared-repo model: its required
fields cover only manifest.yml (`name`, `category`, `role`, `description`) and it
marks contact/support_url as "Planned", while the Drupal sync (RepoSyncService,
on the cyberteam_drupal Collections branch — the future state this design targets;
not yet on the default branch) already enforces appverse.yml required fields for
declared repos. Moving it
unchanged would make the skill check criteria its own canonical rubric doesn't
contain. The move therefore includes these content updates:

1. Add declared-repo (appverse.yml) required-field criteria: description, software,
   app_type, maintainer.name, maintainer.support_url — today documented only in the
   schema reference and enforced only in sync code. Confirm exact enforcement
   against RepoSyncService during implementation (`src/Service/RepoSyncService.php`
   on the Collections branch — check out that branch or its worktree; the service
   is not on the default branch), including how inferred (manifest-only) repos are
   treated, and replace the stale "Planned: contact or support_url" note with what
   is actually enforced for each repo shape.
2. Add the declared-vs-inferred repo distinction and monorepo (`apps[]`) review
   guidance, including per-app decisions.
3. Fix the configuration-portability vocabulary: the body defines three levels
   (Not portable / Partially portable / Portable) while the appendix template lists
   four (adding "Highly portable"). Standardize on the three-level scale everywhere.

## The skills: one orchestrator, four aspect skills

Each review aspect is its own skill file (per team input from Travis), with a thin
orchestrator on top:

- **`review-app` (orchestrator)** — sets up the target once (clone/cwd, schema,
  repo-shape detection, per-app field resolution), then runs the four aspect skills
  as parallel subagents, each in a clean context with only its own instructions.
  It alone synthesizes the report and recommends the decision, because the decision
  rules cut across aspects.
- **`review-structure`, `review-security`, `review-quality`,
  `review-maintenance` (aspects)** — each implements one pass and returns findings
  (criterion / result / evidence), never verdicts. Each is also independently
  invocable (e.g. `/appverse-review:review-security <url>`) for à-la-carte checks;
  when run standalone it performs the shared target setup itself via
  `references/target-setup.md`.

This keeps every skill file small and focused, lets each aspect be calibrated and
tested independently, and sets up phase 2 (CI could run aspects as separate jobs).

Plugin skills in current Claude Code are user-invocable slash commands directly — no
separate `commands/` entry is needed. With plugin name `appverse-review`, the typed
invocation for a full review is namespaced:

```
/appverse-review:review-app [github-url]
```

The URL argument reaches the skill via `$ARGUMENTS`. Model invocation stays enabled
(no `disable-model-invocation`), so "review this app repo" in plain language also
triggers it. Two invocation modes, identical checks:

- **Reviewer mode** — `/appverse-review:review-app https://github.com/owner/repo`:
  shallow-clone (`git clone --depth 1`, default branch) to a temp directory and
  review that.
- **Submitter mode** — invoked with no argument inside an app repo: review the
  current working tree.

### Repo-shape detection (monorepo first-class)

- Root `appverse.yml` present and parseable → **declared repo**. If it has `apps[]`,
  it is a monorepo: every `apps[].path` entry is reviewed as its own app.
- Root `manifest.yml` only → **inferred repo**, single app at the root.
- Neither → the review proceeds and reports a required-criteria failure (it does not
  error out).

For monorepos, per-app fields resolve with the same precedence the Drupal sync uses:

1. Inline in the root `appverse.yml` `apps[]` entry (highest)
2. `<subpath>/appverse.yml`
3. `<subpath>/manifest.yml` (name/description fallback only)

`shared_paths` directories are reviewed once at repo level and are included in the
security pass. All apps are reviewed; there is no per-run cap in v1 (the known
operational ceiling for declared repos is ~50 subpaths).

### Review procedure

The four aspect skills reorganize (not mirror) the checklist's process steps —
Quick Scan / Structure Review / Quality Assessment / Decision. The mapping below is
explicit so no checklist item silently drops:

| Checklist section | Aspect skill |
|---|---|
| Decision Framework + Duplicate Check | Deferred (catalog access); report marks accept as conditional on the human's duplicate check |
| Required 1: Repository Structure | review-structure |
| Required 2: Documentation Minimum | review-structure (substantive-README gate) + review-quality (rating) |
| Required 3: Security Concerns | review-security |
| Required 4: Basic Functionality (YAML validity, ERB/script syntax, no broken references) | review-structure |
| Quality Criteria (docs, portability, code quality) | review-quality |
| Maintenance Signals | review-maintenance |
| Step 4: Decision | Recommended decision by the orchestrator |

1. **Structure pass** — required files (README, LICENSE, manifest.yml or appverse.yml);
   YAML validity for every manifest.yml, appverse.yml, and form.yml encountered;
   ERB templates render and shell scripts pass basic lint; no obviously broken
   references (modules, paths, and variables referenced in templates exist in
   form.yml); required appverse.yml fields per the updated checklist (description,
   software, app_type, maintainer.name, maintainer.support_url); `app_type` is a
   known value; standard OOD layout for the declared app type; README is substantive
   (not the unfilled template); repo not archived.
2. **review-security** — adopts the methodology of the existing security-audit
   proposal (`docs/appverse-security-audit-proposal.md`) rather than the checklist's
   three manual checks: build a **capability profile** of what the app actually does
   (system access, network calls, file reads/writes, spawned processes), judged
   against the per-app-type baseline (narrow for Batch Connect, where anomalies are
   a strong malicious signal; broad-but-reported for Passenger apps, where the
   profile is a transparency tool); run the proposal's **pattern checks** (form
   values reaching shells unvalidated, eval/exec on external input, hardcoded or
   plaintext credentials, services bound to 0.0.0.0 or unauthenticated, CORS open,
   disabled security features, persistence writes to dotfiles/SSH/cron, container
   isolation weakening); and classify each finding under the **OAT taxonomy**
   (OAT-01..08). Covers each app subpath plus `shared_paths`. The proposal's numeric
   scoring, commit-polling pipeline, and catalog badges remain that project's scope —
   the aspect rates findings qualitatively (severity High/Medium/Low per finding).
   The OAT taxonomy, pattern-check tables, and capability baselines are extracted
   into `references/security-rubric.md` in the plugin so the aspect skill and the
   future automated pipeline share one rubric.
3. **Quality pass** — code quality per the checklist (error handling, magic numbers,
   duplication, input validation); configuration portability (hardcoded cluster names,
   module paths, site-specific assumptions) on the three-level scale; README quality
   rated on the checklist's Minimal / Adequate / Strong / Exemplary scale.
4. **Maintenance pass** — via `gh api`: last commit age, tagged releases, issue
   responsiveness, contributor count, CHANGELOG presence, CI presence. If `gh` is
   missing or unauthenticated, degrade gracefully: use `git log` for commit age and
   mark the rest "not checked".

### Output

A markdown report mirroring the checklist:

- **Repo-level section**: required criteria as a pass/fail table with evidence
  (file:line for each finding), maintenance signals, repo-level metadata checks.
- **Per-app sections** (monorepo) or a single app section (inferred repo): structure,
  security, and quality findings; quality ratings with one-line justifications; a
  per-app recommended decision.
- **Overall recommended decision** — accept / accept with suggestions / request
  changes / reject — explicitly labeled as a recommendation for the human reviewer.
  Because the duplicate check is the checklist's first gating question and part of
  its Reject definition, any "accept" recommendation is explicitly worded as
  conditional on the human completing the duplicate/catalog checks the skill cannot
  run. For monorepos the per-app decisions can differ and the overall recommendation
  summarizes them (e.g., "accept 3 apps, request changes on 1").
- **Reviewer mode ending**: a draft contributor feedback message in the checklist's
  template, plain prose, ready to paste into a Drupal moderation comment or GitHub
  issue.
- **Submitter mode ending**: a prioritized fix-before-submitting list instead of the
  feedback draft.
- The skill prints the report and offers to save it as `review-<owner>-<repo>.md`.

### Edge cases

- Nonexistent or private repo: clear error, suggest `gh auth login` for private repos.
- Archived repo: automatic required-criteria fail per the checklist.
- Missing manifest.yml and appverse.yml: required-criteria fail, not a crash.
- Large repos: depth-1 clone; review app subpaths, shared_paths, and root docs — skip
  vendored dependencies and build artifacts.
- Unparseable YAML anywhere: reported as a finding with the parse error, review
  continues.

## Testing

- Run against 2–3 real submissions that have already been human-reviewed and compare
  the skill's recommendation with the human outcome; tune SKILL.md until they match.
- Run against at least one monorepo (declared repo with multiple `apps[]` entries).
- Run against one deliberately broken fixture (missing LICENSE, invalid form.yml,
  a planted fake secret) to confirm findings and evidence quality.
- Run submitter mode inside a checked-out app repo.

## Future phases (documented in the repo README, not built now)

- **Phase 2 — GitHub Action**: a claude-code-action workflow submitters drop into
  their app repos so the review runs in CI. Requires API key/billing decisions.
- **Phase 3 — Drupal integration**: Drupal calls the Claude API when a submission
  hits `ready_for_review` and attaches the AI review to the node for the reviewer.
- Both phases reuse the same rubric reference files; v1 usage is the proving ground
  for the prompt and rubric.

## Open questions for team review

1. **Security aspect adopts the security-audit methodology.** The `review-security`
   aspect implements the capability-profile + pattern-check + OAT-classification
   approach from `docs/appverse-security-audit-proposal.md` (qualitative severity
   only — no numeric scoring, pipeline, or badges in v1). This makes the skill the
   manual vehicle for that proposal's phase 1 calibration. Does the team agree, or
   should v1 stick to the checklist's three manual security checks and keep the
   audit fully separate?
2. **Calibration set.** The tuning step needs 2–3 already-reviewed submissions with
   their human decisions (ideally one accept, one request-changes, one reject).
   Which repos should be the reference set?

## Decided

- **Repo home and name.** A new public repo `Sweet-and-Fizzy/appverse-review`
   (public is required for the simple `/plugin marketplace add` install path). The
   name was chosen after weighing alternatives. These repos will move to a dedicated
   org long term, but it doesn't exist yet, so they stay under Sweet-and-Fizzy for
   now. Not a team question.
- **AI-drafted contributor feedback needs no special handling.** Reviewer-mode
   output ends with a draft feedback message for a human to edit and send. The
   review process and rubric are public, so AI assistance is not something to gate
   or specially flag.
- **Checklist modernization is mechanical, not a policy vote.** The declared-repo
   required fields (software, app_type, maintainer.name, maintainer.support_url) are
   already enforced by `RepoSyncService` — an app missing them is rejected at sync
   time. The checklist update documents existing behavior, it doesn't propose new
   policy; a reviewer can't accept what the sync rejects. Standardizing the
   portability scale to three levels just fixes an internal body-vs-appendix
   contradiction. The only human step is confirming the documented field list
   matches the code (plan Task 2 verifies this against RepoSyncService).
- **Submitter self-check is promoted.** Once calibrated, the contributor guide will
   encourage submitters to run the check before submitting (decided 2026-06-16).
- **Monorepo field inheritance — DECIDED 2026-06-16 (app-developer feedback,
   2026-06-11).** Current `RepoSyncService` (Collections branch, verified
   2026-06-16) reads member-app fields only from `<subpath>/appverse.yml` merged
   with the inline `apps[]` entry; `applyDeclaredApp` is never even passed the root
   parsed `appverse.yml`, so repo-level `maintainer`/`tags` cannot reach member
   apps. An app missing its own `maintainer.name`/`maintainer.support_url` is
   rejected. This contradicts the schema reference, which implies a repo-level
   maintainer covers member apps. **Decision:** implement inheritance, with
   field-appropriate semantics —
   - **maintainer:** inherit-or-override. App's own `maintainer` wins; otherwise it
     inherits the repo-level `maintainer`. (Union is meaningless for a single
     value.)
   - **tags:** additive (union). An app's tags are merged with the repo-level tags
     (deduplicated). No per-app opt-out syntax in v1 — YAGNI; an app that must not
     carry an inherited tag is a documented limitation, revisit only if a real repo
     hits it.

   This is a `RepoSyncService::applyDeclaredApp` change on the Collections branch
   (pass the root parsed array in; fall back for maintainer, union for tags) plus a
   test, and a schema-reference correction — tracked as separate Collections-branch
   work, not part of the appverse-review plugin build. The review skill reviews
   against this intended behavior once it ships; until the code lands it should
   note the gap rather than reject apps that rely on inheritance.

## Relationship to the security-audit proposal

`docs/appverse-security-audit-proposal.md` proposes automated per-commit security
audits with capability profiles, an OAT threat taxonomy, scoring, and catalog
badges. This design and that one share the security rubric but split the work:

- The **review-security aspect skill** is the on-demand, human-triggered audit —
  same capability-profile/pattern-check/OAT methodology, qualitative severity,
  output embedded in the review report. Running it across submissions doubles as
  the proposal's phase 1 ("calibrate by testing against real apps").
- The **audit proposal** keeps the automated pipeline (commit polling, batch run of
  ~70 apps), numeric severity/exploitability scoring, JSON reports, and catalog
  badge integration.
- Both consume `references/security-rubric.md` in the plugin repo, which becomes
  the canonical home of the OAT taxonomy, pattern-check tables, and per-app-type
  capability baselines (extracted from the proposal doc; the proposal doc then
  references it rather than restating it).

## Decisions made during brainstorming

- V1 audience: reviewers, via a Claude Code skill (submitters served by the same
  skill's no-argument mode).
- Input: a GitHub repo URL; no Drupal coupling.
- Output: report plus draft feedback message; human makes the decision.
- Depth: full checklist depth including code-level security and quality reading;
  catalog-dependent checks deferred.
- Home: standalone plugin repo, not ood-appverse and not the Drupal repo, because
  reviewers don't otherwise touch either codebase and a plugin installs anywhere.
- Monorepos supported from v1, with per-app review sections and decisions.
- Modular structure — one skill file per review aspect plus a thin orchestrator
  (suggested by Travis, 2026-06-10): aspects are independently invocable and
  calibratable, run as parallel subagents, and report findings only; the
  orchestrator alone recommends the decision.
- The security aspect adopts the capability-profile / pattern-check / OAT
  methodology from the security-audit proposal instead of the checklist's three
  manual checks (pending team confirmation — open question 6).
