// swift-tools-version:5.3
import PackageDescription

let package = Package(
  name: "SSPreferences",
  platforms: [
    .macOS(.v10_11)
  ],
  products: [
    .library(
      name: "SSPreferences",
      targets: [
        "SSPreferences"
      ]
    )
  ],
  targets: [
    .target(
      name: "SSPreferences"
    )
  ]
)
