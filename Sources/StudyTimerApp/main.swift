import AppKit
#if !INTERNAL_TESTING
// Refuse historical test launchers before opening any user data.
if CommandLine.arguments.contains("--acceptance-mode") || CommandLine.arguments.contains("--ui-check") {
    fputs("此为日常使用版本，不支持模拟验收入口。请直接打开应用。\n", stderr)
    exit(2)
}
#endif
let application=NSApplication.shared
let delegate=AppDelegate()
application.delegate=delegate
application.setActivationPolicy(.accessory)
application.run()
