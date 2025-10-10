// swift-tools-version: 5.7
import PackageDescription

let package = Package(
  name: "CandidateWindow",
  platforms: [
    .macOS(.v11),
  ],
  products: [
    .library(
      name: "CandidateWindow",
      targets: ["CandidateWindow"]
    ),
  ],
  dependencies: [
    .package(path: "../vChewing_Shared"),
  ],
  targets: [
    .target(
      name: "CandidateWindow",
      dependencies: [
        .product(name: "Shared", package: "vChewing_Shared"),
      ]
    ),
    .testTarget(
      name: "CandidateWindowTests",
      dependencies: ["CandidateWindow"]
    ),
  ]
)
