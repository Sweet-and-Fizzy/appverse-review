**Check tiers:** Tiers 1–2

Tier 3 not checked — no isolated execution environment.

| Tool | Status | Result |
|---|---|---|
| shellcheck | Run (ERB-stripped) | 5 findings (SC2086, SC2148, SC2164), 1 of them linted in isolation from the job-script family |
| semgrep | Run | 0 findings |
| bandit | Not run (no applicable files) | — |
| trivy | Not run (no applicable files) | — |
