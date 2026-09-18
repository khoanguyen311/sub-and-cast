// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "SubAndCast",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "SubAndCastKit",
            targets: ["SubAndCastKit"]
        ),
        .executable(
            name: "SubAndCast",
            targets: ["SubAndCast"]
        ),
        .executable(
            name: "SubAndCastTests",
            targets: ["SubAndCastTests"]
        )
    ],
    targets: [
        .target(
            name: "SubAndCastKit",
            dependencies: [],
            resources: [.process("Resources")]
        ),
        .executableTarget(
            name: "SubAndCast",
            dependencies: ["SubAndCastKit"]
        ),
        .executableTarget(
            name: "SubAndCastTests",
            dependencies: ["SubAndCastKit"]
        )
    ],
    swiftLanguageModes: [.v6]
)
