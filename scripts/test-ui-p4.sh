#!/bin/bash
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_root"
mkdir -p work/p4-evidence
trial_dir="$(mktemp -d "$project_root/work/p4-evidence/ui-data-XXXXXX")"
STUDY_TIMER_DATA_DIR="$trial_dir" "$project_root/outputs/P4-v1/StudyTimer.app/Contents/MacOS/StudyTimer" --ui-check "$project_root/work/p4-evidence/ui"
python3 -c 'import json; assert json.load(open("work/p4-evidence/ui/ui-checks.json"))["allPassed"]'
