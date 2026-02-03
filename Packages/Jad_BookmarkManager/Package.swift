// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "BookmarkManager",
  platforms: [
    .macOS(.v10_13),
  ],
  products: [
    .library(
      name: "BookmarkManager",
      targets: ["BookmarkManager"]
    ),
  ],
  dependencies: [
    .package(path: "../vChewing_SwiftExtension"),
  ],
  targets: [
    .target(
      name: "BookmarkManager",
      dependencies: [
        .product(name: "SwiftExtension", package: "vChewing_SwiftExtension"),
      ],
      swiftSettings: [
        .defaultIsolation(MainActor.self), // set Default Actor Isolation
      ]
    ),
    .testTarget(
      name: "BookmarkManagerTests",
      dependencies: [
        "BookmarkManager",
        .product(name: "SwiftExtension", package: "vChewing_SwiftExtension"),
      ],
      path: "Tests/BookmarkManagerTests",
      swiftSettings: [
        .defaultIsolation(MainActor.self), // set Default Actor Isolation
      ]
    ),
  ]
)
