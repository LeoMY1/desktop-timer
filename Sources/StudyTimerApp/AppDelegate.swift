import AppKit
import SwiftUI
import StudyCore
import WindowGeometry

final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = StudyModel()
    var panel: PrototypePanel!
    var historyWindow: NSWindow?
    var statusItem: NSStatusItem!
    var menu = NSMenu()
    var refreshTimer: Timer?
    var observers: [NSObjectProtocol] = []
    var workspaceObservers: [NSObjectProtocol] = []
    var primaryItem: NSMenuItem!
    var stopItem: NSMenuItem!
    var retryItem: NSMenuItem!
    var dragInitialFrame: NSRect?
    let uiCheck = CommandLine.arguments.contains("--ui-check")
    var preferences: UserDefaults { .standard }
    func applicationDidFinishLaunching(_ notification: Notification) {
        if uiCheck {
            guard ProcessInfo.processInfo.environment["STUDY_TIMER_DATA_DIR"] != nil else {
                fputs("--ui-check requires an isolated STUDY_TIMER_DATA_DIR\n", stderr)
                exit(2)
            }
            model.source = UICheckClock()
        }
        model.load()
        buildWindow()
        buildMenus()
        panel.orderFrontRegardless()
        refreshTimer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            do { self?.tick() }
        }
        RunLoop.main.add(refreshTimer!, forMode: .common)
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            do { self?.clampPosition() }
        })
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.didWakeNotification] {
            workspaceObservers.append(NSWorkspace.shared.notificationCenter.addObserver(forName:name,object:nil,queue:.main) { [weak self] _ in
                do {
                    self?.model.tick()
                    if let controller = self?.model.controller { try? controller.checkpoint() }
                    self?.model.refresh(); self?.updateMenu()
                }
            })
        }
        updateMenu()
        if uiCheck { DispatchQueue.main.asyncAfter(deadline: .now()+0.3) { self.runUICheck() } }
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showTimer(); return true }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard model.ready else { return .terminateNow }
        if model.perform(.quit) { return .terminateNow }
        let alert = NSAlert()
        alert.messageText = "退出前未能保存学习记录"
        alert.informativeText = "\(model.errorText ?? "保存失败")\n继续退出将仅保留最后成功保存的数据。"
        alert.addButton(withTitle:"留在应用重试")
        alert.addButton(withTitle:"仍然退出")
        NSApp.activate(ignoringOtherApps:true)
        return alert.runModal() == .alertSecondButtonReturn ? .terminateNow : .terminateCancel
    }
    func applicationWillTerminate(_ notification: Notification) {
        refreshTimer?.invalidate()
        if !uiCheck { preferences.set(NSStringFromPoint(panel.frame.origin),forKey:"timerOrigin") }
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
        for observer in workspaceObservers { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
    }
    func buildWindow() {
        let visible = NSScreen.main!.visibleFrame
        var frame = NSRect(x:visible.maxX-318,y:visible.maxY-220,width:288,height:176)
        if !uiCheck, let saved=preferences.string(forKey:"timerOrigin") { frame.origin=NSPointFromString(saved) }
        if !frame.origin.x.isFinite || !frame.origin.y.isFinite { frame.origin=visible.origin }
        frame=PanelLayout.clamped(frame,to:screen(for:frame).visibleFrame)
        panel=PrototypePanel(frame:frame,permitsTextInput:false)
        panel.title="学习计时 · P3"; panel.identifier=NSUserInterfaceItemIdentifier("p3-timer")
        panel.contentView=PassiveHostingView(rootView:TimerView(model:model,
            primary:{ [weak self] in self?.primaryAction() },stop:{ [weak self] in self?.stopAction() },
            history:{ [weak self] in self?.openHistory() },showMenu:{ [weak self] in self?.showPopupMenu() },
            beginDrag:{ [weak self] in self?.dragInitialFrame=self?.panel.frame },
            endDrag:{ [weak self] in self?.endDrag() }))
    }
    func screen(for frame:NSRect)->NSScreen {
        NSScreen.screens.max { a,b in
            let x=a.visibleFrame.intersection(frame), y=b.visibleFrame.intersection(frame)
            return (x.isNull ? 0:x.width*x.height) < (y.isNull ? 0:y.width*y.height)
        } ?? NSScreen.main!
    }
    func clampPosition() { panel.setFrame(PanelLayout.clamped(panel.frame,to:screen(for:panel.frame).visibleFrame),display:true) }
    func endDrag() {
        defer { dragInitialFrame=nil }
        guard let original=dragInitialFrame, original != panel.frame else { return }
        clampPosition()
        if !uiCheck { preferences.set(NSStringFromPoint(panel.frame.origin),forKey:"timerOrigin") }
    }
    func tick() { model.tick(); updateMenu() }
    @objc func primaryAction() {
        let action:StudyController.Action = model.phase == .running ? .pause : model.phase == .paused ? .resume : .start
        if !model.perform(action) { showError() }
        updateMenu()
    }
    @objc func stopAction() { if !model.perform(.stop) { showError() }; updateMenu() }
    @objc func retry() { model.retry(); updateMenu(); if model.errorText != nil { showError() } }
    @objc func showError() {
        let alert=NSAlert(); alert.messageText="学习记录保存或读取失败"
        alert.informativeText=(model.errorText ?? "暂无错误") + "\n数据目录：" + (model.dataDirectory?.path ?? "无法确定")
        alert.addButton(withTitle:"关闭")
        NSApp.activate(ignoringOtherApps:true); alert.runModal()
    }
    @objc func showTimer() { panel.orderFrontRegardless() }
    @objc func hideTimer() { panel.orderOut(nil) }
    @objc func quit() { NSApp.terminate(nil) }
    @objc func openHistory() {
        if historyWindow == nil {
            let window=NSWindow(contentRect:NSRect(x:0,y:0,width:850,height:620),styleMask:[.titled,.closable,.miniaturizable,.resizable],backing:.buffered,defer:false)
            window.title="学习记录"; window.identifier=NSUserInterfaceItemIdentifier("p3-history")
            window.minSize=NSSize(width:760,height:590); window.isReleasedWhenClosed=false
            window.titlebarAppearsTransparent=true
            window.contentView=NSHostingView(rootView:HistoryView(model:model)); window.center(); historyWindow=window
        }
        historyWindow?.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps:true)
    }
    @objc func setAppearance(_ sender:NSMenuItem) {
        let value=sender.representedObject as? String ?? "system"
        NSApp.appearance=value == "dark" ? NSAppearance(named:.darkAqua) : value == "light" ? NSAppearance(named:.aqua) : nil
    }
    func showPopupMenu() { menu.popUp(positioning:nil,at:NSPoint(x:260,y:153),in:panel.contentView) }
    func buildMenus() {
        statusItem=NSStatusBar.system.statusItem(withLength:NSStatusItem.squareLength)
        statusItem.button?.image=NSImage(systemSymbolName:"timer",accessibilityDescription:"学习计时")
        statusItem.button?.image?.isTemplate=true; statusItem.button?.toolTip="学习计时"
        add("学习计时 · P3",nil); menu.addItem(.separator())
        primaryItem=add("开始学习",#selector(primaryAction)); stopItem=add("停止学习",#selector(stopAction))
        menu.addItem(.separator()); add("显示计时窗",#selector(showTimer)); add("隐藏计时窗",#selector(hideTimer)); add("学习记录",#selector(openHistory))
        menu.addItem(.separator()); retryItem=add("重试保存/读取",#selector(retry)); add("查看保存状态",#selector(showSaveStatus))
        menu.addItem(.separator())
        for (title,value) in [("跟随系统外观","system"),("浅色外观","light"),("深色外观","dark")] { add(title,#selector(setAppearance(_:))).representedObject=value }
        menu.addItem(.separator()); add("退出",#selector(quit),key:"q")
        statusItem.menu=menu
        let main=NSMenu(); let appItem=NSMenuItem(); let appMenu=NSMenu()
        let quitItem=NSMenuItem(title:"退出学习计时",action:#selector(quit),keyEquivalent:"q"); quitItem.target=self
        appMenu.addItem(quitItem); appItem.submenu=appMenu; main.addItem(appItem); NSApp.mainMenu=main
    }
    @discardableResult func add(_ title:String,_ action:Selector?,key:String="")->NSMenuItem {
        let item=NSMenuItem(title:title,action:action,keyEquivalent:key); item.target=self; menu.addItem(item); return item
    }
    func updateMenu() {
        primaryItem?.title=model.phase == .running ? "暂停学习" : model.phase == .paused ? "继续学习" : "开始学习"
        primaryItem?.isEnabled=model.ready; stopItem?.isEnabled=model.ready && model.phase != .stopped
        retryItem?.isHidden=model.errorText == nil
        menu.autoenablesItems=false
    }
    @objc func showSaveStatus() {
        if model.errorText != nil { showError(); return }
        let alert=NSAlert(); alert.messageText="学习记录保存在本机"
        alert.informativeText="最近保存：\(model.lastSavedAt.map { StudyDate.clock($0) } ?? "尚未保存")\n运行时每 5 秒保存，操作时立即保存。\n数据目录：\(model.dataDirectory?.path ?? "")"
        alert.addButton(withTitle:"关闭"); NSApp.activate(ignoringOtherApps:true); alert.runModal()
    }
}
