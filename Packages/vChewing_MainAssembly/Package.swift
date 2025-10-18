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
    .package(path: "../Qwertyyb_ShiftKeyUpChecker"),
    .package(path: "../vChewing_BrailleSputnik"),
    .package(path: "../vChewing_CandidateWindow"),
    .package(path: "../vChewing_OSFrameworkImpl"),
    .package(path: "../vChewing_Hotenka"),
    .package(path: "../vChewing_IMKUtils"),
    .package(path: "../vChewing_KimoDataReader"),
    .package(path: "../vChewing_LangModelAssembly"),
    .package(path: "../vChewing_Megrez"),
    .package(path: "../vChewing_NotifierUI"),
    .package(path: "../vChewing_PhraseEditorUI"),
    .package(path: "../vChewing_PopupCompositionBuffer"),
    .package(path: "../vChewing_Shared"),
    .package(path: "../vChewing_Shared_DarwinImpl"),
    .package(path: "../vChewing_SwiftExtension"),
    .package(path: "../vChewing_Tekkon"),
    .package(path: "../vChewing_Typewriter"),
    .package(path: "../vChewing_TooltipUI"),
    .package(path: "../vChewing_Uninstaller"),
    .package(path: "../vChewing_UpdateSputnik"),
  ],
  targets: [
    .target(
      name: "MainAssembly",
      dependencies: [
        .product(name: "BrailleSputnik", package: "vChewing_BrailleSputnik"),
        .product(name: "BookmarkManager", package: "Jad_BookmarkManager"),
        .product(name: "CandidateWindow", package: "vChewing_CandidateWindow"),
        .product(name: "OSFrameworkImpl", package: "vChewing_OSFrameworkImpl"),
        .product(name: "FolderMonitor", package: "DanielGalasko_FolderMonitor"),
        .product(name: "Hotenka", package: "vChewing_Hotenka"),
        .product(name: "IMKUtils", package: "vChewing_IMKUtils"),
        .product(name: "KimoDataReader", package: "vChewing_KimoDataReader"),
        .product(name: "LangModelAssembly", package: "vChewing_LangModelAssembly"),
        .product(name: "LMAssemblyMaterials4Tests", package: "vChewing_LangModelAssembly"),
        .product(name: "Megrez", package: "vChewing_Megrez"),
        .product(name: "NotifierUI", package: "vChewing_NotifierUI"),
        .product(name: "PhraseEditorUI", package: "vChewing_PhraseEditorUI"),
        .product(name: "PopupCompositionBuffer", package: "vChewing_PopupCompositionBuffer"),
        .product(name: "Shared", package: "vChewing_Shared"),
        .product(name: "Shared_DarwinImpl", package: "vChewing_Shared_DarwinImpl"),
        .product(name: "ShiftKeyUpChecker", package: "Qwertyyb_ShiftKeyUpChecker"),
        .product(name: "SwiftExtension", package: "vChewing_SwiftExtension"),
        .product(name: "SwiftyCapsLockToggler", package: "HangarRash_SwiftyCapsLockToggler"),
        .product(name: "Tekkon", package: "vChewing_Tekkon"),
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
        .product(name: "Typewriter", package: "vChewing_Typewriter"),
      ]
    ),
  ]
)
