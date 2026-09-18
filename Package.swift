// swift-tools-version: 5.8
import PackageDescription

let package = Package(
    name: "StudyTimerPrototype",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "StudyTimerPrototype", targets: ["StudyTimerPrototype"])],
    targets: [
        .target(name: "WindowGeometry"),
        .executableTarget(name: "StudyTimerPrototype", dependencies: ["WindowGeometry"]),
        .executableTarget(name: "GeometryChecks", dependencies: ["WindowGeometry"], path: "Tests/WindowGeometryChecks")
    ]
)
