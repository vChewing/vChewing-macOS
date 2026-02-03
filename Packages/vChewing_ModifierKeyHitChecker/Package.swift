// swift-tools-version: 6.2
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
      ],
      swiftSettings: [
        .defaultIsolation(MainActor.self), // set Default Actor Isolation
      ]
    ),
  ]
)
