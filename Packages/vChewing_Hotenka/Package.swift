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
    .package(path: "../CSQLite3Lib"),
  ],
  targets: [
    .target(
      name: "Hotenka",
      dependencies: [
        .product(name: "CSQLite3Lib", package: "CSQLite3Lib"),
      ]
    ),
    .testTarget(
      name: "HotenkaTests",
      dependencies: ["Hotenka"]
    ),
  ]
)
