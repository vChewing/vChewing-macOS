// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "OSFrameworkImpl",
  platforms: [
    .macOS(.v11),
  ],
  products: [
    .library(
      name: "OSFrameworkImpl",
      targets: ["OSFrameworkImpl"]
    ),
  ],
  dependencies: [
    .package(path: "../vChewing_SwiftExtension"),
  ],
  targets: [
    .target(
      name: "OSFrameworkImpl",
      dependencies: [
        .product(name: "SwiftExtension", package: "vChewing_SwiftExtension"),
      ],
      swiftSettings: [
        .defaultIsolation(MainActor.self), // set Default Actor Isolation
      ]
    ),
    .testTarget(
      name: "OSFrameworkImplTests",
      dependencies: ["OSFrameworkImpl"],
      swiftSettings: [
        .defaultIsolation(MainActor.self), // set Default Actor Isolation
      ]
    ),
  ]
)
