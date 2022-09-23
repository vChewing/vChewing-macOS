// swift-tools-version:5.3
import PackageDescription

let package = Package(
  name: "TooltipUI",
  platforms: [
    .macOS(.v10_11)
  ],
  products: [
    .library(
      name: "TooltipUI",
      targets: ["TooltipUI"]
    )
  ],
  dependencies: [
    .package(path: "../Fuziki_NSAttributedTextView"),
    .package(path: "../vChewing_CocoaExtension"),
    .package(path: "../vChewing_Shared"),
  ],
  targets: [
    .target(
      name: "TooltipUI",
      dependencies: [
        .product(name: "NSAttributedTextView", package: "Fuziki_NSAttributedTextView"),
        .product(name: "CocoaExtension", package: "vChewing_CocoaExtension"),
        .product(name: "Shared", package: "vChewing_Shared"),
      ]
    )
  ]
)
