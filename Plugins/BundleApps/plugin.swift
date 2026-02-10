// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

// MARK: - BundleApps Command Plugin

// Assembles macOS `.app` bundles for vChewing and vChewingInstaller,
// replicating the output that `xcodebuild` produces from the xcodeproj.
//
// Usage:
//   swift package --allow-writing-to-package-directory bundle-apps
//   swift package --allow-writing-to-package-directory bundle-apps -- --debug
//   swift package --allow-writing-to-package-directory bundle-apps -- --archive
//
// For universal (arm64 + x86_64) builds, build externally first:
//   (Do not use both archs on one command which causes lexicon build failures.)
//   swift build -c release --arch x86_64
//   swift build -c release --arch arm64
//   swift package --allow-writing-to-package-directory bundle-apps \
//     -- --build-dir .build/apple/Products/Release

import Foundation
import PackagePlugin

// MARK: - BundleAppsPlugin

@main
struct BundleAppsPlugin: CommandPlugin {
  func performCommand(context: PluginContext, arguments: [String]) async throws {
    let packageDir = context.package.directoryURL
    let isDebug = arguments.contains("--debug")
    let shouldArchive = arguments.contains("--archive")
    let configName = isDebug ? "Debug" : "Release"
    let outputDir = packageDir.appending(path: "Build/Products/\(configName)")
    let fm = FileManager.default

    // --build-dir <path>: use pre-built executables (e.g. from an external
    //   `swift build --arch arm64 --arch x86_64` invocation).
    //   Accepts absolute paths or paths relative to the package root.
    //   When omitted, the plugin builds using the PackageManager API (native arch only).
    let externalBuildDir: String? = {
      guard let idx = arguments.firstIndex(of: "--build-dir"),
            idx + 1 < arguments.count else { return nil }
      return arguments[idx + 1]
    }()

    // Read version info from the single source of truth.
    let (marketingVersion, buildVersion) = try readVersionInfo(
      from: packageDir.appending(path: "Release-Version.plist")
    )
    let deploymentTarget = "12.0"

    // ── Step 1: Build (or locate) executables ──────────────────────────
    let spmBuildDir: URL
    if let externalBuildDir {
      // Use pre-built artifacts supplied by the caller (e.g. universal binary).
      let dir = externalBuildDir.hasPrefix("/")
        ? URL(fileURLWithPath: externalBuildDir)
        : packageDir.appending(path: externalBuildDir)
      guard fm.fileExists(atPath: dir.path) else {
        throw PluginError("Build directory not found: \(dir.path)")
      }
      spmBuildDir = dir
      print("📦 Using pre-built executables from \(dir.path)")
    } else {
      // Build for native architecture via the plugin API.
      let configuration: PackageManager.BuildConfiguration = isDebug ? .debug : .release
      print("🔨 Building executables (\(configName))...")
      let buildResult = try packageManager.build(
        .all(includingTests: false),
        parameters: .init(configuration: configuration)
      )
      guard buildResult.succeeded else {
        print(buildResult.logText)
        throw PluginError("Build failed. See log above.")
      }
      print("  ✓ Build succeeded.")
      guard let firstExe = buildResult.builtArtifacts.first(where: {
        $0.kind == .executable
      }) else {
        throw PluginError("No executables found in build artifacts.")
      }
      spmBuildDir = firstExe.url.deletingLastPathComponent()
    }

    // Locate built executables.
    let vChewingExeURL = spmBuildDir.appending(path: "vChewing")
    let installerExeURL = spmBuildDir.appending(path: "vChewingInstaller")
    guard fm.fileExists(atPath: vChewingExeURL.path) else {
      throw PluginError("vChewing executable not found at \(vChewingExeURL.path)")
    }
    guard fm.fileExists(atPath: installerExeURL.path) else {
      throw PluginError("vChewingInstaller executable not found at \(installerExeURL.path)")
    }

    // Discover SPM resource bundles next to the built executables.
    let spmBundles: [URL] = (try? fm.contentsOfDirectory(
      at: spmBuildDir, includingPropertiesForKeys: [.isDirectoryKey]
    ))?.filter { $0.pathExtension == "bundle" } ?? []

    // Prepare output directory.
    try? fm.removeItem(at: outputDir)
    try fm.createDirectory(at: outputDir, withIntermediateDirectories: true)

    // ── Step 2: Assemble vChewing.app ──────────────────────────────────
    print("📦 Assembling vChewing.app...")
    let vChewingApp = outputDir.appending(path: "vChewing.app")
    try assembleMainIMEApp(
      appDir: vChewingApp,
      packageDir: packageDir,
      executableURL: vChewingExeURL,
      spmBundles: spmBundles,
      marketingVersion: marketingVersion,
      buildVersion: buildVersion,
      deploymentTarget: deploymentTarget
    )
    print("  ✓ vChewing.app assembled.")

    // ── Step 3: Assemble vChewingInstaller.app ─────────────────────────
    print("📦 Assembling vChewingInstaller.app...")
    let installerApp = outputDir.appending(path: "vChewingInstaller.app")
    try assembleInstallerApp(
      appDir: installerApp,
      packageDir: packageDir,
      executableURL: installerExeURL,
      embeddedMainIMEApp: vChewingApp,
      marketingVersion: marketingVersion,
      buildVersion: buildVersion,
      deploymentTarget: deploymentTarget
    )
    print("  ✓ vChewingInstaller.app assembled.")

    // ── Step 4 (optional): Create .xcarchive ──────────────────────────
    if shouldArchive {
      print("📁 Creating .xcarchive...")
      let archivePath = try assembleXcarchive(
        installerApp: installerApp,
        vChewingApp: vChewingApp,
        spmBuildDir: spmBuildDir,
        packageDir: packageDir,
        marketingVersion: marketingVersion,
        buildVersion: buildVersion
      )
      print("  ✓ Archive created: \(archivePath.path)")
    }

    print("✅ Done. Output: \(outputDir.path)")
  }
}

// MARK: - vChewing.app Assembly

extension BundleAppsPlugin {
  private func assembleMainIMEApp(
    appDir: URL,
    packageDir: URL,
    executableURL: URL,
    spmBundles: [URL],
    marketingVersion: String,
    buildVersion: String,
    deploymentTarget: String
  ) throws {
    let fm = FileManager.default
    let contents = appDir.appending(path: "Contents")
    let macOS = contents.appending(path: "MacOS")
    let resources = contents.appending(path: "Resources")
    let srcRes = packageDir.appending(path: "Sources/vChewingIME_macOS/Resources")

    try fm.createDirectory(at: macOS, withIntermediateDirectories: true)
    try fm.createDirectory(at: resources, withIntermediateDirectories: true)

    // ── Executable ──
    try fm.copyItem(at: executableURL, to: macOS.appending(path: "vChewing"))

    // ── PkgInfo ──
    try Data("APPLMACV".utf8).write(to: contents.appending(path: "PkgInfo"))

    // ── Info.plist (with Xcode variable substitution) ──
    try processInfoPlist(
      source: srcRes.appending(path: "Info.plist"),
      destination: contents.appending(path: "Info.plist"),
      substitutions: [
        "$(PRODUCT_BUNDLE_IDENTIFIER)": "org.atelierInmu.inputmethod.vChewing",
        "$(MARKETING_VERSION)": marketingVersion,
        "$(CURRENT_PROJECT_VERSION)": buildVersion,
        "${EXECUTABLE_NAME}": "vChewing",
        "${PRODUCT_NAME}": "vChewing",
        "${MACOSX_DEPLOYMENT_TARGET}": deploymentTarget,
      ],
      additionalKeys: [
        "CFBundleIconFile": "AppIcon",
        "CFBundleIconName": "AppIcon",
        "CFBundleSupportedPlatforms": ["MacOSX"],
      ]
    )

    // ── Compile xcassets → Assets.car + AppIcon.icns ──
    try compileXcassets(
      input: srcRes.appending(path: "Images.xcassets"),
      output: resources,
      deploymentTarget: deploymentTarget,
      appIcon: "AppIcon"
    )

    // ── Combine HiDPI menu icons → .tiff ──
    let menuIconsDir = srcRes.appending(path: "MenuIcons")
    for name in ["MenuIcon-TCVIM", "MenuIcon-SCVIM"] {
      try combineHiDPI(
        base: menuIconsDir.appending(path: "\(name).png"),
        retina: menuIconsDir.appending(path: "\(name)@2x.png"),
        output: resources.appending(path: "\(name).tiff")
      )
    }

    // ── Localization directories ──
    for lproj in ["Base.lproj", "en.lproj", "ja.lproj", "zh-Hans.lproj", "zh-Hant.lproj"] {
      let src = srcRes.appending(path: lproj)
      if fm.fileExists(atPath: src.path) {
        try fm.copyItem(at: src, to: resources.appending(path: lproj))
      }
    }

    // ── Sound files ──
    for file in ["Beep.m4a", "Fart.m4a"] {
      try fm.copyItem(
        at: srcRes.appending(path: "SoundFiles/\(file)"),
        to: resources.appending(path: file)
      )
    }

    // ── Template files ──
    for file in [
      "template-exclusions.txt", "template-replacements.txt",
      "template-userphrases.txt", "template-usersymbolphrases.txt",
    ] {
      try fm.copyItem(at: srcRes.appending(path: file), to: resources.appending(path: file))
    }

    // ── Keyboard layout bundle ──
    try fm.copyItem(
      at: srcRes.appending(path: "vChewingKeyLayout.bundle"),
      to: resources.appending(path: "vChewingKeyLayout.bundle")
    )

    // ── Root-level license and script files ──
    for file in [
      "LICENSE.txt", "LICENSE-CHT.txt", "LICENSE-CHS.txt", "LICENSE-JPN.txt",
      "fixinstall.sh", "uninstall.sh",
    ] {
      try fm.copyItem(
        at: packageDir.appending(path: file),
        to: resources.appending(path: file)
      )
    }

    // ── SPM resource bundles from dependencies ──
    // Placed in Contents/Resources/ (standard macOS bundle location).
    // The Makefile patches SwiftPM's auto-generated resource_bundle_accessor.swift
    // to check Bundle.main.resourceURL before Bundle.main.bundleURL, ensuring
    // the bundles are found when the .app is launched by the system.
    //
    // Exclude build-tool-only bundles that are not needed at runtime.
    let excludedBundlePrefixes = ["VanguardLexicon_", "LangModelAssembly_"]
    for bundle in spmBundles {
      let name = bundle.lastPathComponent
      if excludedBundlePrefixes.contains(where: { name.hasPrefix($0) }) { continue }
      try fm.copyItem(at: bundle, to: resources.appending(path: name))
    }

    // ── Code sign with entitlements ──
    // Inject entitlements that Xcode derives from build settings:
    //   ENABLE_APP_SANDBOX = YES
    //   ENABLE_OUTGOING_NETWORK_CONNECTIONS = YES
    //   ENABLE_USER_SELECTED_FILES = readwrite
    let processedEntitlements = try processEntitlements(
      source: srcRes.appending(path: "vChewing.entitlements"),
      bundleIdentifier: "org.atelierInmu.inputmethod.vChewing",
      additionalEntitlements: [
        "com.apple.security.app-sandbox": true,
        "com.apple.security.network.client": true,
        "com.apple.security.files.user-selected.read-write": true,
      ]
    )
    try codesign(at: appDir, entitlements: processedEntitlements)
  }
}

// MARK: - vChewingInstaller.app Assembly

extension BundleAppsPlugin {
  private func assembleInstallerApp(
    appDir: URL,
    packageDir: URL,
    executableURL: URL,
    embeddedMainIMEApp: URL,
    marketingVersion: String,
    buildVersion: String,
    deploymentTarget: String
  ) throws {
    let fm = FileManager.default
    let contents = appDir.appending(path: "Contents")
    let macOS = contents.appending(path: "MacOS")
    let resources = contents.appending(path: "Resources")
    let srcRes = packageDir.appending(path: "Sources/Installer_macOS/Resources")

    try fm.createDirectory(at: macOS, withIntermediateDirectories: true)
    try fm.createDirectory(at: resources, withIntermediateDirectories: true)

    // ── Executable ──
    try fm.copyItem(at: executableURL, to: macOS.appending(path: "vChewingInstaller"))

    // ── PkgInfo ──
    try Data("APPLMBIN".utf8).write(to: contents.appending(path: "PkgInfo"))

    // ── Info.plist ──
    try processInfoPlist(
      source: srcRes.appending(path: "Info.plist"),
      destination: contents.appending(path: "Info.plist"),
      substitutions: [
        "$(PRODUCT_BUNDLE_IDENTIFIER)": "org.atelierInmu.vChewing.vChewingInstaller",
        "$(MARKETING_VERSION)": marketingVersion,
        "$(CURRENT_PROJECT_VERSION)": buildVersion,
        "${EXECUTABLE_NAME}": "vChewingInstaller",
        "${PRODUCT_NAME}": "vChewingInstaller",
        "${MACOSX_DEPLOYMENT_TARGET}": deploymentTarget,
      ],
      additionalKeys: [
        "CFBundleIconFile": "AppIcon",
        "CFBundleIconName": "AppIcon",
        "CFBundleSupportedPlatforms": ["MacOSX"],
      ]
    )

    // ── Compile xcassets ──
    try compileXcassets(
      input: srcRes.appending(path: "Images.xcassets"),
      output: resources,
      deploymentTarget: deploymentTarget,
      appIcon: "AppIcon"
    )

    // ── Localization directories ──
    for lproj in ["en.lproj", "ja.lproj", "zh-Hans.lproj", "zh-Hant.lproj"] {
      let src = srcRes.appending(path: lproj)
      if fm.fileExists(atPath: src.path) {
        try fm.copyItem(at: src, to: resources.appending(path: lproj))
      }
    }

    // ── Embed the entire vChewing.app ──
    try fm.copyItem(
      at: embeddedMainIMEApp,
      to: resources.appending(path: "vChewing.app")
    )

    // ── Code sign (installer entitlements are empty — no substitution needed) ──
    try codesign(at: appDir, entitlements: srcRes.appending(path: "vChewingInstaller.entitlements"))
  }
}

// MARK: - .xcarchive Assembly

extension BundleAppsPlugin {
  /// Assembles an `.xcarchive` compatible with Xcode Organizer.
  ///
  /// Layout:
  /// ```
  /// Name.xcarchive/
  ///   Info.plist
  ///   Products/Applications/vChewingInstaller.app/
  ///   dSYMs/
  ///     vChewing.app.dSYM/
  ///     vChewingInstaller.app.dSYM/
  /// ```
  private func assembleXcarchive(
    installerApp: URL,
    vChewingApp: URL,
    spmBuildDir: URL,
    packageDir: URL,
    marketingVersion: String,
    buildVersion: String
  ) throws
    -> URL {
    let fm = FileManager.default

    // Determine archive name: Name-YYYY-M-D-HHMMhrs.xcarchive
    let now = Date()
    let cal = Calendar.current
    let year = cal.component(.year, from: now)
    let month = cal.component(.month, from: now)
    let day = cal.component(.day, from: now)
    let hour = cal.component(.hour, from: now)
    let minute = cal.component(.minute, from: now)
    let archiveName =
      "vChewingInstaller-\(year)-\(month)-\(day)-\(String(format: "%02d%02d", hour, minute))hrs.xcarchive"

    // Build the xcarchive inside the package directory first (sandbox-safe).
    let archiveDir = packageDir.appending(path: "Build/Products/\(archiveName)")
    try? fm.removeItem(at: archiveDir)
    try fm.createDirectory(at: archiveDir, withIntermediateDirectories: true)

    // ── Products/Applications/ ──
    let productsApps = archiveDir.appending(path: "Products/Applications")
    try fm.createDirectory(at: productsApps, withIntermediateDirectories: true)
    try fm.copyItem(at: installerApp, to: productsApps.appending(path: "vChewingInstaller.app"))

    // ── dSYMs/ ──
    let dSYMsDir = archiveDir.appending(path: "dSYMs")
    try fm.createDirectory(at: dSYMsDir, withIntermediateDirectories: true)

    // Generate dSYMs for both executables using dsymutil.
    for (name, app) in [
      ("vChewing", vChewingApp),
      ("vChewingInstaller", installerApp),
    ] {
      let execPath = app.appending(path: "Contents/MacOS/\(name)").path
      let dSYMDest = dSYMsDir.appending(path: "\(name).app.dSYM").path
      try run("/usr/bin/xcrun", arguments: [
        "dsymutil", execPath, "-o", dSYMDest,
      ])
    }

    // ── Info.plist ──
    let archiveInfo: [String: Any] = [
      "ArchiveVersion": 2,
      "CreationDate": now,
      "Name": "vChewingInstaller",
      "SchemeName": "vChewingInstaller",
      "ApplicationProperties": [
        "ApplicationPath": "Applications/vChewingInstaller.app",
        "Architectures": try detectArchitectures(
          executable: installerApp.appending(path: "Contents/MacOS/vChewingInstaller")
        ),
        "CFBundleIdentifier": "org.atelierInmu.vChewing.vChewingInstaller",
        "CFBundleShortVersionString": marketingVersion,
        "CFBundleVersion": buildVersion,
        "SigningIdentity": "",
        "Team": "",
      ] as [String: Any],
    ]
    let plistData = try PropertyListSerialization.data(
      fromPropertyList: archiveInfo, format: .xml, options: 0
    )
    try plistData.write(to: archiveDir.appending(path: "Info.plist"))

    return archiveDir
  }

  /// Detects the architecture(s) of the given Mach-O executable using `lipo`.
  private func detectArchitectures(executable: URL) throws -> [String] {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/lipo")
    process.arguments = ["-archs", executable.path]
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = FileHandle.nullDevice
    try process.run()
    process.waitUntilExit()
    let output = String(
      data: pipe.fileHandleForReading.readDataToEndOfFile(),
      encoding: .utf8
    ) ?? ""
    let archs = output.trimmingCharacters(in: .whitespacesAndNewlines)
      .components(separatedBy: " ")
      .filter { !$0.isEmpty }
    return archs.isEmpty ? ["arm64"] : archs
  }
}

// MARK: - Helper Methods

extension BundleAppsPlugin {
  /// Reads marketing version and build version from `Update-Info.plist`.
  private func readVersionInfo(from url: URL) throws -> (marketing: String, build: String) {
    let data = try Data(contentsOf: url)
    guard let plist = try PropertyListSerialization.propertyList(
      from: data, format: nil
    ) as? [String: Any] else {
      throw PluginError("Cannot parse Update-Info.plist.")
    }
    let marketing = plist["CFBundleShortVersionString"] as? String ?? "0.0.0"
    let build = plist["CFBundleVersion"] as? String ?? "0"
    return (marketing, build)
  }

  /// Reads the template Info.plist, substitutes Xcode build variables
  /// (e.g. `$(PRODUCT_BUNDLE_IDENTIFIER)`), injects additional keys
  /// (e.g. `CFBundleIconFile`), and writes the result to `destination`.
  private func processInfoPlist(
    source: URL,
    destination: URL,
    substitutions: [String: String],
    additionalKeys: [String: Any] = [:]
  ) throws {
    var xml = try String(contentsOf: source, encoding: .utf8)
    for (token, value) in substitutions {
      xml = xml.replacingOccurrences(of: token, with: value)
    }
    guard let data = xml.data(using: .utf8),
          var dict = try PropertyListSerialization.propertyList(
            from: data, format: nil
          ) as? [String: Any]
    else {
      throw PluginError("Cannot parse Info.plist at \(source.path).")
    }
    for (key, value) in additionalKeys {
      dict[key] = value
    }
    let output = try PropertyListSerialization.data(
      fromPropertyList: dict, format: .xml, options: 0
    )
    try output.write(to: destination)
  }

  /// Processes entitlements plist by substituting `$(PRODUCT_BUNDLE_IDENTIFIER)`
  /// and injecting entitlements that Xcode normally derives from build settings
  /// (e.g. `ENABLE_APP_SANDBOX`, `ENABLE_HARDENED_RUNTIME`, etc.).
  /// Returns a temporary file URL suitable for passing to `codesign`.
  private func processEntitlements(
    source: URL,
    bundleIdentifier: String,
    additionalEntitlements: [String: Any] = [:]
  ) throws
    -> URL {
    var xml = try String(contentsOf: source, encoding: .utf8)
    xml = xml.replacingOccurrences(of: "$(PRODUCT_BUNDLE_IDENTIFIER)", with: bundleIdentifier)
    guard let data = xml.data(using: .utf8),
          var dict = try PropertyListSerialization.propertyList(
            from: data, format: nil
          ) as? [String: Any]
    else {
      throw PluginError("Cannot parse entitlements at \(source.path).")
    }
    for (key, value) in additionalEntitlements {
      dict[key] = value
    }
    let output = try PropertyListSerialization.data(
      fromPropertyList: dict, format: .xml, options: 0
    )
    let tmp = FileManager.default.temporaryDirectory
      .appending(path: "entitlements-\(UUID().uuidString).plist")
    try output.write(to: tmp)
    return tmp
  }

  /// Compiles an `.xcassets` catalog using `actool` from the Xcode toolchain.
  /// Produces `Assets.car` and `AppIcon.icns` in the output directory.
  private func compileXcassets(
    input: URL,
    output: URL,
    deploymentTarget: String,
    appIcon: String
  ) throws {
    let partialPlist = FileManager.default.temporaryDirectory
      .appending(path: "actool-partial-\(UUID().uuidString).plist")
    try run("/usr/bin/xcrun", arguments: [
      "actool",
      "--compile", output.path,
      "--platform", "macosx",
      "--minimum-deployment-target", deploymentTarget,
      "--app-icon", appIcon,
      "--output-partial-info-plist", partialPlist.path,
      input.path,
    ])
  }

  /// Combines a 1x and 2x image into a multi-resolution TIFF using `tiffutil`.
  private func combineHiDPI(base: URL, retina: URL, output: URL) throws {
    try run("/usr/bin/tiffutil", arguments: [
      "-cathidpicheck", base.path, retina.path,
      "-out", output.path,
    ])
  }

  /// Ad-hoc code signs an app bundle with hardened runtime and the given entitlements file.
  private func codesign(at appDir: URL, entitlements: URL) throws {
    try run("/usr/bin/codesign", arguments: [
      "--sign", "-",
      "--entitlements", entitlements.path,
      "--options", "runtime",
      "--force", "--deep",
      appDir.path,
    ])
  }

  /// Runs an external process synchronously. Throws on non-zero exit.
  @discardableResult
  private func run(_ executable: String, arguments: [String]) throws -> Int32 {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    try process.run()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
      let cmd = ([executable] + arguments).joined(separator: " ")
      throw PluginError(
        "\(URL(fileURLWithPath: executable).lastPathComponent) exited with code "
          + "\(process.terminationStatus).\nCommand: \(cmd)"
      )
    }
    return process.terminationStatus
  }
}

// MARK: - PluginError

struct PluginError: LocalizedError {
  // MARK: Lifecycle

  init(_ message: String) { self.errorDescription = message }

  // MARK: Internal

  let errorDescription: String?
}
