// swift-tools-version: 5.10
import PackageDescription

// 本檔是 `Package.swift`（tools 6.2）的 **Swift 5.10 對位版**，與聚合體根部之同名檔成對；SwiftPM 之
// 版本擇定規則詳見該檔。與 `Package.swift` 的刻意差異有二：
//
// - **產物一律 static**。Swift 5.10 側的宿主是 macOS 10.9 的 legacy app，其 ARC 執行期由 libArcLite
//   提供，而 dylib 必須在建置期就專門摻進該靜態庫、不能像 app 那樣由宿主統一連結——故本側不出貨
//   動態庫，改出 `.a`，由宿主把所有 `.a` 連成單一二進位。（6.2 側則相反：Darwin 出 dynamic，好讓
//   `libVanguard.dylib` 對它是**動態相倚**而非靜態內嵌，故每個行程內本模組恰有一份 image；App-based
//   installer 亦只需帶這一顆小庫，不必連帶吃下整條打字閉包。其餘平台維持 static。）
// - **不含測試靶**。單元測試僅由 Swift 6.2 以上 toolchain 負責，`Tests/SwiftExtensionTests/` 於本側
//   不進 manifest。
//
// 另 `platforms` 填 `nil`（PackageDescription 能宣告的 macOS 最低值只有 10.10，一旦宣告即被明文寫入
// 產物的 `LC_BUILD_VERSION`），亦不使用 `defaultIsolation` 等 6.x 才有的設定。
//
// 註一：SwiftPM 對本地路徑相依的 package identity **取自目錄名**，故各消費端宣告的是
// `package: "VanguardSwiftExtension"`，與本 manifest 的 `name:` 無關。
// 註二：**產品名與模組名刻意不同**——產品叫 `VanguardSwiftExtension`（與本套件同名），
// 而模組仍叫 `SwiftExtension`，故全倉一律 `import SwiftExtension`。SwiftPM 不要求兩者同名。

let package = Package(
  name: "VanguardSwiftExtension",
  platforms: nil,
  products: [
    .library(
      name: "VanguardSwiftExtension",
      type: .static,
      targets: ["SwiftExtension"]
    ),
  ],
  dependencies: [],
  targets: [
    .target(
      name: "SwiftExtension",
      dependencies: []
    ),
  ]
)
