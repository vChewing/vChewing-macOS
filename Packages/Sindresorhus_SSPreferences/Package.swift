// swift-tools-version:5.5
import PackageDescription

let package = Package(
  name: "SSPreferences",
  platforms: [
    .macOS(.v10_13),
  ],
  products: [
    .library(
      name: "SSPreferences",
      targets: [
        "SSPreferences",
      ]
    ),
  ],
  targets: [
    .target(
      name: "SSPreferences"
    ),
  ]
)
