// swift-tools-version: 6.4
import PackageDescription

let package = Package(
  name: "FolderMonitor",
  platforms: [
    .macOS(.v12),
  ],
  products: [
    .library(
      name: "FolderMonitor",
      targets: ["FolderMonitor"]
    ),
  ],
  dependencies: [
    .package(path: "../vChewing_OSNeutral_LibVanguard"),
    // `Vanguard` 是 dynamic 產物，Swift Build 引擎（Swift 6.4 起之預設）不代它把 `SwiftExtension`
    // 的動態庫轉給下游，故凡直接使用 SwiftExtension 符號之靶一律自行宣告本產品。
    .package(path: "../vChewing_OSNeutral_LibVanguard/Deps/VanguardSwiftExtension"),
  ],
  targets: [
    .target(
      name: "FolderMonitor",
      dependencies: [
        .product(name: "Vanguard", package: "vChewing_OSNeutral_LibVanguard"),
        .product(name: "VanguardSwiftExtension", package: "VanguardSwiftExtension"),
      ],
      swiftSettings: [
        .defaultIsolation(MainActor.self), // set Default Actor Isolation
      ]
    ),
  ]
)
