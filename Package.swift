// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "OpenChord",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "OpenChord",
            targets: ["OpenChord"]
        )
    ],
    targets: [
        .executableTarget(
            name: "OpenChord"
        )
    ]
)
