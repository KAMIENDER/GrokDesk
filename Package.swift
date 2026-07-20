// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GrokDesk",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "GrokDesk", targets: ["GrokDesk"])
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.9.0")
    ],
    targets: [
        .executableTarget(
            name: "GrokDesk",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "Sources/GrokDesk"
        )
    ]
)
