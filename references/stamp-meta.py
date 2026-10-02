#!/usr/bin/env python3
"""Write the run facts the workflow knows for certain into a review's
meta.json, over whatever the model wrote.

    python3 references/stamp-meta.py <meta.json> <target-dir> <owner/repo> <model-id>

Sets model, sha (the target checkout's HEAD), ref (its branch, or the sha
when detached), repo_url (https://github.com/<owner/repo>), and repo_shape
when the model left it out or wrote a value outside the vocabulary (from the
target: a root appverse.yml with an apps: list is declared_monorepo, any
other root appverse.yml declared_single, none inferred_single). The model
can drop or misstate any of these; the portal cannot import a review
without the sha.

Exit 0 when the file was stamped; 1 when meta.json is missing or not a JSON
object (check-meta.py reports it, and the repair pass rewrites it); 2 on bad
arguments.
"""
import json
import os
import re
import subprocess
import sys

SHAPES = ("inferred_single", "declared_single", "declared_monorepo")


def git(target, *args):
    r = subprocess.run(["git", "-C", target] + list(args), stdout=subprocess.PIPE,
                       stderr=subprocess.DEVNULL, text=True, timeout=20)
    return r.stdout.strip() if r.returncode == 0 else ""


def shape(target):
    p = os.path.join(target, "appverse.yml")
    if not os.path.isfile(p):
        return "inferred_single"
    try:
        text = open(p, encoding="utf-8", errors="replace").read()
    except OSError:
        return "declared_single"
    return "declared_monorepo" if re.search(r"^apps\s*:", text, re.M) else "declared_single"


def main(argv):
    if len(argv) != 5:
        print("usage: stamp-meta.py <meta.json> <target-dir> <owner/repo> <model-id>", file=sys.stderr)
        return 2
    path, target, repo, model = argv[1:5]
    try:
        with open(path, encoding="utf-8") as f:
            meta = json.load(f)
    except (OSError, ValueError) as e:
        print("stamp-meta: %s not stamped (%s)" % (path, e))
        return 1
    if not isinstance(meta, dict):
        print("stamp-meta: %s is not a JSON object" % path)
        return 1
    sha = git(target, "rev-parse", "HEAD")
    branch = git(target, "rev-parse", "--abbrev-ref", "HEAD")
    meta["model"] = model
    if sha:
        meta["sha"] = sha
        meta["ref"] = branch if branch and branch != "HEAD" else sha
    if repo:
        meta["repo_url"] = "https://github.com/%s" % repo
    if meta.get("repo_shape") not in SHAPES:
        meta["repo_shape"] = shape(target)
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(meta, f, indent=2)
    os.replace(tmp, path)
    print("meta.json stamped: model %s, sha %s, ref %s, repo_shape %s" % (
        model, (meta.get("sha") or "?")[:8], meta.get("ref") or "?", meta["repo_shape"]))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
