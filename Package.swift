// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "EyeLine",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "EyeLineCore"),
        .executableTarget(name: "EyeLine", dependencies: ["EyeLineCore"]),
        .testTarget(name: "EyeLineCoreTests", dependencies: ["EyeLineCore"]),
    ]
)
