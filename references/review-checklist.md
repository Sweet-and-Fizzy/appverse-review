# Appverse Reviewer Process

> **Related Docs:**
> [Appverse Review Rubric](https://openondemand.connectci.org/appverse-review-rubric) |
> [Appverse Contributor Guide](https://openondemand.connectci.org/appverse-contributor-documentation) |
> [Appverse Best Practices](https://openondemand.connectci.org/appverse-best-practices) |
> [Appverse README Template](https://github.com/tamu-edu/appverse_readme_template)

This page takes you through a review, step by step. The criteria are in the
[Review Rubric](https://openondemand.connectci.org/appverse-review-rubric).

We want apps the HPC community can deploy and maintain, and that don't
confuse people browsing the catalog. We are not looking for perfection.

An automated tool, Appverse Review, reads the repo and writes a report. The
report lists findings with the file and line each one comes from. It rates
portability, documentation and upkeep, and it suggests a decision. The
portal shows the report as a review page. On that page you check the
findings, correct them or add your own, write to the contributor, and send
the decision. The tool suggests. You decide.

## What a review is, and what we ask of you

A review is a best-effort look at an app by a volunteer, with help from an
automated report. It is not a security audit or a certification. A listing
is not an endorsement. We publish what the review found, and deployers make
their own decisions with it.

As a reviewer, we ask you to do at least this:

1. Check every security finding, every gate result, and every failure or
   warning of Low severity or above. Open the cited lines and decide whether
   each finding holds. For the remaining findings, a sample is enough.
2. If the app runs its own server code, such as a proxy or a Passenger app,
   read that code yourself. The report can miss the real problem there, such
   as a proxy that accepts requests from any origin.
3. Where a finding does not hold, change it on the review page and say why
   (see "Changing a finding").
4. Add any problem the report missed as a new finding.
5. Write the Public Summary before you send the decision. Say what you
   checked, what you sampled, and what you did not check. You cannot edit it
   afterwards.
6. If you don't know how to check something, ask before you decide. Leave an
   internal note on the review so whoever picks it up knows what is open,
   and ask the Appverse team on Slack.

You are not expected to find everything. A clear record of what you checked
is what makes the review useful.

## Who can review

Appverse PMs review. Site administrators can too. Only an Appverse PM can be
assigned as a repo's reviewer.

## Before you start

Repos awaiting review are on the
[Manage Appverse Repos](https://openondemand.connectci.org/appverse/manage-repos)
page. Each repo's card shows the contributor, where the repo is in review,
and who is assigned. **Open review** takes you to the repo's newest review
page. **Run AI report** starts an automated review of the repo's latest
commit. Once a report exists, the button reads **Rerun report**.

A repo has one reviewer across all its rounds. Use **Assign to me** on the
card, or pick a name in the Reviewer box on the review page. If nobody is
assigned and you are an Appverse PM, saving the review assigns you.

You get an email when a repo is submitted or re-submitted. To stop these,
turn off "Appverse review emails" on your account's edit page. Emails about
your own reviews, such as an assignment, still come.

The review page shows the commit the report was run on. If the repo has
changed since then in a way that matters, click **Rerun report** before you
write anything. A rerun starts a new review on the latest commit. The old
review is marked superseded and can't be sent, and nothing you wrote on it
carries over. Findings from an earlier round are context only. Check each
finding against the current commit.

## Step 1: Gate the app

Decide whether the app belongs in the catalog before you look at its
quality. The report checks the public repo and the license for you, as gates
in the Structure block.

| Question | If no |
|----------|-------|
| Is it an Open OnDemand app? | Reject. No automated check catches this, so it is your call |
| Does this app serve software not already in the catalog? | See "Duplicate check" below |
| Is the repository public? | It can't be included |
| Does it have an open source license? | It can't be included |
| Is there a maintainer who will respond to issues? | Note it in the Public Summary. An abandoned repo is a Reject (see Step 5) |

A repo can hold several apps. Answer these questions once for the repo, then
give each app its own decision.

Each app's Structure block shows **Catalog checks**. They say whether the
app's software, app type and implementation tags are in the catalog, and
which published apps from other repos implement the same software. When
the app type is not in the catalog's list, the check suggests the closest
term. If a result looks wrong, or the page says the catalog was not read,
check by hand (see the appendix).

### Software entry check

The app's `software` value must match a Software entry in the catalog for
the app to be listed under that software.

If no Software entry matches, decide which case it is:

- **The software belongs in the catalog.** Create the Software entry with
  the **Add the Software entry** link on the Software row, or the
  [Add Appverse Software form](https://openondemand.connectci.org/node/add/appverse_software).
  Then click **Re-sync from GitHub** on the repo's card so the app picks up
  the new entry.
- **It's a typo, or the software exists under another name.** Ask the
  contributor to correct the `software` value.
- **The software does not belong in the catalog.** Use your judgment. Choose
  Request changes when the app should point at a different software. Choose
  Reject when the app itself is out of scope.

The page lets you accept an app whose software has no entry, so settle this
before you decide.

### Duplicate check

If the software already has apps in the catalog, compare this app with them:

- **Same app, different site configuration.** Reject. Encourage the
  contributor to document their configuration in the existing app, or to
  contribute changes upstream.
- **Same app, forked with minor changes.** Reject, unless the fork adds
  significant new capability. Encourage contributing back upstream.
- **A maintained fork of an abandoned app in the catalog.** Not a
  duplicate. Review it on its own merits.
- **Same software, a meaningfully different approach.** Accept. Examples are
  containerized versus module-based, GPU versus CPU, or a different execution
  model, such as AlphaFold 2 versus AlphaFold 3 support.

Choose Request changes instead of Reject when the contributor can make the
app a meaningfully different approach.

Each app's Structure block has a **Duplicate check**. Record one of its
three outcomes for each app before you accept it: "No other app for this
software", "Same software, a meaningfully different approach" or "Duplicate
of an existing app". Give your reason. Name the apps you compared and say
how this one differs or which one it copies. You can skip the reason only
when you chose "No other app" and the app matched a Software entry. The
outcome does not limit your decision. If you accept an app you marked as a
duplicate, the page warns you but still lets you send.

When the catalog shows no other app for this software, the page suggests
that outcome. You still record it yourself.

## Step 2: Read the review page

The header shows the repo, its contributor and the commit the report was
run on. A banner appears when a newer review of the repo exists or the
contributor withdrew the submission. The progress line below it shows which
round this is, and findings new since the last round are marked **New**.

Each app has five blocks: Structure, Security, Portability, Documentation
and Code quality. Repo-wide findings and the Upkeep level are under
Repository. Findings are grouped by severity, worst first, and each links
its evidence to the reviewed commit on GitHub. A few things are easy to
misread:

- The repo's own gates appear only under the first app.
- "No findings to review" under Security does not mean the app is safe.
- The **Potentially malicious** marker on a security finding is shown only
  to reviewers.
- **Checked** lists the rows that passed or were not run, so you can confirm
  them. **Dismissed by the reviewer** lists findings a reviewer set aside.

The sidebar holds each app's **Decision**, the **Email to Contributor**, the
**Public Summary** and **Internal notes**.

Each level runs from best to most caution:

| Axis | Levels |
|------|--------|
| Portability | Portable · Needs site config · Site-specific |
| Documentation | Complete · Adequate · Minimal |
| Upkeep | Well maintained · Active · Inactive |

The rubric defines each level.

## Step 3: Check the findings

Click **Save draft** as you go. Nothing reaches the contributor until you
send the decision.

Check the findings against the repo. "What a review is, and what we ask of
you" says which ones. As you go, check that:

1. Required files and metadata are as the gates state: `appverse.yml` or
   `manifest.yml`, `README.md`, `LICENSE`, and the standard OOD layout. A gate
   that warned or was not checked has not passed. Confirm it from the cited
   evidence, record what you found in an internal note, and add a finding if
   the gate fails.
2. Each security finding is real and correctly classified. The tool checks
   that each cited line exists. It does not check that the line shows the
   problem, so you have to.
3. The Portability and Documentation levels match what you see, and so do
   the smaller code findings, such as typos and copy-paste leftovers.
4. The Upkeep level matches the repo's last commit, releases, CI and
   CHANGELOG.
5. The draft email's advice is right for this repo. Before you pass on a
   suggested change, check that it would work. Advice that is sound in
   general, such as adding `set -e`, can break a particular script.

### Changing a finding

Each failure and warning from the tool has an **Edit** button. Use it to
set a new **Severity**, mark it **Not a finding**, or reword its **Summary**
and **Evidence**. When you change the severity or dismiss the finding, give
your reason in **Note to the contributor**.

The tool's own severity, summary and evidence stay on the record beside
yours. To undo a change, choose the original severity, clear "Not a
finding", or empty the text. You can't change the rule code. If it is wrong,
dismiss the finding and add your own with the right code.

Your change updates the counts and the decision floors (Step 5). A dismissed
finding sets no floor. Changes last for this round only. The next round
starts again from the tool's findings.

Some findings cite only demo, docs, example or test files, which a site
does not install. They still count until you act. Decide whether each one
matters to a deployer. If it doesn't, mark it
**Not a finding** and say why. If it does, leave it.

### Adding a finding

Use **+ Add finding** in the block where the problem belongs. Pick the rule
code, or Other and type one. Then give a severity, a summary and the
`file:line` evidence. Your finding is marked **Reviewer** and sets a decision
floor like any other. You can edit or delete it directly.

### Changing a level

Each level starts at the tool's rating. To change one, click the pencil
beside it, pick the level and give your reason. The page then shows the
tool's rating beside yours. The contributor sees your reason. It is never
public.

## Step 4: Curate the feedback

The **Email to Contributor** box starts with the tool's draft. Edit it so
that:

- Every item already appears as a finding on the page. If you notice a real
  problem the report missed, add it as a finding first, then mention it.
- It includes every failed gate and every finding of Low severity or above.
  You can summarize Info findings or leave them out.
- Each item is specific. Name the file and line, say what to change, and
  link an example where one exists.

Your text becomes the body of the decision email. The portal adds the
greeting, each app's decision, how to re-submit, and a note that a reply
reaches you. Write only what to change and why. Leave out a greeting, a
thank-you, the decision and a sign-off. You can use Markdown.

**Good feedback:**
> The README lists prerequisites but doesn't include installation steps. Please add a section showing how to clone and deploy the app (see [ProteinStructure-OOD](https://github.com/EpiGenomicsCode/ProteinStructure-OOD) for an example).

**Poor feedback:**
> README needs work.

The [Best Practices Guide](https://openondemand.connectci.org/appverse-best-practices)
has specific recommendations you can share with contributors.

## Step 5: Decide and send

Use the [Decision rubric](https://openondemand.connectci.org/appverse-review-rubric#decision-rubric)
to choose Accept, Accept with suggestions, Request changes or Reject for
each app. The page calls Reject "Decline".

The decision comes from the gate criteria and from a few kinds of finding:

- A Critical security finding is a Reject: one tagged potentially
  malicious, or one that can't be fixed without redesigning the app (see the
  rubric's [Security](https://openondemand.connectci.org/appverse-review-rubric#security)
  section).
- An abandoned or unmaintained repo is a Reject.
- A duplicate is decided as described in "Duplicate check" (Step 1).

Levels never decide on their own. "Site-specific", "Minimal" or "Inactive"
tells deployers what to read before they deploy. It is not a reason to
reject.

The page does not offer a decision milder than the findings allow. Under
each app's Decision it names the finding that sets the floor, as "At least
Request changes:" followed by the finding. The floors are:

- A security failure at High sets at least Request changes, and at Critical
  sets Reject. This applies to every app in the repo, wherever the finding
  is, because installing any app clones the whole repo.
- A failed Structure gate sets Request changes, at any severity. It applies
  to its own app, or to every app when the gate is the repo's.
- Inactivity sets no floor. Whether an inactive repo is abandoned, and so a
  Reject, is your call.
- A repo that is archived or not public sets Request changes for every app.

Warnings set no floor. Where you changed a severity, the floor uses yours.
If a floor looks wrong, check the finding that sets it and change the
finding, with your reason. The repo's overall decision is the strictest of
its apps' decisions.

Before you send an Accept, use **Public view** to check the public page.

The send button is labelled with your decision, such as **Accept and
publish** or **Request changes**. If it is disabled, the page says why. You
must write the Email to Contributor for every decision except Accept.

Send saves the page and opens a preview. It shows what will change in the
catalog and the email exactly as it will go. Nothing goes out until you
click **Send to** followed by the contributor's name. **Back to the review**
returns you to the page.

What sending does:

| Decision | Catalog | Review | Contributor |
|----------|---------|--------|-------------|
| Accept | The repo and the app go live | Published with them | Told it is in the catalog |
| Accept with suggestions | Nothing goes live yet. The repo waits as Ready to publish | Not public until you publish | Told it is accepted and not live yet |
| Request changes | The repo moves to Needs changes. A live repo comes down | Stays unpublished | Asked to fix the repo on GitHub and re-submit |
| Reject (Decline) | The app stays out of the catalog. A live one comes down | Never published | Told the repo was not accepted |

In a repo with several apps and different decisions, each app moves on its
own. The repo goes live when any app is accepted. A repo that is already
live stays live after an Accept or an Accept with suggestions.

Don't publish, unpublish or change the status of an app or repo yourself.
Sending the decision does that, records the decision and emails the
contributor in one step.

### Publishing after Accept with suggestions

The contributor is told the suggestions are optional. They can reply when
they're ready, or say nothing and the app is listed as it is.

The review page then shows **Publish app and review**, to reviewers only.
Publish when it makes sense to you, whether that's after the contributor
replies or right away. Publishing puts the accepted apps, the repo and the
review live, and emails the contributor. It does not run a new review.

## After the decision

After you send, the findings, levels and Public Summary are locked. You can
still change the reviewer and add internal notes.

Contributor replies to the decision email come to your own inbox. Log
anything decided by email in the internal notes.

- **Update decision** reopens each app's decision, the duplicate check and
  the Email to Contributor, until the contributor re-submits. The
  contributor gets an "Updated:" email that replaces the earlier decision.
  The earlier one stays on record.
- **Start the next round** re-submits the repo for the contributor. It runs
  a new AI report on the latest commit and starts a new round. It appears on
  the newest review while the repo is in Needs changes. Use it when the
  contributor tells you by email that they have fixed things.

A contributor can withdraw a submission before you send a decision, and
then there is nothing to decide. When a contributor re-submits, the whole
repo is reviewed again as a new round.

## Who sees what, and when

Before you send a decision, only reviewers can see the review. After you
send, the contributor can read it. The public can see it only while the
repo is live, that is after an Accept, or after you publish an Accept with
suggestions.

| On the review | Contributor, after you send | Public, while the repo is live |
|---------------|-----------------------------|--------------------------------|
| Each app's decision and levels | Yes | Yes |
| Findings, with your own marked Reviewer | Yes | Yes |
| Public Summary | Yes | Yes |
| A finding's note to the contributor | Yes | No |
| Dismissed findings and why | Yes | No |
| Your reason for changing a level | Yes | No |
| Email to Contributor | Yes | No |
| Internal notes | No | No |
| The tool's suggested decision | No | No |
| The Potentially malicious marker | No | No |

On the public page, a severity you changed shows as "Reviewer changed the
severity from High", and a summary you reworded shows as "Edited by the
reviewer".

## Appendix: Reading the catalog by hand

If the page says the catalog was not read, or a Catalog checks result looks
wrong, you can query the catalog yourself. The commands are in the tool's
README, under
[Checking the catalog by hand](https://github.com/Sweet-and-Fizzy/appverse-review#checking-the-catalog-by-hand).
