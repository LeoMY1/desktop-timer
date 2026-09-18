# 图 1 修订版生成提示词

方式：内置 image_gen 图片编辑；模型型号未由接口暴露。
参考／编辑目标：上一版浅色整体设计 `../v1/01-overall-light.png`。
输出：`01-overall-light.png`。

Edit the provided light-mode UI review image. This image is the EDIT TARGET. Make exactly the following two targeted design changes, preserving the established calm native macOS style, neutral/off-white palette, restrained teal accents, Chinese typography, shadows, corner radii, three labeled example areas, example data, and overall landscape board composition. Produce a crisp high-resolution revised UI design sheet. Do not add features or redesign unrelated controls.

CHANGE 1 — Hourly reflection card ABOVE the floating timer.
In the lower-left example labeled “02 整小时鼓励与记录”, reverse the vertical arrangement: the reflection popup card must sit ABOVE the whole timer window. The entire note card (title “又完成一小时”, small “计时继续中”, secondary “今天已累计学习 2 小时”, text field placeholder “记录刚才的学习内容…”, buttons “稍后填写” and “保存”) is the TOP element. The compact timer window with header “今日学习”, status “学习中”, large “02:00”, restrained star glints, and the “暂停” / “停止学习” controls is BELOW it. Keep all timer controls fully visible and clickable. Place the note card just above the timer with a narrow gap and a tiny downward-pointing callout notch to show it belongs to the timer. Keep the two components aligned and of equal width. Fit them into the existing lower-left example area; do not overlap or alter the separate top-left “01 悬浮计时窗” example. The intended interaction is a popup expanding upward from a stationary timer: no full-screen overlay, no input autofocus, no popup below the timer. Do not draw arrows or explanatory callouts across the UI.

CHANGE 2 — Clearly distinguish clock times from elapsed durations throughout the history window.
The RIGHT history window currently uses colon-formatted elapsed durations immediately after colon-formatted time-of-day ranges. This is hard to distinguish. Keep actual clock ranges colon-formatted (09:00–10:00 and 10:20–至今). Change every elapsed-duration display WITHIN THE HISTORY WINDOW to Chinese units.
- Keep section labels “学习段 1” and “学习段 2”.
- First session metadata: actual clock range “09:00–10:00”, then a small pale-teal capsule reading “学习 1小时”. Make the time range and duration visually distinct by spacing and capsule styling, not merely another separator dot.
- Second session metadata: actual clock range “10:20–至今”, then a matching capsule reading “学习 1小时35分钟”.
- Right-aligned note row durations: “1小时”, “1小时”, “35分钟”, respectively.
- Main “今日累计” statistic: display “2小时35分钟”. Emphasize the numerals 2 and 35 with larger weight, render the units 小时 and 分钟 in smaller type on the same baseline. It should clearly read as an elapsed duration rather than another digital clock. Retain the “今日累计” caption.
- Sidebar elapsed totals: selected “9月18日” with “2小时35分”; “9月17日” with “4小时20分”; “9月16日” with “3小时10分”. Keep date and duration from colliding within the existing sidebar; modestly reduce duration text size if needed.
- Preserve all notes exactly: “高等数学 · 极限与连续”, “英语阅读 · 精读两篇”, “本小时进行中”.
- Preserve the header date “2026年9月18日”, “北京时间”, green “正在学习” indicator, navigation structure, all pencil/history icons and native window traffic lights.

IMPORTANT INVARIANTS:
The LEFT floating timer displays MUST remain in HH:MM format: the top-left still shows “02:35”, the lower-left still shows “02:00”. Do not convert these to Chinese units. Only historical totals and elapsed-duration metadata on the RIGHT use explicit Chinese units.
The numerical data must stay consistent: 2小时35分钟 = 1小时 + 1小时35分钟; second session 1小时35分钟 = 1小时 + 35分钟.
The board title remains “学习计时 · 窗口设计”, subtitle “浅色模式”. Keep the original canvas layout and overall scales except the necessary card/timer swap in the lower-left example. All Chinese text should be clean and readable. No added graphs, settings, streaks, reset buttons, seconds, or other unrequested features.

