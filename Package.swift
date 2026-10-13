// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TomatoClock",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "TomatoClock", targets: ["TomatoClock"])],
    targets: [
        .target(name: "TomatoCore"),
        .executableTarget(name: "TomatoClock", dependencies: ["TomatoCore"]),
        .testTarget(name: "TomatoCoreTests", dependencies: ["TomatoCore"])
    ]
)
