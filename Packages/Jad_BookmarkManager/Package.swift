// swift-tools-version: 6.4
import PackageDescription

let package = Package(
  name: "BookmarkManager",
  platforms: [
    .macOS(.v12),
  ],
  products: [
    .library(
      name: "BookmarkManager",
      targets: ["BookmarkManager"]
    ),
  ],
  dependencies: [
    .package(path: "../vChewing_OSNeutral_LibVanguard"),
    // `Vanguard` 是 dynamic 產物：Swift Build 引擎（Swift 6.4 起之預設）不會代它把 SwiftExtension
    // 的動態庫轉給下游，故凡直接使用 SwiftExtension 符號（含經 `@_exported` 轉出者）的靶一律自行宣告本產品。
    .package(path: "../vChewing_OSNeutral_LibVanguard/Deps/VanguardSwiftExtension"),
  ],
  targets: [
    .target(
      name: "BookmarkManager",
      dependencies: [
        .product(name: "Vanguard", package: "vChewing_OSNeutral_LibVanguard"),
        .product(name: "VanguardSwiftExtension", package: "VanguardSwiftExtension"),
      ],
      swiftSettings: [
        .defaultIsolation(MainActor.self), // set Default Actor Isolation
      ]
    ),
    .testTarget(
      name: "BookmarkManagerTests",
      dependencies: [
        "BookmarkManager",
        .product(name: "Vanguard", package: "vChewing_OSNeutral_LibVanguard"),
        .product(name: "VanguardSwiftExtension", package: "VanguardSwiftExtension"),
      ],
      path: "Tests/BookmarkManagerTests",
      swiftSettings: [
        .defaultIsolation(MainActor.self), // set Default Actor Isolation
      ]
    ),
  ]
)
