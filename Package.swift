// swift-tools-version:5.10
import PackageDescription

let tag = "v1.9.1-beta.1"
let baseArtifactURL = "https://github.com/Simperium/simperium-ios/releases/download/\(tag)"

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
            url: "\(baseArtifactURL)/Simperium-ios.xcframework.zip",
            checksum: "0dd9f439a7c0f9af7ed42945eb0d83cdeb7cc9f3e8495e2604145c15896a9525"
        ),
        .binaryTarget(
            name: "Simperium_macOS",
            url: "\(baseArtifactURL)/Simperium-macos.xcframework.zip",
            checksum: "ae4da609094c0679ddc80b06067e08555c5e1674cf68d16072c492d537d3f287"
        )
    ]
)
