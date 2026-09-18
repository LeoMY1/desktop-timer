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
if [ ! -f "$package_root/.last-acceptance-path" ]; then
  printf '尚无上次验收，请先打开“开始独立验收.command”。\n' >&2
  exit 1
fi
IFS= read -r trial_dir < "$package_root/.last-acceptance-path"
if [[ "$trial_dir" != /* ]] || [ ! -f "$trial_dir/study.sqlite3" ]; then
  printf '上次验收目录不存在，请打开“开始独立验收.command”建立新测试。\n' >&2
  exit 1
fi
printf '继续独立验收数据：%s\n' "$trial_dir"
STUDY_TIMER_DATA_DIR="$trial_dir" "$app_binary" --acceptance-mode
