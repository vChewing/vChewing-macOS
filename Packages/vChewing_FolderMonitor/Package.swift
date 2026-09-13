// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "FolderMonitor",
  platforms: [
    .macOS(.v12),
  ],
  products: [
    .library(
      name: "FolderMonitor",
      targets: ["FolderMonitor"]
    ),
  ],
  dependencies: [
    .package(path: "../vChewing_OSNeutralAssembly"),
  ],
  targets: [
    .target(
      name: "FolderMonitor",
      dependencies: [
        .product(name: "OSNeutralAssembly", package: "vChewing_OSNeutralAssembly"),
      ],
      swiftSettings: [
        .defaultIsolation(MainActor.self), // set Default Actor Isolation
      ]
    ),
  ]
)
