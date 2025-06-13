// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Simperium",
    products: [
        .library(name: "Simperium", targets: ["SimperiumWrapper"]),
    ],
    targets: [
        .target(
            name: "SimperiumWrapper",
            dependencies: [
                .target(name: "Simperium", condition: .when(platforms: [.iOS])),
                .target(name: "Simperium_macOS", condition: .when(platforms: [.macOS]))
            ]
        ),
        .binaryTarget(
            name: "Simperium",
            path: ".build/xcframeworks/Simperium-ios.xcframework"
        ),
        .binaryTarget(
            name: "Simperium_macOS",
            path: ".build/xcframeworks/Simperium-macos.xcframework"
        )
    ]
)
