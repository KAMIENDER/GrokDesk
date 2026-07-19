// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GrokDesk",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "GrokDesk", targets: ["GrokDesk"])
    ],
    targets: [
        .executableTarget(
            name: "GrokDesk",
            path: "Sources/GrokDesk"
        )
    ]
)
