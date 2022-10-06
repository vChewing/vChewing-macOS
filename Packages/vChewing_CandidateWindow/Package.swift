// swift-tools-version:5.3
import PackageDescription

let package = Package(
  name: "CandidateWindow",
  platforms: [
    .macOS(.v10_11)
  ],
  products: [
    .library(
      name: "CandidateWindow",
      targets: ["CandidateWindow"]
    )
  ],
  dependencies: [
    .package(path: "../vChewing_Shared"),
    .package(path: "../ShapsBenkau_SwiftUIBackports"),
  ],
  targets: [
    .target(
      name: "CandidateWindow",
      dependencies: [
        .product(name: "Shared", package: "vChewing_Shared"),
        .product(name: "SwiftUIBackports", package: "ShapsBenkau_SwiftUIBackports"),
      ]
    ),
    .testTarget(
      name: "CandidateWindowTests",
      dependencies: ["CandidateWindow"]
    ),
  ]
)
