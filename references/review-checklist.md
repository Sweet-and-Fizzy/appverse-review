# Appverse App Review Checklist

> **Related Docs:**
> [Appverse Contributor Guide](https://openondemand.connectci.org/appverse-contributor-documentation) |
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

Document the rationale either way.

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
| `software` | Present; must match a Software entry in the catalog or the app won't be listed |
| `app_type` | A known value (see the [appverse.yml reference](https://github.com/Sweet-and-Fizzy/ood-appverse/blob/main/docs/appverse.yml)) |
| `maintainer.name` + `maintainer.support_url` | Both present — the catalog sync will not list an app without a support URL |
| `manifest.yml` at the app's subpath | Required for the app to actually run inside OOD |

For Batch Connect Apps: standard OOD structure with expected files (`form.yml`, `submit.yml.erb`, `template/`)

### 2. Documentation Minimum

The README should follow the [Appverse README Template](https://github.com/tamu-edu/appverse_readme_template) structure (see also the [filled-in example](https://github.com/tamu-edu/appverse_readme_template)). At minimum, it must answer these questions for an HPC admin who has never seen the app:

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

Security review follows the dedicated security rubric in
[`security-rubric.md`](security-rubric.md): build a capability profile for the
app's type, run the pattern checks, and classify findings under the OAT taxonomy.
The three legacy spot-checks (committed credentials, disabled security without
justification, user input reaching shell commands) are all covered by the rubric's
pattern checks.

### 4. Basic Functionality

| Check | What to Look For |
|-------|------------------|
| `form.yml` is valid YAML | Parses without errors |
| `manifest.yml` is valid YAML | Parses without errors |
| Template scripts are syntactically correct | ERB templates render, shell scripts pass basic lint |
| No obviously broken references | Module names, paths, and variables referenced in templates exist in form.yml |

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
| No magic numbers without comments | |
| No large blocks of duplicated code | |
| No commented-out dead code | |
| Input validation on form fields (min/max/required) | |
| ERB templates handle missing/empty values gracefully | |

**Target for inclusion:** At least error handling and input validation. Other items are improvement suggestions.

### Maintenance Signals

| Signal | Good Sign | Concern |
|--------|-----------|---------|
| Last commit | Within 12 months | Over 2 years ago |
| Releases | Tagged releases with versioning | No releases |
| Issues | Responded to | Open issues with no response |
| Contributors | Multiple | Single contributor with no activity |
| CHANGELOG | Present and current | Missing |
| CI/CD | Automated checks | None |

**Target for inclusion:** Active within 12 months and at least one release. For brand-new apps, waive the history requirement but flag for follow-up review in 6 months.

## Review Process

### Where to Find Pending Submissions

Apps awaiting review appear in the Manage Appverse Apps view in Drupal: [openondemand.connectci.org/appverse/manage-apps](https://openondemand.connectci.org/appverse/manage-apps). The view shows the submitter's name and email so you can follow up with questions, the moderation state, and a link to edit the app node.

### Step 1: Quick Scan (5 minutes)

1. Open the repository
2. Check: Does it have `appverse.yml` or `manifest.yml`, plus `README.md` and `LICENSE`?
3. Read the README: Can you understand what this app does and how to deploy it?
4. Check: Is this a duplicate of something already in the catalog?

If it fails the quick scan, provide feedback to the contributor with specific items to address.

### Step 2: Structure Review (10 minutes)

1. Verify required metadata fields for the repo shape (see Repository Structure)
2. Verify `form.yml` is valid and has reasonable defaults
3. Check `submit.yml.erb` for hardcoded paths or cluster-specific values
4. Scan template scripts for error handling and security issues
5. Check for an open source license

### Step 3: Quality Assessment (10 minutes)

1. Rate documentation quality (Minimal / Adequate / Strong / Exemplary)
2. Rate configuration portability
3. Check code quality items
4. Review maintenance signals

### Step 4: Decision

| Outcome | Criteria |
|---------|----------|
| **Accept** | Passes all required criteria, adequate+ documentation, partially portable+ config |
| **Accept with suggestions** | Passes required criteria but has clear improvement areas — include specific feedback |
| **Request changes** | Missing required criteria but fixable — provide specific list of what to address |
| **Reject** | Duplicate app, no license, abandoned/unmaintained, security concerns, or not an OOD app |

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
**Reviewer:** [Name]
**Date:** [Date]

### Required Criteria
- [ ] Required metadata fields for the repo shape (see Repository Structure)
- [ ] README.md (substantive)
- [ ] LICENSE (open source)
- [ ] Standard OOD app structure
- [ ] No security concerns
- [ ] Not a duplicate

For Monorepos: repeat the per-app criteria and decision for each entry in `apps[]`.

### Quality Assessment
- Documentation: [Minimal / Adequate / Strong / Exemplary]
- Portability: [Not portable / Partially portable / Portable]
- Maintenance signals: [Active / Moderate / Inactive]

### Decision: [Accept / Accept with suggestions / Request changes / Reject]

### Feedback
[Specific items to address or improve]
```
