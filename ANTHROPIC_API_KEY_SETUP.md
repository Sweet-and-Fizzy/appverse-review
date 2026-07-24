# Anthropic API Key Setup for AppVerse Review CI

Step-by-step instructions for configuring the Anthropic API key used by
the GitHub Actions workflow.

## Step 1: Get an API Key from Anthropic

1. Go to **https://console.anthropic.com**
2. Sign in (or create an account)
3. Go to **Settings > API Keys**
4. Click **Create Key**
5. Give it a name (e.g. `appverse-review-ci`)
6. Copy the key immediately — it is only shown once
7. The key should start with `sk-ant-api03-...`

## Step 2: Verify Billing Is Active

1. In the Anthropic Console, go to **Settings > Billing**
2. Confirm there is a payment method on file and the account is active
3. Check **Settings > Limits** — make sure usage has not hit the spend
   limit (the workflow uses roughly $2 per review run)

## Step 3: Add the Key as a GitHub Repository Secret

1. Go to the repo: https://github.com/Sweet-and-Fizzy/appverse-review
2. Click **Settings** (requires admin or maintainer access)
3. In the left sidebar: **Secrets and variables > Actions**
4. Make sure you are on the **Secrets** tab (not Variables — variables
   are plaintext and would expose the key in workflow logs)
5. Click **New repository secret**
6. Name: `ANTHROPIC_API_KEY` (must match exactly — this is what the
   workflow references)
7. Value: paste the `sk-ant-api03-...` key with no extra whitespace
8. Click **Add secret**

## Common Pitfalls

| Symptom | Cause |
|---|---|
| `Invalid API key` / 401 error | Key is expired, revoked, or has extra whitespace |
| Key shows as `""` in logs (not `***`) | Secret name does not match `ANTHROPIC_API_KEY` |
| Key shows as `***` but still 401 | Key is from a different Anthropic org, or billing is inactive |
| Stored as variable instead of secret | Used the Variables tab — move it to Secrets |

## How to Verify

After adding the secret, trigger the workflow manually:

1. Go to **Actions > AppVerse App Review**
2. Click **Run workflow**
3. Enter a target repo (e.g. `fasrc/ood-sas`)
4. In the logs, look for `OIDC token successfully obtained` and confirm
   the run progresses past authentication
