# 桌面悬浮计时应用

**P4 v1 已交付，等待用户验收；P5 未开始。** 用户已授权进入 P4，确认真实睡眠和锁屏测试通过；自然跨午夜仍未实测。

## 打开
双击 `outputs/P4-v1/StudyTimer.app`。先退出旧版本，以免混淆。新版从空白记录开始，旧 P3 测试数据不导入。

已支持真实计时、日累计、北京时间归日、SQLite 保存，以及累计整小时无声鼓励、上方备注卡片、提醒合并与排队、历史备注编辑、尾段单独或合并。退出时自动处理尚未选择的尾段，并保留文字。

- [P4 测试步骤](docs/p4-testing.md)
- [P4 自测记录](docs/p4-self-test.md)
- [阶段验收状态](docs/acceptance.md)

交付目录提供 `开始独立验收.command` 和 `继续上次验收.command`，可快进时间测试整小时/跨日，不改系统时间、不写正式库。日常使用直接打开应用即可。

## 数据与构建
正式数据位于 `~/Library/Application Support/StudyTimerP4`。备注约 0.4 秒自动保存，关键操作立即保存，运行时每 5 秒保存检查点。环境变量 STUDY_TIMER_DATA_DIR 支持绝对路径隔离测试。

```sh
bash scripts/build-p4.sh release
bash scripts/test-p4.sh
bash scripts/test-ui-p4.sh
bash scripts/open-p4-acceptance.sh
```

当前源码为 P4，旧阶段重建请使用当时已交付的源码包。当前构建通过 CLT 的 xcrun swiftc，使用系统 SQLite，无第三方库。目标 arm64 / macOS 13，仅当前 Mac 验证。本地 ad-hoc 签名，尚未公证发布。

[需求](docs/requirements.md) · [规格](docs/spec.md) · [阶段计划](docs/delivery-plan.md) · [开发规则](AGENTS.md)

[浅色设计](design/p0/v3/01-overall-light.png) · [深色参考](design/p0/v1/02-states-dark.png)
