// swift-tools-version: 5.7
import PackageDescription

let package = Package(
  name: "MainAssembly",
  platforms: [
    .macOS(.v12),
  ],
  products: [
    .library(
      name: "MainAssembly",
      targets: ["MainAssembly"]
    ),
  ],
  dependencies: [
    .package(path: "../DanielGalasko_FolderMonitor"),
    .package(path: "../HangarRash_SwiftyCapsLockToggler"),
    .package(path: "../Jad_BookmarkManager"),
    .package(path: "../vChewing_ShiftKeyUpChecker"),
    .package(path: "../vChewing_CandidateWindow"),
    .package(path: "../vChewing_Hotenka"),
    .package(path: "../vChewing_IMKUtils"),
    .package(path: "../vChewing_KimoDataReader"),
    .package(path: "../vChewing_LangModelAssembly"), // Unit tests material deps.
    .package(path: "../vChewing_NotifierUI"),
    .package(path: "../vChewing_PhraseEditorUI"),
    .package(path: "../vChewing_PopupCompositionBuffer"),
    .package(path: "../vChewing_Shared_DarwinImpl"),
    .package(path: "../vChewing_Typewriter"),
    .package(path: "../vChewing_TooltipUI"),
    .package(path: "../vChewing_Uninstaller"),
    .package(path: "../vChewing_UpdateSputnik"),
  ],
  targets: [
    .target(
      name: "MainAssembly",
      dependencies: [
        .product(name: "BookmarkManager", package: "Jad_BookmarkManager"),
        .product(name: "CandidateWindow", package: "vChewing_CandidateWindow"),
        .product(name: "FolderMonitor", package: "DanielGalasko_FolderMonitor"),
        .product(name: "Hotenka", package: "vChewing_Hotenka"),
        .product(name: "IMKUtils", package: "vChewing_IMKUtils"),
        .product(name: "KimoDataReader", package: "vChewing_KimoDataReader"),
        .product(name: "LMAssemblyMaterials4Tests", package: "vChewing_LangModelAssembly"),
        .product(name: "NotifierUI", package: "vChewing_NotifierUI"),
        .product(name: "PhraseEditorUI", package: "vChewing_PhraseEditorUI"),
        .product(name: "PopupCompositionBuffer", package: "vChewing_PopupCompositionBuffer"),
        .product(name: "Shared_DarwinImpl", package: "vChewing_Shared_DarwinImpl"),
        .product(name: "ShiftKeyUpChecker", package: "vChewing_ShiftKeyUpChecker"),
        .product(name: "SwiftyCapsLockToggler", package: "HangarRash_SwiftyCapsLockToggler"),
        .product(name: "Typewriter", package: "vChewing_Typewriter"),
        .product(name: "TooltipUI", package: "vChewing_TooltipUI"),
        .product(name: "Uninstaller", package: "vChewing_Uninstaller"),
        .product(name: "UpdateSputnik", package: "vChewing_UpdateSputnik"),
      ],
      resources: [
        .process("Resources/convdict.sqlite"),
      ]
    ),
    .testTarget(
      name: "MainAssemblyTests",
      dependencies: [
        "MainAssembly",
      ]
    ),
  ]
)
