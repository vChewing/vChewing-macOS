// swift-tools-version: 5.7
import PackageDescription

let package = Package(
  name: "LineReader",
  products: [
    .library(
      name: "LineReader",
      targets: ["LineReader"]
    ),
  ],
  dependencies: [
    .package(path: "../vChewing_SwiftExtension"),
  ],
  targets: [
    .target(
      name: "LineReader",
      dependencies: [
        .product(name: "SwiftExtension", package: "vChewing_SwiftExtension"),
      ]
    ),
  ]
)
