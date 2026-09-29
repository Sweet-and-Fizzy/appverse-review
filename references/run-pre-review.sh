#!/usr/bin/env bash
# Pre-review facts: tools and the shell syntax check run here, before the model.
# Usage: run-pre-review.sh <target-dir> <out-dir> [--catalog URL] [--no-catalog]
set -u
# ${0%/*} rather than dirname: the script must run on a PATH with no coreutils.
here="${0%/*}"; [ "$here" = "$0" ] && here=.
exec python3 "$here/pre-review.py" "$@"
