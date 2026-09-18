#!/bin/bash
set -euo pipefail
package_root="$(cd "$(dirname "$0")" && pwd)"
app_binary="$package_root/StudyTimer.app/Contents/MacOS/StudyTimer"
if [ ! -x "$app_binary" ]; then
  printf '请将此启动文件与 StudyTimer.app 放在同一个文件夹中。\n' >&2
  exit 1
fi
if pgrep -x StudyTimer >/dev/null; then
  printf '请先从计时器菜单退出正在运行的版本，再重新打开此文件。\n' >&2
  exit 1
fi
mkdir -p "$package_root/验收数据"
trial_dir="$(mktemp -d "$package_root/验收数据/session-XXXXXX")"
printf '%s\n' "$trial_dir" > "$package_root/.last-acceptance-path"
printf '独立验收数据：%s\n退出后可双击“继续上次验收.command”检查记录；日常使用直接打开 StudyTimer.app。\n' "$trial_dir"
STUDY_TIMER_DATA_DIR="$trial_dir" "$app_binary" --acceptance-mode
