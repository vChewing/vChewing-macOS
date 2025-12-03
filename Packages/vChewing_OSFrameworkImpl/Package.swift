// swift-tools-version: 5.7
import PackageDescription

let package = Package(
  name: "OSFrameworkImpl",
  platforms: [
    .macOS(.v11),
  ],
  products: [
    .library(
      name: "OSFrameworkImpl",
      targets: ["OSFrameworkImpl"]
    ),
  ],
  dependencies: [
    .package(path: "../vChewing_SwiftExtension"),
  ],
  targets: [
    .target(
      name: "OSFrameworkImpl",
      dependencies: [
        .product(name: "SwiftExtension", package: "vChewing_SwiftExtension"),
      ]
    ),
    .testTarget(
      name: "OSFrameworkImplTests",
      dependencies: ["OSFrameworkImpl"]
    ),
  ]
)
