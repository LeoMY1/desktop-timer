import AppKit
import SwiftUI
import WindowGeometry

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let model = PrototypeModel()
    var timerPanel: PrototypePanel!
    var notePanel: PrototypePanel!
    var historyWindow: NSWindow?
    var statusItem: NSStatusItem!
    var menu: NSMenu!
    var restoreFrame: NSRect?
    var programmaticMove = false
    var dragging = false
    var dragInitialFrame: NSRect?
    var pendingPrompt: DispatchWorkItem?
    var moveObserver: NSObjectProtocol?
    var screenObserver: NSObjectProtocol?
    let selfCheck = CommandLine.arguments.contains("--self-check")
    // The .app bundle already has a P2-only identifier. Passing the current
    // bundle identifier to init(suiteName:) can return nil on macOS.
    let preferences = UserDefaults.standard

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureMainMenu()
        createTimerPanel()
        configureStatusItem()
        timerPanel.orderFrontRegardless()
        screenObserver = NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            self?.recoverVisiblePosition()
        }
        if selfCheck {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in self?.runSelfCheck() }
        }
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showTimer()
        return true
    }
    func applicationWillTerminate(_ notification: Notification) {
        pendingPrompt?.cancel()
        savePosition(restoreFrame ?? timerPanel.frame)
        if let observer = moveObserver { NotificationCenter.default.removeObserver(observer) }
        if let observer = screenObserver { NotificationCenter.default.removeObserver(observer) }
    }

    func createTimerPanel() {
        let visible = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        var frame = NSRect(x: visible.maxX - 318, y: visible.maxY - 220, width: 288, height: 176)
        if !selfCheck, let saved = preferences.string(forKey: "timerOrigin") {
            let point = NSPointFromString(saved)
            if point.x.isFinite && point.y.isFinite { frame.origin = point }
        }
        let screen = bestScreen(for: frame)
        frame = PanelLayout.clamped(frame, to: screen.visibleFrame)
        timerPanel = PrototypePanel(frame: frame, permitsTextInput: false)
        timerPanel.title = "学习计时 · P2交互原型"
        timerPanel.identifier = NSUserInterfaceItemIdentifier("p2-timer")
        let content = TimerView(model: model, primary: { [weak self] in self?.primaryAction() },
            stop: { [weak self] in self?.stopDemo() },
            history: { [weak self] in self?.openHistory() },
            showMenu: { [weak self] in self?.showPopupMenu() },
            beginDrag: { [weak self] in self?.beginUserDrag() },
            endDrag: { [weak self] in self?.endUserDrag() })
        timerPanel.contentView = PassiveHostingView(rootView: content)
        notePanel = PrototypePanel(frame: NSRect(x: 0, y: 0, width: 288, height: 244), permitsTextInput: true)
        notePanel.title = "学习备注 · P2交互原型"
        notePanel.identifier = NSUserInterfaceItemIdentifier("p2-note")
        notePanel.contentView = PassiveHostingView(rootView: NoteCardView(model: model,
            close: { [weak self] in self?.closeCard() },
            save: { [weak self] in self?.saveDemoNote(merge: false) },
            merge: { [weak self] in self?.saveDemoNote(merge: true) }))
        moveObserver = NotificationCenter.default.addObserver(forName: NSWindow.didMoveNotification, object: timerPanel, queue: .main) { [weak self] _ in
            guard let self = self, !self.programmaticMove else { return }
            if self.notePanel.isVisible { self.alignPopup(adjustTimer: !self.dragging) }
            if !self.dragging { self.savePosition(self.restoreFrame ?? self.timerPanel.frame) }
        }
    }

    func bestScreen(for frame: NSRect) -> NSScreen {
        NSScreen.screens.max { a, b in
            let ai = a.visibleFrame.intersection(frame)
            let bi = b.visibleFrame.intersection(frame)
            let aa = ai.isNull ? 0 : ai.width * ai.height
            let ba = bi.isNull ? 0 : bi.width * bi.height
            return aa < ba
        } ?? NSScreen.main!
    }

    func setTimerFrame(_ frame: NSRect) {
        programmaticMove = true
        timerPanel.setFrame(frame, display: true)
        programmaticMove = false
    }

    func beginUserDrag() {
        dragging = true
        dragInitialFrame = timerPanel.frame
    }
    func endUserDrag() {
        dragging = false
        let moved = dragInitialFrame.map { abs($0.minX - timerPanel.frame.minX) > 0.5 || abs($0.minY - timerPanel.frame.minY) > 0.5 } ?? false
        dragInitialFrame = nil
        guard moved else { return }
        restoreFrame = nil
        let screen = bestScreen(for: timerPanel.frame)
        setTimerFrame(PanelLayout.clamped(timerPanel.frame, to: screen.visibleFrame))
        if notePanel.isVisible {
            alignPopup(adjustTimer: true, rememberOriginal: false)
            restoreFrame = nil
        }
        savePosition(timerPanel.frame)
    }
    func savePosition(_ frame: NSRect) {
        guard !selfCheck else { return }
        preferences.set(NSStringFromPoint(frame.origin), forKey: "timerOrigin")
    }
    func recoverVisiblePosition() {
        let frame = PanelLayout.clamped(timerPanel.frame, to: bestScreen(for: timerPanel.frame).visibleFrame)
        setTimerFrame(frame)
        if let original = restoreFrame {
            restoreFrame = PanelLayout.clamped(original, to: bestScreen(for: original).visibleFrame)
        }
        if notePanel.isVisible { alignPopup(adjustTimer: true) }
    }

    func alignPopup(adjustTimer: Bool, rememberOriginal: Bool = true) {
        let visible = bestScreen(for: timerPanel.frame).visibleFrame
        if !adjustTimer {
            notePanel.setFrameOrigin(NSPoint(x: timerPanel.frame.minX, y: timerPanel.frame.maxY + 3))
            return
        }
        let placement = PanelLayout.above(timer: timerPanel.frame, popupSize: NSSize(width: 288, height: 244), visible: visible)
        if placement.shifted && rememberOriginal && restoreFrame == nil { restoreFrame = timerPanel.frame }
        setTimerFrame(placement.timer)
        notePanel.setFrame(placement.popup, display: true)
    }

    func showCard(_ kind: DemoCard) {
        showTimer()
        model.card = kind
        if kind == .hourly {
            model.phase = .running
            model.displayTime = "02:00"
            withAnimation(.easeInOut(duration: 0.35)) { model.celebration = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                withAnimation(.easeOut(duration: 0.4)) { self?.model.celebration = false }
            }
        } else {
            model.phase = .stopped
            model.displayTime = "02:35"
        }
        alignPopup(adjustTimer: true)
        // orderFront (not makeKey) is intentional: a reminder must not steal input.
        notePanel.orderFrontRegardless()
    }
    @objc func closeCard() {
        notePanel.orderOut(nil)
        if let original = restoreFrame {
            setTimerFrame(PanelLayout.clamped(original, to: bestScreen(for: original).visibleFrame))
            restoreFrame = nil
        }
        savePosition(timerPanel.frame)
    }
    func saveDemoNote(merge: Bool) {
        model.feedback = merge ? "已演示合并选择 · 不写入学习记录" : "演示文字已暂存 · 仅本次运行"
        closeCard()
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in self?.model.feedback = "" }
    }

    @objc func primaryAction() { model.primaryAction() }
    @objc func stopDemo() { model.phase = .stopped; showCard(.tail) }
    @objc func showHourlyDemo() { showCard(.hourly) }
    @objc func showTailDemo() { showCard(.tail) }
    @objc func delayedHourlyDemo() {
        pendingPrompt?.cancel()
        model.delayedPromptPending = true
        let work = DispatchWorkItem { [weak self] in
            self?.model.delayedPromptPending = false
            self?.showCard(.hourly)
        }
        pendingPrompt = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 8, execute: work)
    }
    @objc func showTimer() { timerPanel.orderFrontRegardless() }
    @objc func hideTimer() {
        closeCard()
        pendingPrompt?.cancel()
        model.delayedPromptPending = false
        timerPanel.orderOut(nil)
    }
    @objc func moveNearTop() {
        closeCard()
        let visible = bestScreen(for: timerPanel.frame).visibleFrame
        var frame = timerPanel.frame
        frame.origin.y = visible.maxY - frame.height - 8
        setTimerFrame(frame)
        savePosition(frame)
        showTimer()
    }
    @objc func setFixture(_ sender: NSMenuItem) {
        closeCard()
        if let state = DemoPhase(rawValue: sender.representedObject as? String ?? "") { model.setFixture(state) }
    }
    @objc func openHistory() {
        if historyWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 850, height: 620),
                                  styleMask: [.titled, .closable, .miniaturizable, .resizable],
                                  backing: .buffered, defer: false)
            window.title = "学习记录 · P2 演示"
            window.identifier = NSUserInterfaceItemIdentifier("p2-history")
            window.isReleasedWhenClosed = false
            window.minSize = NSSize(width: 760, height: 590)
            window.titlebarAppearsTransparent = true
            window.contentView = NSHostingView(rootView: HistoryView(model: model, showTail: { [weak self] in self?.showCard(.tail) }))
            window.center()
            historyWindow = window
        }
        historyWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func setAppearance(_ sender: NSMenuItem) {
        let mode = sender.representedObject as? String ?? "system"
        NSApp.appearance = mode == "dark" ? NSAppearance(named: .darkAqua) : mode == "light" ? NSAppearance(named: .aqua) : nil
        for window in [timerPanel as NSWindow?, notePanel as NSWindow?, historyWindow] {
            window?.contentView?.needsDisplay = true
        }
    }
    @objc func quit() { NSApp.terminate(nil) }

    func configureStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "timer", accessibilityDescription: "学习计时 P2 原型")
        statusItem.button?.image?.isTemplate = true
        statusItem.button?.toolTip = "学习计时 · P2交互原型"
        menu = NSMenu()
        menu.addItem(withTitle: "学习计时 · P2交互原型", action: nil, keyEquivalent: "")
        menu.addItem(withTitle: "仅示例数据，不进行真实计时", action: nil, keyEquivalent: "")
        menu.addItem(.separator())
        addMenu("显示计时窗", action: #selector(showTimer))
        addMenu("隐藏计时窗", action: #selector(hideTimer))
        addMenu("学习记录（演示）", action: #selector(openHistory))
        menu.addItem(.separator())
        addMenu("演示整小时卡片", action: #selector(showHourlyDemo))
        addMenu("8秒后演示卡片（测试不抢焦点）", action: #selector(delayedHourlyDemo))
        addMenu("演示停止后的尾段卡片", action: #selector(showTailDemo))
        addMenu("收起卡片", action: #selector(closeCard))
        addMenu("移到屏幕顶端（验收定位）", action: #selector(moveNearTop))
        menu.addItem(.separator())
        for phase in DemoPhase.allCases {
            let item = addMenu("演示状态：" + phase.title, action: #selector(setFixture(_:)))
            item.representedObject = phase.rawValue
        }
        menu.addItem(.separator())
        for (title, key) in [("跟随系统外观", "system"), ("验收浅色外观", "light"), ("验收深色外观", "dark")] {
            addMenu(title, action: #selector(setAppearance(_:))).representedObject = key
        }
        menu.addItem(.separator())
        addMenu("退出原型", action: #selector(quit), key: "q")
        statusItem.menu = menu
    }
    @discardableResult func addMenu(_ title: String, action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        menu.addItem(item)
        return item
    }
    func showPopupMenu() {
        menu.popUp(positioning: nil, at: NSPoint(x: 260, y: 153), in: timerPanel.contentView)
    }

    func configureMainMenu() {
        let main = NSMenu()
        let applicationItem = NSMenuItem()
        let applicationMenu = NSMenu()
        let quit = NSMenuItem(title: "退出学习计时原型", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        applicationMenu.addItem(quit)
        applicationItem.submenu = applicationMenu
        main.addItem(applicationItem)
        let editItem = NSMenuItem(title: "编辑", action: nil, keyEquivalent: "")
        let edit = NSMenu(title: "编辑")
        edit.addItem(withTitle: "撤销", action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(.separator())
        edit.addItem(withTitle: "剪切", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "复制", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "粘贴", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "全选", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = edit
        main.addItem(editItem)
        NSApp.mainMenu = main
    }
}
