// swift-tools-version: 6.4
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
    .package(path: "../vChewing_OSNeutral_LibVanguard"),
  ],
  targets: [
    .target(
      name: "ModifierKeyHitChecker",
      dependencies: [
        .product(name: "Vanguard", package: "vChewing_OSNeutral_LibVanguard"),
      ],
      swiftSettings: [
        .defaultIsolation(MainActor.self), // set Default Actor Isolation
      ]
    ),
  ]
)
