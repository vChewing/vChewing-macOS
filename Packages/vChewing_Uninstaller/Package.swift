// swift-tools-version: 5.7
import PackageDescription

let package = Package(
  name: "Uninstaller",
  platforms: [
    .macOS(.v11),
  ],
  products: [
    .library(
      name: "Uninstaller",
      targets: ["Uninstaller"]
    ),
  ],
  dependencies: [
    .package(path: "../vChewing_OSFrameworkImpl"),
  ],
  targets: [
    .target(
      name: "Uninstaller",
      dependencies: [
        .product(name: "OSFrameworkImpl", package: "vChewing_OSFrameworkImpl"),
      ]
    ),
  ]
)
