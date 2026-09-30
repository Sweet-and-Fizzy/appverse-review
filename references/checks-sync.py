#!/usr/bin/env python3
"""Generate references/checks.json from references/checks.yml.

    python3 references/checks-sync.py [--verify] [--yml PATH] [--json PATH]

checks.yml is the human-edited manifest; the scripts read checks.json. The
JSON is json.dumps(data, indent=2) plus a newline, so the output is stable.

Without --verify, writes checks.json. With --verify, writes nothing and
exits 1 (printing "checks.json is out of sync with checks.yml") when the
file on disk differs from what would be written.

Needs PyYAML. Without it, prints an error and exits 3 (distinct from 1 so a
caller can SKIP rather than fail; CI has PyYAML). Exit 2 when a file cannot
be read or the YAML has no checks list.
"""
import argparse
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))


def render(data):
    return json.dumps(data, indent=2, ensure_ascii=False) + "\n"


def main(argv):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--verify", action="store_true", help="exit 1 when checks.json is out of sync")
    ap.add_argument("--yml", default=os.path.join(HERE, "checks.yml"))
    ap.add_argument("--json", dest="json_path", default=os.path.join(HERE, "checks.json"))
    args = ap.parse_args(argv[1:])
    try:
        import yaml
    except ImportError:
        print("error: PyYAML is not installed (pip install pyyaml); cannot read checks.yml",
              file=sys.stderr)
        return 3
    try:
        with open(args.yml, encoding="utf-8") as f:
            data = yaml.safe_load(f)
    except (OSError, yaml.YAMLError) as e:
        print("error: cannot read '{}': {}".format(args.yml, e), file=sys.stderr)
        return 2
    if not isinstance(data, dict) or not isinstance(data.get("checks"), list):
        print("error: '{}' has no checks list".format(args.yml), file=sys.stderr)
        return 2
    text = render(data)
    if args.verify:
        try:
            with open(args.json_path, encoding="utf-8") as f:
                current = f.read()
        except OSError as e:
            print("error: cannot read '{}': {}".format(args.json_path, e), file=sys.stderr)
            return 2
        if current != text:
            print("checks.json is out of sync with checks.yml; run python3 references/checks-sync.py")
            return 1
        print("checks.json is in sync with checks.yml")
        return 0
    with open(args.json_path, "w", encoding="utf-8") as f:
        f.write(text)
    print("wrote {}".format(args.json_path))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
