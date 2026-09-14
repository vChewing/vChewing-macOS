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
    .package(path: "../vChewing_OSNeutral_LibVanguard"),
  ],
  targets: [
    .target(
      name: "FolderMonitor",
      dependencies: [
        .product(name: "Vanguard", package: "vChewing_OSNeutral_LibVanguard"),
      ],
      swiftSettings: [
        .defaultIsolation(MainActor.self), // set Default Actor Isolation
      ]
    ),
  ]
)
