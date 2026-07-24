#!/usr/bin/env bash

# trigger-review.sh — trigger an AppVerse review via workflow_dispatch
# Usage: trigger-review.sh <owner/repo> [aspect] [model]

set -euo pipefail

DISPATCH_TOKEN="${APPVERSE_DISPATCH_TOKEN:?Set APPVERSE_DISPATCH_TOKEN to your PAT}"
TARGET_REPO="${1:?Usage: trigger-review.sh owner/repo [aspect] [model]}"
ASPECT="${2:-all}"
MODEL="${3:-sonnet}"

gh api \
  repos/Sweet-and-Fizzy/appverse-review/actions/workflows/appverse-review.yaml/dispatches \
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
echo "Watch: https://github.com/Sweet-and-Fizzy/appverse-review/actions"
