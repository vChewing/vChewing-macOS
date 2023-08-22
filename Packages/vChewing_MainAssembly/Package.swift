// swift-tools-version:5.3
import PackageDescription

let package = Package(
  name: "MainAssembly",
  platforms: [
    .macOS(.v10_13),
  ],
  products: [
    .library(
      name: "MainAssembly",
      targets: ["MainAssembly"]
    ),
  ],
  dependencies: [
    .package(path: "../Jad_BookmarkManager"),
    .package(path: "../vChewing_CandidateWindow"),
    .package(path: "../vChewing_CocoaExtension"),
    .package(path: "../DanielGalasko_FolderMonitor"),
    .package(path: "../vChewing_Hotenka"),
    .package(path: "../vChewing_IMKUtils"),
    .package(path: "../vChewing_LangModelAssembly"),
    .package(path: "../vChewing_Megrez"),
    .package(path: "../vChewing_NotifierUI"),
    .package(path: "../vChewing_PhraseEditorUI"),
    .package(path: "../vChewing_PopupCompositionBuffer"),
    .package(path: "../vChewing_Shared"),
    .package(path: "../Qwertyyb_ShiftKeyUpChecker"),
    .package(path: "../vChewing_SwiftExtension"),
    .package(path: "../vChewing_Tekkon"),
    .package(path: "../vChewing_TooltipUI"),
    .package(path: "../vChewing_UpdateSputnik"),
    .package(path: "../vChewing_Uninstaller"),
  ],
  targets: [
    .target(
      name: "MainAssembly",
      dependencies: [
        .product(name: "BookmarkManager", package: "Jad_BookmarkManager"),
        .product(name: "CandidateWindow", package: "vChewing_CandidateWindow"),
        .product(name: "CocoaExtension", package: "vChewing_CocoaExtension"),
        .product(name: "Hotenka", package: "vChewing_Hotenka"),
        .product(name: "FolderMonitor", package: "DanielGalasko_FolderMonitor"),
        .product(name: "IMKUtils", package: "vChewing_IMKUtils"),
        .product(name: "LangModelAssembly", package: "vChewing_LangModelAssembly"),
        .product(name: "Megrez", package: "vChewing_Megrez"),
        .product(name: "NotifierUI", package: "vChewing_NotifierUI"),
        .product(name: "PhraseEditorUI", package: "vChewing_PhraseEditorUI"),
        .product(name: "PopupCompositionBuffer", package: "vChewing_PopupCompositionBuffer"),
        .product(name: "Shared", package: "vChewing_Shared"),
        .product(name: "ShiftKeyUpChecker", package: "Qwertyyb_ShiftKeyUpChecker"),
        .product(name: "SwiftExtension", package: "vChewing_SwiftExtension"),
        .product(name: "Tekkon", package: "vChewing_Tekkon"),
        .product(name: "TooltipUI", package: "vChewing_TooltipUI"),
        .product(name: "UpdateSputnik", package: "vChewing_UpdateSputnik"),
        .product(name: "Uninstaller", package: "vChewing_Uninstaller"),
      ]
    ),
    .testTarget(
      name: "MainAssemblyTests",
      dependencies: ["MainAssembly"]
    ),
  ]
)
