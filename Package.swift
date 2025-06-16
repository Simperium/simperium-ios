// swift-tools-version:5.10
import PackageDescription

let tag = "v1.9.1-beta.1"

let package = Package(
    name: "Simperium",
    products: [
        .library(name: "Simperium", targets: ["Simperium"])
    ],
    targets: [
        // SwiftPM requires packages to have at least one buildable target.
        .target(name: "Dummy"),
        .binaryTarget(
            name: "Simperium",
            url: "https://github.com/Simperium/simperium-ios/releases/download/\(tag)/Simperium.xcframework.zip",
            checksum: "f6eac1b33f47e9f126e8444c8e157bf22dea7b66e9a6d6ecd50e4a79820ada35"
        )
    ]
)
