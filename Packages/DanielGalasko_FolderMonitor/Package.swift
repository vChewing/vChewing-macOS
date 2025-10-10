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
  dependencies: [],
  targets: [
    .target(
      name: "FolderMonitor",
      dependencies: []
    ),
  ]
)
