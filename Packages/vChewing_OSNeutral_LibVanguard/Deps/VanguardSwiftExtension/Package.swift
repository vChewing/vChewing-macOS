// swift-tools-version: 6.2
import PackageDescription

// SwiftPM 無法把 `#if` 寫進陣列字面量，故以頂層宣告分流。
//
// - Darwin：本模組以 dynamic product 出貨。如此一來，聚合體（`libVanguard.dylib`）對它是
//   **動態相倚**而非靜態內嵌，故每個行程內本模組恰有一份 image；App-based installer 亦只需
//   帶這一顆小庫，不必連帶吃下整條打字閉包。
// - 其餘平台：維持 static（聚合體照舊把它內嵌進唯一那顆 `Vanguard` 動態庫），不產生第二顆
//   動態庫，既有跨平台產物結構不變。
//
// 註一：SwiftPM 對本地路徑相依的 package identity **取自目錄名**，故各消費端宣告的是
// `package: "vChewing_VanguardSwiftExtension"`，與本 manifest 的 `name:` 無關。
// 註二：**產品名與模組名刻意不同**——產品叫 `VanguardSwiftExtension`（與本套件同名），
// 而模組仍叫 `SwiftExtension`，故全倉一律 `import SwiftExtension`。SwiftPM 不要求兩者同名。
#if canImport(Darwin)
  let moduleLibraryType: Product.Library.LibraryType = .dynamic
#else
  let moduleLibraryType: Product.Library.LibraryType = .static
#endif

#if canImport(Darwin)
  let supportedPlatforms: [SupportedPlatform]? = [.macOS(.v12)]
#else
  let supportedPlatforms: [SupportedPlatform]? = nil
#endif

let package = Package(
  name: "VanguardSwiftExtension",
  platforms: supportedPlatforms,
  products: [
    .library(
      name: "VanguardSwiftExtension",
      type: moduleLibraryType,
      targets: ["SwiftExtension"]
    ),
  ],
  dependencies: [],
  targets: [
    .target(
      name: "SwiftExtension",
      dependencies: [],
      swiftSettings: [
        .defaultIsolation(MainActor.self), // set Default Actor Isolation
      ]
    ),
    .testTarget(
      name: "SwiftExtensionTests",
      dependencies: [
        "SwiftExtension",
      ],
      swiftSettings: [
        .defaultIsolation(MainActor.self), // set Default Actor Isolation
      ]
    ),
  ]
)
