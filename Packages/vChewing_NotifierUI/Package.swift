// swift-tools-version: 5.7
import PackageDescription

let package = Package(
  name: "NotifierUI",
  platforms: [
    .macOS(.v11),
  ],
  products: [
    .library(
      name: "NotifierUI",
      targets: ["NotifierUI"]
    ),
  ],
  dependencies: [
    .package(path: "../vChewing_OSFrameworkImpl"),
  ],
  targets: [
    .target(
      name: "NotifierUI",
      dependencies: [
        .product(name: "OSFrameworkImpl", package: "vChewing_OSFrameworkImpl"),
      ]
    ),
  ]
)
