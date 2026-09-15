// swift-tools-version: 6.4
import PackageDescription

let package = Package(
  name: "UpdateSputnik",
  platforms: [
    .macOS(.v12),
  ],
  products: [
    .library(
      name: "UpdateSputnik",
      targets: ["UpdateSputnik"]
    ),
  ],
  dependencies: [
    .package(path: "../vChewing_OSNeutral_LibVanguard"),
  ],
  targets: [
    .target(
      name: "UpdateSputnik",
      dependencies: [
        .product(name: "Vanguard", package: "vChewing_OSNeutral_LibVanguard"),
      ],
      swiftSettings: [
        .defaultIsolation(MainActor.self), // set Default Actor Isolation
      ]
    ),
  ]
)
