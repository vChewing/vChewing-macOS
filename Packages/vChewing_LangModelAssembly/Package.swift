// swift-tools-version: 5.7
import PackageDescription

let package = Package(
  name: "LangModelAssembly",
  products: [
    .library(
      name: "LangModelAssembly",
      targets: ["LangModelAssembly"]
    ),
    .library(
      name: "LMAssemblyMaterials4Tests",
      targets: ["LMAssemblyMaterials4Tests"]
    ),
  ],
  dependencies: [
    .package(path: "../CSQLite3"),
    .package(path: "../RMJay_LineReader"),
    .package(path: "../vChewing_Megrez"),
    .package(path: "../vChewing_SwiftExtension"),
  ],
  targets: [
    .target(
      name: "LMAssemblyMaterials4Tests",
      resources: [
        .process("Resources/vanguardLegacy_test.sql"),
      ]
    ),
    .target(
      name: "LangModelAssembly",
      dependencies: [
        "LMAssemblyMaterials4Tests",
        .product(name: "CSQLite3", package: "CSQLite3"),
        .product(name: "LineReader", package: "RMJay_LineReader"),
        .product(name: "Megrez", package: "vChewing_Megrez"),
        .product(name: "MegrezTestComponents", package: "vChewing_Megrez"),
        .product(name: "SwiftExtension", package: "vChewing_SwiftExtension"),
      ]
    ),
    .testTarget(
      name: "LangModelAssemblyTests",
      dependencies: ["LangModelAssembly"]
    ),
  ]
)
