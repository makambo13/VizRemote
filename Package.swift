// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "VizRemote",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "VizRemote",
            path: "Sources/VizRemote"
        )
    ]
)
