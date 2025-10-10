// swift-tools-version: 5.7

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
    .package(path: "../CSQLite3"),
  ],
  targets: [
    .target(
      name: "Hotenka",
      dependencies: [
        .product(name: "CSQLite3", package: "CSQLite3"),
      ]
    ),
    .testTarget(
      name: "HotenkaTests",
      dependencies: ["Hotenka"]
    ),
  ]
)
