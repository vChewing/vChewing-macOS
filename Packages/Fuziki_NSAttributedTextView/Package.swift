// swift-tools-version:5.3
import PackageDescription

let package = Package(
  name: "NSAttributedTextView",
  platforms: [
    .macOS(.v10_11)
  ],
  products: [
    .library(
      name: "NSAttributedTextView",
      targets: ["NSAttributedTextView"]
    )
  ],
  dependencies: [],
  targets: [
    .target(
      name: "NSAttributedTextView",
      dependencies: []
    )
  ]
)
