#!/bin/zsh
set -euo pipefail
repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
python_runtime="${SCREENSHOT_PYTHON:-/Users/keithbarney/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3}"
exec "$python_runtime" "$repo_dir/scripts/compose-marketing.py" "$@"
