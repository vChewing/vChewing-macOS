// swift-tools-version: 6.2
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
    .package(path: "../vChewing_OSNeutralAssembly"),
  ],
  targets: [
    .target(
      name: "UpdateSputnik",
      dependencies: [
        .product(name: "OSNeutralAssembly", package: "vChewing_OSNeutralAssembly"),
      ],
      swiftSettings: [
        .defaultIsolation(MainActor.self), // set Default Actor Isolation
      ]
    ),
  ]
)
