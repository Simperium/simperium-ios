// swift-tools-version:5.10
import PackageDescription

let tag = "v1.9.1-beta.2"

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
            checksum: "159842b63ab14ed1615fcace752c57b2633b3d3be6fadd4f643a1c8323b70e48"
        )
    ]
)
