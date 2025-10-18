// swift-tools-version: 5.7
import PackageDescription

let package = Package(
  name: "Tekkon",
  platforms: [
    .macOS(.v10_13),
  ],
  products: [
    .library(
      name: "Tekkon",
      targets: ["Tekkon"]
    ),
  ],
  dependencies: [],
  targets: [
    .target(
      name: "Tekkon",
      dependencies: []
    ),
    .testTarget(
      name: "TekkonTests",
      dependencies: ["Tekkon"],
      linkerSettings: [
        .linkedFramework("XCTest", .when(platforms: [.macOS])),
        .linkedFramework("Foundation", .when(platforms: [.macOS])),
      ]
    ),
  ]
)
