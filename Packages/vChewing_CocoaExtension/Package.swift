// swift-tools-version:5.3
import PackageDescription

let package = Package(
  name: "CocoaExtension",
  platforms: [
    .macOS(.v11),
  ],
  products: [
    .library(
      name: "CocoaExtension",
      targets: ["CocoaExtension"]
    ),
  ],
  dependencies: [
    .package(path: "../vChewing_SwiftExtension"),
  ],
  targets: [
    .target(
      name: "CocoaExtension",
      dependencies: [
        .product(name: "SwiftExtension", package: "vChewing_SwiftExtension"),
      ]
    ),
  ]
)
