// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "Tekkon",
  products: [
    .library(
      name: "Tekkon",
      targets: ["Tekkon"]
    ),
  ],
  dependencies: [],
  targets: [
    .target(
      name: "Tekkon",
      dependencies: []
    ),
    .testTarget(
      name: "TekkonTests",
      dependencies: ["Tekkon"],
    ),
  ]
)
