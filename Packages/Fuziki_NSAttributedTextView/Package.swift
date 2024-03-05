// swift-tools-version:5.3
import PackageDescription

let package = Package(
  name: "NSAttributedTextView",
  platforms: [
    .macOS(.v11),
  ],
  products: [
    .library(
      name: "NSAttributedTextView",
      targets: ["NSAttributedTextView"]
    ),
  ],
  dependencies: [
    .package(path: "../vChewing_OSFrameworkImpl"),
  ],
  targets: [
    .target(
      name: "NSAttributedTextView",
      dependencies: [
        .product(name: "OSFrameworkImpl", package: "vChewing_OSFrameworkImpl"),
      ]
    ),
    .testTarget(
      name: "NSAttributedTextViewTests",
      dependencies: ["NSAttributedTextView"]
    ),
  ]
)
