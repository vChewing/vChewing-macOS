// swift-tools-version: 5.7
import PackageDescription

let package = Package(
  name: "ModifierKeyHitChecker",
  platforms: [
    .macOS(.v11),
  ],
  products: [
    .library(
      name: "ModifierKeyHitChecker",
      targets: ["ModifierKeyHitChecker"]
    ),
  ],
  dependencies: [
    .package(path: "../vChewing_Shared"),
  ],
  targets: [
    .target(
      name: "ModifierKeyHitChecker",
      dependencies: [
        .product(name: "Shared", package: "vChewing_Shared"),
      ]
    ),
  ]
)
