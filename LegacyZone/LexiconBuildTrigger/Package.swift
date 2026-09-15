// swift-tools-version: 5.10
import PackageDescription

// 本套件別無用途：只為了讓遠端語料庫套件的 build tool plug-ins 有宿主可依附，藉此產出原廠辭典與
// 使用者片語範本，供稍後組裝 legacy `.app` 時取用。它刻意用 5.10 工具鏈建置（host-only、不分架構）。
//
// `platforms` 必須明示 `.macOS(.v10_15)`：語料庫套件自己就是這個地板，而 SwiftPM 5.10 對未宣告
// `platforms` 的套件一律回退到 10.13，屆時 resolver 會以
// `depends on the product 'VanguardTextMapPlugin' which requires macos 10.15` 拒絕整個依賴。
// 這正是倉根 `Package@swift-5.10.swift`（`platforms: nil`）不得不割捨該依賴的原因；本套件宣告了
// 10.15 地板，故同一條依賴在此可解。
let package = Package(
  name: "LexiconBuildTrigger",
  platforms: [
    .macOS(.v10_15),
  ],
  dependencies: [
    .package(url: "https://atomgit.com/vChewing/vChewing-VanguardLexicon.git", exact: "4.8.0"),
  ],
  targets: [
    .target(
      name: "LexiconBuildTrigger",
      plugins: [
        .plugin(name: "TextTemplateAssetInjectorPlugin", package: "vChewing-VanguardLexicon"),
        .plugin(name: "VanguardTextMapPlugin", package: "vChewing-VanguardLexicon"),
      ]
    ),
  ]
)
