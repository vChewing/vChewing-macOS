// swift-tools-version:5.3
import PackageDescription

let package = Package(
  name: "SwiftExtension",
  platforms: [
    .macOS(.v10_11)
  ],
  products: [
    .library(
      name: "SwiftExtension",
      targets: ["SwiftExtension"]
    )
  ],
  dependencies: [],
  targets: [
    .target(
      name: "SwiftExtension",
      dependencies: []
    )
  ]
)
