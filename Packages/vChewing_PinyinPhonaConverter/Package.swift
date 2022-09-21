// swift-tools-version:5.3
import PackageDescription

let package = Package(
  name: "PinyinPhonaConverter",
  platforms: [
    .macOS(.v10_11)
  ],
  products: [
    .library(
      name: "PinyinPhonaConverter",
      targets: ["PinyinPhonaConverter"]
    )
  ],
  dependencies: [],
  targets: [
    .target(
      name: "PinyinPhonaConverter",
      dependencies: []
    )
  ]
)
