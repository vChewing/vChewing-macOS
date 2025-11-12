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
  dependencies: [
    .package(path: "../vChewing_Shared"),
  ],
  targets: [
    .target(
      name: "ShiftKeyUpChecker",
      dependencies: [
        .product(name: "Shared", package: "vChewing_Shared"),
      ]
    ),
  ]
)
