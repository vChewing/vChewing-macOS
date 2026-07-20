// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "Shared_DarwinImpl",
  platforms: [
    .macOS(.v12),
  ],
  products: [
    .library(
      name: "Shared_DarwinImpl",
      targets: ["Shared_DarwinImpl"]
    ),
  ],
  dependencies: [
    .package(path: "../vChewing_OSFrameworkImpl"),
    .package(path: "../vChewing_Shared"),
    .package(path: "../vChewing_IMKUtils"),
  ],
  targets: [
    .target(
      name: "ObjCUtils",
      cSettings: [
        .unsafeFlags(["-fno-objc-arc"]),
      ]
    ),
    .target(
      name: "Shared_DarwinImpl",
      dependencies: [
        "ObjCUtils",
        .product(name: "OSFrameworkImpl", package: "vChewing_OSFrameworkImpl"),
        .product(name: "Shared", package: "vChewing_Shared"),
        .product(name: "IMKUtils", package: "vChewing_IMKUtils"),
      ],
      swiftSettings: [
        .defaultIsolation(MainActor.self), // set Default Actor Isolation
      ]
    ),
    .testTarget(
      name: "Shared_DarwinImplTests",
      dependencies: [
        "Shared_DarwinImpl",
        .product(name: "OSFrameworkImpl", package: "vChewing_OSFrameworkImpl"),
        .product(name: "Shared", package: "vChewing_Shared"),
        .product(name: "IMKUtils", package: "vChewing_IMKUtils"),
      ],
      swiftSettings: [
        .defaultIsolation(MainActor.self), // set Default Actor Isolation
      ]
    ),
  ]
)
