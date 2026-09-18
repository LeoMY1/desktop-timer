import AppKit
import StudyCore

final class UICheckClock: TimeSource {
    var now=ISO8601DateFormatter().date(from:"2026-09-18T23:40:00+08:00")!
    func add(_ seconds:Double) { now=now.addingTimeInterval(seconds) }
}
extension AppDelegate {
    func runUICheck() {
        guard let index=CommandLine.arguments.firstIndex(of:"--ui-check"), CommandLine.arguments.count>index+1,
              let clock=model.source as? UICheckClock else { exit(2) }
        let output=URL(fileURLWithPath:CommandLine.arguments[index+1],isDirectory:true)
        var checks:[[String:Any]]=[]
        func check(_ name:String,_ result:Bool) { checks.append(["name":name,"passed":result]) }
        func settle() { RunLoop.current.run(until:Date().addingTimeInterval(0.15)) }
        func capture(_ window:NSWindow,_ name:String) {
            settle()
            guard let view=window.contentView,let bitmap=view.bitmapImageRepForCachingDisplay(in:view.bounds) else { return }
            view.cacheDisplay(in:view.bounds,to:bitmap)
            try? bitmap.representation(using:.png,properties:[:])?.write(to:output.appendingPathComponent(name))
        }
        do {
            try FileManager.default.createDirectory(at:output,withIntermediateDirectories:true)
            check("initial_stopped",model.ready && model.phase == .stopped)
            primaryAction(); clock.add(65); tick()
            check("real_model_drives_HH_MM",model.displayTime=="00:01" && model.phase == .running)
            primaryAction(); clock.add(30); tick()
            check("pause_excludes_elapsed",model.displayTime=="00:01" && model.ledger.total(on:model.ledger.day)==65)
            primaryAction(); clock.add(1135); tick()
            check("midnight_current_day_resets",model.ledger.day=="2026-09-19" && model.ledger.total(on:model.ledger.day)==30)
            check("midnight_previous_day_saved",model.ledger.total(on:"2026-09-18")==1170)
            hideTimer(); clock.add(120); tick()
            check("hidden_window_keeps_accruing",!panel.isVisible && model.ledger.total(on:model.ledger.day)==150)
            showTimer(); stopAction()
            check("stop_keeps_total",model.phase == .stopped && model.displayTime=="00:02")
            primaryAction(); clock.add(60); stopAction()
            check("new_session_retains_daily_total",model.ledger.sessions.count==3 && model.ledger.total(on:model.ledger.day)==210)
            check("nonactivating_timer",!panel.canBecomeKey && panel.styleMask.contains(.nonactivatingPanel))
            check("floating_all_spaces",panel.level == .floating && panel.collectionBehavior.contains(.canJoinAllSpaces))
            for (name,theme) in [("light",NSAppearance.Name.aqua),("dark",NSAppearance.Name.darkAqua)] {
                NSApp.appearance=NSAppearance(named:theme)
                capture(panel,"\(name)-timer.png")
                openHistory(); capture(historyWindow!,"\(name)-history.png")
            }
            let report:[String:Any]=["stage":"P3","kind":"AppKit integration using isolated clock and SQLite",
                "checks":checks,"allPassed":checks.allSatisfy { $0["passed"] as? Bool == true }]
            try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]).write(to:output.appendingPathComponent("ui-checks.json"))
            print("P3 UI checks: \(checks.filter { $0["passed"] as? Bool == true }.count)/\(checks.count)")
        } catch { fputs("UI check failed: \(error)\n",stderr) }
        NSApp.terminate(nil)
    }
}
