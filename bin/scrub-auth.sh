#!/usr/bin/env bash
set -euo pipefail

# Wrapper that delegates to the Python implementation next to this script.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_BIN=${PYTHON_BIN:-}

if [[ -n "${PYTHON_BIN}" ]]; then
  exec "${PYTHON_BIN}" "${SCRIPT_DIR}/scrub-auth.py" "$@"
fi

if command -v python3 >/dev/null 2>&1; then
  exec python3 "${SCRIPT_DIR}/scrub-auth.py" "$@"
elif command -v python >/dev/null 2>&1; then
  exec python "${SCRIPT_DIR}/scrub-auth.py" "$@"
else
  echo "scrub-auth: unable to locate python interpreter (python3 or python)" >&2
  exit 1
fi
