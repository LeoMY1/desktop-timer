#!/bin/bash
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$project_root/work/p4-acceptance"
trial_dir="$(mktemp -d "$project_root/work/p4-acceptance/session-XXXXXX")"
printf '独立验收数据：%s\n请先退出正在运行的 P4；退出验收模式后，正常双击应用即可使用真实时间。\n' "$trial_dir"
STUDY_TIMER_DATA_DIR="$trial_dir" "$project_root/outputs/P4-v2/StudyTimer.app/Contents/MacOS/StudyTimer" --acceptance-mode
