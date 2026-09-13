// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "TableSlateIOS",
    platforms: [
        .iOS(.v17),
        .macOS(.v13),
    ],
    products: [
        .library(name: "TableSlateCore", targets: ["TableSlateCore"]),
    ],
    targets: [
        .target(name: "TableSlateCore"),
        .testTarget(
            name: "TableSlateCoreTests",
            dependencies: ["TableSlateCore"]
        ),
    ]
)
