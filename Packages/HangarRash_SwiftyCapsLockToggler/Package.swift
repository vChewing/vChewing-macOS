// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "SwiftyCapsLockToggler",
  platforms: [
    .macOS(.v12),
  ],
  products: [
    // Products define the executables and libraries a package produces, making them visible to other packages.
    .library(
      name: "SwiftyCapsLockToggler",
      targets: ["SwiftyCapsLockToggler"]
    ),
  ],
  dependencies: [
    .package(path: "../vChewing_OSNeutralAssembly"),
  ],
  targets: [
    // Targets are the basic building blocks of a package, defining a module or a test suite.
    // Targets can depend on other targets in this package and products from dependencies.
    .target(
      name: "CapsLockToggler",
      path: "Framework",
      cSettings: [
        .headerSearchPath("include"),
      ],
      swiftSettings: [
        .defaultIsolation(MainActor.self), // set Default Actor Isolation
      ]
    ),
    .target(
      name: "SwiftyCapsLockToggler",
      dependencies: [
        "CapsLockToggler",
        .product(name: "OSNeutralAssembly", package: "vChewing_OSNeutralAssembly"),
      ],
      swiftSettings: [
        .defaultIsolation(MainActor.self), // set Default Actor Isolation
      ]
    ),
  ]
)
