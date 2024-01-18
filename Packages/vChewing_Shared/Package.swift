// swift-tools-version:5.3
import PackageDescription

let package = Package(
  name: "Shared",
  platforms: [
    .macOS(.v11),
  ],
  products: [
    .library(
      name: "Shared",
      targets: ["Shared"]
    ),
  ],
  dependencies: [
    .package(path: "../vChewing_CocoaExtension"),
    .package(path: "../vChewing_IMKUtils"),
    .package(path: "../vChewing_SwiftExtension"),
  ],
  targets: [
    .target(
      name: "Shared",
      dependencies: [
        .product(name: "CocoaExtension", package: "vChewing_CocoaExtension"),
        .product(name: "IMKUtils", package: "vChewing_IMKUtils"),
        .product(name: "SwiftExtension", package: "vChewing_SwiftExtension"),
      ]
    ),
  ]
)
