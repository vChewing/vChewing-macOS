// swift-tools-version:5.3
import PackageDescription

let package = Package(
  name: "LangModelAssembly",
  platforms: [
    .macOS(.v10_11)
  ],
  products: [
    .library(
      name: "LangModelAssembly",
      targets: ["LangModelAssembly"]
    )
  ],
  dependencies: [
    .package(path: "../RMJay_LineReader"),
    .package(path: "../vChewing_Megrez"),
    .package(path: "../vChewing_PinyinPhonaConverter"),
    .package(path: "../vChewing_Shared"),
  ],
  targets: [
    .target(
      name: "LangModelAssembly",
      dependencies: [
        .product(name: "LineReader", package: "RMJay_LineReader"),
        .product(name: "Megrez", package: "vChewing_Megrez"),
        .product(name: "Shared", package: "vChewing_Shared"),
        .product(name: "PinyinPhonaConverter", package: "vChewing_PinyinPhonaConverter"),
      ]
    )
  ]
)
