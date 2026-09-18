import AppKit
import SwiftUI
import WindowGeometry

extension AppDelegate {
    /// Isolated P2 smoke test of actual NSPanel instances. This is not a substitute
    /// for user interaction, a real full-screen application, or real IME typing.
    func runSelfCheck() {
        let args = CommandLine.arguments
        guard let position = args.firstIndex(of: "--self-check"), args.count > position + 1 else {
            fputs("Usage: --self-check ABSOLUTE_OUTPUT_DIRECTORY\n", stderr)
            NSApp.terminate(nil)
            return
        }
        let folder = URL(fileURLWithPath: args[position + 1], isDirectory: true)
        var checks: [[String: Any]] = []
        func check(_ name: String, _ passed: Bool) { checks.append(["name": name, "passed": passed]) }
        func settle() { RunLoop.current.run(until: Date().addingTimeInterval(0.12)) }
        func capture(_ window: NSWindow, _ name: String) {
            guard let view = window.contentView else { return }
            view.layoutSubtreeIfNeeded()
            view.displayIfNeeded()
            settle()
            guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
            view.cacheDisplay(in: view.bounds, to: bitmap)
            if let data = bitmap.representation(using: .png, properties: [:]) {
                try? data.write(to: folder.appendingPathComponent(name))
            }
        }
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            check("initial_fixture_idle_00_00", model.phase == .idle && model.displayTime == "00:00")
            check("timer_cannot_become_key", !timerPanel.canBecomeKey)
            check("nonactivating_panel_flags", timerPanel.styleMask.contains(.nonactivatingPanel) && notePanel.styleMask.contains(.nonactivatingPanel))
            check("all_spaces_and_full_screen_flags", timerPanel.collectionBehavior.contains(.canJoinAllSpaces) && timerPanel.collectionBehavior.contains(.fullScreenAuxiliary))
            check("floating_and_no_hide_on_deactivate", timerPanel.level == .floating && !timerPanel.hidesOnDeactivate)
            moveNearTop()
            let original = timerPanel.frame
            let frontBefore = NSWorkspace.shared.frontmostApplication?.processIdentifier
            showHourlyDemo()
            settle()
            check("card_does_not_take_key_on_show", !notePanel.isKeyWindow)
            check("front_application_unchanged_on_card_show", frontBefore == NSWorkspace.shared.frontmostApplication?.processIdentifier)
            check("card_above_timer", notePanel.frame.minY >= timerPanel.frame.maxY)
            check("top_edge_temporarily_shifts_timer", timerPanel.frame.minY < original.minY && restoreFrame != nil)
            check("card_inside_visible_screen", bestScreen(for: timerPanel.frame).visibleFrame.contains(notePanel.frame))
            beginUserDrag()
            endUserDrag()
            check("click_without_drag_preserves_restore", restoreFrame == original)
            closeCard()
            check("close_restores_exact_original_frame", timerPanel.frame == original)
            showHourlyDemo()
            beginUserDrag()
            var moved = timerPanel.frame
            moved.origin.x -= 45
            moved.origin.y -= 45
            setTimerFrame(moved)
            endUserDrag()
            let dragged = timerPanel.frame
            closeCard()
            check("drag_cancels_original_restore", restoreFrame == nil && timerPanel.frame == dragged)
            model.hourlyDraft = "P2输入演示：微积分复习"
            showHourlyDemo()
            closeCard()
            showHourlyDemo()
            check("draft_survives_card_close_in_memory", model.hourlyDraft == "P2输入演示：微积分复习")
            func findInput(_ view: NSView?) -> NSTextView? {
                guard let view = view else { return nil }
                if let input = view as? NSTextView { return input }
                return view.subviews.compactMap { findInput($0) }.first
            }
            settle()
            let input = findInput(notePanel.contentView)
            check("note_input_has_usable_bounds", (input?.bounds.width ?? 0) > 100 && (input?.bounds.height ?? 0) > 10)
            notePanel.makeKey()
            let focused = input.map { notePanel.makeFirstResponder($0) } ?? false
            check("note_accepts_explicit_text_focus", focused && notePanel.firstResponder === input)
            if let input = input {
                input.selectAll(nil)
                input.insertText("高等数学：极限与连续", replacementRange: input.selectedRange())
                settle()
                check("native_chinese_insertion_updates_draft", model.hourlyDraft == "高等数学：极限与连续")
                input.setSelectedRange(NSRange(location: 0, length: 4))
                input.insertText("数学复习", replacementRange: input.selectedRange())
                settle()
                check("native_selection_replacement_updates_draft", model.hourlyDraft == "数学复习：极限与连续")
            } else {
                check("native_chinese_insertion_updates_draft", false)
                check("native_selection_replacement_updates_draft", false)
            }
            closeCard()
            hideTimer()
            check("hide_orders_window_out", !timerPanel.isVisible)
            showTimer()
            check("show_orders_window_in", timerPanel.isVisible)
            model.setFixture(.running)
            primaryAction()
            check("pause_button_changes_fixture", model.phase == .paused && model.displayTime == "02:35")
            primaryAction()
            check("continue_button_changes_fixture", model.phase == .running)
            stopDemo()
            check("stop_opens_tail_fixture", model.phase == .stopped && model.card == .tail)
            closeCard()
            model.hourlyDraft = ""
            for (theme, appearance) in [("light", NSAppearance.Name.aqua), ("dark", NSAppearance.Name.darkAqua)] {
                NSApp.appearance = NSAppearance(named: appearance)
                model.setFixture(.idle); settle()
                capture(timerPanel, "\(theme)-idle.png")
                model.setFixture(.running); settle()
                capture(timerPanel, "\(theme)-running.png")
                model.setFixture(.paused); settle()
                capture(timerPanel, "\(theme)-paused.png")
                showHourlyDemo(); settle()
                capture(notePanel, "\(theme)-hourly-card.png")
                closeCard()
                showTailDemo(); settle()
                capture(notePanel, "\(theme)-tail-card.png")
                closeCard()
                openHistory(); settle()
                capture(historyWindow!, "\(theme)-history.png")
            }
            let report: [String: Any] = [
                "stage": "P2",
                "mode": "AppKit configuration and scripted window smoke checks",
                "system": ProcessInfo.processInfo.operatingSystemVersionString,
                "checks": checks,
                "allPassed": checks.allSatisfy { $0["passed"] as? Bool == true },
                "notCovered": ["Real full-screen browser", "Real desktop switching", "Real pointer dragging", "Chinese IME composition", "Real elapsed-time behavior (outside P2)"]
            ]
            try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]).write(to: folder.appendingPathComponent("appkit-self-check.json"))
            print("P2 AppKit checks: \(checks.filter { $0["passed"] as? Bool == true }.count)/\(checks.count). Report: \(folder.path)")
        } catch {
            fputs("P2 self-check error: \(error)\n", stderr)
        }
        NSApp.terminate(nil)
    }
}
