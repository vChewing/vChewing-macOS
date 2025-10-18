// swift-tools-version: 5.7
import PackageDescription

let package = Package(
  name: "SwiftExtension",
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
