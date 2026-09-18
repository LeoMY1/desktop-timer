# 学习计时

**P4 已由用户确认完成；P5 1.0.0 已交付，等待用户最终验收。** 本地 macOS 学习计时器：悬浮日累计、暂停/继续/停止、整小时鼓励、备注与每日历史记录。

## 打开
双击 `outputs/P5-v1/StudyTimer.app`。先退出旧版本。继续使用现有 P4 正式记录，启动不自动计时；最终应用没有模拟快进或验收入口，退出只用鼠标点击菜单。

[使用说明](docs/user-guide.md) · [最终验收单](docs/p5-testing.md) · [自测记录](docs/p5-self-test.md) · [阶段状态](docs/acceptance.md)

## 构建与检查
当前 Apple Silicon Mac、macOS 13 部署目标、Swift 5.8 及 Command Line Tools，无第三方依赖，使用系统 SQLite。

```sh
bash scripts/build-p5.sh release
bash scripts/test-p5.sh
bash scripts/test-geometry-p5.sh
bash scripts/test-process-p5.sh
bash scripts/build-p5.sh test
bash scripts/test-ui-p5.sh
```

Release 应用为 `outputs/P5-v1/StudyTimer.app`。内部检查构建单独位于 `work/p5-build/test/StudyTimer-Checks.app`，仅内部版本定义 INTERNAL_TESTING；不随日常应用交付。检查使用独立数据目录，不覆盖正式库。所有当前源代码的正式构建请用 P5 脚本；历史 P2/P3/P4 重建使用对应阶段已交付的源码包。

`STUDY_TIMER_DATA_DIR` 可显式指定绝对路径进行隔离测试。默认目录保持 `~/Library/Application Support/StudyTimerP4`，SQLite/快照版本 2，兼容已有 P4 数据。退出后备份整个目录。

本地 ad-hoc 签名，未公证发行；仅当前 Mac 实测，自然跨午夜仍未实测。完整限制见使用说明。

[需求](docs/requirements.md) · [规格](docs/spec.md) · [阶段计划](docs/delivery-plan.md) · [开发规则](AGENTS.md)
