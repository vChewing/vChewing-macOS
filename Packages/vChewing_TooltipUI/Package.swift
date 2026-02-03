// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "TooltipUI",
  platforms: [
    .macOS(.v11),
  ],
  products: [
    .library(
      name: "TooltipUI",
      targets: ["TooltipUI"]
    ),
  ],
  dependencies: [
    .package(path: "../vChewing_Shared_DarwinImpl"),
  ],
  targets: [
    .target(
      name: "TooltipUI",
      dependencies: [
        .product(name: "Shared_DarwinImpl", package: "vChewing_Shared_DarwinImpl"),
      ],
      swiftSettings: [
        .defaultIsolation(MainActor.self), // set Default Actor Isolation
      ]
    ),
  ]
)
