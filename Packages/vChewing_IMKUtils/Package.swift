// swift-tools-version:5.3
import PackageDescription

let package = Package(
  name: "IMKUtils",
  platforms: [
    .macOS(.v11),
  ],
  products: [
    .library(
      name: "IMKUtils",
      targets: ["IMKUtils"]
    ),
  ],
  dependencies: [],
  targets: [
    .target(
      name: "IMKUtils",
      dependencies: []
    ),
  ]
)
