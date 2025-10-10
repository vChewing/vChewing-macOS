// swift-tools-version: 5.7
import PackageDescription

let package = Package(
  name: "ShiftKeyUpChecker",
  platforms: [
    .macOS(.v11),
  ],
  products: [
    .library(
      name: "ShiftKeyUpChecker",
      targets: ["ShiftKeyUpChecker"]
    ),
  ],
  dependencies: [],
  targets: [
    .target(
      name: "ShiftKeyUpChecker",
      dependencies: []
    ),
  ]
)
