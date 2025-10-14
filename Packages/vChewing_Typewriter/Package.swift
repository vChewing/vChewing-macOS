// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "Typewriter",
  platforms: [
    .macOS(.v11),
  ],
  products: [
    .library(
      name: "Typewriter",
      targets: ["Typewriter"]
    ),
  ],
  dependencies: [
    .package(path: "../vChewing_BrailleSputnik"),
    .package(path: "../vChewing_LangModelAssembly"),
    .package(path: "../vChewing_IMKUtils"),
    .package(path: "../vChewing_Megrez"),
    .package(path: "../vChewing_Shared"),
    .package(path: "../vChewing_SwiftExtension"),
    .package(path: "../vChewing_Tekkon"),
  ],
  targets: [
    // Targets are the basic building blocks of a package, defining a module or a test suite.
    // Targets can depend on other targets in this package and products from dependencies.
    .target(
      name: "Typewriter",
      dependencies: [
        .product(name: "BrailleSputnik", package: "vChewing_BrailleSputnik"),
        .product(name: "LangModelAssembly", package: "vChewing_LangModelAssembly"),
        .product(name: "Megrez", package: "vChewing_Megrez"),
        .product(name: "Shared", package: "vChewing_Shared"),
        .product(name: "SwiftExtension", package: "vChewing_SwiftExtension"),
        .product(name: "Tekkon", package: "vChewing_Tekkon"),
      ],
      linkerSettings: [
        .linkedLibrary("iconv", .when(platforms: [.macOS])),
      ]
    ),
    .testTarget(
      name: "TypewriterTests",
      dependencies: [
        "Typewriter",
        .product(name: "IMKUtils", package: "vChewing_IMKUtils"),
        .product(name: "LangModelAssembly", package: "vChewing_LangModelAssembly"),
        .product(name: "Megrez", package: "vChewing_Megrez"),
        .product(name: "MegrezTestComponents", package: "vChewing_Megrez"),
        .product(name: "Shared", package: "vChewing_Shared"),
        .product(name: "Tekkon", package: "vChewing_Tekkon"),
      ],
      linkerSettings: [
        .linkedLibrary("iconv", .when(platforms: [.macOS])),
      ]
    ),
  ]
)
