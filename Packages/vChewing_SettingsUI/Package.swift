// swift-tools-version: 6.4
import PackageDescription

let package = Package(
  name: "SettingsUI",
  platforms: [
    .macOS(.v12),
  ],
  products: [
    .library(
      name: "SettingsUI",
      targets: ["SettingsUI"]
    ),
  ],
  dependencies: [
    .package(path: "../vChewing_OSNeutral_LibVanguard"),
    .package(path: "../vChewing_Shared_DarwinImpl"),
    .package(path: "../vChewing_OSFrameworkImpl"),
    .package(path: "../vChewing_IMKUtils"),
    .package(path: "../Jad_BookmarkManager"),
  ],
  targets: [
    .target(
      name: "SettingsUI",
      dependencies: [
        .product(name: "Vanguard", package: "vChewing_OSNeutral_LibVanguard"),
        .product(name: "Shared_DarwinImpl", package: "vChewing_Shared_DarwinImpl"),
        .product(name: "OSFrameworkImpl", package: "vChewing_OSFrameworkImpl"),
        .product(name: "IMKUtils", package: "vChewing_IMKUtils"),
        .product(name: "BookmarkManager", package: "Jad_BookmarkManager"),
      ],
      swiftSettings: [
        .defaultIsolation(MainActor.self), // set Default Actor Isolation
      ]
    ),
    .testTarget(
      name: "SettingsUITests",
      dependencies: [
        "SettingsUI",
        .product(name: "Vanguard", package: "vChewing_OSNeutral_LibVanguard"),
      ],
      swiftSettings: [
        .defaultIsolation(MainActor.self), // set Default Actor Isolation
      ]
    ),
  ]
)
