// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "Megrez",
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
