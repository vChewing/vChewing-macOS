// swift-tools-version: 5.10
import PackageDescription

// 本檔是 `Package.swift`（tools 6.4）的 **Swift 5.10 對位版**：同一份 `Sources/` 於 Swift 5.10 toolchain 下
// 以本 manifest 建置，於 Swift 6.4 以上以 `Package.swift` 建置。SwiftPM 之版本擇定規則為「於
// `Package*.swift` 全集中，取**檔內宣告**的 tools version 不高於 toolchain 版本者之**最高者**；同版時
// `Package.swift` 勝出」——故 5.10 toolchain 恆取本檔、6.0／6.1／6.2／6.3 各由同目錄的封堵檔接下、
// 6.4 以上取 `Package.swift`。
//
// 與 `Package.swift` 的刻意差異：
//
// 1. **產物一律 static**。Swift 5.10 側的宿主是 macOS 10.9 的 legacy app，其 ARC 執行期由 libArcLite
//    提供，而 dylib 必須在建置期就專門摻進該靜態庫（不能像 app 那樣由宿主統一連結），故本側不出動態庫，
//    只出 `.a`、由宿主把所有 `.a` 連成單一二進位。
// 2. **`platforms` 填 `nil`**。PackageDescription 能宣告的 macOS 最低值只有 10.10，一旦宣告即被明文寫入
//    產物的 `LC_BUILD_VERSION`；本側索性不宣告平台限制，讓 SDK 之預設值說話。
// 3. **不含任何測試靶**（Unit Tests 不對 Swift 5.10 開放）：`Package.swift` 的
//    `MainAssembly4DarwinTests` 整段略去。
// 4. **不使用 6.x 才有的設定**：`.defaultIsolation(MainActor.self)` 與 `swiftLanguageModes` 皆為 tools 6.2
//    起才存在；本側語言模式即 5.10 toolchain 之預設（Swift 5），另以 `swiftLanguageVersions: [.v5]` 明示。
// 5. **不收遠端 lexicon 依賴、也不收其兩支 build plugin**（本側與 `Package.swift` 之刻意不對稱）：
//    `Package.swift` 收 `.package(url: "https://atomgit.com/vChewing/vChewing-VanguardLexicon.git",
//    exact: "4.8.0")` 與 `TextTemplateAssetInjectorPlugin`／`VanguardTextMapPlugin`，本側一概不收。
//
//    理由（2026-09-16 實測）：本側產物是靜態 `.a`，其宿主是 legacy app，詞庫另有來源，這兩支 buildTool
//    plugin 在本側沒有功能；而只要收下該依賴，5.10 側就無論如何過不了——先是 4.7.4 及以前 `CSQLite3`
//    帶 `.unsafeFlags(["-w"])`（5.10 SwiftPM 對非根套件的 unsafe flags 一律硬拒），4.8.0 雖已移除 SQLite，
//    卻又卡在平台下限：該套件兩份 manifest 都宣告 `platforms: [.macOS(.v10_15)]`（其 deploy 工具真的用到
//    concurrency，`AsyncThrowingStream`／`withTaskGroup`／`Actor` 等一律自 10.15 起算——把該宣告降到
//    10.13 會炸出 125 筆 availability 錯誤，其中 82 筆是 `concurrency is only available in macOS 10.15`），
//    而本側是 `platforms: nil`（SwiftPM 地板 10.13），解析期即報
//    `depends on the product 'VanguardTextMapPlugin' which requires macos 10.15`。
//
//    本側亦無法改用「宣告 `.macOS(.v10_15)`」來繞：SwiftPM 是**按各套件自身的 `platforms`** 決定其 target
//    的 deployment target，把本側抬到 10.15 並不會抬起 lexicon 自己的地板，那 125 筆錯誤照樣發生。
//    故此不對稱維持至 lexicon 願拆包（plugin 與資料庫分成兩套件）或把 deploy 工具改成非並發寫法為止。
//
// 環境配對與各項差異的機理見 vChewing-DevLogs/Research/Phase217_SOP.md §三／§四。

let package = Package(
  name: "MainAssembly4Darwin",
  platforms: nil,
  products: [
    .library(
      name: "MainAssembly4Darwin",
      type: .static,
      targets: ["MainAssembly4Darwin"]
    ),
  ],
  dependencies: [
    .package(path: "../vChewing_FolderMonitor"),
    .package(path: "../HangarRash_SwiftyCapsLockToggler"),
    .package(path: "../Jad_BookmarkManager"),
    .package(path: "../vChewing_ModifierKeyHitChecker"),
    .package(path: "../vChewing_CandidateWindow"),
    .package(path: "../vChewing_Hotenka"),
    .package(path: "../vChewing_IMKUtils"),
    .package(path: "../vChewing_OtherIMEDataReader"),
    .package(path: "../vChewing_NotifierUI"),
    .package(path: "../vChewing_PopupCompositionBuffer"),
    .package(path: "../vChewing_Shared_DarwinImpl"),
    .package(path: "../vChewing_SettingsUI"),
    .package(path: "../vChewing_OSNeutral_LibVanguard"),
    .package(path: "../vChewing_TooltipUI"),
    .package(path: "../vChewing_Uninstaller"),
    .package(path: "../vChewing_UpdateSputnik"),
  ],
  targets: [
    .target(
      name: "MainAssembly4Darwin",
      dependencies: [
        .product(name: "BookmarkManager", package: "Jad_BookmarkManager"),
        .product(name: "CandidateWindow", package: "vChewing_CandidateWindow"),
        .product(name: "FolderMonitor", package: "vChewing_FolderMonitor"),
        .product(name: "Hotenka", package: "vChewing_Hotenka"),
        .product(name: "IMKUtils", package: "vChewing_IMKUtils"),
        .product(name: "OtherIMEDataReader", package: "vChewing_OtherIMEDataReader"),
        .product(name: "NotifierUI", package: "vChewing_NotifierUI"),
        .product(name: "PopupCompositionBuffer", package: "vChewing_PopupCompositionBuffer"),
        .product(name: "Shared_DarwinImpl", package: "vChewing_Shared_DarwinImpl"),
        .product(name: "SettingsUI", package: "vChewing_SettingsUI"),
        .product(name: "ModifierKeyHitChecker", package: "vChewing_ModifierKeyHitChecker"),
        .product(name: "SwiftyCapsLockToggler", package: "HangarRash_SwiftyCapsLockToggler"),
        .product(name: "Vanguard", package: "vChewing_OSNeutral_LibVanguard"),
        .product(name: "TooltipUI", package: "vChewing_TooltipUI"),
        .product(name: "Uninstaller", package: "vChewing_Uninstaller"),
        .product(name: "UpdateSputnik", package: "vChewing_UpdateSputnik"),
      ],
      resources: [
        .process("Resources"),
      ]
    ),
  ],
  swiftLanguageVersions: [.v5]
)
