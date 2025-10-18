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
    .package(path: "../vChewing_Shared_DarwinImpl"),
  ],
  targets: [
    .target(
      name: "CandidateWindow",
      dependencies: [
        .product(name: "Shared_DarwinImpl", package: "vChewing_Shared_DarwinImpl"),
      ]
    ),
    .testTarget(
      name: "CandidateWindowTests",
      dependencies: ["CandidateWindow"]
    ),
  ]
)
