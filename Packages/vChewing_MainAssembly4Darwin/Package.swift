// swift-tools-version: 6.4
import PackageDescription

let package = Package(
  name: "MainAssembly4Darwin",
  platforms: [
    .macOS(.v12),
  ],
  products: [
    .library(
      name: "MainAssembly4Darwin",
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
    .package(url: "https://atomgit.com/vChewing/vChewing-VanguardLexicon.git", exact: "4.8.4"),
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
      ],
      swiftSettings: [
        .defaultIsolation(MainActor.self), // set Default Actor Isolation
      ],
      plugins: [
        .plugin(name: "TextTemplateAssetInjectorPlugin", package: "vChewing-VanguardLexicon"),
        .plugin(name: "VanguardTextMapPlugin", package: "vChewing-VanguardLexicon"),
      ]
    ),
    .testTarget(
      name: "MainAssembly4DarwinTests",
      dependencies: [
        "MainAssembly4Darwin",
      ],
      swiftSettings: [
        .defaultIsolation(MainActor.self), // set Default Actor Isolation
      ]
    ),
  ]
)
