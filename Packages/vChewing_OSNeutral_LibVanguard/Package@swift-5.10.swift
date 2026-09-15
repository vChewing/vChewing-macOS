// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

// 本檔是 `Package.swift`（tools 6.2）的 **Swift 5.10 對位版**：同一份 `Sources/` 於 Swift 5.10
// toolchain 下以本 manifest 建置，於 Swift 6.2 以上以 `Package.swift` 建置。
//
// SwiftPM 之版本擇定規則（實測）：於 `Package*.swift` 全集中，取「**檔內宣告**的 tools version
// 不高於 toolchain 版本」者之**最高者**；同版時 `Package.swift` 勝出；宣告值高於 toolchain 者單純
// 落選（不報錯）。故 5.10 toolchain 恆取本檔、6.2 以上恆取 `Package.swift`、6.0／6.1 兩版則由
// `Package@swift-6.0.swift` 與 `Package@swift-6.1.swift` 這兩份封堵檔接下。
//
// 與 `Package.swift` 的刻意差異：
//
// 1. **產物一律 static**。Swift 5.10 側的宿主是 macOS 10.9 的 legacy app：ARC 執行期由 libArcLite
//    提供，而 dylib 必須在建置期就專門摻進該靜態庫（不能像 app 那樣由宿主統一連結），故本側不產出
//    任何動態庫——`Vanguard` 改出 `.a`，`SwiftExtension` 亦於其自身 manifest 同步改為 static，
//    由宿主把所有 `.a` 連成單一二進位。
// 2. **`platforms` 填 `nil`**。PackageDescription 能宣告的 macOS 最低值只有 10.10，一旦宣告即被
//    明文寫入產物的 `LC_BUILD_VERSION`；本側索性不宣告任何平台限制，讓 SDK 之預設值說話。
// 3. **不含任何測試靶**。單元測試僅由 Swift 6.2 以上 toolchain 負責（Swift Testing 等設施本身即
//    非 5.10 所及），故 `Tests/` 全目錄於本側不進 manifest；僅為測試供料的 `LXAssemblyMaterials4Tests`
//    與 `HomaSharedTestComponents` 兩靶及其產品亦一併不宣告。
// 4. **不使用 6.x 才有的設定**：`.defaultIsolation(MainActor.self)` 與 `swiftLanguageModes` 皆為
//    tools 6.2 起才存在；本側語言模式即 5.10 toolchain 之預設（Swift 5），故僅以
//    `swiftLanguageVersions: [.v5]` 明示之。
// 5. **不需要 `Package.swift` 那套 `@resultBuilder` DSL**。該 DSL 是為了讓 `#if` 能寫進 builder
//    body；本側的產品型別與平台清單皆為無條件值，用不上條件編譯，直接寫陣列字面量即可。
//
// 6. **不收 `vChewingSharedCLI`**。該靶是早年用來輔助提取 `UserDef` localization key 的一次性枴杖，
//    非出貨路徑；且它是本側唯一的**可執行檔**——唯有可執行檔會被壓上 `LC_BUILD_VERSION`／
//    `LC_VERSION_MIN_MACOSX` 的 minOS（本側因 5.10 工具鏈地板而必為 10.13），靜態庫則完全不帶
//    load command。不收它，既省事也少一處與 macOS 10.9 目標相牴觸的產物。
//
// 註：套件名為 `LibVanguard`、出貨產品名為 `Vanguard`，故靜態產物是 `libVanguard.a`；SwiftPM 的
// 資源 bundle 名取「套件名 ＋ 靶名」，故各靶的資源 bundle 實名仍為 `LibVanguard_<Target>.bundle`。

let package = Package(
  name: "LibVanguard",
  platforms: nil,
  products: [
    /// 唯一的出貨靜態庫：整個依賴閉包的聚合體。
    .library(
      name: "Vanguard",
      type: .static,
      targets: [
        "LibVanguard",
        "Shared",
        "ResourceLocator",
        "LexiconAssembly",
        "TrieKit",
        "Homa",
        "Tekkon",
        "BrailleSputnik",
        "BPMFVS",
      ]
    ),
  ],
  dependencies: [
    .package(path: "Deps/VanguardSwiftExtension"),
  ],
  targets: [
    // MARK: - Library Targets

    .target(
      name: "ResourceLocator",
      dependencies: [
        .product(
          name: "VanguardSwiftExtension", package: "VanguardSwiftExtension"
        ),
      ]
    ),
    .target(
      name: "TrieKit",
      dependencies: [
        .product(
          name: "VanguardSwiftExtension", package: "VanguardSwiftExtension"
        ),
      ]
    ),
    .target(
      name: "Tekkon"
    ),
    .target(
      name: "Homa"
    ),
    .target(
      name: "BPMFVS",
      dependencies: [
        "ResourceLocator",
      ],
      resources: [
        .process("Resources"),
      ]
    ),
    .target(
      name: "Shared",
      dependencies: [
        .product(
          name: "VanguardSwiftExtension", package: "VanguardSwiftExtension"
        ),
      ]
    ),
    .target(
      name: "BrailleSputnik",
      dependencies: [
        "Shared",
        "Tekkon",
      ]
    ),
    .target(
      name: "LexiconAssembly",
      dependencies: [
        "TrieKit",
        "Homa",
        "Shared",
        .product(
          name: "VanguardSwiftExtension", package: "VanguardSwiftExtension"
        ),
      ]
    ),
    .target(
      name: "LibVanguard",
      dependencies: [
        "BPMFVS",
        "BrailleSputnik",
        "LexiconAssembly",
        "Homa",
        "ResourceLocator",
        "Shared",
        .product(
          name: "VanguardSwiftExtension", package: "VanguardSwiftExtension"
        ),
        "Tekkon",
      ],
      linkerSettings: [
        LinkerSetting.linkedLibrary("iconv", .when(platforms: [.macOS])),
      ]
    ),
  ],
  swiftLanguageVersions: [.v5]
)
