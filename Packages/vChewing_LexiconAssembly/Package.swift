// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "LexiconAssembly",
  platforms: [
    .macOS(.v12),
  ],
  products: [
    .library(
      name: "LexiconAssembly",
      targets: ["LexiconAssembly"]
    ),
    .library(
      name: "LXAssemblyMaterials4Tests",
      targets: ["LXAssemblyMaterials4Tests"]
    ),
  ],
  dependencies: [
    .package(path: "../vChewing_Homa"),
    .package(path: "../vChewing_Shared"),
    .package(path: "../vChewing_SwiftExtension"),
    .package(path: "../vChewing_Tekkon"),
  ],
  targets: [
    .target(
      name: "TrieKit",
      dependencies: [
        .product(name: "SwiftExtension", package: "vChewing_SwiftExtension"),
      ]
    ),
    .target(
      name: "LXAssemblyMaterials4Tests",
      resources: [
        .process("Resources"),
      ]
    ),
    .target(
      name: "LexiconAssembly",
      dependencies: [
        "TrieKit",
        .product(name: "Homa", package: "vChewing_Homa"),
        .product(name: "Shared", package: "vChewing_Shared"),
        .product(name: "SwiftExtension", package: "vChewing_SwiftExtension"),
      ],
      swiftSettings: [
        .defaultIsolation(MainActor.self), // set Default Actor Isolation
      ]
    ),
    .testTarget(
      name: "TrieKitTests",
      dependencies: [
        "TrieKit",
        "LXAssemblyMaterials4Tests",
        .product(name: "Homa", package: "vChewing_Homa"),
        .product(name: "Tekkon", package: "vChewing_Tekkon"),
      ],
      swiftSettings: [
        .defaultIsolation(MainActor.self), // set Default Actor Isolation
      ]
    ),
    .testTarget(
      name: "LexiconAssemblyTests",
      dependencies: [
        "LexiconAssembly",
        "LXAssemblyMaterials4Tests",
        .product(name: "Homa", package: "vChewing_Homa"),
        .product(name: "HomaSharedTestComponents", package: "vChewing_Homa"),
        .product(name: "Tekkon", package: "vChewing_Tekkon"),
      ],
      swiftSettings: [
        .defaultIsolation(MainActor.self), // set Default Actor Isolation
      ]
    ),
  ]
)
