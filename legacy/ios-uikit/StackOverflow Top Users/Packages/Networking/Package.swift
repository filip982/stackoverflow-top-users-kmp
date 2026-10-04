// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "Networking",
    platforms: [.iOS(.v18), .macOS(.v14)],
    products: [
        .library(name: "Networking", targets: ["Networking"]),
        .library(name: "NetworkingTestSupport", targets: ["NetworkingTestSupport"]),
    ],
    targets: [
        .target(name: "Networking"),
        .target(name: "NetworkingTestSupport", dependencies: ["Networking"]),
        .testTarget(
            name: "NetworkingTests",
            dependencies: ["Networking", "NetworkingTestSupport"],
        ),
    ],
    swiftLanguageModes: [.v6]
)
