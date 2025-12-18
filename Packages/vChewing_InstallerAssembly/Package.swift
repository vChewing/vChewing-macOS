// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "InstallerAssembly",
  platforms: [
    .macOS(.v12),
  ],
  products: [
    .library(
      name: "InstallerAssembly",
      targets: ["InstallerAssembly"]
    ),
  ],
  dependencies: [
    .package(path: "../vChewing_IMKUtils"),
    .package(path: "../vChewing_OSFrameworkImpl"),
    .package(path: "../vChewing_SwiftExtension"),
  ],
  targets: [
    .target(
      name: "InstallerAssembly",
      dependencies: [
        .product(name: "IMKUtils", package: "vChewing_IMKUtils"),
        .product(name: "SwiftExtension", package: "vChewing_SwiftExtension"),
        .product(name: "OSFrameworkImpl", package: "vChewing_OSFrameworkImpl"),
      ]
    ),
    .testTarget(
      name: "InstallerAssemblyTests",
      dependencies: ["InstallerAssembly"]
    ),
  ]
)
