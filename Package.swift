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
            sources: ["Core", "Domain", "Data", "Services", "Infrastructure"]
        ),
        .testTarget(
            name: "EarnlySystemsTests",
            dependencies: ["EarnlySystems"],
            path: "EarnlyTests",
            sources: ["Domain", "Services", "Infrastructure"]
        )
    ]
)
