#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

if [[ ! -x .venv/bin/openwrite ]]; then
  echo "OpenWrite is not installed in .venv. Run: python3 -m venv .venv && .venv/bin/python -m pip install -e ." >&2
  exit 1
fi

source ./openwrite-env.sh
source .venv/bin/activate

if [[ $# -eq 0 ]]; then
  exec openwrite goethe
fi

exec openwrite "$@"
