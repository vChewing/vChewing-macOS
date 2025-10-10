// swift-tools-version: 5.7
import PackageDescription

let package = Package(
  name: "BookmarkManager",
  platforms: [
    .macOS(.v10_13),
  ],
  products: [
    .library(
      name: "BookmarkManager",
      targets: ["BookmarkManager"]
    ),
  ],
  dependencies: [],
  targets: [
    .target(
      name: "BookmarkManager",
      dependencies: []
    ),
  ]
)
