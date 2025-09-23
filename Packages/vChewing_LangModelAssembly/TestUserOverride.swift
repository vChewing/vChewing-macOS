// swift-tools-version:5.3
import PackageDescription

let package = Package(
  name: "TestPerceptionOverride",
  dependencies: [
    .package(path: "."),
  ],
  targets: [
    .target(
      name: "TestPerceptionOverride",
      dependencies: ["LangModelAssembly"],
      path: "TestSources"
    ),
    .executableTarget(
      name: "TestApp",
      dependencies: ["TestPerceptionOverride"],
      path: "TestApp"
    ),
  ]
)
