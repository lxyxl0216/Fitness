// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FitnessCore",
    platforms: [.macOS(.v14)],
    products: [.library(name: "FitnessCore", targets: ["FitnessCore"])],
    targets: [
        .target(name: "FitnessCore", path: "Fitness/Core"),
        .testTarget(name: "FitnessCoreTests", dependencies: ["FitnessCore"], path: "Tests/FitnessCoreTests")
    ]
)
