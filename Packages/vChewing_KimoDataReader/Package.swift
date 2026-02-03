// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "KimoDataReader",
  products: [
    // Products define the executables and libraries a package produces, making them visible to other packages.
    .library(
      name: "KimoDataReader",
      targets: ["KimoDataReader"]
    ),
  ],
  dependencies: [
    .package(path: "../CSQLite3Lib"),
  ],
  targets: [
    // Targets are the basic building blocks of a package, defining a module or a test suite.
    // Targets can depend on other targets in this package and products from dependencies.
    .target(
      name: "KeyKeyUserDBKit",
      dependencies: [
        .product(name: "CSQLite3Lib", package: "CSQLite3Lib"),
      ]
    ),
    .target(
      name: "KimoDataReader",
      dependencies: ["KeyKeyUserDBKit"]
    ),
    .testTarget(
      name: "KimoDataReaderTests",
      dependencies: ["KimoDataReader"]
    ),
  ]
)
