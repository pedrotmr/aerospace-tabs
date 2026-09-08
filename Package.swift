// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AerospaceTabs",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "AerospaceTabs", targets: ["AerospaceTabs"]),
    ],
    targets: [
        .executableTarget(
            name: "AerospaceTabs",
            path: "Sources/AerospaceTabs",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Carbon"),
                .linkedFramework("ApplicationServices"),
            ]
        ),
    ]
)
