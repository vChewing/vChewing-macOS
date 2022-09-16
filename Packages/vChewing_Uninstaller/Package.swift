// swift-tools-version:5.3
import PackageDescription

let package = Package(
  name: "Uninstaller",
  platforms: [
    .macOS(.v10_11)
  ],
  products: [
    .library(
      name: "Uninstaller",
      targets: ["Uninstaller"]
    )
  ],
  dependencies: [
    .package(path: "../vChewing_CocoaExtension")
  ],
  targets: [
    .target(
      name: "Uninstaller",
      dependencies: [
        .product(name: "CocoaExtension", package: "vChewing_CocoaExtension")
      ]
    )
  ]
)
