import SwiftUI
import StudyCore

final class StudyModel: ObservableObject {
    @Published var ledger = Ledger(now: Date())
    @Published var errorText: String?
    @Published var ready = false
    @Published var lastSavedAt: Date?
    @Published var drafts: [UUID:String] = [:]
    @Published var cardEntryIDs: [UUID] = []
    @Published var cardIndex = 0
    @Published var cardTitle = ""
    @Published var celebration = false
    @Published var isEditingHistory = false
    private var dirty: Set<UUID> = []
    private var draftWork: DispatchWorkItem?
    private var draftError: String?
    var controller: StudyController?
    var source: TimeSource = ContinuousTimeSource()
    var dataDirectory: URL?
    var acceptanceMode = false
    var phase: StudyPhase { ledger.phase }
    var phaseTitle: String {
        if !ready { return "无法加载" }
        switch phase { case .running: return "学习中"; case .paused: return "已暂停"; case .stopped: return "未计时" }
    }
    var displayTime: String { StudyDate.timer(ledger.total(on: ledger.day)) }
    var footer: String {
        if acceptanceMode && errorText == nil { return "验收模式 · 独立数据，可快进时间" }
        if errorText != nil { return "保存/读取失败 · 点右上角菜单查看" }
        return phase == .running ? "本地保存 · 学习时间持续累计" : "本地保存 · " + (phase == .paused ? "暂停期间不计时" : "点击开始学习")
    }
    func load() {
        guard controller == nil else { return }
        do {
            let directory = try SQLiteLedgerStore.defaultDirectory()
            dataDirectory = directory
            let store = try SQLiteLedgerStore(directory: directory, now: source.now)
            if acceptanceMode,let clock=source as? UICheckClock {clock.now=max(clock.now,try store.load().checkpointAt)}
            controller = try StudyController(source: source, store: store)
            ready = true; errorText = nil; refresh()
        } catch { ready = false; errorText = error.localizedDescription }
    }
    func refresh() {
        guard let controller = controller else { return }
        ledger = controller.ledger; lastSavedAt = controller.lastSavedAt
        errorText = draftError ?? controller.lastSaveError
    }
    func tick() { controller?.tick(); refresh() }
    @discardableResult func perform(_ action: StudyController.Action) -> Bool {
        guard let controller = controller else { return false }
        guard flushDrafts() else { return false }
        do { try controller.perform(action); refresh(); return true }
        catch { refresh(); errorText = error.localizedDescription; return false }
    }
    func retry() {
        if let controller = controller {
            guard flushDrafts() else { return }
            do { try controller.checkpoint(); refresh() }
            catch { errorText = error.localizedDescription }
        } else { load() }
    }
    var currentEntry: LearningEntry? {
        guard cardEntryIDs.indices.contains(cardIndex) else { return nil }
        return ledger.entries.first { $0.id==cardEntryIDs[cardIndex] }
    }
    func note(_ id:UUID)->String { drafts[id] ?? ledger.entries.first{$0.id==id}?.note ?? "" }
    func setNote(_ id:UUID,_ text:String) {
        drafts[id]=text; dirty.insert(id); draftWork?.cancel()
        let work=DispatchWorkItem { [weak self] in _=self?.flushDrafts() }
        draftWork=work; DispatchQueue.main.asyncAfter(deadline:.now()+0.4,execute:work)
    }
    @discardableResult func flushDrafts()->Bool {
        draftWork?.cancel()
        guard !dirty.isEmpty else { return true }
        guard let controller=controller else { return false }
        let values=Dictionary(uniqueKeysWithValues:dirty.compactMap { id in drafts[id].map{(id,$0)} })
        do {
            try controller.editNotes(values); dirty.removeAll(); draftError=nil; refresh()
            for id in values.keys {drafts[id]=nil}
            return true
        } catch { draftError=error.localizedDescription;errorText=draftError;return false }
    }
    func beginReminder(_ pending:[HourlyMilestone])->Bool {
        guard !pending.isEmpty,let controller=controller else { return false }
        do {
            try controller.markPresented(Set(pending.map(\.id)));refresh()
            cardEntryIDs=Array(pending.compactMap(\.entryID).reduce(into:[UUID]()) { result,id in if !result.contains(id){result.append(id)} })
            cardIndex=0;cardTitle=pending.count==1 ? "又完成一小时" : "已完成 \(pending.count) 个整小时"
            withAnimation(.easeInOut(duration:0.35)){celebration=true}
            DispatchQueue.main.asyncAfter(deadline:.now()+2) { [weak self] in withAnimation(.easeOut(duration:0.4)){self?.celebration=false} }
            return currentEntry != nil
        } catch { errorText=error.localizedDescription;return false }
    }
    func beginTail(_ id:UUID) { cardEntryIDs=[id];cardIndex=0;cardTitle="记录最后一段学习" }
    func resolveCurrentTail(merge:Bool)->Bool {
        guard flushDrafts(),let entry=currentEntry,let controller=controller else { return false }
        do { try controller.resolveTail(entry.id,merge:merge);drafts[entry.id]=nil;refresh();return true }
        catch { errorText=error.localizedDescription;return false }
    }
    var hasUnsavedNotes: Bool { !dirty.isEmpty }

}
