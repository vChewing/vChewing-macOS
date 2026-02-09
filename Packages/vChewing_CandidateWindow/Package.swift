// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "CandidateWindow",
  platforms: [
    .macOS(.v11),
  ],
  products: [
    .library(
      name: "CandidateWindow",
      targets: ["CandidateWindow"]
    ),
  ],
  dependencies: [
    .package(path: "../vChewing_Shared_DarwinImpl"),
  ],
  targets: buildTargets {
    Target.target(
      name: "CandidateWindow",
      dependencies: buildTargetDependencies {
        #if os(macOS)
          Target.Dependency("TDK4AppKit")
        #endif
      },
      swiftSettings: [
        .defaultIsolation(MainActor.self), // set Default Actor Isolation
      ]
    )
    #if os(macOS)
      Target.target(
        name: "TDK4AppKit",
        dependencies: [
          .product(name: "Shared_DarwinImpl", package: "vChewing_Shared_DarwinImpl"),
        ],
        swiftSettings: [
          .defaultIsolation(MainActor.self), // set Default Actor Isolation
        ]
      )
      Target.testTarget(
        name: "TDK4AppKitTests",
        dependencies: ["TDK4AppKit"],
        swiftSettings: [
          .defaultIsolation(MainActor.self), // set Default Actor Isolation
        ]
      )
    #endif
  }
)

// MARK: - ArrayBuilder

@resultBuilder
enum ArrayBuilder<Element> {
  static func buildEither(first elements: [Element]) -> [Element] {
    elements
  }

  static func buildEither(second elements: [Element]) -> [Element] {
    elements
  }

  static func buildOptional(_ elements: [Element]?) -> [Element] {
    elements ?? []
  }

  static func buildExpression(_ expression: Element) -> [Element] {
    [expression]
  }

  static func buildExpression(_: ()) -> [Element] {
    []
  }

  static func buildBlock(_ elements: [Element]...) -> [Element] {
    elements.flatMap { $0 }
  }

  static func buildArray(_ elements: [[Element]]) -> [Element] {
    Array(elements.joined())
  }
}

func buildTargets(@ArrayBuilder<Target?> targets: () -> [Target?]) -> [Target] {
  targets().compactMap { $0 }
}

func buildStrings(@ArrayBuilder<String?> strings: () -> [String?]) -> [String] {
  strings().compactMap { $0 }
}

func buildProducts(@ArrayBuilder<Product?> products: () -> [Product?]) -> [Product] {
  products().compactMap { $0 }
}

func buildTargetDependencies(
  @ArrayBuilder<Target.Dependency?> dependencies: () -> [Target.Dependency?]
)
  -> [Target.Dependency] {
  dependencies().compactMap { $0 }
}

func buildResources(
  @ArrayBuilder<Resource?> resources: () -> [Resource?]
)
  -> [Resource] {
  resources().compactMap { $0 }
}

func buildPackageDependencies(
  @ArrayBuilder<Package.Dependency?> dependencies: () -> [Package.Dependency?]
)
  -> [Package.Dependency] {
  dependencies().compactMap { $0 }
}
