// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SalaryTrackerCore",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "SalaryTrackerCore",
            targets: ["SalaryTrackerCore"]
        )
    ],
    targets: [
        .target(
            name: "SalaryTrackerCore",
            path: "Sources/SalaryTrackerCore"
        ),
        .testTarget(
            name: "SalaryTrackerCoreTests",
            dependencies: ["SalaryTrackerCore"],
            path: "Tests/SalaryTrackerCoreTests"
        )
    ]
)
