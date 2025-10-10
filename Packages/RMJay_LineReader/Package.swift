// swift-tools-version:5.3
import PackageDescription

let package = Package(
  name: "LineReader",
  platforms: [
    .macOS(.v11),
  ],
  products: [
    .library(
      name: "LineReader",
      targets: ["LineReader"]
    ),
  ],
  targets: [
    .target(
      name: "LineReader"
    ),
  ]
)
