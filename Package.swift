// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NotesPlus",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "NotesPlus", swiftSettings: [.swiftLanguageMode(.v5)])
    ]
)
