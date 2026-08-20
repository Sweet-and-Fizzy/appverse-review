# Appverse App Review Checklist

> **Related Docs:**
> [Appverse Contributor Guide](https://openondemand.connectci.org/appverse-contributor-documentation) |
> [Appverse Security Rubric](https://openondemand.connectci.org/appverse-security-rubric) |
> [Appverse Best Practices](https://openondemand.connectci.org/appverse-best-practices) |
> [Appverse README Template](https://github.com/tamu-edu/appverse_readme_template)

A guide for reviewers evaluating whether a new app should be included in the Appverse catalog.

## Overview

The goal of review is to ensure that apps in the catalog are **useful, deployable, and maintainable** by the broader HPC community. We're not looking for perfection — we're looking for apps that meet a quality bar and don't create confusion in the catalog.

## Decision Framework

### Should This App Exist in the Catalog?

Ask these questions first, before evaluating quality:

| Question | If No... |
|----------|----------|
| Does this app serve software not already in the catalog? | See "Duplicate Check" below |
| Is the repository public and accessible? | Cannot be included — public repo required |
| Does it have an open source license? | Cannot be included — license required |
| Is there a maintainer who will respond to issues? | Flag as a risk — orphaned apps hurt the catalog |

### Duplicate Check

If the software already has apps in the catalog:

- **Same app, different site config** → Reject. Encourage the contributor to document their configuration in the existing app or contribute changes upstream.
- **Same app, forked with minor changes** → Reject unless the fork adds significant new capability. Encourage contributing back upstream.
- **Same software, meaningfully different approach** → Accept. Examples: containerized vs. module-based, GPU vs. CPU, different execution model (e.g., AlphaFold 2 vs. AlphaFold 3 support).

Document the rationale either way — the review report has a duplicate-check
rationale field under "Not checked" for this; fill it in before pasting the
feedback into the issue or email.

### Software Entry Check

The app's `software` value must match a Software entry in the catalog or the app
won't be listed. Software is its own catalog node type, created separately from
the app — the app form only references an existing Software entry, it cannot
create one. If there is no matching entry, it is the reviewer's decision, not an
automatic failure:

- **Software should exist in the catalog** → create the Software entry first
  using the [Add Appverse Software form](https://openondemand.connectci.org/node/add/appverse_software)
  (reviewer login required), then the app can reference it and list.
- **Typo, or maps to an existing entry under a different name** → ask the
  contributor to correct the `software` value.
- **Not appropriate for the catalog** → Request changes, with the reason.

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

## Required Criteria

All of these must be met for inclusion. These are pass/fail.

### 1. Repository Structure

Every repo, regardless of shape:

| Check | What to Look For |
|-------|------------------|
| `README.md` exists | Is substantive (not just a title) — see Documentation section |
| `LICENSE` exists | Open source license present (MIT recommended) |
| Repo shape is identifiable | Root `appverse.yml` (declared) or root `manifest.yml` (inferred) — see "Declared vs. Inferred Repos and Monorepos" above |

**Inferred repos** (root `manifest.yml`, no `appverse.yml`):

| Check | What to Look For |
|-------|------------------|
| `manifest.yml` required fields | `name`, `category`, `role`, `description` at minimum |

**Declared repos** (root `appverse.yml`), checked per app after field-precedence resolution:

| Check | What to Look For |
|-------|------------------|
| `description` | Present |
| `software` | Present (checked here). It must also match a catalog Software entry to be listed — see Software Entry Check for what to do when it doesn't |
| `app_type` | A known value (see the [appverse.yml reference](https://github.com/Sweet-and-Fizzy/ood-appverse/blob/main/docs/appverse.yml)) |
| `maintainer.name` + `maintainer.support_url` | Both required and present. An app without a support URL gives deployers no one to contact — a missing one is a required-criteria failure |
| `manifest.yml` at the app's subpath | Required for the app to actually run inside OOD |

For Batch Connect Apps: standard OOD structure with expected files (`form.yml` or `form.yml.erb`, `submit.yml.erb`, `template/`). OOD renders `form.yml.erb` at request time, so an app shipping only the `.erb` variant is complete; shipping both is unusual and worth a look

### 2. Documentation Minimum

The README should follow the [Appverse README Template](https://github.com/tamu-edu/appverse_readme_template) structure. At minimum, it must answer these questions for an HPC admin who has never seen the app:

| Question | Where to Find It |
|----------|-----------------|
| What does this app launch? | Overview section |
| What needs to be installed on compute nodes? | Requirements section and Software Installation in References section |
| How do I deploy it? | Installation section |
| What do I need to customize? | Configuration section |

**Red flags:**
- README is still the unfilled template (placeholder text like "Key feature 1" still present)
- README only contains a project name and/or contact email
- README references a different institution's paths without noting they need to change
- No Configuration section — deployers can't tell what to customize

### 3. Security Concerns

Security review follows the dedicated [Appverse Security
Rubric](https://openondemand.connectci.org/appverse-security-rubric): build a
capability profile for the app's type, run the pattern checks, and classify
findings under the OODT taxonomy.
The three legacy spot-checks (committed credentials, disabled security without
justification, user input reaching shell commands) are all covered by the rubric's
pattern checks.

### 4. Basic Functionality

| Check | What to Look For |
|-------|------------------|
| `form.yml` or `form.yml.erb` is valid | `form.yml` parses without errors; `form.yml.erb` has balanced ERB tags (it cannot be YAML-parsed directly) |
| `manifest.yml` is valid YAML | Parses without errors |
| Template scripts are syntactically correct | ERB templates render, shell scripts pass `bash -n` (for `.sh.erb`, strip ERB tags first — see [security-tools.md](https://github.com/Sweet-and-Fizzy/appverse-review/blob/main/references/security-tools.md)). Shellcheck is a best-effort tier 2 tool — run it when available, but its absence does not fail this criterion |
| No obviously broken references | Module names, paths, and variables referenced in templates exist in `form.yml` or `form.yml.erb` |

## Quality Criteria

These are evaluated on a scale. An app doesn't need to be perfect, but the more boxes checked, the better.

### Documentation Quality

| Level | Description |
|-------|-------------|
| **Minimal** | What it launches + prerequisites only |
| **Adequate** | Above + installation + configuration + known limitations |
| **Strong** | Above + troubleshooting + screenshots + environment variable docs |
| **Exemplary** | Above + user-facing info panel + architecture explanation |

**Target for inclusion:** Adequate or above.

### Configuration Portability

| Level | Description |
|-------|-------------|
| **Not portable** | Hardcoded paths, cluster names, module versions throughout |
| **Partially portable** | Some hardcoding, but main config is in form.yml attributes |
| **Portable** | All site-specific values centralized and clearly marked |

**Target for inclusion:** Partially portable or above. If "Not portable," ask the contributor to centralize configuration before accepting.

### Code Quality

| Check | Status |
|-------|--------|
| Error handling in scripts (`set -e` or explicit checks) | |
| No undocumented magic numbers or hardcoded literals (resource limits, tunables, ports, hex colors, module versions) without comments | |
| No large blocks of duplicated code | |
| No commented-out dead code | |
| Input validation on form fields (min/max/required) | |
| ERB templates handle missing/empty values gracefully | |

**Target for inclusion:** At least error handling and input validation. Other items are improvement suggestions.

## Maintenance Signals

Repo-level signals about the project's health.

| Signal | Good Sign | Concern |
|--------|-----------|---------|
| Last commit | Within 12 months | Over 2 years ago |
| Releases | Tagged releases with versioning | No releases |
| Issues | Responded to | Open issues with no response |
| Contributors | Multiple | Single contributor with no activity |
| CHANGELOG | Present and current | Missing |
| CI/CD | A workflow that lints shell/ERB or validates the YAML (`.github/workflows/` or equivalent) | None |

**Target for inclusion:** Active within 12 months. For brand-new apps, waive the history requirement but flag for follow-up review in 6 months.

The other signals — tagged releases, issue responsiveness, contributors, CHANGELOG, CI — are good-practice indicators, not requirements. There is no requirement to cut releases or use versioning; a release is a positive signal that the team follows good practices, and its absence is worth a suggestion, never a failure. CI is the weakest of these for an app repo: most Appverse apps are config-and-template repos with little to test beyond YAML validity and shell/ERB lint, which Appverse Review already checks — so weight a missing CI workflow low.

## Review Process

### Where to Find Pending Submissions

Apps awaiting review appear in the Manage Appverse Apps view in Drupal: [openondemand.connectci.org/appverse/manage-apps](https://openondemand.connectci.org/appverse/manage-apps). The view shows the submitter's name and email so you can follow up with questions, the moderation state, and a link to edit the app node.

Most of the checks below are performed by **Appverse Review**, which produces an
evidence-backed report covering structure, security, quality, and maintenance,
with file:line findings and a recommended decision. The reviewer receives this
report, verifies its findings, and makes the call — the review recommends, a
human decides.

### Step 1: Start from the review report

Begin with the Appverse Review report for the submitted repo. Note the commit it
was run against — the report pins a commit SHA, and its file:line findings are
only valid for that commit. If the repo has moved on since, get a fresh report
before continuing.

### Step 2: Verify the findings

Read the report against the repo and confirm its findings hold, rather than
taking them on trust. Spot-check that:

1. Required files and metadata are as the report states — `appverse.yml` or
   `manifest.yml`, `README.md`, `LICENSE`, standard OOD structure.
2. Security findings are real and correctly rated — open a few and check the
   cited `file:line` actually shows the flagged pattern.
3. Quality ratings and any correctness-&-polish findings match what you see —
   documentation level, portability, and any copy-paste artifacts or typos.
4. Maintenance signals are current — last commit, releases, CI, CHANGELOG.
5. The duplicate check is settled — the review cannot see the catalog, so this is
   the reviewer's to confirm (see Duplicate Check above).

Trust the report's structure but verify its substance; if a finding does not
hold, correct it before it reaches the contributor.

### Step 3: Decision

| Outcome | Criteria |
|---------|----------|
| **Accept** | Passes all required criteria, adequate+ documentation, partially portable+ config. Always conditional on the duplicate/catalog checks the review cannot perform — word any Accept as pending those. |
| **Accept with suggestions** | Passes required criteria but has clear improvement areas — include specific feedback. Below-target docs or portability belongs here, not Request changes, when required criteria are otherwise met. |
| **Request changes** | Missing required criteria but fixable — provide specific list of what to address. A fixable security misconfiguration, even High severity (e.g. CORS open to all origins), is Request changes, not Reject. |
| **Reject** | Duplicate app, no license, abandoned/unmaintained, not an OOD app, or a security finding tagged potentially malicious or unfixable without redesigning the app. |

### Providing Feedback

When requesting changes or suggesting improvements, be specific:

**Good feedback:**
> The README lists prerequisites but doesn't include installation steps. Please add a section showing how to clone and deploy the app (see [ProteinStructure-OOD](https://github.com/EpiGenomicsCode/ProteinStructure-OOD) for an example).

**Poor feedback:**
> README needs work.

Reference the [Best Practices Guide](https://openondemand.connectci.org/appverse-best-practices) for specific recommendations to share with contributors.

## Common Issues Found in Real Apps

Based on analysis of apps currently in the Appverse:

| Issue | Frequency | Severity |
|-------|-----------|----------|
| Missing or stub README | Common | High — blocks deployment |
| No error handling in scripts | Very common | Low — causes silent failures |
| Hardcoded paths | Common | Medium — blocks portability |
| No releases or versioning | Common | Low — but makes updates risky |
| Missing CHANGELOG | Common | Low — but reduces trust |
| No troubleshooting docs | Very common | Low — but increases support burden |
| Dead/commented-out code | Occasional | Low — but confusing |
| Magic numbers without comments | Occasional | Low — but hinders maintenance |
| Security settings disabled without explanation | Rare | High — potential vulnerability |

## Appendix: Review Template

Copy this template when reviewing a new app submission:

```markdown
## App Review: [App Name]

**Repository:** [URL]
**Reviewed commit:** [SHA] ([date])
**Reviewer:** [Name]
**Date:** [Date]

### Required Criteria
- [ ] Required metadata fields for the repo shape (see Repository Structure)
- [ ] README.md (substantive)
- [ ] LICENSE (open source)
- [ ] Standard OOD app structure

For Monorepos: repeat the per-app criteria and decision for each entry in `apps[]`.

### Security
- Findings classified under the OODT taxonomy, with severity and file:line evidence

### Quality Assessment
- Documentation: [Minimal / Adequate / Strong / Exemplary]
- Portability: [Not portable / Partially portable / Portable]
- Code quality and correctness-&-polish findings, with file:line evidence

### Maintenance Signals
- [Active / Moderate / Inactive] — last commit, releases, CI, CHANGELOG

### Not Checked (requires catalog access)
- [ ] Duplicate check against the existing catalog
- [ ] `software` value matches a catalog Software entry (see Software Entry Check — create the entry if the software should exist)

### Decision: [Accept / Accept with suggestions / Request changes / Reject]
- Accept is conditional on the Not Checked items above

### Feedback
[Specific items to address or improve — every item must already appear above]
```
