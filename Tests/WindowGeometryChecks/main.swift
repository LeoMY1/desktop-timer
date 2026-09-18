import Foundation
import CoreGraphics
import WindowGeometry

struct CheckFailure: Error, CustomStringConvertible {
    let description: String
}
func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() { throw CheckFailure(description: message) }
}
let screen = CGRect(x: 0, y: 40, width: 1440, height: 840)
let popup = CGSize(width: 288, height: 244)
let cases: [(String, () throws -> Void)] = [
    ("room_above_does_not_move_timer", {
        let timer = CGRect(x: 100, y: 100, width: 288, height: 176)
        let p = PanelLayout.above(timer: timer, popupSize: popup, visible: screen)
        try expect(p.timer == timer && !p.shifted, "Unnecessary movement")
        try expect(p.popup.minY > timer.maxY, "Popup is not above")
    }),
    ("top_edge_shifts_only_enough", {
        let timer = CGRect(x: 100, y: 690, width: 288, height: 176)
        let p = PanelLayout.above(timer: timer, popupSize: popup, visible: screen)
        try expect(p.shifted && p.popup.maxY == screen.maxY - 8, "Incorrect top-edge shift")
        try expect(p.timer.minX == timer.minX, "Unnecessary horizontal movement")
        try expect(screen.contains(p.timer) && screen.contains(p.popup), "Panel escaped visible frame")
    }),
    ("negative_coordinate_left_monitor", {
        let monitor = CGRect(x: -1920, y: 60, width: 1920, height: 1020)
        let p = PanelLayout.above(timer: CGRect(x: -1700, y: 850, width: 288, height: 176), popupSize: popup, visible: monitor)
        try expect(monitor.contains(p.timer) && monitor.contains(p.popup), "Off monitor")
        try expect(p.popup.minX < 0, "Wrong coordinate system")
    }),
    ("offscreen_position_recovery", {
        let adjusted = PanelLayout.clamped(CGRect(x: 8000, y: -600, width: 288, height: 176), to: screen)
        try expect(screen.contains(adjusted), "Offscreen position not recovered")
        try expect(adjusted.minY == screen.minY + 8 && adjusted.maxX == screen.maxX - 8, "Incorrect clamping")
    }),
    ("horizontal_edges", {
        for x: CGFloat in [-100, 1400] {
            let p = PanelLayout.above(timer: CGRect(x: x, y: 500, width: 288, height: 176), popupSize: popup, visible: screen)
            try expect(screen.contains(p.popup) && screen.contains(p.timer), "Horizontal clipping")
        }
    }),
    ("compact_screen_keeps_card_above", {
        let compact = CGRect(x: 0, y: 24, width: 800, height: 540)
        let p = PanelLayout.above(timer: CGRect(x: 400, y: 350, width: 288, height: 176), popupSize: popup, visible: compact)
        try expect(compact.contains(p.popup) && p.popup.minY > p.timer.maxY, "Wrong compact-screen layout")
        try expect(p.popup.height == 244, "Unnecessarily shrunk card")
    }),
    ("placement_is_idempotent", {
        let first = PanelLayout.above(timer: CGRect(x: 400, y: 700, width: 288, height: 176), popupSize: popup, visible: screen)
        let second = PanelLayout.above(timer: first.timer, popupSize: popup, visible: screen)
        try expect(first.timer == second.timer && first.popup == second.popup && !second.shifted, "Repeated placement drifts")
    })
]
var results: [[String: Any]] = []
for (name, test) in cases {
    do { try test(); results.append(["name": name, "passed": true]) }
    catch { results.append(["name": name, "passed": false, "error": String(describing: error)]) }
}
let allPassed = results.allSatisfy { $0["passed"] as? Bool == true }
let report: [String: Any] = ["stage": "P2", "kind": "pure geometry checks", "allPassed": allPassed, "checks": results]
let json = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
if CommandLine.arguments.count > 1 {
    let output = URL(fileURLWithPath: CommandLine.arguments[1])
    try FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
    try json.write(to: output)
}
print(String(data: json, encoding: .utf8)!)
if !allPassed { exit(1) }
