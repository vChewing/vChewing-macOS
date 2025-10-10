// swift-tools-version: 5.7
import PackageDescription

let package = Package(
  name: "Megrez",
  platforms: [
    .macOS(.v10_11),
  ],
  products: [
    .library(
      name: "Megrez",
      targets: ["Megrez"]
    ),
    .library(
      name: "MegrezTestComponents",
      targets: ["MegrezTestComponents"]
    ),
  ],
  dependencies: [],
  targets: [
    .target(
      name: "Megrez",
      dependencies: []
    ),
    .target(
      name: "MegrezTestComponents",
      dependencies: [
        "Megrez",
      ]
    ),
    .testTarget(
      name: "MegrezTests",
      dependencies: [
        "Megrez",
        "MegrezTestComponents",
      ]
    ),
  ]
)
