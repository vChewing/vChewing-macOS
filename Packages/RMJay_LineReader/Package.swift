// swift-tools-version:5.3
import PackageDescription

let package = Package(
  name: "LineReader",
  platforms: [
    .macOS(.v10_11)
  ],
  products: [
    .library(
      name: "LineReader",
      targets: ["LineReader"]
    )
  ],
  dependencies: [],
  targets: [
    .target(
      name: "LineReader",
      dependencies: []
    )
  ]
)
