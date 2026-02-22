// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "OtherIMEDataReader",
  products: [
    // Products define the executables and libraries a package produces, making them visible to other packages.
    .library(
      name: "OtherIMEDataReader",
      targets: ["OtherIMEDataReader"]
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
      name: "OtherIMEDataReader",
      dependencies: [
        "KeyKeyUserDBKit",
      ],
      swiftSettings: [
        .defaultIsolation(MainActor.self), // set Default Actor Isolation
      ]
    ),
  ]
)
