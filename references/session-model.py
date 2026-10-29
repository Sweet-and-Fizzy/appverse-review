#!/usr/bin/env python3
"""Print the model a Claude Code session ran, from its execution log.

    python3 references/session-model.py <session.json>

The workflow passes `--model sonnet` or `--model opus` for an Anthropic run,
which Claude Code resolves to its newest model of that tier, so the
requested name is not the model that ran. The log's init message names the
resolved model; failing that, the first assistant message does. The
printed id is checked against the same characters the workflow allows a
model id (letters, digits and . _ / : -), since it goes to GITHUB_ENV.

Exit 0 with the id on stdout, 1 with nothing printed when the log is
missing, unreadable or names no usable model.
"""
import json
import re
import sys

MODEL_RE = re.compile(r"[A-Za-z0-9._/:-]+")


def session_model(messages):
    if not isinstance(messages, list):
        return None
    msgs = [m for m in messages if isinstance(m, dict)]
    for m in msgs:
        if m.get("type") == "system" and m.get("subtype") == "init" and m.get("model"):
            return m["model"]
    for m in msgs:
        inner = m.get("message")
        if m.get("type") == "assistant" and isinstance(inner, dict) and inner.get("model"):
            return inner["model"]
    return None


def main(argv):
    if len(argv) != 2:
        print("usage: session-model.py <session.json>", file=sys.stderr)
        return 1
    try:
        with open(argv[1]) as f:
            model = session_model(json.load(f))
    except (OSError, ValueError):
        return 1
    if not isinstance(model, str) or not MODEL_RE.fullmatch(model):
        return 1
    print(model)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
