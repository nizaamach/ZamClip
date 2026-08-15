// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ZamClip",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "ZamClip", targets: ["ZamClip"])
    ],
    targets: [
        .target(
            name: "ZamClipCore",
            path: "Sources/ZamClipCore"
        ),
        .executableTarget(
            name: "ZamClip",
            dependencies: ["ZamClipCore"],
            path: "Sources/ZamClip"
        ),
        .testTarget(
            name: "ZamClipCoreTests",
            dependencies: ["ZamClipCore"],
            path: "Tests/ZamClipCoreTests"
        )
    ],
    swiftLanguageModes: [.v5]
)
