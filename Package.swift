// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "GMGNTraderNative",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "GMGNTraderNative", targets: ["GMGNTraderNative"])
    ],
    targets: [
        .executableTarget(
            name: "GMGNTraderNative",
            linkerSettings: [
                .linkedFramework("Security")
            ]
        )
    ]
)
