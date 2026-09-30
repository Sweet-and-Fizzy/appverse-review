"""Shared repo-path helpers for the finding checkers (check-keys.py,
check-evidence.py): the fixed pseudo-anchor set and a case-exact existence
check. Both scripts import this module instead of keeping their own copy, so
the pseudo-anchor list cannot drift between them.

Each script's own directory is already on sys.path when it runs by path
(python's default for a script argument), so `from repo_paths import ...`
resolves whether check-keys.py or check-evidence.py is the one running.
"""
import os

PSEUDO_ANCHORS = {
    "LICENSE", "README.md", "CHANGELOG.md", ".github/workflows",
    "releases", "issues", "contributors", "commits", "root",
}


def exists_case_exact(root, anchor):
    """Whether anchor (repo-relative) exists under root with every segment's
    case matching exactly. os.path.exists is case-insensitive on some
    filesystems (APFS default, most of Windows), which would let
    'readme.md:readme-typo' validate locally and fail in CI or vice versa.
    Walk the anchor's segments and require each to appear byte-for-byte in
    os.listdir() of its parent."""
    current = root
    for seg in anchor.split("/"):
        try:
            entries = os.listdir(current)
        except OSError:
            return False
        if seg not in entries:
            return False
        current = os.path.join(current, seg)
    return True
