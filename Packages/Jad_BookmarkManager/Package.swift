// swift-tools-version: 6.4
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
    .package(path: "../vChewing_OSNeutral_LibVanguard"),
  ],
  targets: [
    .target(
      name: "BookmarkManager",
      dependencies: [
        .product(name: "Vanguard", package: "vChewing_OSNeutral_LibVanguard"),
      ],
      swiftSettings: [
        .defaultIsolation(MainActor.self), // set Default Actor Isolation
      ]
    ),
    .testTarget(
      name: "BookmarkManagerTests",
      dependencies: [
        "BookmarkManager",
        .product(name: "Vanguard", package: "vChewing_OSNeutral_LibVanguard"),
      ],
      path: "Tests/BookmarkManagerTests",
      swiftSettings: [
        .defaultIsolation(MainActor.self), // set Default Actor Isolation
      ]
    ),
  ]
)
