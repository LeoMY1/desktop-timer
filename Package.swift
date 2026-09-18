// swift-tools-version: 5.8
import PackageDescription

let package = Package(
    name: "StudyTimerPrototype",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "StudyTimerPrototype", targets: ["StudyTimerPrototype"]), .executable(name: "StudyTimer", targets: ["StudyTimerApp"])],
    targets: [
        .target(name: "WindowGeometry"),
        .systemLibrary(name: "CSQLite"),
        .target(name: "StudyCore", dependencies: ["CSQLite"]),
        .executableTarget(name: "StudyTimerApp", dependencies: ["StudyCore", "WindowGeometry"]),
        .executableTarget(name: "CoreChecks", dependencies: ["StudyCore", "CSQLite"], path: "Tests/StudyCoreChecks"),
        .executableTarget(name: "ProcessProbe", dependencies: ["StudyCore"], path: "Tests/StudyProcessProbe"),
        .executableTarget(name: "StudyTimerPrototype", dependencies: ["WindowGeometry"]),
        .executableTarget(name: "GeometryChecks", dependencies: ["WindowGeometry"], path: "Tests/WindowGeometryChecks")
    ]
)
