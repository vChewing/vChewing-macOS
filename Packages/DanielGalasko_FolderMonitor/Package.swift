// swift-tools-version:5.3
import PackageDescription

let package = Package(
  name: "FolderMonitor",
  platforms: [
    .macOS(.v10_11)
  ],
  products: [
    .library(
      name: "FolderMonitor",
      targets: ["FolderMonitor"]
    )
  ],
  dependencies: [],
  targets: [
    .target(
      name: "FolderMonitor",
      dependencies: []
    )
  ]
)
