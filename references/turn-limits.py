#!/usr/bin/env python3
"""Print the review session's turn limit.

    python3 references/turn-limits.py <apps.json> [override]

The limit is min(100 + 10 * (apps - 1), 150), with apps the length of the
pre-review step's apps.json list, or 1 when the file is missing, unreadable
or not a non-empty list (dry runs and failed pre-reviews have none). A
one-app repo keeps the 100 turns it always had; a monorepo gets more, but
the app count is the repo's to choose, so 150 caps it however many apps a
submission claims.

An override (the workflow's max_turns dispatch input) replaces the computed
limit when it is 1 to 4 digits and at least 1, clamped to the same cap;
anything else is ignored with a warning, since it reaches claude_args and a
newline or space there would add flags. Always exits 0 and prints one
integer.
"""
import json
import re
import sys

BASE = 100
PER_EXTRA_APP = 10
CAP = 150
OVERRIDE_RE = re.compile(r"\A[0-9]{1,4}\Z")


def warn(message):
    print("warning: " + message, file=sys.stderr)


def app_count(path):
    try:
        with open(path, encoding="utf-8") as f:
            apps = json.load(f)
    except FileNotFoundError:
        return 1
    except (OSError, ValueError) as e:
        warn("cannot read {} ({}); counting 1 app".format(path, e))
        return 1
    return len(apps) if isinstance(apps, list) and apps else 1


def limit(apps, override=""):
    computed = min(BASE + PER_EXTRA_APP * (apps - 1), CAP)
    if override == "":
        return computed
    if not OVERRIDE_RE.match(override) or int(override) < 1:
        warn("max_turns override {!r} is not a number from 1 to {}; using {}".format(override, CAP, computed))
        return computed
    return min(int(override), CAP)


def main(argv):
    if len(argv) not in (2, 3):
        warn("usage: turn-limits.py <apps.json> [override]; using {}".format(BASE))
        print(BASE)
        return 0
    print(limit(app_count(argv[1]), argv[2] if len(argv) == 3 else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
