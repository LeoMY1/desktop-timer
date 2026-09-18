# 桌面悬浮计时应用

面向日常学习的本地 Mac 计时器。当前已交付 **P2 原生交互原型 v3，等待用户测试验收**。用户于 2026-09-18 明确要求“按照文档，完成P2开发”；P3 尚未获准。

## 运行与验收
双击 `outputs/P2-v3/StudyTimer-P2.app`。仅支持本次构建的 Apple Silicon Mac。

这是窗口交互原型：时间、日期和历史均为固定演示数据，不会真实计时；文字只保留在本次运行。仅窗口位置保存到独立 P2 偏好设置，不创建学习数据库。

- [P2 用户测试清单](docs/p2-testing.md)：如何运行、触发卡片和逐项测试。
- [P2 自测记录](docs/p2-self-test.md)：已测范围、证据与未测项。
- [当前验收状态](docs/acceptance.md)：内部检查与用户验收分开记录。

## 构建
当前机器只有 Command Line Tools，使用不依赖完整 Xcode 的脚本：

```sh
bash scripts/build.sh release
bash scripts/test.sh
./outputs/P2-v3/StudyTimer-P2.app/Contents/MacOS/StudyTimerPrototype --self-check "$PWD/work/p2-evidence/local"
```

构建目标为 arm64 / macOS 13，无第三方依赖。`Package.swift` 保留工程结构；当前 CLT 环境的 `swift build` 无法查询 SDK PlatformPath，因此本机交付采用 `xcrun swiftc`。测试是独立 Swift 检查程序，不依赖 XCTest。

## 产品文档
- [需求文档](docs/requirements.md)
- [技术规格](docs/spec.md)
- [分阶段交付计划](docs/delivery-plan.md)
- [开发协作规则](AGENTS.md)

## 设计参考
- [浅色最新稿](design/p0/v3/01-overall-light.png)
- [深色与状态参考](design/p0/v1/02-states-dark.png)

P2 已采用卡片在上、顶部避让、历史中文时长和隐藏时区标签的修订。主窗为 288×176 pt，额外高度用于明确显示原型提示。下一阶段必须等用户验收 P2 并明确允许继续。
