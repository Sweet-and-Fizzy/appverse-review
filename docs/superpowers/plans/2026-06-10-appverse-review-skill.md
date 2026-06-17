# AppVerse Review Skill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A standalone Claude Code plugin repo (`appverse-review`) with one orchestrator skill and four aspect skills (structure, security, quality, maintenance) that review AppVerse app submissions against the official checklist — usable by reviewers (GitHub URL) and submitters (current repo), per-app for monorepos.

**Architecture:** New repo at `$SITES/appverse-review`, packaged as its own Claude Code plugin marketplace. Shared references hold the canonical rubrics: the review checklist (moved from ood-appverse and modernized), a security rubric (OAT taxonomy + pattern checks + capability baselines extracted from the security-audit proposal), the cached appverse.yml schema, and a shared target-setup procedure. The `review-app` orchestrator sets up the target once, runs the four aspects as parallel subagents, and alone recommends the decision; each aspect is also independently invocable.

**Tech Stack:** Claude Code plugin (plugin.json + marketplace.json + SKILL.md files), markdown rubric references, `git`/`gh` CLI, no application code.

**Spec:** `docs/superpowers/specs/2026-06-10-appverse-review-skill-design.md` (in ood-appverse)

**Path convention:** `$SITES` is your local checkout root — the directory containing
your clones of [ood-appverse](https://github.com/Sweet-and-Fizzy/ood-appverse) and
[cyberteam_drupal](https://github.com/necyberteam/cyberteam_drupal), and where the
new `appverse-review` repo gets created. Set it before running any commands, e.g.
`export SITES=~/Sites/connectci`. `$DRUPAL` is a cyberteam_drupal checkout on the
**Collections branch** — the future state this plan targets. `RepoSyncService` and
the Collections/Repos model are NOT on the default branch yet; use the Collections
feature branch or its worktree (e.g. `export DRUPAL=$SITES/worktrees/md-2724`).

**Gates:** Two spec open questions remain — security methodology (OQ1) and the
calibration set (OQ2). Tasks 4 + 8 Step 2 (security rubric + review-security)
implement OQ1 and must wait for team sign-off. Task 3 (checklist modernization) is
no longer gated: it documents required fields RepoSyncService already enforces (the
spec moved it from open question to Decided), so it's mechanical — but Task 2 must
still verify the documented field list against the code first. All other tasks are
safe to start any time.

---

## File map

New repo `$SITES/appverse-review`:

| File | Responsibility |
|---|---|
| `.claude-plugin/plugin.json` | Plugin identity. `name` MUST be exactly `appverse-review` (produces the `/appverse-review:` namespace). |
| `.claude-plugin/marketplace.json` | Lets the repo serve as its own marketplace. |
| `references/review-checklist.md` | Canonical rubric — moved from ood-appverse and modernized. |
| `references/security-rubric.md` | OAT taxonomy, pattern checks, capability baselines — extracted from the security-audit proposal. |
| `references/appverse.yml` | Verbatim cached copy of `ood-appverse/docs/appverse.yml` (offline fallback). |
| `references/target-setup.md` | Shared setup: target/mode, schema load, repo-shape detection, findings format. |
| `skills/review-app/SKILL.md` | Orchestrator: setup once, dispatch aspects in parallel, synthesize report, recommend decision. |
| `skills/review-structure/SKILL.md` | Aspect: required files, metadata fields, YAML validity, OOD layout, broken references. |
| `skills/review-security/SKILL.md` | Aspect: capability profile, pattern checks, OAT classification. |
| `skills/review-quality/SKILL.md` | Aspect: documentation rating, portability rating, code-quality checklist. |
| `skills/review-maintenance/SKILL.md` | Aspect: gh signals, CHANGELOG, CI. |
| `tests/fixtures/broken-app/*` | Deliberately broken single-app fixture. |
| `tests/fixtures/monorepo/*` | Declared multi-app fixture. |
| `README.md` | Audience, install, usage, roadmap. |

Modified in ood-appverse:

| File | Change |
|---|---|
| `docs/app-review-checklist.md` | Replaced by a pointer to the new canonical home. |
| `docs/appverse-security-audit-proposal.md` | Gains a note that the OAT/pattern/baseline tables now live canonically in the plugin repo. |

---

### Task 1: Scaffold the plugin repo

**Files:**
- Create: `$SITES/appverse-review/.claude-plugin/plugin.json`
- Create: `$SITES/appverse-review/.claude-plugin/marketplace.json`

- [ ] **Step 1: Init the repo**

```bash
mkdir -p $SITES/appverse-review/.claude-plugin
cd $SITES/appverse-review
git init -b main
```

- [ ] **Step 2: Write plugin.json**

`.claude-plugin/plugin.json` — the `name` value is load-bearing; it must stay exactly `appverse-review`:

```json
{
  "name": "appverse-review",
  "description": "AI-assisted review of AppVerse app submissions against the official review checklist",
  "version": "0.1.0",
  "author": {
    "name": "Sweet-and-Fizzy"
  }
}
```

- [ ] **Step 3: Write marketplace.json**

`.claude-plugin/marketplace.json`:

```json
{
  "name": "appverse-review",
  "owner": {
    "name": "Sweet-and-Fizzy"
  },
  "plugins": [
    {
      "name": "appverse-review",
      "source": "./",
      "description": "AI-assisted review of AppVerse app submissions against the official review checklist"
    }
  ]
}
```

- [ ] **Step 4: Add LICENSE and .gitignore**

The repo becomes public in Task 14; license it like the apps it reviews. `LICENSE` (MIT):

```
MIT License

Copyright (c) 2026 Sweet-and-Fizzy

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

`.gitignore`:

```
.DS_Store
```

- [ ] **Step 5: Validate the plugin manifest**

Run: `claude plugin validate $SITES/appverse-review`
Expected: validation passes (no schema errors).
If `claude plugin validate` is not available in the installed CLI version, validate instead inside a Claude Code session: `/plugin marketplace add $SITES/appverse-review` — expected: marketplace appears with one plugin listed.

- [ ] **Step 6: Commit**

```bash
cd $SITES/appverse-review
git add .claude-plugin LICENSE .gitignore
git commit -m "feat: scaffold appverse-review plugin manifests"
```

---

### Task 2: Verify what the Drupal sync actually enforces

The checklist modernization (Task 3) asserts required fields for declared repos. Confirm them against the code that enforces them, so the canonical rubric documents reality.

**IMPORTANT — branch:** `RepoSyncService` exists only on the Collections branch (`$DRUPAL`, see Path convention), NOT on cyberteam_drupal's default branch. If the greps below return nothing, you are on the wrong branch — do not conclude the model is different.

**Files:**
- Read: `$DRUPAL/web/modules/custom/ood_software/src/Service/RepoSyncService.php`
- Read: `$DRUPAL/web/modules/custom/ood_software/tests/src/Unit/Service/RepoSyncServiceTest.php` (the tests document enforced behavior — often the fastest source of truth)
- Read: `$DRUPAL/web/modules/custom/ood_software/src/Plugin/GitHubService.php` (submission-time validation)

- [ ] **Step 1: Locate the validation**

```bash
grep -n "repo_sync" $DRUPAL/web/modules/custom/ood_software/ood_software.services.yml
grep -rn "support_url\|maintainer\|app_type\|required" --include="*.php" $DRUPAL/web/modules/custom/ood_software/src/Service/ $DRUPAL/web/modules/custom/ood_software/src/Plugin/GitHubService.php | head -40
```

- [ ] **Step 2: Record findings**

Answer, with file:line evidence from the Collections branch, and write the answers into a scratch note for Task 3:
1. For **declared** repos, which per-app fields cause rejection when missing? (Expected: description, software, app_type, maintainer.name, maintainer.support_url — adjust Task 3 content if the code differs.)
2. For **inferred** (manifest-only) repos, is `support_url`/contact enforced at all, or genuinely still "planned"? (Expected: not enforced — GitHub metadata is used; confirm.)
3. What is the exact list of accepted `app_type` values? Cross-check against `ood-appverse/docs/appverse.yml`. (Expected: batch-connect-basic, batch-connect-VNC, companion_app, widgets, dashboards.)
4. Is "software must match a catalog Software entry" a hard reject or save-but-unlisted? (Expected per spec research: rejected from listing but saved.)

No commit — findings feed Task 3.

---

### Task 3: Move and modernize the checklist

**Not gated (mechanical):** documents required fields RepoSyncService already
enforces — the spec lists this under Decided, not open questions. Run Task 2 first
to confirm the field list matches the code.

**Files:**
- Create: `$SITES/appverse-review/references/review-checklist.md` (copied from `$SITES/ood-appverse/docs/app-review-checklist.md`, then edited)

- [ ] **Step 1: Copy the checklist**

```bash
mkdir -p $SITES/appverse-review/references
cp $SITES/ood-appverse/docs/app-review-checklist.md \
   $SITES/appverse-review/references/review-checklist.md
```

- [ ] **Step 2: Replace "Required Criteria → 1. Repository Structure"**

Replace this block:

```markdown
### 1. Repository Structure

| Check | What to Look For |
|-------|------------------|
| `manifest.yml` exists | Has `name`, `category`, `role`, `description` at minimum. **Planned:** `contact` or `support_url` will become required — apps without one won't be listed. |
| `README.md` exists | Is substantive (not just a title) — see Documentation section |
| `LICENSE` exists | Open source license present (MIT recommended) |

For Batch Connect Apps: standard OOD structure with expected files (`form.yml`, `submit.yml.erb`, `template/`)
```

with:

```markdown
### 1. Repository Structure

Every repo, regardless of shape:

| Check | What to Look For |
|-------|------------------|
| `README.md` exists | Is substantive (not just a title) — see Documentation section |
| `LICENSE` exists | Open source license present (MIT recommended) |
| Repo shape is identifiable | Root `appverse.yml` (declared) or root `manifest.yml` (inferred) — see "Declared vs. Inferred Repos and Monorepos" below |

**Inferred repos** (root `manifest.yml`, no `appverse.yml`):

| Check | What to Look For |
|-------|------------------|
| `manifest.yml` required fields | `name`, `category`, `role`, `description` at minimum |

**Declared repos** (root `appverse.yml`), checked per app after field-precedence resolution:

| Check | What to Look For |
|-------|------------------|
| `description` | Present |
| `software` | Present; must match a Software entry in the catalog or the app won't be listed |
| `app_type` | A known value (see the [appverse.yml reference](https://github.com/Sweet-and-Fizzy/ood-appverse/blob/main/docs/appverse.yml)) |
| `maintainer.name` + `maintainer.support_url` | Both present — the catalog sync will not list an app without a support URL |
| `manifest.yml` at the app's subpath | Required for the app to actually run inside OOD |

For Batch Connect Apps: standard OOD structure with expected files (`form.yml`, `submit.yml.erb`, `template/`)
```

**Adjust the declared-repo table to match Task 2's findings** (field list, app_type values, soft-vs-hard software matching). If Task 2 found that inferred repos do enforce a support URL, add that row to the inferred table instead of dropping the old "Planned" note silently.

- [ ] **Step 3: Insert the monorepo section**

Insert after the "Duplicate Check" section (before "## Required Criteria"):

```markdown
## Declared vs. Inferred Repos and Monorepos

A repo with a root `appverse.yml` is **declared**: the contributor states how their
app(s) appear in the catalog. A repo with only a root `manifest.yml` is **inferred**:
the catalog derives a single app from that file plus GitHub metadata.

A declared repo whose `appverse.yml` has an `apps:` list is a **Monorepo**. Review
every entry in `apps[]` as its own app — each gets its own structure, security, and
quality assessment, and its own decision. Per-app fields resolve with this precedence:

1. Inline in the root `appverse.yml` `apps[]` entry (highest)
2. `<subpath>/appverse.yml`
3. `<subpath>/manifest.yml` (name/description fallback only)

Directories listed in `shared_paths` are shared code: review them once at repo level
and include them in the security review. Decisions can differ per app — e.g., accept
three apps and request changes on a fourth.

Repo-level `maintainer` and `tags` also describe the Monorepo's own catalog entry,
and they inherit into member apps: an app with no `maintainer` inherits the
repo-level one; an app's `tags` are added to (unioned with) the repo-level tags.
An app can override the maintainer by declaring its own.
```

- [ ] **Step 4: Point the security section at the security rubric**

Replace the body of "### 3. Security Concerns" (keep the heading) with:

```markdown
Security review follows the dedicated security rubric in
[`security-rubric.md`](security-rubric.md): build a capability profile for the
app's type, run the pattern checks, and classify findings under the OAT taxonomy.
The three legacy spot-checks (committed credentials, disabled security without
justification, user input reaching shell commands) are all covered by the rubric's
pattern checks.
```

- [ ] **Step 5: Update Quick Scan and the appendix template**

In "Step 1: Quick Scan", change:
`2. Check: Does it have `manifest.yml`, `README.md`, `LICENSE`?`
to:
`2. Check: Does it have `appverse.yml` or `manifest.yml`, plus `README.md` and `LICENSE`?`

In the appendix template, change:
`- [ ] manifest.yml with required fields (planned: `contact` or `support_url` will be required)`
to:
`- [ ] Required metadata fields for the repo shape (see Repository Structure)`

and change:
`- Portability: [Not portable / Partially / Portable / Highly portable]`
to:
`- Portability: [Not portable / Partially portable / Portable]`

and add below the "### Required Criteria" checkbox list:
`For Monorepos: repeat the per-app criteria and decision for each entry in `apps[]`.`

- [ ] **Step 6: Verify internal consistency**

Run: `grep -n "Highly portable\|Planned" $SITES/appverse-review/references/review-checklist.md`
Expected: no matches.

- [ ] **Step 7: Commit**

```bash
cd $SITES/appverse-review
git add references/review-checklist.md
git commit -m "feat: add canonical review checklist, modernized for declared repos and monorepos"
```

---

### Task 4: Extract the security rubric

**Gate:** implements spec open question 1 (security methodology) — adopting the
security-audit approach as review policy. Do not execute until the team signs off.

**Files:**
- Create: `$SITES/appverse-review/references/security-rubric.md`
- Source: `$SITES/ood-appverse/docs/appverse-security-audit-proposal.md`

- [ ] **Step 1: Write security-rubric.md**

The rubric is the proposal's reusable criteria, minus the pipeline/scoring/badge
material. Structure it exactly as follows, copying the three tables **verbatim**
from the proposal:

```markdown
# AppVerse Security Rubric

The canonical security criteria for AppVerse app review. Used by the
`review-security` skill today and by the automated audit pipeline (see the
security-audit proposal) later. Extracted from
`appverse-security-audit-proposal.md`; that document covers the threat model,
automated pipeline, scoring, and catalog badges.

Two complementary methods, both feeding the same threat classification:

- **Capability profiling** catalogs what an app actually does — system access,
  network calls, file reads/writes, spawned processes, dynamic code loading, auth
  posture. Batch Connect apps have a narrow expected profile, so anomalies are a
  strong malicious signal. Passenger apps have legitimately broad profiles, so the
  profile is a transparency tool; only the "Flagged" capabilities generate
  findings. An app is never penalized for doing what it is designed to do.
- **Pattern checks** catch capabilities used unsafely, regardless of app type.

## Capability baseline: Batch Connect apps

[copy the proposal's "Batch connect apps" capability table verbatim — the one with
columns Capability / Expected in / Anomalous in]

## Capability baseline: Passenger apps

[copy the proposal's "Passenger apps" capability table verbatim — the one with
columns Capability / Reported / Flagged]

**Dashboard apps and widgets:** no detailed baseline yet — apply the pattern
checks and report whatever capabilities are found.

## Pattern checks (all app types)

[copy the proposal's "Pattern checks" table verbatim — columns Pattern / What's
wrong / Threat (OAT)]

## OAT — Open OnDemand App Threats

Every finding is classified under one of these eight threat types.

[copy the proposal's OAT table verbatim — columns ID / Threat / Risk Level / What
it is]

## Rating findings

Rate each finding's severity qualitatively — High / Medium / Low — based on blast
radius (cross-user or cross-site > self-harm) and ease of triggering. Tag each
finding as **unintentional** or **potentially malicious**. Numeric
severity/exploitability scoring belongs to the automated audit pipeline, not this
rubric.
```

The four `[copy ...]` placeholders above are instructions to the implementer:
replace each with the exact markdown table(s) from the proposal document. The
"Capability profiles by app type" section contains two tables (Batch Connect,
then Passenger — don't drop the second); "Pattern checks" and "OAT — Open
OnDemand App Threats" contain one each. Do not paraphrase them.

- [ ] **Step 2: Verify the tables transferred**

Run: `grep -c "OAT-0" $SITES/appverse-review/references/security-rubric.md`
Expected: at least 8 (the eight IDs in the OAT table; the pattern-checks table
references threats by name, not ID).

- [ ] **Step 3: Commit**

```bash
cd $SITES/appverse-review
git add references/security-rubric.md
git commit -m "feat: extract canonical security rubric (OAT, pattern checks, capability baselines)"
```

---

### Task 5: Cache the schema reference

**Files:**
- Create: `$SITES/appverse-review/references/appverse.yml`

- [ ] **Step 1: Copy verbatim**

```bash
cp $SITES/ood-appverse/docs/appverse.yml \
   $SITES/appverse-review/references/appverse.yml
```

- [ ] **Step 2: Commit**

```bash
cd $SITES/appverse-review
git add references/appverse.yml
git commit -m "feat: cache appverse.yml schema reference as offline fallback"
```

---

### Task 6: Write the shared target-setup reference

**Files:**
- Create: `$SITES/appverse-review/references/target-setup.md`

- [ ] **Step 1: Write target-setup.md**

```markdown
# Target Setup (shared by all review skills)

Establish what to review before running any checks. The `review-app` orchestrator
runs this once and hands the results to each aspect; an aspect skill invoked on its
own runs it itself.

## 1. Target and mode

- A GitHub URL argument — delivered via `$ARGUMENTS` when the skill is invoked
  as a slash command (`https://github.com/<owner>/<repo>`): **reviewer mode**.
  Shallow-clone the default branch:

      TMP=$(mktemp -d) && git clone --depth 1 <url> "$TMP/repo"

  - Clone fails / repo not found: tell the user the repo may be private or
    nonexistent; suggest `gh auth login` for private repos. Stop.
  - URL is not a github.com repo URL: say only GitHub repos are supported. Stop.
- No argument: **submitter mode**. Review the current working tree. Derive
  `<owner>/<repo>` from `git remote get-url origin` if available. If the tree has
  neither `appverse.yml` nor `manifest.yml` at its root, warn that this will fail
  required criteria and confirm the directory is the app repo before continuing.

## 2. Schema

Fetch the live annotated schema:

    curl -fsSL https://raw.githubusercontent.com/Sweet-and-Fizzy/ood-appverse/main/docs/appverse.yml

If the fetch fails (offline), use the cached copy at
`${CLAUDE_PLUGIN_ROOT}/references/appverse.yml` and note in the output that the
cached schema was used.

## 3. Repo shape and app list

- Root `appverse.yml` parses → **declared repo**. If it has an `apps:` list, it is
  a **monorepo**: the app list is every `apps[].path`, with each app's fields
  resolved by precedence — inline `apps[]` entry → `<subpath>/appverse.yml` →
  `<subpath>/manifest.yml` (name/description fallback only). Repo-level
  `maintainer` and `tags` inherit into member apps (decided 2026-06-16, spec OQ7):
  **maintainer** inherits unless the app declares its own; **tags** are additive
  (app tags unioned with repo tags). NOTE: the `RepoSyncService` change
  implementing this is separate Collections-branch work; until it lands, the
  current code does NOT inherit. The skill should treat an app that relies on
  repo-level maintainer/tags as valid (per the decision) and note if the running
  sync version doesn't yet support it, rather than reject it. Record any
  `shared_paths` for repo-level review.
- Root `manifest.yml` only → **inferred repo**, one app at the repo root.
- Neither, or root appverse.yml fails to parse → record as a required-criteria
  failure and continue (do not abort). Report YAML parse errors verbatim.
- Archived on GitHub (`gh api repos/<owner>/<repo> --jq .archived`) → automatic
  required-criteria failure; still complete the review.

## 4. Findings format (all aspect skills)

Aspects report findings, never decisions or verdicts. Output one repo-level
findings table plus one per app:

| Criterion | Result | Evidence |
|---|---|---|

- Result: PASS / FAIL / WARN / NOT CHECKED.
- Evidence: `file:line` plus a short quote or description. Every FAIL/WARN needs
  evidence.
- Skip vendored and build directories: `node_modules/`, `vendor/`, `dist/`,
  `.git/`.
```

- [ ] **Step 2: Commit**

```bash
cd $SITES/appverse-review
git add references/target-setup.md
git commit -m "feat: add shared target-setup reference"
```

---

### Task 7: Build the test fixtures

Fixtures come before the skills (they are the "failing tests" the skills must catch).

**Files:**
- Create: `$SITES/appverse-review/tests/fixtures/broken-app/manifest.yml`
- Create: `$SITES/appverse-review/tests/fixtures/broken-app/form.yml`
- Create: `$SITES/appverse-review/tests/fixtures/broken-app/submit.yml.erb`
- Create: `$SITES/appverse-review/tests/fixtures/broken-app/template/script.sh.erb`
- Create: `$SITES/appverse-review/tests/fixtures/broken-app/README.md`
- Create: `$SITES/appverse-review/tests/fixtures/monorepo/appverse.yml`
- Create: `$SITES/appverse-review/tests/fixtures/monorepo/README.md`
- Create: `$SITES/appverse-review/tests/fixtures/monorepo/LICENSE`
- Create: `$SITES/appverse-review/tests/fixtures/monorepo/apps/good-app/manifest.yml`
- Create: `$SITES/appverse-review/tests/fixtures/monorepo/apps/good-app/form.yml`
- Create: `$SITES/appverse-review/tests/fixtures/monorepo/apps/bad-app/manifest.yml`
- Create: `$SITES/appverse-review/tests/fixtures/monorepo/shared/common.sh`

- [ ] **Step 1: Broken single-app fixture**

Planted defects: no LICENSE, invalid YAML in form.yml, fake committed secret, service bound to all interfaces, hardcoded cluster path, stub README, no error handling.

`tests/fixtures/broken-app/manifest.yml`:

```yaml
name: Broken Demo App
category: Interactive Apps
role: batch_connect
description: A deliberately broken fixture app for testing the review skill.
```

`tests/fixtures/broken-app/form.yml` (note the unclosed bracket — invalid YAML on purpose):

```yaml
cluster: "faster"
attributes:
  modules: [python/3.10
form:
  - modules
```

`tests/fixtures/broken-app/submit.yml.erb`:

```yaml
batch_connect:
  template: basic
script:
  native:
    - "--partition=gpu-a100"
    - "--account=hardcoded-site-account-123"
```

`tests/fixtures/broken-app/template/script.sh.erb`:

```bash
#!/bin/bash
export API_TOKEN="sk-live-FAKE1234567890abcdef"
cd /scratch/group/oursite/apps/demo
python server.py --host 0.0.0.0 --port 8080
```

`tests/fixtures/broken-app/README.md`:

```markdown
# Broken Demo App

Contact: someone@example.edu
```

- [ ] **Step 2: Monorepo fixture**

Two apps: `good-app` (complete) and `bad-app` (missing `software` and `app_type`), plus a `shared/` path.

`tests/fixtures/monorepo/appverse.yml`:

```yaml
description: Fixture monorepo with one complete and one incomplete app.
maintainer:
  name: Fixture Team
  support_url: https://github.com/example/fixture-monorepo/issues
shared_paths:
  - shared
tags:
  - "containerized"
apps:
  - path: apps/good-app
    name: Good App
    description: A complete fixture app.
    software: JupyterLab
    app_type: batch-connect-basic
    tags:
      - "gpu-enabled"
  - path: apps/bad-app
    name: Bad App
```

(Inheritance is decided behavior — spec OQ7, 2026-06-16. `good-app` declares no
maintainer, so it inherits the repo-level `Fixture Team` maintainer; its effective
tags are the union `containerized` + `gpu-enabled`. `bad-app` declares only a name
— it inherits the repo maintainer but is still missing required `description`,
`software`, and `app_type`, so it must be flagged for those, NOT for maintainer.)

`tests/fixtures/monorepo/README.md`:

```markdown
# Fixture Monorepo

Two Batch Connect apps used to test per-app review behavior.

## Requirements
JupyterLab installed on compute nodes.

## Installation
Clone into your OOD app directory.

## Configuration
Edit `form.yml` cluster attributes per site.
```

`tests/fixtures/monorepo/LICENSE`:

```
MIT License

Copyright (c) 2026 Fixture Team

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

`tests/fixtures/monorepo/apps/good-app/manifest.yml`:

```yaml
name: Good App
category: Interactive Apps
role: batch_connect
description: A complete fixture app.
```

`tests/fixtures/monorepo/apps/good-app/form.yml`:

```yaml
cluster: "{{ cluster }}"
attributes:
  hours:
    widget: number_field
    min: 1
    max: 48
    value: 4
form:
  - hours
```

`tests/fixtures/monorepo/apps/bad-app/manifest.yml`:

```yaml
name: Bad App
category: Interactive Apps
role: batch_connect
description: Incomplete fixture app missing declared metadata.
```

`tests/fixtures/monorepo/shared/common.sh`:

```bash
#!/bin/bash
set -e
log() { echo "[fixture] $*"; }
```

- [ ] **Step 3: Commit**

```bash
cd $SITES/appverse-review
git add tests
git commit -m "test: add broken-app and monorepo review fixtures"
```

---

### Task 8: Write the four aspect skills

**Files:**
- Create: `$SITES/appverse-review/skills/review-structure/SKILL.md`
- Create: `$SITES/appverse-review/skills/review-security/SKILL.md`
- Create: `$SITES/appverse-review/skills/review-quality/SKILL.md`
- Create: `$SITES/appverse-review/skills/review-maintenance/SKILL.md`

Every aspect shares two rules: if the orchestrator provided a prepared target (repo path, mode, shape, app list, shared_paths), use it; otherwise follow `${CLAUDE_PLUGIN_ROOT}/references/target-setup.md` first. And aspects output findings in target-setup.md §4 format — never decisions.

**Gate:** Step 2 (review-security) implements spec open question 1 (security methodology) and depends on Task 4's rubric — blocked on team sign-off. The other three aspects are not gated.

- [ ] **Step 1: review-structure**

`skills/review-structure/SKILL.md`:

```markdown
---
name: review-structure
description: Check an AppVerse app repo's structure — required files, required metadata fields, YAML validity, standard OOD layout, broken references. Use for the structure aspect of an AppVerse review, or when asked to check an OOD app repo's structure or metadata.
argument-hint: "[github-url]"
---

# Structure Review (aspect)

Criteria: `${CLAUDE_PLUGIN_ROOT}/references/review-checklist.md` — sections
"Repository Structure", "Documentation Minimum" (the substantive-README gate
only; rating is review-quality's job), and "Basic Functionality".

**Setup:** Use the orchestrator's prepared target if provided; otherwise follow
`${CLAUDE_PLUGIN_ROOT}/references/target-setup.md` first.

## Repo-level checks

- `README.md` exists and is substantive: not the unfilled template (placeholder
  text like "Key feature 1"), not just a title and contact line.
- `LICENSE` exists and contains an open-source license.
- Repo shape identifiable: `appverse.yml` or `manifest.yml` at root.
- Repo is not archived on GitHub.

## Per-app checks (use the resolved field set from setup)

- Required metadata fields for the repo shape, per the checklist's Repository
  Structure section.
- `app_type` is a known value per the appverse.yml schema reference.
- Every `manifest.yml`, `appverse.yml`, and `form.yml` parses; report parse
  errors verbatim.
- ERB templates look renderable (balanced `<%= %>` tags); shell scripts pass
  `bash -n`.
- No broken references: variables and attributes used in `submit.yml.erb` and
  `template/` files exist in `form.yml`.
- Batch Connect apps have the standard layout: `form.yml`, `submit.yml.erb`,
  `template/`.

## Output

Findings tables per target-setup.md §4: one repo-level table, one per app.
```

- [ ] **Step 2: review-security**

`skills/review-security/SKILL.md`:

```markdown
---
name: review-security
description: Security review of an AppVerse / Open OnDemand app repo — capability profile, unsafe-pattern checks, OAT threat classification. Use for the security aspect of an AppVerse review, or when asked to security-audit an OOD app.
argument-hint: "[github-url]"
---

# Security Review (aspect)

Rubric: `${CLAUDE_PLUGIN_ROOT}/references/security-rubric.md` — read it before
starting. It defines the capability baselines per app type, the pattern checks,
and the OAT threat taxonomy.

**Setup:** Use the orchestrator's prepared target if provided; otherwise follow
`${CLAUDE_PLUGIN_ROOT}/references/target-setup.md` first.

## Procedure

1. Determine each app's type (Batch Connect, Passenger, dashboard, widget) from
   its manifest `role` / declared `app_type` — the capability baseline differs.
2. Identify in-scope files. Batch Connect: `form.yml(.erb)`, `submit.yml.erb`,
   `template/**`, `connection.yml`, container definitions. Passenger: the full
   application source (routes, controllers, views, config, scripts). Always
   include `shared_paths`. List binary files that cannot be audited.
3. **Capability profile** — catalog what the code actually does: system access,
   network calls, file reads and writes, spawned processes, dynamic code loading,
   authentication posture.
   - Batch Connect: compare against the narrow baseline; anomalies (network calls
     from ERB, SSH-key reads, base64-decode-and-execute, writes to dotfiles or
     cron) are strong signals — flag each as a finding.
   - Passenger: report the full profile for transparency; flag only capabilities
     in the rubric's "Flagged" column. Never penalize an app for its designed
     purpose — a job composer running shell commands is its job; running them
     with CORS open to all origins is a finding.
4. **Pattern checks** — apply the rubric's pattern table across all in-scope
   files.
5. Classify every finding under OAT-01..08, rate severity High / Medium / Low,
   and tag it unintentional or potentially malicious, per the rubric's "Rating
   findings" section.

## Output

- The capability profile: a compact File / Capabilities / Anomalies table for
  Batch Connect apps; a short narrative for Passenger apps.
- Findings tables per target-setup.md §4, with two extra columns: OAT class and
  severity.

No decisions, no numeric risk scores.
```

- [ ] **Step 3: review-quality**

`skills/review-quality/SKILL.md`:

```markdown
---
name: review-quality
description: Quality review of an AppVerse app repo — documentation rating, configuration portability, code-quality checklist. Use for the quality aspect of an AppVerse review, or when asked to assess an OOD app's documentation or code quality.
argument-hint: "[github-url]"
---

# Quality Review (aspect)

Criteria: `${CLAUDE_PLUGIN_ROOT}/references/review-checklist.md` — section
"Quality Criteria" (Documentation Quality, Configuration Portability, Code
Quality), including the target-for-inclusion thresholds.

**Setup:** Use the orchestrator's prepared target if provided; otherwise follow
`${CLAUDE_PLUGIN_ROOT}/references/target-setup.md` first.

## Per-app assessment

- **Documentation**: rate Minimal / Adequate / Strong / Exemplary against the
  checklist's documentation table and its four README questions (what does it
  launch, what must be installed, how to deploy, what to customize). One-line
  justification citing README sections present or missing.
- **Configuration portability**: rate Not portable / Partially portable /
  Portable. Look for hardcoded cluster names, partitions, accounts, absolute
  site paths, and module versions in `submit.yml.erb`, `form.yml`, and
  `template/` scripts.
- **Code quality** checkboxes, each PASS/FAIL/WARN with evidence: error handling
  (`set -e` or explicit checks), no uncommented magic numbers, no large
  duplicated blocks, no commented-out dead code, form input validation
  (min/max/required), ERB templates handle missing or empty values gracefully.

## Output

Per app: the two ratings with one-line justifications, then a findings table per
target-setup.md §4 for the code-quality items. Note which target-for-inclusion
thresholds (Adequate+ docs, Partially portable+) are not met — as findings, not
decisions.
```

- [ ] **Step 4: review-maintenance**

`skills/review-maintenance/SKILL.md`:

```markdown
---
name: review-maintenance
description: Maintenance-signal review of an AppVerse app repo — commit recency, releases, issue responsiveness, contributors, CHANGELOG, CI. Use for the maintenance aspect of an AppVerse review, or when asked whether an app repo looks actively maintained.
argument-hint: "[github-url]"
---

# Maintenance Review (aspect)

Criteria: `${CLAUDE_PLUGIN_ROOT}/references/review-checklist.md` — section
"Maintenance Signals", including its target-for-inclusion line and the
brand-new-app waiver.

**Setup:** Use the orchestrator's prepared target if provided; otherwise follow
`${CLAUDE_PLUGIN_ROOT}/references/target-setup.md` first. This aspect needs
`<owner>/<repo>`; in submitter mode derive it from the git remote.

## Signals

With the `gh` CLI:

    gh api repos/<owner>/<repo> --jq '{pushed_at, archived, open_issues_count}'
    gh api repos/<owner>/<repo>/releases --jq 'length'
    gh api repos/<owner>/<repo>/contributors --jq 'length'
    gh api 'repos/<owner>/<repo>/issues?state=open&per_page=5' --jq '.[].comments'

In the working tree: CHANGELOG file present and current; CI configuration
present (`.github/workflows/`, or equivalent).

If `gh` is missing or unauthenticated: use `git log -1 --format=%ci` for
last-commit age and mark the other signals NOT CHECKED.

## Output

One repo-level table — Signal / Value / Assessment (Good sign / Concern, per the
checklist's table) — followed by a findings table per target-setup.md §4 for
anything below the checklist's target (e.g., no activity in over 12 months, no
releases). Apply the checklist's brand-new-app waiver where relevant and say so.
```

- [ ] **Step 5: Commit**

```bash
cd $SITES/appverse-review
git add skills/review-structure skills/review-security skills/review-quality skills/review-maintenance
git commit -m "feat: add the four review aspect skills"
```

---

### Task 9: Write the orchestrator skill

**Files:**
- Create: `$SITES/appverse-review/skills/review-app/SKILL.md`

- [ ] **Step 1: Write the skill**

````markdown
---
name: review-app
description: Full AppVerse submission review — structure, security, quality, and maintenance — with a recommended decision and draft feedback. Use when asked to review an app submission or app repo for AppVerse, to check a repo before submitting it to AppVerse, or when given a GitHub URL of an Open OnDemand app to review.
argument-hint: "[github-url]"
---

# AppVerse App Review (orchestrator)

Produce an evidence-backed review with a recommended decision. You recommend; a
human decides.

Read first:
- `${CLAUDE_PLUGIN_ROOT}/references/review-checklist.md` (canonical criteria,
  including the decision rules in its Step 4)
- `${CLAUDE_PLUGIN_ROOT}/references/target-setup.md` (setup procedure and
  findings format)

## 1. Set up the target

Follow target-setup.md sections 1–3 once. You now have: mode (reviewer or
submitter), repo path, `<owner>/<repo>` if known, repo shape, the app list with
resolved fields, and `shared_paths`.

## 2. Run the four aspects in parallel

Dispatch four subagents concurrently — one per aspect: review-structure,
review-security, review-quality, review-maintenance. Each subagent's prompt:

> Read `${CLAUDE_PLUGIN_ROOT}/skills/<aspect>/SKILL.md` and follow it exactly.
> Prepared target (do not redo setup): repo path: <path>; mode: <mode>;
> owner/repo: <owner/repo or unknown>; repo shape: <shape>; apps: <list of
> path + resolved fields>; shared_paths: <list>; schema source: <live|cached>.
> Return only your findings in the skill's output format. Do not make accept or
> reject judgments.

If subagent dispatch is unavailable, run the four aspect skill files yourself,
one at a time, in the order above.

## 3. Synthesize the report

```markdown
# AppVerse Review: <repo name>

**Repository:** <url or path>  **Mode:** reviewer|submitter  **Date:** <today>
**Repo shape:** declared monorepo (N apps) | declared single app | inferred single app

## Repo-level required criteria

| Criterion | Result | Evidence |
|---|---|---|
| README.md substantive | PASS/FAIL | ... |
| LICENSE present | PASS/FAIL | ... |
| Repo not archived | PASS/FAIL/NOT CHECKED | ... |
| shared_paths security review | PASS/FAIL/N-A | ... |

## Maintenance signals

| Signal | Value | Assessment |
|---|---|---|
| Last commit | ... | ... |
| Releases | ... | ... |
| Issues responsiveness | ... | ... |
| Contributors | ... | ... |
| CHANGELOG | ... | ... |
| CI | ... | ... |

## App: <name> (<subpath>)

### Required criteria
| Criterion | Result | Evidence |
|---|---|---|
| Required metadata fields | PASS/FAIL | ... |
| YAML validity (manifest/form) | PASS/FAIL | ... |
| Standard OOD structure | PASS/FAIL | ... |
| No broken references | PASS/FAIL | ... |

### Security
<capability profile: table for Batch Connect, narrative for Passenger>

| Finding | OAT | Severity | Evidence |
|---|---|---|---|

### Quality
- Documentation: <rating> — <one-line justification>
- Portability: <rating> — <one-line justification>
- Code quality: <met/missed checkboxes with evidence>

### Recommended decision: <Accept | Accept with suggestions | Request changes | Reject>

## Not checked (requires catalog access)
- Duplicate check against the existing catalog
- `software` value matches a catalog Software entry

## Overall recommendation
<one paragraph; for monorepos, summarize per-app decisions>
```

Decision rules are the checklist's Step 4 table. Security findings count as
"security concerns" for its Reject row only when tagged potentially malicious or
when the exposure cannot be fixed without redesigning the app; a fixable
misconfiguration — even High severity, like CORS open to all origins — points to
Request changes, not Reject. **Any Accept must be worded as conditional on the
human reviewer completing the duplicate/catalog checks listed under "Not
checked".**

## 4. Mode-specific ending

- **Reviewer mode:** append a draft contributor feedback message using the
  checklist's feedback guidance (specific, references files, links the README
  template or best-practices guide where relevant). Plain prose paragraphs,
  ready to paste into a Drupal moderation comment or GitHub issue. Label it
  "Draft feedback — edit before sending."
- **Submitter mode:** append a prioritized "Fix before submitting" list instead —
  required-criteria failures first (security findings at the top), then quality
  improvements, each with the file to change.

## 5. Wrap up

- Print the full report in the conversation.
- Offer to save it as `review-<owner>-<repo>.md` in the current directory.
- Reviewer mode: remove the temp clone (`rm -rf "$TMP"`).
````

- [ ] **Step 2: Commit**

```bash
cd $SITES/appverse-review
git add skills/review-app
git commit -m "feat: add review-app orchestrator skill"
```

---

### Task 10: Install locally and smoke-test

- [ ] **Step 1: Install from the local marketplace**

In a Claude Code session (any directory):

```
/plugin marketplace add $SITES/appverse-review
/plugin install appverse-review@appverse-review
```

Expected: plugin installs; `/appverse-review:review-app` and the four aspect skills appear in the slash-command list.

- [ ] **Step 2: Full review against a real repo**

```
/appverse-review:review-app https://github.com/EpiGenomicsCode/ProteinStructure-OOD
```

(The checklist itself cites this repo as a good example.)

Expected:
- Target set up once; four aspect subagents dispatched in parallel.
- Report contains: repo-level criteria table, maintenance signals with real values, one app section including a capability profile and OAT-classified security findings (likely none or Low), quality ratings with justifications, "Not checked" catalog section, an overall recommendation conditional on the duplicate check, and a draft feedback message.
- Temp clone removed afterward.

- [ ] **Step 3: One aspect standalone**

```
/appverse-review:review-security https://github.com/EpiGenomicsCode/ProteinStructure-OOD
```

Expected: the aspect performs its own target setup, outputs a capability profile and findings only — no decision, no report wrapper.

- [ ] **Step 4: Fix anything that failed and commit**

```bash
cd $SITES/appverse-review
git add -A
git commit -m "fix: smoke-test corrections"
```

---

### Task 11: Test submitter mode against the broken fixture

- [ ] **Step 1: Run with cwd inside the fixture**

Start Claude Code in `$SITES/appverse-review/tests/fixtures/broken-app` and run `/appverse-review:review-app` with no argument.

Expected findings (all six must appear, with evidence):
1. LICENSE missing → required-criteria FAIL (structure).
2. `form.yml` invalid YAML → FAIL with the parse error quoted (structure).
3. Committed secret `API_TOKEN="sk-live-..."` in `template/script.sh.erb` → security finding, OAT-02 Credential Exposure, High (security).
4. Service bound to `0.0.0.0` → security finding, OAT-05 Network Exposure (security).
5. Hardcoded account/partition in `submit.yml.erb` and `/scratch/group/oursite` path → portability "Not portable" (quality).
6. README is a stub → substantive-README FAIL (structure), documentation "Minimal" (quality).

Expected ending: a prioritized "Fix before submitting" list with security items first. Expected recommendation: Request changes or Reject on security grounds — either is acceptable if the credential finding is cited.

- [ ] **Step 2: Tune the relevant aspect skill (not the orchestrator) until all six findings appear, then commit**

```bash
cd $SITES/appverse-review
git add skills
git commit -m "fix: tune aspect detection against broken-app fixture"
```

---

### Task 12: Test monorepo handling

- [ ] **Step 1: Run with cwd inside the monorepo fixture**

Start Claude Code in `$SITES/appverse-review/tests/fixtures/monorepo` and run `/appverse-review:review-app` with no argument.

Expected:
- Repo shape reported as "declared monorepo (2 apps)".
- Two app sections: `Good App (apps/good-app)` and `Bad App (apps/bad-app)`.
- Bad App fails required metadata for `description`, `software`, and `app_type` — but NOT for maintainer: it inherits the repo-level `Fixture Team` maintainer (decided inheritance, spec OQ7).
- Good App passes required metadata: it inherits the repo maintainer, and its effective tags are the union of repo (`containerized`) + app (`gpu-enabled`).
- `shared/common.sh` reviewed once at repo level (shared_paths row + included in the security pass).
- Per-app decisions differ; overall recommendation summarizes both.

- [ ] **Step 2: Tune until per-app behavior is correct, then commit**

```bash
cd $SITES/appverse-review
git add skills references
git commit -m "fix: tune monorepo handling against fixture"
```

---

### Task 13: Write the README

**Files:**
- Create: `$SITES/appverse-review/README.md`

- [ ] **Step 1: Write README.md**

````markdown
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

## Install

In [Claude Code](https://claude.com/claude-code):

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
detection — Monorepos are reviewed per app), then runs the four aspects as
parallel subagents and synthesizes the report and recommended decision.

The security aspect builds a **capability profile** of what the app actually
does, runs unsafe-pattern checks, and classifies findings under the OAT (Open
OnDemand App Threats) taxonomy — narrow-baseline anomaly detection for Batch
Connect apps, transparency profiling for Passenger apps.

## Roadmap

- **Phase 2 — GitHub Action**: a workflow contributors can drop into their app
  repos so the review runs in CI on every push.
- **Phase 3 — Drupal integration**: the AppVerse site calls the Claude API when
  a submission reaches review and attaches the report for the human reviewer.
- **Automated security audits**: the per-commit audit pipeline, numeric risk
  scoring, and catalog badges described in the AppVerse security-audit proposal
  consume the same [security rubric](references/security-rubric.md).
````

- [ ] **Step 2: Commit**

```bash
cd $SITES/appverse-review
git add README.md
git commit -m "docs: add README with install, usage, and roadmap"
```

---

### Task 14: Publish to GitHub and verify remote install

**Confirm with Andrew before this task** — it creates a public repo under Sweet-and-Fizzy.

- [ ] **Step 1: Create and push**

```bash
cd $SITES/appverse-review
gh repo create Sweet-and-Fizzy/appverse-review --public --source . --push
```

Expected: repo exists at https://github.com/Sweet-and-Fizzy/appverse-review with all commits.

- [ ] **Step 2: Verify remote marketplace install**

In a Claude Code session:

```
/plugin marketplace remove appverse-review
/plugin marketplace add Sweet-and-Fizzy/appverse-review
/plugin install appverse-review@appverse-review
/appverse-review:review-app https://github.com/EpiGenomicsCode/ProteinStructure-OOD
```

Expected: install succeeds from GitHub; the review runs identically to Task 10.

---

### Task 15: Point ood-appverse docs at the new canonical homes

Runs after Task 14 — the links below 404 until the repo is published.

**Files:**
- Modify: `$SITES/ood-appverse/docs/app-review-checklist.md` (full replacement)
- Modify: `$SITES/ood-appverse/docs/appverse-security-audit-proposal.md` (add one note)

- [ ] **Step 1: Replace the checklist file content**

```markdown
# Appverse App Review Checklist

This checklist has moved. The canonical version now lives in the
[appverse-review](https://github.com/Sweet-and-Fizzy/appverse-review) repo:

**[Review checklist (canonical)](https://github.com/Sweet-and-Fizzy/appverse-review/blob/main/references/review-checklist.md)**

That repo also ships a Claude Code plugin that runs the checklist as an
AI-assisted review — see its README for install and usage.
```

- [ ] **Step 2: Add the note to the security-audit proposal**

Insert immediately after the "## Two ways to catch things" heading:

```markdown
> **Note (2026-06):** The reusable criteria below — the capability baselines,
> pattern checks, and OAT taxonomy — now live canonically in
> [appverse-review/references/security-rubric.md](https://github.com/Sweet-and-Fizzy/appverse-review/blob/main/references/security-rubric.md),
> where the `review-security` skill applies them on demand. This document
> remains the home of the threat model, automated pipeline, scoring, and badge
> design.
```

- [ ] **Step 3: Stage in ood-appverse and provide a commit message**

Per Andrew's workflow, stage and supply the message; he runs the commit:

```bash
cd $SITES/ood-appverse
git add docs/app-review-checklist.md docs/appverse-security-audit-proposal.md
```

Suggested message: `docs: point review checklist and security rubric at appverse-review canonical homes`

---

### Task 16: Calibration

- [ ] **Step 1: General calibration set**

Ask Andrew for 2–3 submission repos that have already been human-reviewed, with the human decision for each (ideally one accept, one request-changes, one reject). Run `/appverse-review:review-app <url>` for each and compare the recommended decision and key findings with the human review.

- [ ] **Step 2: Security-aspect calibration against a known Passenger app**

```
/appverse-review:review-security https://github.com/tamu-edu/dor-hprc-drona-composer
```

The security-audit proposal analyzed this app, so expected results are known:
- Capability profile (narrative, Passenger) reports: shell execution via PTY from browser, file access at user paths, detached background processes, importlib dynamic loading, CORS enabled, SQLite, PUN-only auth.
- The designed capabilities (shell execution, file access, dynamic loading, background processes) appear in the profile, NOT as findings.
- CORS open to all origins appears as a finding: OAT-05 Network Exposure, High.
- In a full `/appverse-review:review-app` run on this repo, the High CORS finding leads to **Request changes, not Reject** — it's a fixable misconfiguration. If the orchestrator maps High severity to Reject bluntly, that undoes the rubric's "don't penalize design" philosophy; fix the orchestrator's decision rules, not the rubric.

If designed capabilities show up as findings, or CORS doesn't, tune `review-security`/`security-rubric.md`.

- [ ] **Step 3: Tune and commit**

Where outcomes diverge, determine whether the skill missed evidence, over-weighted a criterion, or the rubric itself is ambiguous. Adjust the aspect skills (detection emphasis), the orchestrator (decision rules), or the rubrics (genuine ambiguities). Commit:

```bash
cd $SITES/appverse-review
git add -A
git commit -m "fix: calibrate review skills against known-outcome repos"
git push
```
