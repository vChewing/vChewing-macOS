// swift-tools-version:5.3
import PackageDescription

let package = Package(
  name: "UpdateSputnik",
  platforms: [
    .macOS(.v10_11)
  ],
  products: [
    .library(
      name: "UpdateSputnik",
      targets: ["UpdateSputnik"]
    )
  ],
  dependencies: [],
  targets: [
    .target(
      name: "UpdateSputnik",
      dependencies: []
    )
  ]
)
