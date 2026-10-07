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
for perfection. We're looking for apps that meet a quality bar and don't
create confusion in the catalog.

Most of the checking is done by **Appverse Review**, which reads the repo and
writes an evidence-backed report covering structure, security, quality, and
maintenance, with `file:line` findings, a level for portability,
documentation, and upkeep, and a suggested decision. The portal turns that
report into a **review page**: you check the findings there, correct them or
add to them, write to the contributor, and send the decision from the same
page. The tool suggests; a human decides.

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
2. Where a finding does not hold, change it on the review page: give it the
   severity it deserves, or mark it "Not a finding", and say why in its note
   to the contributor. The tool's own values stay on the record beside yours.
3. Add any problem you find that the report missed, as a new finding.
4. Record what you did in the Public summary: what you checked, what you
   sampled, and anything you did not check. Write it before you send the
   decision, since it cannot be edited afterwards.
5. If you come across something you don't know how to check, ask the other
   reviewers for help before you decide. Leave an internal note on the
   review so whoever picks it up knows what is still open.

You are not expected to find everything. A clear record of what you checked
is what makes the review useful to the people who rely on it.

## Who can review

Reviewing needs the `administer appverse content` permission, which comes
with the Appverse PM role (site administrators hold it too). Anyone with the
permission can open a review page, save it and send a decision. Only Appverse
PM users can be assigned as a repo's reviewer.

## Before you start

Repos awaiting review are on the Manage Appverse Repos page:
[openondemand.connectci.org/appverse/manage-repos](https://openondemand.connectci.org/appverse/manage-repos).
Each repo's card shows the contributor's name and email, where the repo is
in review, and who is assigned. **Open review** takes you to the repo's
newest review page. **Run AI report** (or **Rerun report**, once one has run)
starts a new automated review of the repo's latest commit.

A repo has one reviewer across all its rounds. Use **Assign to me** on the
card, or pick a name in the Reviewer box on the review page. If nobody is
assigned when you first save a review, you are assigned (when you hold the
Appverse PM role).

Reviewers are emailed when a repo is submitted, re-submitted or updated for
review. You can turn that off under "Appverse review emails" on your
account's edit page; emails about your own reviews, such as an assignment,
still come.

The report is generated against a specific commit, shown at the top of the
review page. If the repo has moved on since then and the change matters, use
Rerun report before doing anything else. A rerun makes a new review on the
latest commit. The review you were on is then marked as superseded and
cannot be sent, and nothing you wrote on it carries over. A prior review's
findings are context only, not a shortcut: every finding is re-verified
against the current commit.

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
| Is the repository public and accessible? | Cannot be included: public repo required |
| Does it have an open source license? | Cannot be included: license required |
| Is there a maintainer who will respond to issues? | Flag it as a risk in the Public summary: orphaned apps hurt the catalog |

A repo whose `appverse.yml` lists several apps is gated once and decided per
app: each app gets its own findings and its own decision. Installing any app
clones the whole repo, so a High security failure sets at least Request
changes, and a Critical one sets Reject, for every app, wherever in the repo
it was found. The review page applies this for you (see Step 5). The overall
decision is the strictest of the per-app ones.

### Duplicate check

If the software already has apps in the catalog:

- **Same app, different site config** → Reject. Encourage the contributor to document their configuration in the existing app or contribute changes upstream.
- **Same app, forked with minor changes** → Reject unless the fork adds significant new capability. Encourage contributing back upstream.
- **Same software, meaningfully different approach** → Accept. Examples: containerized vs. module-based, GPU vs. CPU, different execution model (e.g., AlphaFold 2 vs. AlphaFold 3 support).

A duplicate is normally Reject. Use Request changes instead when the
contributor can make the app a meaningfully different approach.

Each app's Structure block on the review page has a **Duplicate check** with
three outcomes:

- **No other app for this software**
- **Same software, a meaningfully different approach**
- **Duplicate of an existing app**

Write the rationale (which apps you compared, and how this one differs or
which one it duplicates) for the last two. Write it for "No other app" as
well when no Software entry matched, since you then compared by name rather
than against the catalog. You must record the duplicate check before you
can send Accept or Accept with suggestions for an app. It does not limit the
decision: if you accept an app you marked a duplicate, the page warns you
but lets you send.

When the catalog settles the question (the app's software matched a Software
entry and no app from another repo implements it), the page shows an
automated suggestion under the outcomes. The outcome is still yours to
record.

### What the review reads from the catalog

The review reads the catalog before the model runs. On the review page, each
app's Structure block shows the results as **Catalog checks** rows:

- **Software**: whether the app's `software` value matches a Software entry,
  and the closest entry when it does not.
- **App type**: whether `app_type` is in the catalog's vocabulary.
- **Implementation tags**: whether every `implementation_tags` entry is in
  the vocabulary.
- **Same software**: the published apps from other repos that implement the
  same software, each linked to its code. With no Software entry to compare
  by, this row says to compare by name against the published apps.

Reviews from older versions of the tool show the report's Catalog checks text
in place of the rows.

These come from the catalog's public data. If something looks off (a value
you expect to match, a vocabulary term you know exists), check it by hand.
If the review says the catalog was not read, run the checks by hand (see the
appendix, "Reading the catalog by hand").

### Software entry check

The app's `software` value must match a Software entry in the catalog for the
app to be listed under its software. An inferred repo (no `appverse.yml`)
declares no `software` value, so there is nothing to match: the check does
not apply, and the Software row says so. Software is its own catalog node
type, created separately from the app. The app form only references an
existing Software entry; it cannot create one. If none matches, it is the
reviewer's decision, not an automatic failure:

- **Software should exist in the catalog** → create the Software entry
  first, with the **Add the Software entry** link on the Software row or the
  [Add Appverse Software form](https://openondemand.connectci.org/node/add/appverse_software)
  (reviewer login required). Then use **Re-sync from GitHub** on the repo's
  card, so the app picks up the new entry.
- **Typo, or maps to an existing entry under a different name** → ask the
  contributor to correct the `software` value.
- **Not appropriate for the catalog** → Request changes, with the reason.

The page does not stop you accepting an app whose software has no entry, so
settle this before you decide.

## Step 2: Read the review page

The review page is at `/appverse/review/<id>`. From the top:

- **The header**: the repo, its maintainer and contributor, the repo's shape
  (single app or monorepo), the reviewed commit and when it ran. On the
  right, a **Public view** link shows the page as visitors will see it. A
  banner says when a newer review of the repo exists, or when the
  contributor withdrew the submission.
- **The progress line**: where the repo is, from submission to decision, and
  which round this is. Below it are the repo's earlier reviews, and how many
  findings are new or resolved since the last round. New findings are marked
  **New**.
- **One section per app** (a single-app repo has one), with five blocks:
  **Structure**, **Security**, **Portability**, **Documentation**, and
  **Code quality**.
  - Structure carries the gate results: the repo's gates (on the first app)
    and the app's own file checks, each passed, failed, warned or not
    checked, with the evidence for each repo gate. Then come the Catalog
    checks and the Duplicate check (Step 1).
  - Portability and Documentation each carry a level and an evidence phrase.
    Security has no level. It lists findings, or says "No findings to
    review" when there are none, which is not a claim that the app is safe.
  - Each block groups its findings by severity, worst first, with Info
    collapsed. A finding shows its rule code, summary and `file:line`
    evidence, linked to the reviewed commit on GitHub. A security finding
    the tool tagged potentially malicious carries a **Potentially malicious**
    marker, which only reviewers see.
  - **Checked** lists the rows that passed or were not checked, so you can
    confirm a cleared check. **Dismissed by the reviewer** lists the findings
    a reviewer set aside (Step 3).
  - **+ Add finding** adds your own finding to the block.
- **Repository**: repo-wide findings, and the repo's **Upkeep** level.
- **The sidebar**: the Reviewer box, each app's **Decision** (with the tool's
  suggestion shown once your decision differs from it), the **Email to
  Contributor**, the **Public Summary**, the Save and Send buttons, and
  **Internal notes**.

Each axis has its own level words, from the good end to the end with the most
to read before deploying:

| Axis | Levels |
|------|--------|
| Portability | Portable · Needs site config · Site-specific |
| Documentation | Complete · Adequate · Minimal |
| Upkeep | Well maintained · Active · Inactive |

A level describes; it does not decide. "Site-specific" or "Minimal" means
"read this section before deploying", not "reject". The rubric defines each
level.

## Step 3: Check the findings

Read the page against the repo and check its findings, rather than taking
them on trust (see "What we ask of you" above for which ones). As you go,
check that:

1. Required files and metadata are as the gates state: `appverse.yml` or
   `manifest.yml`, `README.md`, `LICENSE`, standard OOD structure. A gate row
   that warned or was not checked is not a pass. Confirm it by hand from the
   cited evidence before you decide, record what you found in an internal
   note, and add a finding if the gate fails.
2. Security findings are real and correctly classified. For each one, look at
   the cited line and check it shows what the finding says. The review
   confirms that every cited line exists, not that it says what the finding
   claims.
3. When the app runs its own server code (a proxy, a Passenger app, anything
   that listens on a port or handles requests), read that code yourself
   rather than spot-checking. The report can miss the real issue there, such
   as a proxy that accepts requests from any origin.
4. The Portability and Documentation levels and the smaller code findings
   (typos, copy-paste leftovers) match what you see.
5. Upkeep is current: last commit, releases, CI, CHANGELOG.
6. The draft email's advice is right for this repo. Before passing on a
   suggested change, check it would work: advice that is sound in general
   (add `set -e`, say) can break a particular script.
7. The duplicate check is recorded for each app (Step 1).

### Changing a finding

Each of the tool's failures and warnings has an **Edit** button. It opens:

- **Severity**: a new severity, higher or lower than the tool's.
- **Not a finding**: dismisses it.
- **Summary** and **Evidence**: your own wording, when the tool's is wrong
  or unclear.
- **Note to the contributor**: the reason. It is required when you change
  the severity or dismiss the finding. A wording change needs none.

The tool's own severity, summary and evidence stay on the record beside
yours. To undo a change, choose the original severity, clear "Not a finding",
or empty the text. The rule code cannot be changed: if it is wrong, dismiss
the finding and add your own with the right code.

Everything on the page follows your change: the severity groups, the counts,
the decision floors (Step 5) and the catalog's Security count. A dismissed
finding counts as no finding and sets no floor. Changes apply to this round
only; the next round's review starts again from the tool's findings.

Passed and not-checked rows have no Edit. A finding you added has its own
fields, which you edit directly, and can be deleted.

### Adding a finding

Use **+ Add finding** in the block where the problem belongs. Pick the rule
code (or Other, and type one), a severity, a summary and the `file:line`
evidence. Your finding is marked **Reviewer** wherever it is shown, and it
sets a decision floor like any other.

### Notes

There are two kinds of note:

- A finding's **Note to the contributor** goes to the contributor with the
  finding. It never appears on the public page.
- **Internal notes**, in the sidebar, are for reviewers only: context for
  whoever picks the review up next. You can add them at any time, including
  after the decision is sent. Contributor replies to the decision email come
  to your own inbox, so log anything decided by email here.

### Levels

Each level starts at the tool's rating. To change one, use the pencil beside
it, pick the level and give the reason for changing the automated rating.
The page then shows the tool's rating beside yours.

**Save draft** saves everything on the page; a finding's own Save does the
same and returns you to that finding. Nothing reaches the contributor until
you send the decision.

## Step 4: Curate the feedback

The **Email to Contributor** box starts with the tool's draft feedback. It is
the tool's first pass. Make it yours:

- Every item in the feedback must already appear as a finding on the page.
  If you notice a real defect the report missed, add it as a finding first,
  then mention it.
- Genuine fix-items (Low severity and above, and every failed gate) belong in
  the feedback. Info-level polish can be summarized or left out.
- Be specific: name the file and line, say what to change, and link an example
  where one exists.
- What you write becomes the body of the decision email. The email already
  greets the contributor, gives each app's decision, says how to re-submit
  and tells them a reply reaches you, so write only the review itself: what
  to change and why. Leave out a greeting, a thank-you opening, a restated
  decision and a sign-off. Markdown is rendered.
- If you send the report's draft outside the portal, delete the hidden
  `<!-- feedback-covers: … -->` line at its end first. The portal removes it
  for you.

**Good feedback:**
> The README lists prerequisites but doesn't include installation steps. Please add a section showing how to clone and deploy the app (see [ProteinStructure-OOD](https://github.com/EpiGenomicsCode/ProteinStructure-OOD) for an example).

**Poor feedback:**
> README needs work.

Reference the [Best Practices Guide](https://openondemand.connectci.org/appverse-best-practices) for specific recommendations to share with contributors.

## Step 5: Decide and send

Apply the [Decision rubric](https://openondemand.connectci.org/appverse-review-rubric#decision-rubric):
Accept, Accept with suggestions, Request changes, or Reject, for each app. The
decision comes from the gate criteria and from properties of individual
findings (a potentially malicious security finding, an unmaintained repo, a
duplicate). It does not come from the levels: "Site-specific" or "Inactive"
is something a deployer should read, not a reason to reject.

The page does not offer a decision milder than the findings allow. Under each
app's Decision it says why, as "At least Request changes:" followed by the
finding that sets it. The floors are:

- A security failure at High sets at least Request changes, and at Critical
  sets Reject, for every app.
- A failed Structure gate sets at least Request changes whatever its
  severity, and Reject at Critical, for its own app (every app when the gate
  is the repo's).
- An upkeep failure (MNT-01) at High sets at least Request changes, and at
  Critical sets Reject.
- A repo that is archived or not public sets Request changes for every app.

Warnings set no floor, and neither does a dismissed finding. Where you
changed a severity, the floor uses yours. If a floor looks wrong, check the
finding that sets it, and change the finding with your reason.

**Send** is named for the decision it sends (Accept and publish, Request
changes, and so on). It stays disabled, with the reason beside it, until:

- every app has a decision,
- the Email to Contributor is written (required for every decision except
  Accept), and
- every app you accept has its duplicate check recorded.

Send saves the page and opens a preview; nothing is sent until you confirm
there. The preview lists what moves (the repo, each app and the review),
then shows the email exactly as it will go: To (the repo owner's account
email), Reply-To (you), Subject and body. It is your last look before the
contributor reads it. **Send to** the contributor sends it; **Back to the
review** returns you to the page.

What sending does:

| Decision | Catalog | Review | Contributor |
|----------|---------|--------|-------------|
| Accept | The repo and the app go live | Published with them | Told it is in the catalog |
| Accept with suggestions | Nothing goes live yet; the repo waits as Ready to publish | Not public until you publish | Told it is accepted and not live yet |
| Request changes | The repo moves to Needs changes; a live repo comes down | Stays unpublished | Asked to fix the repo on GitHub and re-submit |
| Reject | The app stays out of the catalog; a live one comes down | Never published | Told it was not accepted |

The page's button and heading say Decline for Reject, and the email says the
repo "was not accepted". In a monorepo with different decisions, each app
moves on its own, and the repo goes live when any app is accepted. A repo
that is already live stays live after an Accept or an Accept with
suggestions.

Do not change an app's or a repo's moderation state by hand. Sending the
decision moves them, records the decision and emails the contributor
together.

### Accept with suggestions: Publish

After an Accept with suggestions, the email tells the contributor the app is
accepted but not in the catalog yet, that none of the suggestions block it,
and that they can reply when they are ready or say nothing and it will be
listed as it is. The suggestions are optional.

The review page then shows **Publish app and review**, to reviewers only.
Publish when the contributor replies, when you have waited long enough, or
right away. It publishes the accepted apps, the repo and the review, and
emails the contributor that it is live. Publishing does not review the repo
again.

## After the decision

Once the decision is sent, the review page is the record of it. The sidebar
shows the decision, who sent it and when, who the repo is waiting on, and
the email as sent. The findings, levels and Public summary are read-only;
internal notes and the Reviewer box still work.

- **Update decision** reopens each app's decision, the duplicate check and
  the Email to Contributor, until the contributor re-submits. The preview
  shows where the repo, each app and the review will end up. The contributor
  gets an "Updated:" email saying it replaces the earlier decision, which
  stays on record.
- **Start the next round** re-submits the repo for its contributor, exactly
  as their own Re-submit does: a new AI report on the latest commit, and a
  new round. It is offered on the newest review while the repo is in Needs
  changes. Use it when the contributor tells you by email that they have
  fixed things.

On the contributor's side:

- **Withdraw from review** takes a submission out of review before a decision
  is sent. The review then says it was withdrawn, and there is nothing to
  decide unless they re-submit.
- **Re-submit** is on their Appverse page when the repo is in Needs changes,
  or when some apps were sent back while others were accepted. The whole repo
  is reviewed again, as a new round.

## Who sees what, and when

- **Before a decision is sent**: reviewers only. The contributor cannot open
  the review.
- **Once it is sent**: the contributor (the repo's owner) can read the whole
  review: the findings, your notes to them, the findings you dismissed and
  why, the Email to Contributor and the Public summary. They never see
  internal notes, the tool's suggested decision, or the potentially
  malicious marker.
- **The public**: only while the review and its repo are both published,
  that is after an Accept, or after you publish an Accept with suggestions.
  Visitors see each app's decision and levels, the findings (rule, severity,
  summary and evidence, with your own findings marked Reviewer), and the
  Public summary. A severity you changed shows as "Reviewer changed the
  severity from High", and a summary you reworded as "Edited by the
  reviewer". Notes to the contributor, dismissed findings, the email and
  internal notes are never public. If the repo is later sent back or
  unpublished, its review stops being public until the repo is live again.

Use **Public view** to check the public page before you send an Accept.

## Appendix: Reading the catalog by hand

The review reads the catalog for you; these are for when it could not, or
when you want to look further.

The catalog is a Drupal site with JSON:API enabled and readable anonymously, so
the Software entry, the vocabularies and the published app list can all be
checked from the command line, with no reviewer account needed.

Two things will make these look like an unreachable host if you get them wrong.
Follow redirects (`-L`), or the request returns `000`. And percent-encode the
query brackets as `%5B`/`%5D`: a URL with literal `[` is dropped before it
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

Writing still needs a login: creating a Software entry, sending a decision.
Reading does not.
