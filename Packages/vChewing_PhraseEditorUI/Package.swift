// swift-tools-version: 5.7
import PackageDescription

let package = Package(
  name: "PhraseEditorUI",
  platforms: [
    .macOS(.v11),
  ],
  products: [
    .library(
      name: "PhraseEditorUI",
      targets: ["PhraseEditorUI"]
    ),
  ],
  dependencies: [
    .package(path: "../vChewing_LangModelAssembly"),
    .package(path: "../vChewing_Shared_DarwinImpl"),
  ],
  targets: [
    .target(
      name: "PhraseEditorUI",
      dependencies: [
        .product(name: "LangModelAssembly", package: "vChewing_LangModelAssembly"),
        .product(name: "Shared_DarwinImpl", package: "vChewing_Shared_DarwinImpl"),
      ]
    ),
  ]
)
