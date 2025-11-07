// swift-tools-version: 5.7
import PackageDescription

let package = Package(
  name: "FolderMonitor",
  platforms: [
    .macOS(.v11),
  ],
  products: [
    .library(
      name: "FolderMonitor",
      targets: ["FolderMonitor"]
    ),
  ],
  dependencies: [
    .package(path: "../vChewing_SwiftExtension"),
  ],
  targets: [
    .target(
      name: "FolderMonitor",
      dependencies: [
        .product(name: "SwiftExtension", package: "vChewing_SwiftExtension"),
      ]
    ),
  ]
)
