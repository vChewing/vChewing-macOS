// swift-tools-version: 6.2
import PackageDescription

// 本套件是 `OSNeutralAssembly` 依賴閉包的聚合包：原 `vChewing_BPMFVS`、
// `vChewing_BrailleSputnik`、`vChewing_Homa`、`vChewing_LexiconAssembly`、
// `vChewing_Shared`、`vChewing_SwiftExtension`、`vChewing_Tekkon` 的所有 target 都併入此處。
//
// 之所以聚合：SwiftPM 拒絕讓同一個 target 同時被「動態產品」與「靜態產品」取用
// （`This will result in duplication of library code.`），因此整個閉包只能以單一動態庫出貨。
// 各模組原有的授權檔保存在 `LICENSES/` 之下。
let package = Package(
  name: "OSNeutralAssembly",
  platforms: [
    .macOS(.v12),
  ],
  products: [
    /// 唯一的出貨動態庫：整個依賴閉包的聚合體。
    .library(
      name: "OSNeutralAssembly",
      type: .dynamic,
      targets: [
        "OSNeutralAssembly",
        "Shared",
        "SwiftExtension",
        "ResourceLocator",
        "LexiconAssembly",
        "TrieKit",
        "Homa",
        "Tekkon",
        "BrailleSputnik",
        "BPMFVS",
      ]
    ),
    /// 測試素材靶另行出貨，刻意與出貨動態庫分開，避免將測試素材塞進出貨 dylib。
    .library(
      name: "LXAssemblyMaterials4Tests",
      type: .dynamic,
      targets: ["LXAssemblyMaterials4Tests"]
    ),
    .library(
      name: "HomaSharedTestComponents",
      type: .dynamic,
      targets: ["HomaSharedTestComponents"]
    ),
    .executable(
      name: "vChewingSharedCLI",
      targets: ["vChewingSharedCLI"]
    ),
  ],
  dependencies: [],
  targets: [
    // MARK: - Library Targets

    .target(
      name: "SwiftExtension",
      dependencies: [],
      swiftSettings: [
        .defaultIsolation(MainActor.self), // set Default Actor Isolation
      ]
    ),
    .target(
      name: "ResourceLocator",
      dependencies: ["SwiftExtension"]
    ),
    .target(
      name: "TrieKit",
      dependencies: ["SwiftExtension"]
    ),
    .target(
      name: "Tekkon",
      dependencies: []
    ),
    .target(
      name: "Homa",
      dependencies: []
    ),
    .target(
      name: "BPMFVS",
      dependencies: ["ResourceLocator"],
      resources: [
        .process("Resources"),
      ],
      swiftSettings: [
        .defaultIsolation(MainActor.self), // set Default Actor Isolation
      ]
    ),
    .target(
      name: "Shared",
      dependencies: ["SwiftExtension"],
      swiftSettings: [
        .defaultIsolation(MainActor.self), // set Default Actor Isolation
      ]
    ),
    .target(
      name: "BrailleSputnik",
      dependencies: ["Shared", "Tekkon"],
      swiftSettings: [
        .defaultIsolation(MainActor.self), // set Default Actor Isolation
      ]
    ),
    .target(
      name: "LexiconAssembly",
      dependencies: ["TrieKit", "Homa", "Shared", "SwiftExtension"],
      swiftSettings: [
        .defaultIsolation(MainActor.self), // set Default Actor Isolation
      ]
    ),
    .target(
      name: "OSNeutralAssembly",
      dependencies: [
        "BPMFVS",
        "BrailleSputnik",
        "LexiconAssembly",
        "Homa",
        "ResourceLocator",
        "Shared",
        "SwiftExtension",
        "Tekkon",
      ],
      swiftSettings: [
        .defaultIsolation(MainActor.self), // set Default Actor Isolation
      ],
      linkerSettings: [
        .linkedLibrary("iconv", .when(platforms: [.macOS])),
      ]
    ),

    // MARK: - Test Support Targets

    // 測試素材靶：原始佈局位於 `Tests/`，故保留顯式 `path`。
    .target(
      name: "HomaSharedTestComponents",
      dependencies: ["Homa"],
      path: "Tests/HomaSharedTestComponents"
    ),
    .target(
      name: "LXAssemblyMaterials4Tests",
      resources: [
        .process("Resources"),
      ]
    ),

    // MARK: - Executable Target

    .executableTarget(
      name: "vChewingSharedCLI",
      dependencies: ["Shared"],
      swiftSettings: [
        .defaultIsolation(MainActor.self), // set Default Actor Isolation
      ]
    ),

    // MARK: - Test Targets

    .testTarget(
      name: "BPMFVSTests",
      dependencies: ["BPMFVS"],
      swiftSettings: [
        .defaultIsolation(MainActor.self), // set Default Actor Isolation
      ]
    ),
    .testTarget(
      name: "BrailleSputnikTests",
      dependencies: ["BrailleSputnik"],
      swiftSettings: [
        .defaultIsolation(MainActor.self), // set Default Actor Isolation
      ]
    ),
    .testTarget(
      name: "HomaTests",
      dependencies: [
        "Homa",
        "HomaSharedTestComponents",
      ]
    ),
    .testTarget(
      name: "TekkonTests",
      dependencies: ["Tekkon"]
    ),
    .testTarget(
      name: "SharedTests",
      dependencies: ["Shared"],
      swiftSettings: [
        .defaultIsolation(MainActor.self), // set Default Actor Isolation
      ]
    ),
    .testTarget(
      name: "SwiftExtensionTests",
      dependencies: ["SwiftExtension"],
      swiftSettings: [
        .defaultIsolation(MainActor.self), // set Default Actor Isolation
      ]
    ),
    .testTarget(
      name: "ResourceLocatorTests",
      dependencies: ["ResourceLocator"],
      resources: [
        .process("Resources"),
      ]
    ),
    .testTarget(
      name: "TrieKitTests",
      dependencies: ["TrieKit", "LXAssemblyMaterials4Tests", "Homa", "Tekkon"],
      swiftSettings: [
        .defaultIsolation(MainActor.self), // set Default Actor Isolation
      ]
    ),
    .testTarget(
      name: "LexiconAssemblyTests",
      dependencies: [
        "LexiconAssembly",
        "LXAssemblyMaterials4Tests",
        "Homa",
        "HomaSharedTestComponents",
        "Tekkon",
      ],
      swiftSettings: [
        .defaultIsolation(MainActor.self), // set Default Actor Isolation
      ]
    ),
    .testTarget(
      name: "OSNeutralAssemblyTests",
      dependencies: [
        "OSNeutralAssembly",
        "LexiconAssembly",
        "LXAssemblyMaterials4Tests",
        "Homa",
        "HomaSharedTestComponents",
        "ResourceLocator",
        "Shared",
        "Tekkon",
      ],
      swiftSettings: [
        .defaultIsolation(MainActor.self), // set Default Actor Isolation
      ],
      linkerSettings: [
        .linkedLibrary("iconv", .when(platforms: [.macOS])),
      ]
    ),
  ],
  swiftLanguageModes: [.v6]
)
