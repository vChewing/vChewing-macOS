// swift-tools-version: 5.10
import PackageDescription

// 本套件是**語料庫（原廠辭典＋兩份聯想詞模板）的帶外產製器**：一支只為承載 lexicon 的兩支 buildTool
// plugin 而存在的空殼建置目標。它同時服務兩條建置鏈，故 manifest 刻意停在 `swift-tools-version: 5.10`：
// 5.10 與 6.4 兩顆工具鏈都讀得懂這一份，而本套件原始碼只有一個空 enum，沒有任何隨語言模式改變的內容。
// 遠端 lexicon 則自備 `Package.swift`（6.2）與 `Package@swift-5.swift`，兩顆工具鏈各取所需。
//
// 為什麼要另開一個套件：`vChewing-VanguardLexicon` 的 plugin 產物寫在**整份 scratch 共用的**
// `plugins/outputs/…` 之下，但 SwiftPM 對每個 destination（＝每個 `--arch`／每個 config）各跑一次
// build command——故只要把 plugin 掛在 app 自己的建置目標上，`make release` 的 arm64 與 x86_64 兩個
// slice 就會各建一次原廠辭典（實測各約 35–49 秒）。改由本套件以 **host-only（不下 `--arch`）** 建置
// 一次、把產物集中到固定目錄，再由 `vChewing_MainAssembly4Darwin` 的本地 buildTool plugin 純複製注入，
// 整條鏈就只建一次。Swift 5.10 legacy 側同理：`bundleLegacy` 由此固定目錄取用。
//
// 平台下限隨 5.10 側定為 macOS 10.15（legacy app 的部署目標是 10.9，而 lexicon 的產製工具真的用了
// Swift Concurrency）；這只影響本套件自己，與 app 的 `platforms:` 無關。
//
// 本套件不產出任何可執行檔或函式庫，`LexiconBuildTrigger` 這個空 enum 僅是 plugin 的附著點。
let package = Package(
  name: "LexiconBuildTrigger",
  platforms: [
    .macOS(.v10_15),
  ],
  dependencies: [
    .package(url: "https://gitee.com/vChewing/vChewing-VanguardLexicon.git", exact: "4.9.2"),
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
