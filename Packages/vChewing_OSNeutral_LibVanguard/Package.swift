// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

// 本套件是整個輸入核心依賴閉包的聚合包：原 `vChewing_BPMFVS`、`vChewing_BrailleSputnik`、
// `vChewing_Homa`、`vChewing_LexiconAssembly`、`vChewing_Shared`、`vChewing_SwiftExtension`、
// `vChewing_Tekkon` 諸套件的所有 target 都併於其中。
//
// 之所以必須是聚合體：SwiftPM 拒絕讓同一個 target 同時被「動態產品」與「靜態產品」取用
// （`This will result in duplication of library code.`），因此整個閉包只能以單一動態庫出貨。
//
// 套件名為 `LibVanguard`、出貨產品名為 `Vanguard`，故產物是 `libVanguard.dylib` 而非
// `libLibVanguard.dylib`。SwiftPM 的資源 bundle 名取「套件名 ＋ target 名」，是以各靶的資源
// bundle 實名為 `LibVanguard_<Target>.bundle`。
//
// 本 manifest 以 `@resultBuilder` 的 DSL 撰寫（見檔尾的 `ArrayBuilder`），
// 藉此得以在 builder body 內直接以 `#if` 施加 OS 專屬的編譯旗標與連結設定。
let package = Package(
  name: "LibVanguard",
  platforms: buildSupportedPlatform {
    #if canImport(Darwin)
      // `Observation` 等跨平台特性在 Apple 平台上會被系統版本所限，故最低支援版本須明列。
      SupportedPlatform.macOS(.v12)
    #endif
  },
  products: buildProducts {
    /// 唯一的出貨動態庫：整個依賴閉包的聚合體。
    Product.library(
      name: "Vanguard",
      type: .dynamic,
      targets: buildStrings {
        "LibVanguard"
        "Shared"
        "SwiftExtension"
        "ResourceLocator"
        "LexiconAssembly"
        "TrieKit"
        "Homa"
        "Tekkon"
        "BrailleSputnik"
        "BPMFVS"
      }
    )
    /// 測試素材靶另行出貨，刻意與出貨動態庫分開，避免將測試素材塞進出貨 dylib。
    Product.library(
      name: "LXAssemblyMaterials4Tests",
      type: .dynamic,
      targets: buildStrings {
        "LXAssemblyMaterials4Tests"
      }
    )
    Product.library(
      name: "HomaSharedTestComponents",
      type: .dynamic,
      targets: buildStrings {
        "HomaSharedTestComponents"
      }
    )
    Product.executable(
      name: "vChewingSharedCLI",
      targets: buildStrings {
        "vChewingSharedCLI"
      }
    )
  },
  dependencies: buildPackageDependencies {},
  targets: buildTargets {
    // MARK: - Library Targets

    Target.target(
      name: "SwiftExtension",
      swiftSettings: buildSwiftSettings {
        .defaultIsolation(MainActor.self) // set Default Actor Isolation
      }
    )
    Target.target(
      name: "ResourceLocator",
      dependencies: buildTargetDependencies {
        "SwiftExtension"
      }
    )
    Target.target(
      name: "TrieKit",
      dependencies: buildTargetDependencies {
        "SwiftExtension"
      }
    )
    Target.target(
      name: "Tekkon"
    )
    Target.target(
      name: "Homa"
    )
    Target.target(
      name: "BPMFVS",
      dependencies: buildTargetDependencies {
        "ResourceLocator"
      },
      resources: buildResources {
        Resource.process("Resources")
      },
      swiftSettings: buildSwiftSettings {
        .defaultIsolation(MainActor.self) // set Default Actor Isolation
      }
    )
    Target.target(
      name: "Shared",
      dependencies: buildTargetDependencies {
        "SwiftExtension"
      },
      swiftSettings: buildSwiftSettings {
        .defaultIsolation(MainActor.self) // set Default Actor Isolation
      }
    )
    Target.target(
      name: "BrailleSputnik",
      dependencies: buildTargetDependencies {
        "Shared"
        "Tekkon"
      },
      swiftSettings: buildSwiftSettings {
        .defaultIsolation(MainActor.self) // set Default Actor Isolation
      }
    )
    Target.target(
      name: "LexiconAssembly",
      dependencies: buildTargetDependencies {
        "TrieKit"
        "Homa"
        "Shared"
        "SwiftExtension"
      },
      swiftSettings: buildSwiftSettings {
        .defaultIsolation(MainActor.self) // set Default Actor Isolation
      }
    )
    Target.target(
      name: "LibVanguard",
      dependencies: buildTargetDependencies {
        "BPMFVS"
        "BrailleSputnik"
        "LexiconAssembly"
        "Homa"
        "ResourceLocator"
        "Shared"
        "SwiftExtension"
        "Tekkon"
      },
      swiftSettings: buildSwiftSettings {
        .defaultIsolation(MainActor.self) // set Default Actor Isolation
      },
      linkerSettings: buildLinkerSettings {
        LinkerSetting.linkedLibrary("iconv", .when(platforms: [.macOS]))
      }
    )

    // MARK: - Test Support Targets

    // 測試素材靶：原始佈局位於 `Tests/`，故保留顯式 `path`。
    Target.target(
      name: "HomaSharedTestComponents",
      dependencies: buildTargetDependencies {
        "Homa"
      },
      path: "Tests/HomaSharedTestComponents"
    )
    Target.target(
      name: "LXAssemblyMaterials4Tests",
      resources: buildResources {
        Resource.process("Resources")
      }
    )

    // MARK: - Executable Target

    Target.executableTarget(
      name: "vChewingSharedCLI",
      dependencies: buildTargetDependencies {
        "Shared"
      },
      swiftSettings: buildSwiftSettings {
        .defaultIsolation(MainActor.self) // set Default Actor Isolation
      }
    )

    // MARK: - Test Targets

    Target.testTarget(
      name: "BPMFVSTests",
      dependencies: buildTargetDependencies {
        "BPMFVS"
      },
      swiftSettings: buildSwiftSettings {
        .defaultIsolation(MainActor.self) // set Default Actor Isolation
      }
    )
    Target.testTarget(
      name: "BrailleSputnikTests",
      dependencies: buildTargetDependencies {
        "BrailleSputnik"
      },
      swiftSettings: buildSwiftSettings {
        .defaultIsolation(MainActor.self) // set Default Actor Isolation
      }
    )
    Target.testTarget(
      name: "HomaTests",
      dependencies: buildTargetDependencies {
        "Homa"
        "HomaSharedTestComponents"
      }
    )
    Target.testTarget(
      name: "TekkonTests",
      dependencies: buildTargetDependencies {
        "Tekkon"
      }
    )
    Target.testTarget(
      name: "SharedTests",
      dependencies: buildTargetDependencies {
        "Shared"
      },
      swiftSettings: buildSwiftSettings {
        .defaultIsolation(MainActor.self) // set Default Actor Isolation
      }
    )
    Target.testTarget(
      name: "SwiftExtensionTests",
      dependencies: buildTargetDependencies {
        "SwiftExtension"
      },
      swiftSettings: buildSwiftSettings {
        .defaultIsolation(MainActor.self) // set Default Actor Isolation
      }
    )
    Target.testTarget(
      name: "ResourceLocatorTests",
      dependencies: buildTargetDependencies {
        "ResourceLocator"
      },
      resources: buildResources {
        Resource.process("Resources")
      }
    )
    Target.testTarget(
      name: "TrieKitTests",
      dependencies: buildTargetDependencies {
        "TrieKit"
        "LXAssemblyMaterials4Tests"
        "Homa"
        "Tekkon"
      },
      swiftSettings: buildSwiftSettings {
        .defaultIsolation(MainActor.self) // set Default Actor Isolation
      }
    )
    Target.testTarget(
      name: "LexiconAssemblyTests",
      dependencies: buildTargetDependencies {
        "LexiconAssembly"
        "LXAssemblyMaterials4Tests"
        "Homa"
        "HomaSharedTestComponents"
        "Tekkon"
      },
      swiftSettings: buildSwiftSettings {
        .defaultIsolation(MainActor.self) // set Default Actor Isolation
      }
    )
    Target.testTarget(
      name: "LibVanguardTests",
      dependencies: buildTargetDependencies {
        "LibVanguard"
        "LexiconAssembly"
        "LXAssemblyMaterials4Tests"
        "Homa"
        "HomaSharedTestComponents"
        "ResourceLocator"
        "Shared"
        "Tekkon"
      },
      swiftSettings: buildSwiftSettings {
        .defaultIsolation(MainActor.self) // set Default Actor Isolation
      },
      linkerSettings: buildLinkerSettings {
        LinkerSetting.linkedLibrary("iconv", .when(platforms: [.macOS]))
      }
    )
  },
  swiftLanguageModes: [.v6]
)

// MARK: - ArrayBuilder

@resultBuilder
enum ArrayBuilder<Element> {
  static func buildEither(first elements: [Element]) -> [Element] {
    elements
  }

  static func buildEither(second elements: [Element]) -> [Element] {
    elements
  }

  static func buildOptional(_ elements: [Element]?) -> [Element] {
    elements ?? []
  }

  static func buildExpression(_ expression: Element) -> [Element] {
    [expression]
  }

  static func buildExpression(_: ()) -> [Element] {
    []
  }

  static func buildBlock(_ elements: [Element]...) -> [Element] {
    elements.flatMap { $0 }
  }

  static func buildArray(_ elements: [[Element]]) -> [Element] {
    Array(elements.joined())
  }
}

func buildTargets(@ArrayBuilder<Target?> targets: () -> [Target?]) -> [Target] {
  targets().compactMap { $0 }
}

func buildStrings(@ArrayBuilder<String?> strings: () -> [String?]) -> [String] {
  strings().compactMap { $0 }
}

func buildProducts(@ArrayBuilder<Product?> products: () -> [Product?]) -> [Product] {
  products().compactMap { $0 }
}

func buildTargetDependencies(
  @ArrayBuilder<Target.Dependency?> dependencies: () -> [Target.Dependency?]
)
  -> [Target.Dependency] {
  dependencies().compactMap { $0 }
}

func buildSwiftSettings(
  @ArrayBuilder<SwiftSetting?> settings: () -> [SwiftSetting?]
)
  -> [SwiftSetting] {
  settings().compactMap { $0 }
}

func buildLinkerSettings(
  @ArrayBuilder<LinkerSetting?> settings: () -> [LinkerSetting?]
)
  -> [LinkerSetting] {
  settings().compactMap { $0 }
}

func buildResources(
  @ArrayBuilder<Resource?> resources: () -> [Resource?]
)
  -> [Resource] {
  resources().compactMap { $0 }
}

func buildPackageDependencies(
  @ArrayBuilder<Package.Dependency?> dependencies: () -> [Package.Dependency?]
)
  -> [Package.Dependency] {
  dependencies().compactMap { $0 }
}

func buildSupportedPlatform(
  @ArrayBuilder<SupportedPlatform?> dependencies: () -> [SupportedPlatform?]
)
  -> [SupportedPlatform]? {
  let result = dependencies().compactMap { $0 }
  return result.isEmpty ? nil : result
}
