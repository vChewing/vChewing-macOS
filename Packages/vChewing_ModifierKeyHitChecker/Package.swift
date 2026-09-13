// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "ModifierKeyHitChecker",
  platforms: [
    .macOS(.v12),
  ],
  products: [
    .library(
      name: "ModifierKeyHitChecker",
      targets: ["ModifierKeyHitChecker"]
    ),
  ],
  dependencies: [
    .package(path: "../vChewing_OSNeutralAssembly"),
  ],
  targets: [
    .target(
      name: "ModifierKeyHitChecker",
      dependencies: [
        .product(name: "OSNeutralAssembly", package: "vChewing_OSNeutralAssembly"),
      ],
      swiftSettings: [
        .defaultIsolation(MainActor.self), // set Default Actor Isolation
      ]
    ),
  ]
)
