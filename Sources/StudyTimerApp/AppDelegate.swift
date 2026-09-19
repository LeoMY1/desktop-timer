import AppKit
import SwiftUI
import StudyCore
import WindowGeometry

final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = StudyModel()
    var panel: PrototypePanel!
    var notePanel: PrototypePanel!
    var restoreFrame: NSRect?
    var dragging = false
    var programmaticMove = false
    var tailQueue: [UUID] = []
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
    #if INTERNAL_TESTING
    let acceptanceMode = CommandLine.arguments.contains("--acceptance-mode")
    let uiCheck = CommandLine.arguments.contains("--ui-check")
    #else
    let uiCheck = false
    #endif
    var preferences: UserDefaults { .standard }
    func applicationDidFinishLaunching(_ notification: Notification) {
        #if INTERNAL_TESTING
        if uiCheck || acceptanceMode {
            guard ProcessInfo.processInfo.environment["STUDY_TIMER_DATA_DIR"] != nil else {
                fputs("--ui-check requires an isolated STUDY_TIMER_DATA_DIR\n", stderr)
                exit(2)
            }
            model.source = uiCheck ? UICheckClock() : PreviewTimeSource()
            model.acceptanceMode=acceptanceMode
        }
        #endif
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
                    self?.model.refresh(); self?.updateMenu(); self?.offerReminders()
                }
            })
        }
        updateMenu()
        #if INTERNAL_TESTING
        if uiCheck { DispatchQueue.main.asyncAfter(deadline: .now()+0.3) { self.runUICheck() } }
        #endif
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
        if !uiCheck { preferences.set(NSStringFromPoint((restoreFrame ?? panel.frame).origin),forKey:"timerOrigin") }
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
        panel.title="学习计时"; panel.identifier=NSUserInterfaceItemIdentifier("study-timer")
        panel.contentView=PassiveHostingView(rootView:TimerView(model:model,
            primary:{ [weak self] in self?.primaryAction() },stop:{ [weak self] in self?.stopAction() },
            history:{ [weak self] in self?.openHistory() },showMenu:{ [weak self] in self?.showPopupMenu() },
            beginDrag:{ [weak self] in self?.dragInitialFrame=self?.panel.frame; self?.dragging=true },
            endDrag:{ [weak self] in self?.endDrag() }))
        notePanel=PrototypePanel(frame:NSRect(x:0,y:0,width:288,height:300),permitsTextInput:true)
        notePanel.title="学习内容记录"
        notePanel.contentView=PassiveHostingView(rootView:NoteCard(model:model,
            close:{[weak self] in self?.closeNote()},save:{[weak self] in self?.saveNote(merge:false)},
            merge:{[weak self] in self?.saveNote(merge:true)},next:{[weak self] in self?.nextNote($0)}))
        observers.append(NotificationCenter.default.addObserver(forName:NSWindow.didMoveNotification,object:panel,queue:.main){ [weak self] _ in
            guard let self=self,!self.programmaticMove else {return}
            if self.notePanel.isVisible { self.alignNote(adjust:!self.dragging) }
        })
    }
    func screen(for frame:NSRect)->NSScreen {
        NSScreen.screens.max { a,b in
            let x=a.visibleFrame.intersection(frame), y=b.visibleFrame.intersection(frame)
            return (x.isNull ? 0:x.width*x.height) < (y.isNull ? 0:y.width*y.height)
        } ?? NSScreen.main!
    }
    func setFrame(_ frame:NSRect) { programmaticMove=true;panel.setFrame(frame,display:true);programmaticMove=false }
    func clampPosition() {
        setFrame(PanelLayout.clamped(panel.frame,to:screen(for:panel.frame).visibleFrame))
        if let frame=restoreFrame { restoreFrame=PanelLayout.clamped(frame,to:screen(for:frame).visibleFrame) }
        if notePanel.isVisible { alignNote() }
    }
    func endDrag() {
        dragging=false
        defer { dragInitialFrame=nil }
        guard let original=dragInitialFrame, original != panel.frame else { return }
        restoreFrame=nil
        setFrame(PanelLayout.clamped(panel.frame,to:screen(for:panel.frame).visibleFrame))
        if notePanel.isVisible { alignNote(remember:false) }
        if !uiCheck { preferences.set(NSStringFromPoint(panel.frame.origin),forKey:"timerOrigin") }
    }
    func tick() { model.tick();updateMenu();offerReminders() }
    func alignNote(adjust:Bool=true,remember:Bool=true) {
        if !adjust { notePanel.setFrameOrigin(NSPoint(x:panel.frame.minX,y:panel.frame.maxY+3));return }
        let placement=PanelLayout.above(timer:panel.frame,popupSize:NSSize(width:288,height:300),visible:screen(for:panel.frame).visibleFrame)
        if placement.shifted && remember && restoreFrame==nil {restoreFrame=panel.frame}
        setFrame(placement.timer);notePanel.setFrame(placement.popup,display:true)
    }
    func offerReminders() {
        guard panel.isVisible,!notePanel.isVisible,!model.isEditingHistory,model.ready,model.errorText==nil else {return}
        let pending=ReminderCoordinator.pending(in:model.ledger)
        if !pending.isEmpty,model.beginReminder(pending) { alignNote();notePanel.orderFrontRegardless();return }
        while !tailQueue.isEmpty {
            let id=tailQueue.removeFirst()
            if model.ledger.entries.contains(where:{$0.id==id && $0.pendingTail}) { showTail(id);return }
        }
    }
    func showTail(_ id:UUID) {
        if notePanel.isVisible && !model.flushDrafts() {showError();return}
        model.beginTail(id);panel.orderFrontRegardless();alignNote();notePanel.orderFrontRegardless()
    }
    @objc func closeNote() {
        guard model.flushDrafts() else {showError();return}
        notePanel.orderOut(nil);model.cardEntryIDs=[]
        if let frame=restoreFrame { setFrame(PanelLayout.clamped(frame,to:screen(for:frame).visibleFrame));restoreFrame=nil }
    }
    func nextNote(_ offset:Int) {
        guard model.flushDrafts() else {showError();return}
        let next=model.cardIndex+offset
        if model.cardEntryIDs.indices.contains(next) {model.cardIndex=next}
    }
    func saveNote(merge:Bool) {
        if model.currentEntry?.pendingTail == true {
            guard model.resolveCurrentTail(merge:merge) else {showError();return}
        } else if !model.flushDrafts() {showError();return}
        if model.cardIndex+1<model.cardEntryIDs.count {nextNote(1)} else {closeNote()}
    }
    @objc func primaryAction() {
        let action:StudyController.Action = model.phase == .running ? .pause : model.phase == .paused ? .resume : .start
        if !model.perform(action) { showError() }
        updateMenu()
    }
    @objc func stopAction() {
        let previous=Set(model.ledger.entries.map(\.id))
        if !model.perform(.stop) {showError()}
        else {tailQueue += model.ledger.entries.filter{$0.pendingTail && !previous.contains($0.id)}.map(\.id)}
        updateMenu();offerReminders()
    }
    @objc func retry() { model.retry(); updateMenu(); if model.errorText != nil { showError() } }
    @objc func showError() {
        let alert=NSAlert(); alert.messageText="学习记录保存或读取失败"
        alert.informativeText=(model.errorText ?? "暂无错误") + "\n数据目录：" + (model.dataDirectory?.path ?? "无法确定")
        alert.addButton(withTitle:"关闭")
        NSApp.activate(ignoringOtherApps:true); alert.runModal()
    }
    @objc func showTimer() { panel.orderFrontRegardless();offerReminders() }
    @objc func hideTimer() { guard model.flushDrafts() else {showError();return};closeNote();panel.orderOut(nil) }
    @objc func quit() { NSApp.terminate(nil) }
    @objc func openHistory() {
        if historyWindow == nil {
            let window=NSWindow(contentRect:NSRect(x:0,y:0,width:850,height:620),styleMask:[.titled,.closable,.miniaturizable,.resizable],backing:.buffered,defer:false)
            window.title="学习记录"; window.identifier=NSUserInterfaceItemIdentifier("study-history")
            window.minSize=NSSize(width:760,height:590); window.isReleasedWhenClosed=false
            window.titlebarAppearsTransparent=true
            window.contentView=NSHostingView(rootView:HistoryView(model:model,showTail:{[weak self] id in self?.showTail(id)},deleteRecord:{[weak self] target in self?.requestDeletion(target)})); window.center(); historyWindow=window
        }
        historyWindow?.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps:true)
    }
    func requestDeletion(_ target: RecordDeletion) {
        guard let window = historyWindow, !model.isEditingHistory else { return }
        model.tick()
        guard let session = model.ledger.session(for: target) else { return }
        let title: String
        let seconds: Double
        switch target {
        case .session:
            title = "删除这个学习段？"; seconds = session.seconds
        case .entry(let id):
            guard let entry = model.ledger.entries.first(where: { $0.id == id }) else { return }
            title = "删除这条内容记录？"; seconds = entry.seconds
        }
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = "日期：\(session.day)\n当前有效时长：\(StudyDate.duration(seconds))\n将删除所选记录及其备注，并扣除对应时长。删除后无法撤销。\n" +
            "若确认时该记录属于今天，正在进行的计时会暂停，可手动继续；删除其他日期不影响当前计时。" +
            (session.endedAt == nil ? "\n该段尚未结束，确认时按最新记录结算并删除。" : "")
        alert.alertStyle = .warning
        alert.addButton(withTitle: "取消")
        alert.addButton(withTitle: "删除")
        alert.buttons[1].hasDestructiveAction = true
        model.isEditingHistory = true
        alert.beginSheetModal(for: window) { [weak self] response in
            guard let self = self else { return }
            if response == .alertSecondButtonReturn { self.deleteRecord(target) }
            self.model.isEditingHistory = false
        }
    }
    @discardableResult func deleteRecord(_ target: RecordDeletion) -> Bool {
        guard model.deleteRecord(target) else { updateMenu(); return false }
        let liveIDs = Set(model.ledger.entries.filter { $0.pendingTail }.map(\.id))
        tailQueue.removeAll { !liveIDs.contains($0) }
        if notePanel.isVisible && model.cardEntryIDs.isEmpty { closeNote() }
        updateMenu()
        return true
    }
    #if INTERNAL_TESTING
    @objc func setAppearance(_ sender:NSMenuItem) {
        let value=sender.representedObject as? String ?? "system"
        NSApp.appearance=value == "dark" ? NSAppearance(named:.darkAqua) : value == "light" ? NSAppearance(named:.aqua) : nil
    }
    #endif
    func showPopupMenu() { menu.popUp(positioning:nil,at:NSPoint(x:260,y:153),in:panel.contentView) }
    func buildMenus() {
        statusItem=NSStatusBar.system.statusItem(withLength:NSStatusItem.squareLength)
        statusItem.button?.image=NSImage(systemSymbolName:"timer",accessibilityDescription:"学习计时")
        statusItem.button?.image?.isTemplate=true; statusItem.button?.toolTip="学习计时"
        add("学习计时",nil); menu.addItem(.separator())
        primaryItem=add("开始学习",#selector(primaryAction)); stopItem=add("停止学习",#selector(stopAction))
        menu.addItem(.separator()); add("显示计时窗",#selector(showTimer)); add("隐藏计时窗",#selector(hideTimer)); add("学习记录",#selector(openHistory))
        menu.addItem(.separator()); retryItem=add("重试保存/读取",#selector(retry)); add("查看保存状态",#selector(showSaveStatus))
        #if INTERNAL_TESTING
        menu.addItem(.separator())
        for (title,value) in [("跟随系统外观","system"),("浅色外观","light"),("深色外观","dark")] { add(title,#selector(setAppearance(_:))).representedObject=value }
        if acceptanceMode {
            menu.addItem(.separator())
            add("模拟验收 · 快进会增加测试时长",nil)
            for minutes in [1,30,60,180] {add("推进 \(minutes) 分钟",#selector(advanceAcceptance(_:))).representedObject=minutes}
            add("模拟持续学习至次日 00:20…",#selector(advanceAcceptanceMidnight))
        }
        #endif
        menu.addItem(.separator()); add("退出",#selector(quit))
        statusItem.menu=menu
        let main=NSMenu(); let appItem=NSMenuItem(); let appMenu=NSMenu()
        let quitItem=NSMenuItem(title:"退出学习计时",action:#selector(quit),keyEquivalent:""); quitItem.target=self
        appMenu.addItem(quitItem); appItem.submenu=appMenu; main.addItem(appItem)
        let editItem=NSMenuItem(title:"编辑",action:nil,keyEquivalent:"")
        let edit=NSMenu(title:"编辑")
        for (title,selector,key) in [("撤销","undo:","z"),("剪切","cut:","x"),("复制","copy:","c"),("粘贴","paste:","v"),("全选","selectAll:","a")] {
            edit.addItem(withTitle:title,action:Selector(selector),keyEquivalent:key)
        }
        editItem.submenu=edit;main.addItem(editItem);NSApp.mainMenu=main
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
    #if INTERNAL_TESTING
    @objc func advanceAcceptance(_ item:NSMenuItem) {
        guard acceptanceMode,let clock=model.source as? PreviewTimeSource,let minutes=item.representedObject as? Int else{return}
        clock.add(Double(minutes)*60);tick()
    }
    @objc func advanceAcceptanceMidnight() {
        guard acceptanceMode,let clock=model.source as? PreviewTimeSource else{return}
        let target = StudyDate.nextMidnight(clock.now).addingTimeInterval(1200)
        let alert = NSAlert()
        alert.messageText = "模拟跨日：快进时间将计入测试记录"
        let elapsed = StudyDate.duration(target.timeIntervalSince(clock.now))
        alert.informativeText = "当前模拟时间：\(StudyDate.day(clock.now)) \(StudyDate.clock(clock.now))\n目标：\(StudyDate.day(target)) 00:20\n" + (model.phase == .running ? "正在计时，将新增约 \(elapsed) 的模拟学习时长，并按午夜拆分。" : "当前未运行，不增加学习时长。") + "\n仅影响独立验收数据，已有学习段保留。"
        alert.addButton(withTitle: "取消")
        alert.addButton(withTitle: "确认模拟快进")
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertSecondButtonReturn else { return }
        clock.add(max(0, target.timeIntervalSince(clock.now))); tick()
    }
    #endif
    @objc func showSaveStatus() {
        if model.errorText != nil { showError(); return }
        let alert=NSAlert(); alert.messageText="学习记录保存在本机"
        alert.informativeText="最近保存：\(model.lastSavedAt.map { StudyDate.clock($0) } ?? "尚未保存")\n运行时每 5 秒保存，操作时立即保存。\n数据目录：\(model.dataDirectory?.path ?? "")"
        alert.addButton(withTitle:"关闭"); NSApp.activate(ignoringOtherApps:true); alert.runModal()
    }
}
