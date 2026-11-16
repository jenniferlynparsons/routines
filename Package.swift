// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Routines",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "Routines", path: "Sources/Routines")
    ]
)
