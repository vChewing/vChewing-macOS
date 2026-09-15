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
// 1. **產物一律 static**（兩個產品皆然）。Swift 5.10 側的宿主是 macOS 10.9 的 legacy app，其 ARC 執行期
//    由 libArcLite 提供，而 dylib 必須在建置期就專門摻進該靜態庫（不能像 app 那樣由宿主統一連結），
//    故本側不出動態庫，只出 `.a`、由宿主把所有 `.a` 連成單一二進位。
// 2. **`platforms` 填 `nil`**。PackageDescription 能宣告的 macOS 最低值只有 10.10，一旦宣告即被明文寫入
//    產物的 `LC_BUILD_VERSION`；本側索性不宣告平台限制，讓 SDK 之預設值說話。
// 3. **不含任何測試靶**（Unit Tests 不對 Swift 5.10 開放）。本套件的 6.2 側本即無測試靶。
// 4. **不使用 6.x 才有的設定**：`.defaultIsolation(MainActor.self)` 與 `swiftLanguageModes` 皆為 tools 6.2
//    起才存在；本側語言模式即 5.10 toolchain 之預設（Swift 5），另以 `swiftLanguageVersions: [.v5]` 明示。
//
// C／ObjC 靶 `IMKSwiftModernHeaders`（`cSettings: [.unsafeFlags(["-fno-objc-arc"])]`）原樣保留——它是
// **生產靶**、不是測試靶。環境配對與各項差異的機理見 vChewing-DevLogs/Research/Phase217_SOP.md §三／§四。

let package = Package(
  name: "IMKUtils",
  platforms: nil,
  products: [
    .library(
      name: "IMKUtils",
      type: .static,
      targets: ["IMKUtils"]
    ),
    .library(
      name: "IMKSwift",
      type: .static,
      targets: ["IMKSwift"]
    ),
  ],
  dependencies: [
    .package(path: "../vChewing_OSNeutral_LibVanguard/Deps/VanguardSwiftExtension"),
  ],
  targets: [
    .target(
      name: "IMKSwift",
      dependencies: [
        "IMKSwiftModernHeaders",
      ],
      resources: []
    ),
    .target(
      name: "IMKSwiftModernHeaders",
      cSettings: [
        .unsafeFlags(["-fno-objc-arc"]),
      ]
    ),
    .target(
      name: "IMKUtils",
      dependencies: [
        "IMKSwift",
        .product(name: "VanguardSwiftExtension", package: "VanguardSwiftExtension"),
      ]
    ),
  ],
  swiftLanguageVersions: [.v5]
)
