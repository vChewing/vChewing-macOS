// swift-tools-version:5.3
import PackageDescription

let package = Package(
  name: "BookmarkManager",
  platforms: [
    .macOS(.v10_11)
  ],
  products: [
    .library(
      name: "BookmarkManager",
      targets: ["BookmarkManager"]
    )
  ],
  dependencies: [],
  targets: [
    .target(
      name: "BookmarkManager",
      dependencies: []
    )
  ]
)
