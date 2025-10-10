// swift-tools-version: 5.7
import PackageDescription

let package = Package(
  name: "PopupCompositionBuffer",
  platforms: [
    .macOS(.v11),
  ],
  products: [
    .library(
      name: "PopupCompositionBuffer",
      targets: ["PopupCompositionBuffer"]
    ),
  ],
  dependencies: [
    .package(path: "../vChewing_Shared"),
  ],
  targets: [
    .target(
      name: "PopupCompositionBuffer",
      dependencies: [
        .product(name: "Shared", package: "vChewing_Shared"),
      ]
    ),
  ]
)
