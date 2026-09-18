#!/bin/bash
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_root"
mkdir -p work/p5-evidence
trial_dir="$(mktemp -d "$project_root/work/p5-evidence/ui-data-XXXXXX")"
STUDY_TIMER_DATA_DIR="$trial_dir" "$project_root/work/p5-build/test/StudyTimer-Checks.app/Contents/MacOS/StudyTimer" --ui-check "$project_root/work/p5-evidence/ui"
python3 -c 'import json; assert json.load(open("work/p5-evidence/ui/ui-checks.json"))["allPassed"]'
