// swift-tools-version:5.10
import PackageDescription

let version = "v1.9.2"

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
            checksum: "ed949d8bad6a02d5b13bc85e067542c06720000c671f2f9e6310116ccb02e6e6"
        )
    ]
)
