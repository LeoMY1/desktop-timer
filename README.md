# 桌面悬浮计时应用

当前阶段：**P2 已通过；P3 v1 已交付，等待用户验收。P4 未开始。**

## 打开和使用
双击 `outputs/P3-v1/StudyTimer.app`，或解压 `StudyTimer-P3-v1.zip` 后打开应用。请先退出旧 P2 原型以免混淆。

P3 使用真实时间和本地 SQLite：开始、暂停/继续、停止、多段日累计、北京时间跨日、锁屏/睡眠继续累计、正常退出与异常恢复。启动不自动开始。记录图标打开真实日记录，菜单栏可恢复隐藏的窗口。

- [P3 用户测试清单](docs/p3-testing.md)
- [P3 自测结果与限制](docs/p3-self-test.md)
- [阶段验收记录](docs/acceptance.md)

备注、整小时鼓励和尾段合并将在 P4 接入；P3 停止直接保存时长。P2 文件留在历史版本目录，不与真实数据库混用。

## 构建与验证
本机 Apple Silicon / macOS 26.6.2 / Swift 5.8.1 / CLT SDK 13.3。最低部署目标 macOS 13，其他机型和系统版本尚未验证。无需第三方依赖。

```sh
bash scripts/build-p3.sh release
bash scripts/test-p3.sh
bash scripts/test-process-p3.sh
bash scripts/test-ui-p3.sh
```

当前 CLT 的 Swift Package 构建无法查询 SDK PlatformPath，因此交付脚本直接调用 `xcrun swiftc`，链接系统 SQLite，再生成本地签名的 .app。Package.swift 同时描述正式应用与保留的 P2 原型；`scripts/build.sh` 仍专供旧 P2。

所有自动化数据使用 `work/p3-evidence` 下独立目录。默认正式数据目录为 `~/Library/Application Support/StudyTimer`；`STUDY_TIMER_DATA_DIR` 可指定绝对路径隔离数据。不要手工覆盖数据库及 WAL 文件。

## 产品与设计
[需求](docs/requirements.md) · [规格](docs/spec.md) · [阶段计划](docs/delivery-plan.md) · [开发规则](AGENTS.md)

[浅色设计](design/p0/v3/01-overall-light.png) · [深色参考](design/p0/v1/02-states-dark.png)

P3 保留已验收的悬浮、全区域拖动及 20×20 pt 顶部图标点击范围。所有下一阶段工作必须等用户明确验收与放行。
