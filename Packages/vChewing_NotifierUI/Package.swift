// swift-tools-version:5.3
import PackageDescription

let package = Package(
  name: "NotifierUI",
  platforms: [
    .macOS(.v10_11)
  ],
  products: [
    .library(
      name: "NotifierUI",
      targets: ["NotifierUI"]
    )
  ],
  dependencies: [],
  targets: [
    .target(
      name: "NotifierUI",
      dependencies: []
    )
  ]
)
