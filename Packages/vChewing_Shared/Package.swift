// swift-tools-version: 5.7
import PackageDescription

let package = Package(
  name: "Shared",
  products: [
    .library(
      name: "Shared",
      targets: ["Shared"]
    ),
  ],
  dependencies: [
    .package(path: "../vChewing_SwiftExtension"),
  ],
  targets: [
    .target(
      name: "Shared",
      dependencies: [
        .product(name: "SwiftExtension", package: "vChewing_SwiftExtension"),
      ]
    ),
    .testTarget(
      name: "SharedTests",
      dependencies: ["Shared"]
    ),
  ]
)
