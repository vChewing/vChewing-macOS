// swift-tools-version: 5.5
import PackageDescription

let package = Package(
  name: "SwiftUIBackports",
  platforms: [
    .iOS(.v13),
    .tvOS(.v13),
    .watchOS(.v6),
    .macOS(.v10_15),
  ],
  products: [
    .library(
      name: "SwiftUIBackports",
      targets: ["SwiftUIBackports"]
    )
  ],
  targets: [
    .target(name: "SwiftUIBackports")
  ],
  swiftLanguageVersions: [.v5]
)
