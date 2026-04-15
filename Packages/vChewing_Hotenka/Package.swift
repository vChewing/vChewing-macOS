// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "Hotenka",
  platforms: [
    .macOS(.v11),
  ],
  products: [
    .library(
      name: "Hotenka",
      targets: ["Hotenka"]
    ),
  ],
  dependencies: [],
  targets: [
    .target(
      name: "Hotenka",
      dependencies: [],
      swiftSettings: [
        .defaultIsolation(MainActor.self), // set Default Actor Isolation
      ]
    ),
    .testTarget(
      name: "HotenkaTests",
      dependencies: [
        "Hotenka",
      ],
      swiftSettings: [
        .defaultIsolation(MainActor.self), // set Default Actor Isolation
      ]
    ),
  ]
)
