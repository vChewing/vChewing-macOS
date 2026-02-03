// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "PopupCompositionBuffer",
  platforms: [
    .macOS(.v11),
  ],
  products: [
    .library(
      name: "PopupCompositionBuffer",
      targets: ["PopupCompositionBuffer"]
    ),
  ],
  dependencies: [
    .package(path: "../vChewing_Shared_DarwinImpl"),
  ],
  targets: [
    .target(
      name: "PopupCompositionBuffer",
      dependencies: [
        .product(name: "Shared_DarwinImpl", package: "vChewing_Shared_DarwinImpl"),
      ],
      swiftSettings: [
        .defaultIsolation(MainActor.self), // set Default Actor Isolation
      ]
    ),
  ]
)
