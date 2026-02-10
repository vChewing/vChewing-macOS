// swift-tools-version: 6.2
import PackageDescription

#if os(macOS)
  let package = Package(
    name: "vChewingIME",
    platforms: [
      .macOS(.v12),
    ],
    products: [
      .executable(
        name: "vChewing",
        targets: ["vChewing"]
      ),
      .executable(
        name: "vChewingInstaller",
        targets: ["vChewingInstaller"]
      ),
    ],
    dependencies: [
      .package(path: "./Packages/vChewing_InstallerAssembly4Darwin"),
      .package(path: "./Packages/vChewing_MainAssembly4Darwin"),
    ],
    targets: [
      // MARK: - Executable Targets

      .executableTarget(
        name: "vChewing",
        dependencies: [
          .product(name: "MainAssembly4Darwin", package: "vChewing_MainAssembly4Darwin"),
        ],
        path: "./Sources/vChewingIME_macOS",
        exclude: ["Resources"],
        sources: ["Modules"],
        swiftSettings: [
          .defaultIsolation(MainActor.self),
        ]
      ),
      .executableTarget(
        name: "vChewingInstaller",
        dependencies: [
          .product(name: "InstallerAssembly4Darwin", package: "vChewing_InstallerAssembly4Darwin"),
        ],
        path: "./Sources/Installer_macOS",
        exclude: ["Resources"],
        swiftSettings: [
          .defaultIsolation(MainActor.self),
        ]
      ),

      // MARK: - Build Plugin

      /// Assembles macOS `.app` bundles for vChewing and vChewingInstaller.
      ///
      /// Usage:
      /// ```
      /// swift package --allow-writing-to-package-directory bundle-apps
      /// swift package --allow-writing-to-package-directory bundle-apps -- --debug
      /// swift package --allow-writing-to-package-directory bundle-apps -- --archive
      /// ```
      ///
      /// Output goes to `Build/Products/Release/` (or `Debug/`).
      /// With `--archive`, also creates an `.xcarchive` in
      /// `~/Library/Developer/Xcode/Archives/`.
      .plugin(
        name: "BundleApps",
        capability: .command(
          intent: .custom(
            verb: "bundle-apps",
            description: "Build and assemble macOS app bundles for vChewing and vChewingInstaller"
          ),
          permissions: [
            .writeToPackageDirectory(
              reason: "Creates app bundles in Build/Products/"
            ),
          ]
        )
      ),
    ]
  )

#else

  let package = Package(
    name: "vChewingIME",
    targets: []
  )

#endif
