// swift-tools-version: 5.7
import PackageDescription

let package = Package(
  name: "Tekkon",
  platforms: [
    .macOS(.v10_11),
  ],
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
      dependencies: ["Tekkon"]
    ),
  ]
)
