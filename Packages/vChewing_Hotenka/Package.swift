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
  dependencies: [
    .package(path: "../CSQLite3Lib"),
  ],
  targets: [
    .target(
      name: "Hotenka",
      dependencies: [
        .product(name: "CSQLite3Lib", package: "CSQLite3Lib"),
      ],
      swiftSettings: [
        .defaultIsolation(MainActor.self), // set Default Actor Isolation
      ]
    ),
    .target(
      name: "HotenkaTestDictData",
      resources: [
        .process("Resources")
      ]
    ),
    .testTarget(
      name: "HotenkaTests",
      dependencies: [
        "Hotenka",
        "HotenkaTestDictData"
      ],
      swiftSettings: [
        .defaultIsolation(MainActor.self), // set Default Actor Isolation
      ]
    ),
  ]
)
