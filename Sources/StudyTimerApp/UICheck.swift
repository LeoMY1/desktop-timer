#if INTERNAL_TESTING
import AppKit
import StudyCore

final class UICheckClock: TimeSource {
    var now=ISO8601DateFormatter().date(from:"2026-09-18T09:00:00+08:00")!
    func add(_ seconds:Double) {now=now.addingTimeInterval(seconds)}
}
extension AppDelegate {
    func runUICheck() {
        guard let index=CommandLine.arguments.firstIndex(of:"--ui-check"),CommandLine.arguments.count>index+1,
              let clock=model.source as? UICheckClock else {exit(2)}
        let output=URL(fileURLWithPath:CommandLine.arguments[index+1],isDirectory:true)
        var checks:[[String:Any]]=[]
        func check(_ name:String,_ result:Bool) {checks.append(["name":name,"passed":result])}
        func settle(){RunLoop.current.run(until:Date().addingTimeInterval(0.12))}
        func capture(_ window:NSWindow,_ name:String){
            settle();guard let view=window.contentView,let bitmap=view.bitmapImageRepForCachingDisplay(in:view.bounds) else{return}
            view.cacheDisplay(in:view.bounds,to:bitmap)
            try? bitmap.representation(using:.png,properties:[:])?.write(to:output.appendingPathComponent(name))
        }
        do {
            try FileManager.default.createDirectory(at:output,withIntermediateDirectories:true)
            check("initial_stopped",model.ready && model.phase == .stopped)
            var exits = menu.items.filter { $0.action == #selector(quit) }
            for rootItem in NSApp.mainMenu?.items ?? [] {
                for item in rootItem.submenu?.items ?? [] {
                    if item.action == #selector(quit) { exits.append(item) }
                }
            }
            check("all_exit_menus_have_no_shortcut",exits.count == 2 && exits.allSatisfy { $0.keyEquivalent.isEmpty })
            check("timer_cannot_become_key", !panel.canBecomeKey)
            check("nonactivating_panels", panel.styleMask.contains(.nonactivatingPanel) && notePanel.styleMask.contains(.nonactivatingPanel))
            check("all_spaces_fullscreen_flags", panel.collectionBehavior.contains(.canJoinAllSpaces) && panel.collectionBehavior.contains(.fullScreenAuxiliary))
            check("floating_no_hide_on_deactivate", panel.level == .floating && !panel.hidesOnDeactivate)
            func findDrag(_ view: NSView) -> DragView? {
                if let drag = view as? DragView { return drag }
                return view.subviews.compactMap { findDrag($0) }.first
            }
            func checkHitAreas(_ phase: String) {
                settle()
                let root = panel.contentView!
                let drag = findDrag(root)
                func hit(_ point: NSPoint) -> NSView? {
                    guard let drag = drag else { return nil }
                    return root.hitTest(drag.convert(point, to: root.superview))
                }
                let edges = [NSPoint(x:2,y:88),NSPoint(x:286,y:88),NSPoint(x:144,y:2),NSPoint(x:144,y:174)]
                check("\(phase)_four_edges_drag", drag != nil && edges.allSatisfy { hit($0) === drag })
                let blanks = [NSPoint(x:144,y:76),NSPoint(x:144,y:156),NSPoint(x:7,y:130)]
                check("\(phase)_digits_blank_drag", drag != nil && blanks.allSatisfy { hit($0) === drag })
                let controls = drag?.excludedRects ?? []
                let expected = model.phase == .stopped ? 3 : 4
                check("\(phase)_buttons_not_drag", controls.count == expected && controls.allSatisfy { let view = hit(NSPoint(x:$0.midX,y:$0.midY)); return view != nil && view !== drag })
                check("\(phase)_two_full_icon_targets", controls.filter { abs($0.width-20)<0.1 && abs($0.height-20)<0.1 }.count == 2)
            }
            checkHitAreas("stopped")
            let visible=screen(for:panel.frame).visibleFrame
            setFrame(NSRect(x:panel.frame.minX,y:visible.maxY-panel.frame.height-8,width:288,height:176))
            let original=panel.frame
            let front=NSWorkspace.shared.frontmostApplication?.processIdentifier
            primaryAction();clock.add(3600);tick();settle()
            check("hourly_card_visible_above",notePanel.isVisible && notePanel.frame.minY>panel.frame.maxY)
            check("hourly_panel_not_key",!notePanel.isKeyWindow)
            check("front_app_unchanged",NSWorkspace.shared.frontmostApplication?.processIdentifier==front)
            check("top_edge_shift",panel.frame.minY<original.minY && restoreFrame==original)
            check("running_during_card",model.phase == .running && model.displayTime=="01:00")
            checkHitAreas("running")
            primaryAction();checkHitAreas("paused");primaryAction()
            let first=model.currentEntry!.id
            model.setNote(first,"高等数学 · 极限与连续");check("draft_flush",model.flushDrafts())
            clock.add(3600);tick()
            check("new_hour_keeps_active_card",model.currentEntry?.id==first && model.note(first)=="高等数学 · 极限与连续")
            check("new_hour_queued",ReminderCoordinator.pending(in:model.ledger).count==1)
            closeNote();check("close_restores_top_position",panel.frame==original)
            tick();check("next_reminder_after_close",model.currentEntry?.id != first && notePanel.isVisible)
            let second=model.currentEntry!.id
            model.setNote(second,"英语阅读 · 精读两篇");_ = model.flushDrafts();closeNote()
            clock.add(1800);stopAction()
            check("stop_tail_visible",notePanel.isVisible && model.currentEntry?.pendingTail==true)
            check("tail_can_merge",model.ledger.canMerge(model.currentEntry!.id))
            model.setNote(model.currentEntry!.id,"复习错题")
            saveNote(merge:true)
            check("merge_preserves_total",model.ledger.total(on:model.ledger.day)==9000 && model.ledger.entries.count==2)
            check("merge_preserves_both_texts",model.ledger.entries.last!.note=="英语阅读 · 精读两篇\n复习错题")
            check("merged_note_display_matches_saved",model.note(second)==model.ledger.entries.last!.note)
            primaryAction();clock.add(300);stopAction()
            check("short_session_no_previous_merge",!model.ledger.canMerge(model.currentEntry!.id))
            saveNote(merge:false);check("separate_resolves_tail",!model.ledger.entries.last!.pendingTail)
            primaryAction();hideTimer();clock.add(7200);tick()
            check("hidden_reminders_retained",!notePanel.isVisible && ReminderCoordinator.pending(in:model.ledger).count==2)
            showTimer();check("missed_hours_one_batch",notePanel.isVisible && model.cardEntryIDs.count==2)
            let batch=model.cardEntryIDs;nextNote(1)
            check("batch_navigation",model.currentEntry?.id==batch[1])
            for (name,theme) in [("light",NSAppearance.Name.aqua),("dark",NSAppearance.Name.darkAqua)] {
                NSApp.appearance=NSAppearance(named:theme)
                capture(panel,"\(name)-timer.png");capture(notePanel,"\(name)-hourly.png")
                openHistory();capture(historyWindow!,"\(name)-history.png")
            }
            closeNote();stopAction()
            if notePanel.isVisible {capture(notePanel,"tail-card.png");closeNote()}
            let remaining=ReminderCoordinator.pending(in:model.ledger).count
            tick();check("already_presented_not_repeated",remaining==0 && ReminderCoordinator.pending(in:model.ledger).isEmpty)
            check("quit_flush_and_settle",model.perform(.quit) && !model.ledger.entries.contains{$0.pendingTail})
            let snapshot=model.ledger
            let store=try SQLiteLedgerStore(directory:output.appendingPathComponent("snapshot-check"),now:clock.now)
            try store.save(snapshot);let loaded=try store.load()
            check("SQLite_full_record_roundtrip",loaded==snapshot)
            // Return to the main run loop so scheduled animation callbacks can execute.
            // A nested run loop inside this main-queue callback cannot service main-queue blocks.
            let effect = StudyModel()
            effect.startCelebration()
            var levels: [Double] = []
            for point in [0.65,1.05,1.45,1.85,2.25,2.65] {
                DispatchQueue.main.asyncAfter(deadline: .now() + point) { levels.append(effect.celebrationOpacity) }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                check("celebration_three_dim_bright_cycles", levels == [0.15,1,0.15,1,0.15,1])
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 29) {
                check("celebration_held_before_30_seconds", effect.celebration && effect.celebrationOpacity == 1)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 30.4) {
                check("celebration_ends_at_30_seconds", !effect.celebration)
                let report:[String:Any]=["stage":"P5","kind":"AppKit integration with isolated clock and SQLite; effect observed over 30 real seconds","checks":checks,
                    "allPassed":checks.allSatisfy{$0["passed"] as? Bool==true}]
                do {
                    try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]).write(to:output.appendingPathComponent("ui-checks.json"))
                    print("P4 UI checks: \(checks.filter{$0["passed"] as? Bool==true}.count)/\(checks.count)")
                } catch { fputs("P4 UI report failed: \(error)\n", stderr) }
                NSApp.terminate(nil)
            }
            return
        } catch {fputs("P4 UI check failed: \(error)\n",stderr)}
        NSApp.terminate(nil)
    }
}

#endif
