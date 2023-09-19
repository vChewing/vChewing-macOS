// swift-tools-version:5.3
import PackageDescription

let package = Package(
  name: "NSAttributedTextView",
  platforms: [
    .macOS(.v10_11),
  ],
  products: [
    .library(
      name: "NSAttributedTextView",
      targets: ["NSAttributedTextView"]
    ),
  ],
  dependencies: [
    .package(path: "../vChewing_CocoaExtension"),
  ],
  targets: [
    .target(
      name: "NSAttributedTextView",
      dependencies: [
        .product(name: "CocoaExtension", package: "vChewing_CocoaExtension"),
      ]
    ),
    .testTarget(
      name: "NSAttributedTextViewTests",
      dependencies: ["NSAttributedTextView"]
    ),
  ]
)
