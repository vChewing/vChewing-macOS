// swift-tools-version: 5.7
import PackageDescription

let package = Package(
  name: "BrailleSputnik",
  platforms: [
    .macOS(.v11),
  ],
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
      ]
    ),
    .testTarget(
      name: "BrailleSputnikTests",
      dependencies: ["BrailleSputnik"]
    ),
  ]
)
