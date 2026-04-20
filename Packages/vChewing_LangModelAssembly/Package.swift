// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "LangModelAssembly",
  products: [
    .library(
      name: "LangModelAssembly",
      targets: ["LangModelAssembly"]
    ),
    .library(
      name: "LMAssemblyMaterials4Tests",
      targets: ["LMAssemblyMaterials4Tests"]
    ),
  ],
  dependencies: [
    .package(path: "../RMJay_LineReader"),
    .package(path: "../vChewing_Homa"),
    .package(path: "../vChewing_Shared"),
    .package(path: "../vChewing_SwiftExtension"),
    .package(path: "../vChewing_Tekkon"),
  ],
  targets: [
    .target(name: "TrieKit"),
    .target(
      name: "LMAssemblyMaterials4Tests",
      resources: [
        .process("Resources"),
      ]
    ),
    .target(
      name: "LangModelAssembly",
      dependencies: [
        "LMAssemblyMaterials4Tests",
        "TrieKit",
        .product(name: "LineReader", package: "RMJay_LineReader"),
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
        "LMAssemblyMaterials4Tests",
        .product(name: "Homa", package: "vChewing_Homa"),
        .product(name: "Tekkon", package: "vChewing_Tekkon"),
      ],
      swiftSettings: [
        .defaultIsolation(MainActor.self), // set Default Actor Isolation
      ]
    ),
    .testTarget(
      name: "LangModelAssemblyTests",
      dependencies: [
        "LangModelAssembly",
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
