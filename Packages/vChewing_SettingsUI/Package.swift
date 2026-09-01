// swift-tools-version: 6.2
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
    .package(path: "../vChewing_Shared"),
    .package(path: "../vChewing_Shared_DarwinImpl"),
    .package(path: "../vChewing_SwiftExtension"),
    .package(path: "../vChewing_OSFrameworkImpl"),
    .package(path: "../vChewing_IMKUtils"),
    .package(path: "../vChewing_LangModelAssembly"),
    .package(path: "../Jad_BookmarkManager"),
  ],
  targets: [
    .target(
      name: "SettingsUI",
      dependencies: [
        .product(name: "Shared", package: "vChewing_Shared"),
        .product(name: "Shared_DarwinImpl", package: "vChewing_Shared_DarwinImpl"),
        .product(name: "SwiftExtension", package: "vChewing_SwiftExtension"),
        .product(name: "OSFrameworkImpl", package: "vChewing_OSFrameworkImpl"),
        .product(name: "IMKUtils", package: "vChewing_IMKUtils"),
        .product(name: "LangModelAssembly", package: "vChewing_LangModelAssembly"),
        .product(name: "BookmarkManager", package: "Jad_BookmarkManager"),
      ],
      swiftSettings: [
        .defaultIsolation(MainActor.self), // set Default Actor Isolation
      ]
    ),
  ]
)
