// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "OSFrameworkImpl",
  platforms: [
    .macOS(.v12),
  ],
  products: [
    .library(
      name: "OSFrameworkImpl",
      targets: ["OSFrameworkImpl"]
    ),
  ],
  dependencies: [
    .package(path: "../vChewing_OSNeutral_LibVanguard"),
  ],
  targets: [
    .target(
      name: "OSFrameworkImplViaObjC",
      cSettings: [
        .unsafeFlags(["-fno-objc-arc"]),
      ]
    ),
    .target(
      name: "OSFrameworkImpl",
      dependencies: [
        "OSFrameworkImplViaObjC",
        .product(name: "Vanguard", package: "vChewing_OSNeutral_LibVanguard"),
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
