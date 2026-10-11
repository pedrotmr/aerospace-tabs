// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AerospaceTabs",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "SessionPolicy", targets: ["SessionPolicy"]),
        .executable(name: "AerospaceTabs", targets: ["AerospaceTabs"]),
    ],
    targets: [
        .target(
            name: "SessionPolicy",
            path: "Sources/SessionPolicy"
        ),
        .executableTarget(
            name: "AerospaceTabs",
            dependencies: ["SessionPolicy"],
            path: "Sources/AerospaceTabs",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Carbon"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("ScreenCaptureKit"),
            ]
        ),
        .testTarget(
            name: "AerospaceTabsTests",
            dependencies: ["AerospaceTabs", "SessionPolicy"],
            path: "Tests/AerospaceTabsTests"
        ),
        .testTarget(
            name: "SessionPolicyTests",
            dependencies: ["SessionPolicy"],
            path: "Tests/SessionPolicyTests"
        ),
    ]
)
