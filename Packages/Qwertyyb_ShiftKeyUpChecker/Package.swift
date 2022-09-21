// swift-tools-version:5.3
import PackageDescription

let package = Package(
  name: "ShiftKeyUpChecker",
  platforms: [
    .macOS(.v10_11)
  ],
  products: [
    .library(
      name: "ShiftKeyUpChecker",
      targets: ["ShiftKeyUpChecker"]
    )
  ],
  dependencies: [],
  targets: [
    .target(
      name: "ShiftKeyUpChecker",
      dependencies: []
    )
  ]
)
