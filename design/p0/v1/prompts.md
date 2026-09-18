# P0 设计稿生成提示词

生成方式：内置 image_gen。实际模型型号未由工具暴露；未使用 CLI/API 密钥。两张图为待审查提案。

## 01 — 浅色整体窗口

输出：`01-overall-light.png`

Use case: ui-mockup.
Create ONE polished, realistic, implementation-ready macOS desktop app UI review board, landscape, high resolution, with crisp legible Simplified Chinese text. This is a visual design proposal, not an implemented app screenshot. App working title: “学习计时”. The user wants a calm, compact always-on-top learning timer and daily learning notes. Design light mode first. No external brand or invented features.

Visual language: quiet native macOS refinement, warm off-white and very pale gray surfaces, dark graphite text, restrained low-saturation teal accent (#467D74), fine neutral borders, soft short shadows, corner radius about 16 pt, tasteful translucent panel material without losing contrast. SF Pro-like UI lettering and PingFang-like Chinese; large tabular monospaced time digits. No neon, no purple gradients, no huge marketing slogans, no photography, no cute mascots, no heavy glass blur. Small neutral canvas outside the windows, generous disciplined spacing. All three UI examples must clearly share one component system. Show windows front-on, no perspective, no laptop frame, no browser frame around the board.

Board composition: a small editorial title at top “学习计时 · 窗口设计”, subtitle “浅色模式”. LEFT column contains two stacked component examples with modest section labels; RIGHT has a larger daily-history window. Present the small windows enlarged for review but retain their compact proportions. The history window should be the largest element. Avoid large unused decorative areas.

LEFT TOP — label “01  悬浮计时窗”. A compact horizontal rounded utility window, approximately 270×145 logical points, draggable surface without normal macOS traffic-light controls. Header “今日学习”, a tiny subdued green dot with “学习中”, and a small history/list icon at far right. Main visual “02:35” in large precise tabular digits, representing HOURS:MINUTES only. Footer two compact controls: pause icon plus “暂停”, stop icon plus “停止学习”. Pause is the emphasized teal-tinted action; stop is a neutral secondary action, not a dangerous bright red. Clear, easy-to-hit controls, restrained padding. No seconds, no progress ring, no countdown and no daily target.

LEFT BOTTOM — label “02  整小时鼓励与记录”. A state example of the same floating window with time “02:00”, expanded into an attached compact note card below. Preserve the same timer header and controls so it is evident timing continues. Show a very small cluster of soft teal/gold four-point glints near the time: a single keyframe of a gentle 2-second silent celebration, not confetti across the desktop. Inside the attached note area: title “又完成一小时”, secondary “今天已累计学习 2 小时”, a simple multiline text field with placeholder “记录刚才的学习内容…”, footer buttons “稍后填写” and a teal “保存”. Small muted status “计时继续中”. Do not show an input caret or focused blue text-field ring, since the card does not autofocus. These two left examples are DIFFERENT moments, not two simultaneously running timers.

RIGHT — label “03  每日学习记录”. A clean native macOS document window about 760×570 logical points, subtle traffic lights at top left, title “学习记录”. Narrow left sidebar with heading “每日记录” and three date rows, selected “9月18日” / “02:35”, followed by “9月17日” / “04:20” and “9月16日” / “03:10”. Main content header “2026年9月18日”, small label “北京时间”, hero statistic “02:35” with caption “今日累计”. A small quiet green status “正在学习”. Below: two learning-session groups with comfortably readable notes, gentle dividing lines and small pencil edit icons:
Group 1 heading “学习段 1”, metadata “09:00–10:00 · 01:00”, one note row “高等数学 · 极限与连续” with duration “01:00”.
Group 2 heading “学习段 2”, metadata “10:20–至今 · 01:35”, completed note row “英语阅读 · 精读两篇” with duration “01:00”, followed by a clearly muted running row “本小时进行中” with duration “00:35”.
Arithmetic must be consistent: 01:00 + 01:35 = 02:35; second group 01:00 + 00:35 = 01:35. The note rows are the records, not analytics charts.
Keep the hierarchy dates → learning sessions → learning notes visually clear. Modest empty space is fine; do not fill with extra metrics.

Important constraints: All interface text in Simplified Chinese exactly as specified wherever possible; natural Chinese glyphs, no gibberish. UI should look buildable using native SwiftUI/AppKit controls. No chart, heat map, streak, leaderboard, pomodoro, account/avatar, cloud sync, task tags, manual time editing, export button, settings dashboard, alarm, or notifications permission dialog. No oversized widget that obstructs daily browsing. Do not add additional timer windows beyond the two explicitly labeled state examples. The result should be a coherent high-fidelity design review sheet, not a promotional poster.

## 02 — 状态与深色设计

输出：`02-states-dark.png`

参考图：`01-overall-light.png`，仅用于保持组件与视觉风格一致。

Use case: ui-mockup.
Create ONE companion high-fidelity macOS UI design review board for “学习计时”, using the supplied light-mode image ONLY as a visual-system reference. This is a NEW second design sheet showing additional states in DARK MODE. Preserve the same typography, timer digit design, compact widget proportions, understated teal accent, corner radii, control shapes and information hierarchy. Do not alter the previously generated image.

A clean front-on product design board, landscape with sufficient vertical room (prefer 4:3), high resolution, all Simplified Chinese text sharp and correctly formed. Dark canvas #15191B, elevated panel surfaces approximately #242B2E, very subtle light border, warm off-white primary text, clearly legible cool-gray secondary text, muted light-teal #8DC4BA accents with good contrast. Buttons remain restrained, no glowing/neon surfaces. Same native macOS UI feeling as the reference; no perspective, photo, laptop, browser chrome, decoration or marketing poster. Board title at top “学习计时 · 状态与深色设计”, small subtitle “深色模式”. On this review board each labeled example represents an independent state at a different moment; they are not simultaneously running timers.

Composition: narrow LEFT column with THREE stacked, compact timer state examples, and a larger RIGHT column with ONE dark daily-history window. Give the bottom-left example enough room for its attached tail-record card. Do not repeat large idle blank areas. Small clear labels outside each example.

LEFT TOP — label “01  未开始”.
Same compact floating window as the reference, header “今日学习”, small status “未开始”, history/list icon at upper right. Large tabular “00:00”. Bottom one balanced teal primary button with a play icon and label “开始学习”. No reset button, no irrelevant disabled pause button.

LEFT MIDDLE — label “02  已暂停”.
Same window and header, a subtle amber-gray status dot with “已暂停”. Large time “01:25”. Bottom two buttons: emphasized teal “继续学习” with play icon, secondary neutral “停止学习” with stop icon. The numbers are unchanged while paused; no extra helper prose in the widget.

LEFT BOTTOM — label “03  停止后的尾段处理”.
Same timer shell, header “今日学习”, status “已停止”, large time “02:35”. Main action “开始学习”, because starting again begins a new learning session without resetting today's total.
Attached compact card below, same construction as the attached reflection card in the light reference: title “最后 35 分钟”, subtle supporting sentence “选择这段学习的记录方式”. Multiline unfocused input field with placeholder “写下这段学习内容…”. Two clearly distinct buttons “单独记录” and “合并上一条”; use the same teal primary and neutral secondary styles as the reference. Small quiet tertiary link “稍后处理”. This card is local to the stopped session, not a modal overlay and not a full-screen alert. It must not obscure the timer above. No text caret or autofocus ring.

RIGHT — label “04  每日记录 · 深色”.
A larger native macOS dark window, identical structural hierarchy to the light reference: subtle traffic lights, window title “学习记录”, left date sidebar and right content. Sidebar heading “每日记录”; selected “9月18日” / “02:35”, next “9月17日” / “04:20”, next “9月16日” / “03:10”. Selection is a muted teal tinted surface.
Content top: “2026年9月18日”, “北京时间”, large “02:35” and “今日累计”. Quiet status “已停止”.
First group: “学习段 1”, “09:00–10:00 · 01:00”, note row “高等数学 · 极限与连续”, right duration “01:00”, a small edit pencil where appropriate.
Second group: “学习段 2”, “10:20–11:55 · 01:35”, completed row “英语阅读 · 精读两篇”, right duration “01:00”, then a subdued pending row “尾段待处理”, right duration “00:35”, modest text action “处理”.
All arithmetic must be consistent: today's 02:35 = session 1's 01:00 + session 2's 01:35; session 2 = completed note 01:00 + pending tail 00:35. Do not duplicate the tail into another record before the user chooses a treatment. No running indicator in this history snapshot since this is the stopped-state example.

Constraints: all interface content in Simplified Chinese, natural Chinese glyphs, clear contrast and implementable typography. Only the four specified examples. No chart, timeline graph, heat map, progress ring, goal, streak, leaderboard, mascot, emoji reward, cloud sync, account, export, manual editing of durations, countdown, seconds, reset action, notification permission, or gratuitous settings. No solid black illegible surfaces. Treat this as a practical companion sheet that a user can compare with the provided light-mode sheet to approve the full window style and states.

