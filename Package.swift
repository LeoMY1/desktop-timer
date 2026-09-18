// swift-tools-version: 5.8
import PackageDescription

let package = Package(
    name: "StudyTimer",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "StudyTimer", targets: ["StudyTimerApp"])],
    targets: [
        .target(name: "WindowGeometry"),
        .systemLibrary(name: "CSQLite"),
        .target(name: "StudyCore", dependencies: ["CSQLite"]),
        .executableTarget(name: "StudyTimerApp", dependencies: ["StudyCore", "WindowGeometry"]),
        .executableTarget(name: "RecordChecks", dependencies: ["StudyCore", "CSQLite"], path: "Tests/StudyRecordChecks"),
        .executableTarget(name: "CoreChecks", dependencies: ["StudyCore", "CSQLite"], path: "Tests/StudyCoreChecks"),
        .executableTarget(name: "ProcessProbe", dependencies: ["StudyCore"], path: "Tests/StudyProcessProbe"),
        .executableTarget(name: "GeometryChecks", dependencies: ["WindowGeometry"], path: "Tests/WindowGeometryChecks")
    ]
)
