// swift-tools-version:5.10
import PackageDescription

let version = "v1.9.2-beta.1"

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
            url: "https://github.com/Simperium/simperium-ios/releases/download/\(version)/Simperium.xcframework.zip",
            checksum: "98e68843157b954d2d211520ea726b2f9cf4da1c730449d6dcc8a81fa10ec127"
        )
    ]
)
