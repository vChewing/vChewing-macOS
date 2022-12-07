// swift-tools-version:5.3
import PackageDescription

let package = Package(
  name: "PhraseEditorUI",
  platforms: [
    .macOS(.v10_11)
  ],
  products: [
    .library(
      name: "PhraseEditorUI",
      targets: ["PhraseEditorUI"]
    )
  ],
  dependencies: [
    .package(path: "../vChewing_LangModelAssembly"),
    .package(path: "../vChewing_Shared"),
    .package(path: "../ShapsBenkau_SwiftUIBackports"),
  ],
  targets: [
    .target(
      name: "PhraseEditorUI",
      dependencies: [
        .product(name: "LangModelAssembly", package: "vChewing_LangModelAssembly"),
        .product(name: "SwiftUIBackports", package: "ShapsBenkau_SwiftUIBackports"),
        .product(name: "Shared", package: "vChewing_Shared"),
      ]
    )
  ]
)
