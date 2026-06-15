// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "Shared",
  platforms: [
    .macOS(.v12),
  ],
  products: [
    .library(
      name: "Shared",
      targets: ["Shared"]
    ),
    .executable(
      name: "vChewingSharedCLI",
      targets: ["vChewingSharedCLI"]
    ),
  ],
  dependencies: [
    .package(path: "../vChewing_SwiftExtension"),
  ],
  targets: [
    .target(
      name: "Shared",
      dependencies: [
        .product(name: "SwiftExtension", package: "vChewing_SwiftExtension"),
      ],
      swiftSettings: [
        .defaultIsolation(MainActor.self), // set Default Actor Isolation
      ]
    ),
    .testTarget(
      name: "SharedTests",
      dependencies: ["Shared"],
      swiftSettings: [
        .defaultIsolation(MainActor.self), // set Default Actor Isolation
      ]
    ),
    .executableTarget(
      name: "vChewingSharedCLI",
      dependencies: ["Shared"],
      swiftSettings: [
        .defaultIsolation(MainActor.self), // set Default Actor Isolation
      ]
    ),
  ]
)
