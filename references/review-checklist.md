# Appverse Reviewer Process

> **Related Docs:**
> [Appverse Review Rubric](https://openondemand.connectci.org/appverse-review-rubric) |
> [Appverse Contributor Guide](https://openondemand.connectci.org/appverse-contributor-documentation) |
> [Appverse Best Practices](https://openondemand.connectci.org/appverse-best-practices) |
> [Appverse README Template](https://github.com/tamu-edu/appverse_readme_template)

What a reviewer does, in the order it happens, when an app is submitted to the
Appverse catalog. The criteria themselves live in the
[Review Rubric](https://openondemand.connectci.org/appverse-review-rubric);
this page only refers to them.

The goal of review is to ensure that apps in the catalog are **useful,
deployable, and maintainable** by the broader HPC community. We're not looking
for perfection — we're looking for apps that meet a quality bar and don't
create confusion in the catalog.

Most of the checking is done by **Appverse Review**, which produces an
evidence-backed report covering structure, security, quality, and maintenance,
with `file:line` findings, Low / Medium / High signals per dimension, and a
recommended decision. The reviewer receives that report, verifies it, curates
the feedback, and makes the call. The review recommends; a human decides.

## Before you start

Apps awaiting review appear in the Manage Appverse Apps view in Drupal: [openondemand.connectci.org/appverse/manage-apps](https://openondemand.connectci.org/appverse/manage-apps). The view shows the submitter's name and email so you can follow up with questions, the moderation state, and a link to edit the app node.

The report is generated against a specific commit. If the repo has moved on
since the report was run, get a fresh report before doing anything else. A
prior review's findings are context only, not a shortcut — every finding is
re-verified against the current commit.

Contributors can run the same review on their own repo before submitting (the
tool's submitter mode). It applies this rubric unchanged and ends with a "Fix
before submitting" list instead of draft feedback; a submission that arrives
with that list already worked through is the fast path.

## Step 1: Gate the app

Decide whether this app belongs in the catalog at all, before reading about its
quality. These are catalog-suitability screens; the two that are hard requirements
(public repository, open source license) are also gate criteria in the rubric's
Structure section, where the automated review checks them.

Ask these questions first, before evaluating quality:

| Question | If No... |
|----------|----------|
| Does this app serve software not already in the catalog? | See "Duplicate check" below |
| Is the repository public and accessible? | Cannot be included — public repo required |
| Does it have an open source license? | Cannot be included — license required |
| Is there a maintainer who will respond to issues? | Flag as a risk — orphaned apps hurt the catalog |

### Duplicate check

If the software already has apps in the catalog:

- **Same app, different site config** → Reject. Encourage the contributor to document their configuration in the existing app or contribute changes upstream.
- **Same app, forked with minor changes** → Reject unless the fork adds significant new capability. Encourage contributing back upstream.
- **Same software, meaningfully different approach** → Accept. Examples: containerized vs. module-based, GPU vs. CPU, different execution model (e.g., AlphaFold 2 vs. AlphaFold 3 support).

Document the rationale either way — the review report has a duplicate-check
rationale field under "Not checked" for this; fill it in before pasting the
feedback into the issue or email.

### Reading the catalog without a login

The catalog is a Drupal site with JSON:API enabled and readable anonymously, so
the Software entry, the vocabularies and the published app list can all be
checked from the command line — no reviewer account needed.

Two things will make these look like an unreachable host if you get them wrong.
Follow redirects (`-L`), or the request returns `000`. And percent-encode the
query brackets as `%5B`/`%5D` — a URL with literal `[` is dropped before it
reaches Drupal and yields an empty response with no status code at all.

```bash
# Does a Software entry exist for this app's `software` value?
curl -sL -H 'Accept: application/vnd.api+json' \
  'https://openondemand.connectci.org/jsonapi/node/appverse_software?filter%5Btitle%5D=API%20Access&fields%5Bnode--appverse_software%5D=title'

# The implementation-tags vocabulary (matching is case-insensitive)
curl -sL -H 'Accept: application/vnd.api+json' \
  'https://openondemand.connectci.org/jsonapi/taxonomy_term/appverse_implementation_tags?fields%5Btaxonomy_term--appverse_implementation_tags%5D=name&page%5Blimit%5D=50'

# Published apps, for the duplicate check
curl -sL -H 'Accept: application/vnd.api+json' \
  'https://openondemand.connectci.org/jsonapi/node/appverse_app?fields%5Bnode--appverse_app%5D=title&page%5Blimit%5D=100'
```

Sibling resources on the same API: `taxonomy_term--appverse_app_type`,
`taxonomy_term--appverse_license`, `node--appverse_repo`. `GET /jsonapi` lists
everything available.

Writing still needs a login — creating a Software entry, moderating an app.
Reading does not, so report these checks as performed rather than deferred.

### Software entry check

The app's `software` value must match a Software entry in the catalog or the app
won't be listed. Software is its own catalog node type, created separately from
the app — the app form only references an existing Software entry, it cannot
create one. Query for it with the command above. If there is no matching entry,
it is the reviewer's decision, not an automatic failure:

- **Software should exist in the catalog** → create the Software entry first
  using the [Add Appverse Software form](https://openondemand.connectci.org/node/add/appverse_software)
  (reviewer login required), then the app can reference it and list.
- **Typo, or maps to an existing entry under a different name** → ask the
  contributor to correct the `software` value.
- **Not appropriate for the catalog** → Request changes, with the reason.

Monorepos: a declared repo with an `apps:` list is reviewed as one app per
entry, each with its own findings and its own decision (see the rubric's Repo
shapes section). Gate the repo once; decide per app.

## Step 2: Open the review report

Begin with the Appverse Review report for the submitted repo. Read the header
first: the reviewed commit, the version of the review tool, and the disclaimer.
The report is organized the way the rubric is:

- **Repo-level gate criteria** (pass / fail) and the repo's **Upkeep** signal.
- Per app: a **Signals** block (Security, Portability, Documentation at Low /
  Medium / High with an evidence phrase), then the app's **Structure** gate
  results, then **Security**, **Portability**, **Documentation**, and **Code
  Quality** findings, each with a rule code, severity, and `file:line`.
- **Review scope**: which security tiers ran and what was not checked.
- **Catalog checks** the tool could not perform, left for you.
- The tool's **recommendation** and rationale, and a **draft feedback** note.

Low is the good end of every signal. A High signal means "read this section
before deploying", not "reject".

## Step 3: Verify the findings

Read the report against the repo and confirm its findings hold, rather than
taking them on trust. Spot-check that:

1. Required files and metadata are as the report states — `appverse.yml` or
   `manifest.yml`, `README.md`, `LICENSE`, standard OOD structure.
2. Security findings are real and correctly rated — open a few and check the
   cited `file:line` actually shows the flagged pattern.
3. Portability and Documentation ratings and any correctness-&-polish findings match what you see —
   documentation level, portability, and any copy-paste artifacts or typos.
4. Upkeep signals are current — last commit, releases, CI, CHANGELOG.
5. The duplicate check is settled — the review cannot see the catalog, so this is
   the reviewer's to confirm (see Duplicate check above).

Trust the report's structure but verify its substance; if a finding does not
hold, correct it before it reaches the contributor.

## Step 4: Curate the feedback

The draft feedback in the report is the tool's first pass. Make it yours:

- Every item in the feedback must already appear as a finding in the report.
  If you notice a real defect the report missed, add it as a finding first,
  then mention it.
- Genuine fix-items (Low severity and above, plus any failed gate criterion)
  belong in the feedback. Info-level polish can be summarized or left out.
- Be specific: name the file and line, say what to change, and link an example
  where one exists.
- The draft ends with an HTML comment `<!-- feedback-covers: … -->` listing
  the finding keys it addresses. It is machine-checked. If you add a
  fix-item to the feedback, add its key; if you remove one, remove the key.

**Good feedback:**
> The README lists prerequisites but doesn't include installation steps. Please add a section showing how to clone and deploy the app (see [ProteinStructure-OOD](https://github.com/EpiGenomicsCode/ProteinStructure-OOD) for an example).

**Poor feedback:**
> README needs work.

Reference the [Best Practices Guide](https://openondemand.connectci.org/appverse-best-practices) for specific recommendations to share with contributors.

## Step 5: Decide

Apply the [Decision rubric](https://openondemand.connectci.org/appverse-review-rubric):
accept, accept with suggestions, request changes, or reject. The decision comes
from the gate criteria and from properties of individual findings (a
potentially-malicious security finding, an unmaintained repo, a duplicate).
It does not come from the signal levels: a High signal is something a deployer
should read, not a reason to reject.

Any Accept is conditional on the catalog checks in Step 1. If one could not be
run, say which and why in the feedback rather than leaving it unmarked.

Record the decision in the catalog (moderation state on the app) and send the
feedback to the contributor by the channel the submission came in on.

## Appendix: Review template

Copy this template when recording a review by hand:

```markdown
## App Review: [App Name]

**Repository:** [URL]
**Reviewed commit:** [SHA] ([date])
**Reviewer:** [Name]
**Date:** [Date]

### Gate criteria
- [ ] Repo shape identifiable and required metadata present (see the rubric's Structure section)
- [ ] README.md (substantive)
- [ ] LICENSE (open source)
- [ ] Standard OOD app structure and valid YAML / templates

For Monorepos: repeat the per-app criteria and decision for each entry in `apps[]`.

### Signals
- Security: [Low / Medium / High] — findings classified under OODT, with severity and file:line evidence
- Portability: [Low / Medium / High] — [Not portable / Partially portable / Portable]
- Documentation: [Low / Medium / High] — [Minimal / Adequate / Strong / Exemplary]
- Upkeep (repo): [Low / Medium / High] — last commit, releases, CI, CHANGELOG

### Code quality
- Findings with file:line evidence

### Catalog checks
- [ ] Duplicate check against the existing catalog — [outcome and rationale]
- [ ] `software` value matches a catalog Software entry (create the entry if the software should exist)
- [ ] `app_type` and `implementation_tags` are in the catalog vocabularies

Query these against the public JSON:API — see "Reading the catalog without a
login". Record what each returned. If one could not be run, say which and why,
rather than leaving it unmarked.

### Decision: [Accept / Accept with suggestions / Request changes / Reject]
- If any catalog check above could not be run, Accept is conditional on it

### Feedback
[Specific items to address or improve — every item must already appear above]
```
