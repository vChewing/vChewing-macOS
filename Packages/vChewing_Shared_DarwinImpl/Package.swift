// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "Shared_DarwinImpl",
  platforms: [
    .macOS(.v11),
  ],
  products: [
    .library(
      name: "Shared_DarwinImpl",
      targets: ["Shared_DarwinImpl"]
    ),
  ],
  dependencies: [
    .package(path: "../vChewing_OSFrameworkImpl"),
    .package(path: "../vChewing_Shared"),
    .package(path: "../vChewing_SwiftExtension"),
  ],
  targets: [
    .target(
      name: "Shared_DarwinImpl",
      dependencies: [
        .product(name: "OSFrameworkImpl", package: "vChewing_OSFrameworkImpl"),
        .product(name: "Shared", package: "vChewing_Shared"),
        .product(name: "SwiftExtension", package: "vChewing_SwiftExtension"),
      ]
    ),
    .testTarget(
      name: "Shared_DarwinImplTests",
      dependencies: [
        "Shared_DarwinImpl",
        .product(name: "OSFrameworkImpl", package: "vChewing_OSFrameworkImpl"),
        .product(name: "Shared", package: "vChewing_Shared"),
        .product(name: "SwiftExtension", package: "vChewing_SwiftExtension"),
      ]
    ),
  ]
)
