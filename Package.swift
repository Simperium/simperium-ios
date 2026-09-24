// swift-tools-version:5.10
import PackageDescription

let version = "v1.9.1"

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
            checksum: "50f70027230524a08f7de4742cb27737430e058c38f25a37ac1a0a5eba3444f0"
        )
    ]
)
