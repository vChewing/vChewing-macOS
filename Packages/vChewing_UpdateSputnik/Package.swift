// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "UpdateSputnik",
  platforms: [
    .macOS(.v11),
  ],
  products: [
    .library(
      name: "UpdateSputnik",
      targets: ["UpdateSputnik"]
    ),
  ],
  dependencies: [
    .package(path: "../vChewing_SwiftExtension"),
  ],
  targets: [
    .target(
      name: "UpdateSputnik",
      dependencies: [
        .product(name: "SwiftExtension", package: "vChewing_SwiftExtension"),
      ],
      swiftSettings: [
        .defaultIsolation(MainActor.self), // set Default Actor Isolation
      ]
    ),
  ]
)
