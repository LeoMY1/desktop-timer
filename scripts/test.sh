#!/bin/bash
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_root"
bash scripts/build.sh release
bash scripts/test-core.sh
bash scripts/test-geometry.sh
bash scripts/test-process.sh
bash scripts/build.sh test
bash scripts/test-ui.sh
python3 scripts/test-release.py
