// swift-tools-version: 5.7
import PackageDescription

let package = Package(
  name: "IMKUtils",
  platforms: [
    .macOS(.v11),
  ],
  products: [
    .library(
      name: "IMKUtils",
      targets: ["IMKUtils"]
    ),
  ],
  dependencies: [
    .package(path: "../vChewing_SwiftExtension"),
  ],
  targets: [
    .target(
      name: "IMKUtils",
      dependencies: [
        .product(name: "SwiftExtension", package: "vChewing_SwiftExtension"),
      ]
    ),
  ]
)
