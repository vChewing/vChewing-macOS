// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "OSNeutralAssembly",
  platforms: [
    .macOS(.v12),
  ],
  products: [
    .library(
      name: "OSNeutralAssembly",
      targets: ["OSNeutralAssembly"]
    ),
  ],
  dependencies: [
    .package(path: "../vChewing_BPMFVS"),
    .package(path: "../vChewing_BrailleSputnik"),
    .package(path: "../vChewing_LexiconAssembly"),
    .package(path: "../vChewing_Homa"),
    .package(path: "../vChewing_Shared"),
    .package(path: "../vChewing_SwiftExtension"),
    .package(path: "../vChewing_Tekkon"),
  ],
  targets: [
    // Targets are the basic building blocks of a package, defining a module or a test suite.
    // Targets can depend on other targets in this package and products from dependencies.
    .target(
      name: "OSNeutralAssembly",
      dependencies: [
        .product(name: "BPMFVS", package: "vChewing_BPMFVS"),
        .product(name: "BrailleSputnik", package: "vChewing_BrailleSputnik"),
        .product(name: "LexiconAssembly", package: "vChewing_LexiconAssembly"),
        .product(name: "Homa", package: "vChewing_Homa"),
        .product(name: "Shared", package: "vChewing_Shared"),
        .product(name: "SwiftExtension", package: "vChewing_SwiftExtension"),
        .product(name: "Tekkon", package: "vChewing_Tekkon"),
      ],
      swiftSettings: [
        .defaultIsolation(MainActor.self), // set Default Actor Isolation
      ],
      linkerSettings: [
        .linkedLibrary("iconv", .when(platforms: [.macOS])),
      ]
    ),
    .testTarget(
      name: "OSNeutralAssemblyTests",
      dependencies: [
        "OSNeutralAssembly",
        .product(name: "LexiconAssembly", package: "vChewing_LexiconAssembly"),
        .product(name: "LXAssemblyMaterials4Tests", package: "vChewing_LexiconAssembly"),
        .product(name: "Homa", package: "vChewing_Homa"),
        .product(name: "HomaSharedTestComponents", package: "vChewing_Homa"),
        .product(name: "Shared", package: "vChewing_Shared"),
        .product(name: "Tekkon", package: "vChewing_Tekkon"),
      ],
      swiftSettings: [
        .defaultIsolation(MainActor.self), // set Default Actor Isolation
      ],
      linkerSettings: [
        .linkedLibrary("iconv", .when(platforms: [.macOS])),
      ]
    ),
  ]
)
