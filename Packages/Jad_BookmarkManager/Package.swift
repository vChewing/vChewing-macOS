// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "BookmarkManager",
  platforms: [
    .macOS(.v12),
  ],
  products: [
    .library(
      name: "BookmarkManager",
      targets: ["BookmarkManager"]
    ),
  ],
  dependencies: [
    .package(path: "../vChewing_OSNeutralAssembly"),
  ],
  targets: [
    .target(
      name: "BookmarkManager",
      dependencies: [
        .product(name: "OSNeutralAssembly", package: "vChewing_OSNeutralAssembly"),
      ],
      swiftSettings: [
        .defaultIsolation(MainActor.self), // set Default Actor Isolation
      ]
    ),
    .testTarget(
      name: "BookmarkManagerTests",
      dependencies: [
        "BookmarkManager",
        .product(name: "OSNeutralAssembly", package: "vChewing_OSNeutralAssembly"),
      ],
      path: "Tests/BookmarkManagerTests",
      swiftSettings: [
        .defaultIsolation(MainActor.self), // set Default Actor Isolation
      ]
    ),
  ]
)
