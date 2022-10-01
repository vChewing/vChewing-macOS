// swift-tools-version:5.3
import PackageDescription

let package = Package(
  name: "TDKCandidateBackports",
  platforms: [
    .macOS(.v10_11)
  ],
  products: [
    .library(
      name: "TDKCandidateBackports",
      targets: ["TDKCandidateBackports"]
    )
  ],
  dependencies: [
    .package(path: "../vChewing_Shared"),
    .package(path: "../vChewing_CandidateWindow"),
    .package(path: "../ShapsBenkau_SwiftUIBackports"),
  ],
  targets: [
    .target(
      name: "TDKCandidateBackports",
      dependencies: [
        .product(name: "Shared", package: "vChewing_Shared"),
        .product(name: "CandidateWindow", package: "vChewing_CandidateWindow"),
        .product(name: "SwiftUIBackports", package: "ShapsBenkau_SwiftUIBackports"),
      ]
    )
  ]
)
