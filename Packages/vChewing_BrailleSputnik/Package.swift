// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "BrailleSputnik",
  products: [
    // Products define the executables and libraries a package produces, making them visible to other packages.
    .library(
      name: "BrailleSputnik",
      targets: ["BrailleSputnik"]
    ),
  ],
  dependencies: [
    .package(path: "../vChewing_Shared"),
    .package(path: "../vChewing_Tekkon"),
  ],
  targets: [
    // Targets are the basic building blocks of a package, defining a module or a test suite.
    // Targets can depend on other targets in this package and products from dependencies.
    .target(
      name: "BrailleSputnik",
      dependencies: [
        .product(name: "Shared", package: "vChewing_Shared"),
        .product(name: "Tekkon", package: "vChewing_Tekkon"),
      ],
      swiftSettings: [
        .defaultIsolation(MainActor.self), // set Default Actor Isolation
      ]
    ),
    .testTarget(
      name: "BrailleSputnikTests",
      dependencies: ["BrailleSputnik"],
      swiftSettings: [
        .defaultIsolation(MainActor.self), // set Default Actor Isolation
      ]
    ),
  ]
)
