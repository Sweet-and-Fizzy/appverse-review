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
with `file:line` findings, Low / Medium / High signals for portability,
documentation, and upkeep, and a recommended decision. The reviewer receives
that report, verifies it, curates the feedback, and makes the call. The review
recommends; a human decides.

## What a review is, and what we ask of you

A review is a best-effort look at an app by a volunteer, supported by an
automated report. It is not a security audit or a certification, and a
listing is not an endorsement. We publish what the review found, and
deployers make their own decisions with it.

As a reviewer, the minimum we ask is:

1. Check every finding that will reach the contributor or the public page:
   each failure and warning of Low severity or above, the gate results, and
   every security finding. Look at the cited lines and decide whether the
   finding holds. For the rest, a sample is enough.
2. Where you disagree with a finding, say so in a note on it. Explain what
   you saw instead; don't delete it.
3. Add any problem you find that the report missed, as a new finding.
4. Record what you did in your reviewer assessment: what you checked, what
   you sampled, and anything you did not check.
5. If you come across something you don't know how to check, ask the other
   reviewers for help before you decide. Leave an internal note on the
   review so whoever picks it up knows what is still open.

Your notes and your assessment are published with the review. You are not
expected to find everything. A clear record of what you checked is what
makes the review useful to the people who rely on it.

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

A repo whose `appverse.yml` lists several apps is gated once and decided per
app: each app gets its own findings and its own decision. Installing any app
clones the whole repo, so a High security finding sets Request changes, and a
Critical one sets Reject, for every app, wherever in the repo it was found.
The overall decision is the strictest of the per-app ones.

### Duplicate check

If the software already has apps in the catalog:

- **Same app, different site config** → Reject. Encourage the contributor to document their configuration in the existing app or contribute changes upstream.
- **Same app, forked with minor changes** → Reject unless the fork adds significant new capability. Encourage contributing back upstream.
- **Same software, meaningfully different approach** → Accept. Examples: containerized vs. module-based, GPU vs. CPU, different execution model (e.g., AlphaFold 2 vs. AlphaFold 3 support).

Document the rationale either way — the review report has a duplicate-check
rationale field under "Catalog checks" for this; fill it in before pasting the
feedback into the issue or email.

### What the review reads from the catalog

The review reads the catalog before the model runs, and its Catalog checks
section reports the results: whether the app's `software` value matches a
Software entry, whether its `app_type` and `implementation_tags` are in the
catalog's vocabularies, and which published apps implement the same
software, grouped by repository, with the submitted repo marked. They come
from the catalog's public data; if something looks off (a value you expect
to match, a vocabulary term you know exists), check it by hand. The duplicate
decision is still yours: read the apps the report lists, decide whether this
one is distinct, and write the rationale. If the report says the catalog was
not read, run the checks by hand (see the appendix, "Reading the catalog by
hand").

### Software entry check

The app's `software` value must match a Software entry in the catalog or the app
won't be listed. An inferred repo (no `appverse.yml`) declares no `software`
value, so there is nothing to match: the check does not apply, and the report
says so. Software is its own catalog node type, created separately from
the app — the app form only references an existing Software entry, it cannot
create one. The report's Catalog checks section says whether one matches. If
none does, it is the reviewer's decision, not an automatic failure:

- **Software should exist in the catalog** → create the Software entry first
  using the [Add Appverse Software form](https://openondemand.connectci.org/node/add/appverse_software)
  (reviewer login required), then the app can reference it and list.
- **Typo, or maps to an existing entry under a different name** → ask the
  contributor to correct the `software` value.
- **Not appropriate for the catalog** → Request changes, with the reason.

## Step 2: Open the review report

Begin with the Appverse Review report for the submitted repo. Read the header
first: the reviewed commit, the version of the review tool, and the disclaimer.
The report is organized the way the rubric is:

- **Repo-level gate criteria** (pass / fail) and the repo's **Upkeep** signal.
- Per app: a **Signals** block (Portability, Documentation at Low / Medium /
  High with an evidence phrase), then the app's **Structure** gate
  results, then **Security**, **Portability**, **Documentation**, and **Code
  Quality** findings, each with a rule code, severity, and `file:line`.
  Security lists every place in the code the tool was told to check,
  including the ones it cleared (PASS), then an "Additional observations"
  table for anything else it found on its own reading.
- **Review scope**: which security tiers ran and what was not checked.
- **Catalog checks**, read from the catalog before the model runs: whether the
  `software` value has a Software entry, whether the `app_type` and
  `implementation_tags` are known terms, and which published apps implement
  the same software. The duplicate decision itself is still yours.
- The tool's **recommendation** and rationale, and a **draft feedback** note.

Low is the good end of every signal. A High signal means "read this section
before deploying", not "reject".

## Step 3: Check the findings

Read the report against the repo and check its findings, rather than taking
them on trust (see "What we ask of you" above for which ones). As you go,
check that:

1. Required files and metadata are as the report states — `appverse.yml` or
   `manifest.yml`, `README.md`, `LICENSE`, standard OOD structure.
2. Security findings are real and correctly classified. For each one, look at
   the cited line and check it shows what the finding says. The review
   confirms that every cited line exists, not that it says what the finding
   claims.
3. When the app runs its own server code (a proxy, a Passenger app, anything
   that listens on a port or handles requests), read that code yourself
   rather than spot-checking. The report can miss the real issue there, such
   as a proxy that accepts requests from any origin.
4. The Portability and Documentation ratings and the smaller code findings
   (typos, copy-paste leftovers) match what you see.
5. Upkeep is current: last commit, releases, CI, CHANGELOG.
6. The draft feedback's advice is right for this repo. Before passing on a
   suggested change, check it would work: advice that is sound in general
   (add `set -e`, say) can break a particular script.
7. The duplicate check is settled — the report performs the catalog reads
   when it can reach the catalog, but the duplicate decision itself is the
   reviewer's to confirm (see Duplicate check above).

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
- The draft ends with a hidden `<!-- feedback-covers: … -->` line that the
  review uses to check itself. Delete it before you send the feedback.

**Good feedback:**
> The README lists prerequisites but doesn't include installation steps. Please add a section showing how to clone and deploy the app (see [ProteinStructure-OOD](https://github.com/EpiGenomicsCode/ProteinStructure-OOD) for an example).

**Poor feedback:**
> README needs work.

Reference the [Best Practices Guide](https://openondemand.connectci.org/appverse-best-practices) for specific recommendations to share with contributors.

## Step 5: Decide

Apply the [Decision rubric](https://openondemand.connectci.org/appverse-review-rubric#decision-rubric):
accept, accept with suggestions, request changes, or reject. The decision comes
from the gate criteria and from properties of individual findings (a
potentially-malicious security finding, an unmaintained repo, a duplicate).
It does not come from the signal levels: a High signal is something a deployer
should read, not a reason to reject.

Any Accept is conditional on the catalog checks in Step 1. If one could not be
run, say which and why in the feedback rather than leaving it unmarked.

For Accept with suggestions, ask the contributor whether they want the app
published now or would rather make the changes first. For Request changes,
list what must change before it can be published.

Record the decision in the catalog (moderation state on the app) and send the
feedback to the contributor by the channel the submission came in on.

## Appendix: Reading the catalog by hand

The review reads the catalog for you; these are for when it could not, or
when you want to look further.

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

# Published apps, for the duplicate check (50 per page at most)
curl -sL -H 'Accept: application/vnd.api+json' \
  'https://openondemand.connectci.org/jsonapi/node/appverse_app?fields%5Bnode--appverse_app%5D=title&page%5Blimit%5D=50'
```

A list longer than one page carries a `links.next` URL in the response; keep
following it until there is none. Reading only the first page misses apps.

Sibling resources on the same API: `taxonomy_term--appverse_app_type`,
`taxonomy_term--appverse_license`, `node--appverse_repo`. `GET /jsonapi` lists
everything available.

Writing still needs a login — creating a Software entry, moderating an app.
Reading does not.
