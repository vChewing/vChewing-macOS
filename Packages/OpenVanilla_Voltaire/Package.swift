// swift-tools-version:5.3
import PackageDescription

let package = Package(
  name: "Voltaire",
  platforms: [
    .macOS(.v10_11)
  ],
  products: [
    .library(
      name: "Voltaire",
      targets: ["Voltaire"]
    )
  ],
  dependencies: [
    .package(path: "../vChewing_CandidateWindow"),
    .package(path: "../vChewing_Shared"),
  ],
  targets: [
    .target(
      name: "Voltaire",
      dependencies: [
        .product(name: "Shared", package: "vChewing_Shared"),
        .product(name: "CandidateWindow", package: "vChewing_CandidateWindow"),
      ]
    )
  ]
)
