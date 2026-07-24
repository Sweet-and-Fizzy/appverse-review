#!/usr/bin/env bash

# trigger-review.sh — trigger an Appverse review via workflow_dispatch
# Usage: trigger-review.sh <owner/repo> [aspect] [model]

set -euo pipefail

# Derive the review repo from the git remote of this checkout.
# Falls back to Sweet-and-Fizzy/appverse-review if not in a git repo.
REVIEW_REPO=$(git remote get-url origin 2>/dev/null \
  | sed -n 's|.*github\.com[:/]\(.*\)\.git$|\1|p; s|.*github\.com[:/]\(.*\)$|\1|p')
REVIEW_REPO="${REVIEW_REPO:-Sweet-and-Fizzy/appverse-review}"

DISPATCH_TOKEN="${APPVERSE_DISPATCH_TOKEN:?Set APPVERSE_DISPATCH_TOKEN to your PAT}"
TARGET_REPO="${1:?Usage: trigger-review.sh owner/repo [aspect] [model]}"
ASPECT="${2:-all}"
MODEL="${3:-sonnet}"

gh api \
  "repos/${REVIEW_REPO}/actions/workflows/appverse-review.yaml/dispatches" \
  --method POST \
  --input - <<EOF
{
  "ref": "main",
  "inputs": {
    "target_repo": "${TARGET_REPO}",
    "review_aspects": "${ASPECT}",
    "model": "${MODEL}"
  }
}
EOF

echo "Dispatched review of ${TARGET_REPO} (aspect=${ASPECT}, model=${MODEL})"
echo "Watch: https://github.com/${REVIEW_REPO}/actions"
