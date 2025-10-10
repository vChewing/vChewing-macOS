// swift-tools-version: 5.7
import PackageDescription

let package = Package(
  name: "TooltipUI",
  platforms: [
    .macOS(.v11),
  ],
  products: [
    .library(
      name: "TooltipUI",
      targets: ["TooltipUI"]
    ),
  ],
  dependencies: [
    .package(path: "../vChewing_OSFrameworkImpl"),
    .package(path: "../vChewing_Shared"),
  ],
  targets: [
    .target(
      name: "TooltipUI",
      dependencies: [
        .product(name: "OSFrameworkImpl", package: "vChewing_OSFrameworkImpl"),
        .product(name: "Shared", package: "vChewing_Shared"),
      ]
    ),
  ]
)
