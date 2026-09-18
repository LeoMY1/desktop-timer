import Foundation
import Darwin
import StudyCore
let args=CommandLine.arguments
let mode=args[1], directory=URL(fileURLWithPath:args[2],isDirectory:true), report=URL(fileURLWithPath:args[3])
let clock=ContinuousTimeSource()
let store=try SQLiteLedgerStore(directory:directory,now:clock.now)
let controller=try StudyController(source:clock,store:store)
func write(_ value:[String:Any]) throws {
    try FileManager.default.createDirectory(at:report.deletingLastPathComponent(),withIntermediateDirectories:true)
    try JSONSerialization.data(withJSONObject:value,options:[.prettyPrinted,.sortedKeys]).write(to:report)
}
if mode=="recover" {
    try write(["phase":controller.ledger.phase.rawValue,"seconds":controller.ledger.sessions.reduce(0){$0+$1.seconds},
        "sessions":controller.ledger.sessions.count,"endReason":controller.ledger.sessions.last?.endReason?.rawValue ?? "none"])
} else {
    try controller.perform(.start)
    let start=clock.now
    let duration:Double=mode=="live" ? 65 : 8
    while clock.now.timeIntervalSince(start)<duration { controller.tick(); Thread.sleep(forTimeInterval:0.1) }
    if mode=="crash" {
        let saved=try store.load()
        try write(["savedSeconds":saved.sessions.reduce(0){$0+$1.seconds},"elapsedSeconds":clock.now.timeIntervalSince(start)])
        kill(getpid(),SIGKILL)
    } else {
        try controller.perform(.pause)
        let paused=controller.ledger.sessions.reduce(0){$0+$1.seconds}
        let display=StudyDate.timer(paused)
        Thread.sleep(forTimeInterval:2.2);controller.tick()
        let pausedAfter=controller.ledger.sessions.reduce(0){$0+$1.seconds}
        try controller.perform(.resume);Thread.sleep(forTimeInterval:1.2);try controller.perform(.stop)
        let total=controller.ledger.sessions.reduce(0){$0+$1.seconds}
        try controller.perform(.quit)
        try write(["displayAfter65Seconds":display,"pausedSeconds":paused,"afterPauseWait":pausedAfter,
            "totalSeconds":total,"phase":controller.ledger.phase.rawValue,
            "allPassed":display=="00:01" && paused==pausedAfter && total>paused+1 && total<paused+2])
    }
}
