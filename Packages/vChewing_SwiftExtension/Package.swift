// swift-tools-version: 5.7
import PackageDescription

let package = Package(
  name: "SwiftExtension",
  platforms: [
    .macOS(.v11),
  ],
  products: [
    .library(
      name: "SwiftExtension",
      targets: ["SwiftExtension"]
    ),
  ],
  dependencies: [],
  targets: [
    .target(
      name: "SwiftExtension",
      dependencies: []
    ),
  ]
)
