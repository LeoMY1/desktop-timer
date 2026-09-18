import SwiftUI
import StudyCore

final class StudyModel: ObservableObject {
    @Published var ledger = Ledger(now: Date())
    @Published var errorText: String?
    @Published var ready = false
    @Published var lastSavedAt: Date?
    var controller: StudyController?
    var source: TimeSource = ContinuousTimeSource()
    var dataDirectory: URL?
    var phase: StudyPhase { ledger.phase }
    var phaseTitle: String {
        if !ready { return "无法加载" }
        switch phase { case .running: return "学习中"; case .paused: return "已暂停"; case .stopped: return "未计时" }
    }
    var displayTime: String { StudyDate.timer(ledger.total(on: ledger.day)) }
    var footer: String {
        if errorText != nil { return "保存/读取失败 · 点右上角菜单查看" }
        return phase == .running ? "本地保存 · 学习时间持续累计" : "本地保存 · " + (phase == .paused ? "暂停期间不计时" : "点击开始学习")
    }
    func load() {
        guard controller == nil else { return }
        do {
            let directory = try SQLiteLedgerStore.defaultDirectory()
            dataDirectory = directory
            let store = try SQLiteLedgerStore(directory: directory, now: source.now)
            controller = try StudyController(source: source, store: store)
            ready = true; errorText = nil; refresh()
        } catch { ready = false; errorText = error.localizedDescription }
    }
    func refresh() {
        guard let controller = controller else { return }
        ledger = controller.ledger; lastSavedAt = controller.lastSavedAt
        errorText = controller.lastSaveError
    }
    func tick() { controller?.tick(); refresh() }
    @discardableResult func perform(_ action: StudyController.Action) -> Bool {
        guard let controller = controller else { return false }
        do { try controller.perform(action); refresh(); return true }
        catch { refresh(); errorText = error.localizedDescription; return false }
    }
    func retry() {
        if let controller = controller {
            do { try controller.checkpoint(); refresh() }
            catch { errorText = error.localizedDescription }
        } else { load() }
    }
}
