// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "Homa",
  products: [
    .library(
      name: "Homa",
      targets: ["Homa"]
    ),
    .library(
      name: "HomaSharedTestComponents",
      targets: ["HomaSharedTestComponents"]
    ),
  ],
  dependencies: [],
  targets: [
    .target(
      name: "Homa",
      dependencies: []
    ),
    .target(
      name: "HomaSharedTestComponents",
      dependencies: ["Homa"],
      path: "Tests/HomaSharedTestComponents"
    ),
    .testTarget(
      name: "HomaTests",
      dependencies: [
        "Homa",
        "HomaSharedTestComponents",
      ]
    ),
  ]
)
