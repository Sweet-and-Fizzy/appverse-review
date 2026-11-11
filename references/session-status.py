#!/usr/bin/env python3
"""Print how a Claude Code session ended, from its execution log.

    python3 references/session-status.py <session.json>

Prints one word, from the log's last result message:

    ok                the session finished
    max_turns         it ran out of turns (subtype error_max_turns)
    context_overflow  the API refused a request because its input passed the
                      model's limit; the session ends there, so whatever the
                      model was doing is unfinished
    error             it ended on another error
    no_result         the log has no result message

The overflow is recognised by the error's wording, which differs by
provider ("prompt is too long", "input is too long", "maximum context
length", "exceed context limit", "longer than the maximum model
length"), so a gateway or model change needs no change here as long as
its error says so in one of those ways.

Exit 0 with the word on stdout, 1 with nothing printed when the log is
missing or unreadable.
"""
import json
import re
import sys

OVERFLOW_RE = re.compile(
    r"(?:prompt|input|request) is too long|maximum context length|context (?:length|window) (?:exceeded|of)"
    r"|exceeds? (?:the )?(?:model'?s )?(?:maximum )?context|longer than the (?:model'?s )?(?:maximum model|context) length"
    # "too many tokens per minute" is a rate limit, not an overflow.
    r"|too many (?:input )?tokens(?! per)",
    re.I)


def session_status(messages):
    if not isinstance(messages, list):
        return None
    results = [m for m in messages if isinstance(m, dict) and m.get("type") == "result"]
    if not results:
        return "no_result"
    r = results[-1]
    if r.get("subtype") == "error_max_turns":
        return "max_turns"
    if not r.get("is_error"):
        return "ok"
    text = r.get("result") if isinstance(r.get("result"), str) else ""
    return "context_overflow" if OVERFLOW_RE.search(text) else "error"


def main(argv):
    if len(argv) != 2 or not argv[1]:
        print("usage: session-status.py <session.json>", file=sys.stderr)
        return 1
    try:
        with open(argv[1]) as f:
            status = session_status(json.load(f))
    except (OSError, ValueError):
        return 1
    if status is None:
        return 1
    print(status)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
