// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "IMKUtils",
  platforms: [
    .macOS(.v11),
  ],
  products: [
    .library(
      name: "IMKUtils",
      targets: ["IMKUtils"]
    ),
    .library(
      name: "IMKSwift",
      targets: ["IMKSwift"]
    ),
  ],
  dependencies: [
    .package(path: "../vChewing_SwiftExtension"),
  ],
  targets: [
    .target(
      name: "IMKSwift",
      dependencies: [
        "IMKSwiftModernHeaders",
      ],
      resources: [],
      swiftSettings: [
        .defaultIsolation(MainActor.self), // set Default Actor Isolation
      ]
    ),
    .target(
      name: "IMKSwiftModernHeaders",
      resources: []
    ),
    .target(
      name: "IMKUtils",
      dependencies: [
        "IMKSwift",
        .product(name: "SwiftExtension", package: "vChewing_SwiftExtension"),
      ],
      swiftSettings: [
        .defaultIsolation(MainActor.self), // set Default Actor Isolation
      ]
    ),
  ]
)
