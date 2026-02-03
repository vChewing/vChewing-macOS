// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "SwiftExtension",
  products: [
    .library(
      name: "SwiftExtension",
      targets: ["SwiftExtension"]
    ),
  ],
  dependencies: [],
  targets: [
    .target(
      name: "SwiftExtension",
      dependencies: [],
      swiftSettings: [
        .defaultIsolation(MainActor.self), // set Default Actor Isolation
      ],
    ),
  ]
)
