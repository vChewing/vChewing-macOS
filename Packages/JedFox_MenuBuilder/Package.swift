// swift-tools-version:5.3
import PackageDescription

let package = Package(
  name: "MenuBuilder",
  // only tested on macOS 11, but I’m happy to accept PRs for older versions
  platforms: [.macOS(.v10_10)],
  products: [
    .library(
      name: "MenuBuilder",
      targets: ["MenuBuilder"]
    )
  ],
  dependencies: [],
  targets: [
    .target(
      name: "MenuBuilder",
      dependencies: []
    ),
    .testTarget(
      name: "MenuBuilderTests",
      dependencies: ["MenuBuilder"]
    ),
  ]
)
