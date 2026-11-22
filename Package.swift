// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EarnlySystems",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "EarnlySystems", targets: ["EarnlySystems"])],
    targets: [
        .target(
            name: "EarnlySystems",
            path: "Earnly",
            exclude: ["Assets.xcassets", "DesignSystem", "Integration", "Navigation", "Presentation",
                      "ContentView.swift", "EarnlyApp.swift"],
            sources: ["Core", "Domain", "Data", "Services", "Infrastructure"]
        ),
        .testTarget(
            name: "EarnlySystemsTests",
            dependencies: ["EarnlySystems"],
            path: "EarnlyTests",
            exclude: ["Presentation"],
            sources: ["Domain", "Services", "Infrastructure"]
        )
    ]
)
