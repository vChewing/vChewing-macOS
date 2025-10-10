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
  targets: [
    // Targets are the basic building blocks of a package, defining a module or a test suite.
    // Targets can depend on other targets in this package and products from dependencies.
    .target(
      name: "ObjcKimoCommunicator",
      publicHeadersPath: "include"
    ),
    .target(
      name: "KimoDataReader",
      dependencies: ["ObjcKimoCommunicator"]
    ),
    .testTarget(
      name: "KimoDataReaderTests",
      dependencies: ["KimoDataReader"]
    ),
  ]
)
