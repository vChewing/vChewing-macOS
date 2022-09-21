// swift-tools-version:5.3
import PackageDescription

let package = Package(
  name: "Hotenka",
  platforms: [
    .macOS(.v10_11)
  ],
  products: [
    .library(
      name: "Hotenka",
      targets: ["Hotenka"]
    )
  ],
  dependencies: [],
  targets: [
    .target(
      name: "Hotenka",
      dependencies: []
    ),
    .testTarget(
      name: "HotenkaTests",
      dependencies: ["Hotenka"]
    ),
  ]
)
