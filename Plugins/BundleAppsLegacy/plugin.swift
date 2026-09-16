// (c) 2022 and onwards The vChewing Project (MulanPSL-2.0 License).
// ====================
// This code is released under the SPDX-License-Identifier: `MulanPSL-2.0`.

// MARK: - BundleAppsLegacy Command Plugin

// Back-deployment support for the legacy (Swift 5.10, `x86_64-apple-macosx10.9`) build:
// collects the Swift runtime dylibs from the back-deployment runtime directories
// (`usr/lib/swift-5.0/macosx` and `usr/lib/swift-5.5/macosx`) of every Xcode bundle found
// under the search root, copies them next to the executables into `<build-dir>/Frameworks/`,
// and appends `@loader_path/Frameworks` to the executables' rpath list when it is missing.
//
// Two tiers decide which runtime a `libswift*.dylib` load command resolves to, and those
// commands are left as `@rpath/…` so that both stay in charge:
//
//   /usr/lib/swift           — the system runtime.  On macOS 10.14.4 and later dyld serves it
//                              from the shared cache, so the copies below are never loaded.
//   @loader_path/Frameworks  — this plugin's copies, appended last.  macOS 10.9–10.13 ships no
//                              `/usr/lib/swift`, so resolution falls through to them.
//
// A record pointing straight into `Frameworks/` would beat both tiers, so the only records
// this plugin edits are left-overs from an older version that wrote exactly that: they are
// normalized back to `@rpath/…`.
//
// Usage:
//   swift package --allow-writing-to-package-directory bundle-apps-legacy -- --debug
//   swift package --allow-writing-to-package-directory bundle-apps-legacy \
//     -- --build-dir .build/.legacy-root/x86_64-apple-macosx/debug
//   swift package --allow-writing-to-package-directory bundle-apps-legacy -- --xcode-root /Applications
//   swift package --allow-writing-to-package-directory bundle-apps-legacy \
//     -- --build-dir .build/.legacy-root/x86_64-apple-macosx/release \
//     --sdk /Library/Developer/CommandLineTools/SDKs/MacOSX13.3.sdk --archive
//
// `--build-dir` matters here because the legacy build normally runs with a custom
// `--scratch-path` (e.g. `.build/.legacy-root`), which moves its products away from the
// default `.build/<triple>/<config>` location the plugin would otherwise look at.
//
// It then assembles the two `.app` bundles the legacy Xcode project produces:
//
//   Build/Products/Legacy/vChewing.app                    — the IME
//   Build/Products/Legacy/vChewingInstallerLegacy.app     — the installer, embedding the IME
//
// The output directory is `Build/Products/Legacy/` and not `Build/Products/<Config>/`: the IME
// bundle has to keep the name `vChewing.app`, which is the name `BundleApps` owns one level up.
// Each bundle carries its own copy of the collected runtime in `Contents/Frameworks/` and gets
// `@executable_path/../Frameworks` appended to its rpath, which is exactly the two-tier lookup the
// legacy Xcode build installs.
//
// The IME bundle takes its lexicon assets from `LegacyZone/LexiconBuildTrigger/Build/` — the 5.10
// build carries no lexicon dependency of its own (`Packages/vChewing_MainAssembly4Darwin/
// Package@swift-5.10.swift` omits it), so those three files are produced out of band by that
// throwaway package.
//
// `--archive` finally writes an `.xcarchive` of those bundles next to them under
// `Build/Products/`, in the same shape `BundleApps` writes for the modern distro, so that the
// legacy distro can be signed and notarized from Xcode Organizer like any other archive. The
// archive is written inside the package directory and not straight into
// `~/Library/Developer/Xcode/Archives/` because a command plugin may only write there; the move is
// `make archiveLegacy`'s job, again the same division of labour as the modern path.

import Foundation
import PackagePlugin

// MARK: - BundleAppsLegacyPlugin

@main
struct BundleAppsLegacyPlugin: CommandPlugin {
  func performCommand(context: PluginContext, arguments: [String]) async throws {
    let fm = FileManager.default
    // `Package.directoryURL` only exists in newer PackagePlugin revisions; the Swift 5.10
    // toolchain that compiles this plugin exposes `Package.directory` instead.
    let packageDir = URL(fileURLWithPath: context.package.directory.string)
    let configName = arguments.contains("--debug") ? "debug" : "release"

    // --archive: also write an `.xcarchive` of the assembled bundles under `Build/Products/`.
    //   `make archiveLegacy` uses it and then moves the archive to the Xcode Archives folder.
    let shouldArchive = arguments.contains("--archive")

    // --xcode-root <path>: where the Xcode bundles are installed.
    let searchRoot = URL(fileURLWithPath: value(of: "--xcode-root", in: arguments) ?? "/Applications")

    // --build-dir <path>: directory holding the legacy build products.
    //   Absolute, or relative to the package root.  Omitted: the default scratch path.
    let buildDir: URL
    if let raw = value(of: "--build-dir", in: arguments) {
      buildDir = raw.hasPrefix("/") ? URL(fileURLWithPath: raw) : packageDir.appendingPathComponent(raw)
    } else {
      buildDir = packageDir
        .appendingPathComponent(".build")
        .appendingPathComponent("x86_64-apple-macosx")
        .appendingPathComponent(configName)
    }

    // --sdk <path>: the SDK the legacy executables were linked against.
    //   `make bundleLegacy` passes the same `MacOSX13.3.sdk` it built with.  Omitted: the assembled
    //   Info.plists carry no `DT*` build-environment metadata at all — better none than a record
    //   describing whichever Xcode this machine happens to default to.
    let sdkPath = value(of: "--sdk", in: arguments)

    // ── Step 1: Locate the legacy executables ──────────────────────────
    let executableURLs = try executableNames.map { name -> URL in
      let url = buildDir.appendingPathComponent(name)
      guard fm.fileExists(atPath: url.path) else {
        throw PluginError(
          "Executable not found at \(url.path). Looked in \(buildDir.path); pass "
            + "--build-dir <path> when the legacy build used a custom --scratch-path "
            + "(it builds into .build/.legacy-root by default)."
        )
      }
      return url
    }
    let executablesByName = Dictionary(uniqueKeysWithValues: zip(executableNames, executableURLs))

    // ── Step 2: Catalog the Swift runtime dylibs shipped inside the Xcodes ──
    print("🔎 Cataloging Swift runtime dylibs under \(searchRoot.path)…")
    let catalog = DylibCatalog(searchRoot: searchRoot)
    print("  \(catalog.bundleCount) Xcode bundle(s), \(catalog.candidateCount) candidate dylib(s).")
    var warnings = [String]()
    var chosen = [String: DylibCandidate]()
    for name in requestedDylibNames {
      guard let candidate = catalog.preferred(named: name) else {
        warnings.append("\(name): not found under any Xcode; skipped.")
        continue
      }
      chosen[name] = candidate
      print(
        "  • \(padded(name, to: 30)) minOS \(padded(candidate.minOSDescription, to: 8)) \(candidate.url.path)"
      )
    }

    // ── Step 3: Read the Swift runtime dependencies of each executable ──
    let links = try executableURLs.map { url -> (executable: URL, dylibs: [LinkedDylib]) in
      (url, try linkedSwiftRuntimeDylibs(of: url))
    }

    // ── Step 4: Resolve names outside the requested set on demand ───────
    for entry in links {
      for dylib in entry.dylibs
        where chosen[dylib.name] == nil && !requestedDylibNames.contains(dylib.name) {
        guard let candidate = catalog.preferred(named: dylib.name) else { continue }
        chosen[dylib.name] = candidate
        print(
          "  + \(dylib.name) (linked by \(entry.executable.lastPathComponent)): "
            + "\(candidate.url.path) [minOS \(candidate.minOSDescription)]"
        )
      }
    }

    // ── Step 5: Copy the runtime next to the executables ────────────────
    let frameworksDir = buildDir.appendingPathComponent("Frameworks")
    try fm.createDirectory(at: frameworksDir, withIntermediateDirectories: true)
    var copied = [String: URL]()
    for name in chosen.keys.sorted() {
      guard let candidate = chosen[name] else { continue }
      let destination = frameworksDir.appendingPathComponent(name)
      try? fm.removeItem(at: destination)
      try fm.copyItem(at: candidate.url, to: destination)
      copied[name] = destination
    }
    print("📦 Copied \(copied.count) dylib(s) into \(frameworksDir.path)")

    // ── Step 6: Normalize left-overs, add the fallback rpath ─────────────
    var unresolved = [String]()
    var modified = [URL]()
    var patchReports = [(executable: String, normalized: Int, rpathAdded: Bool)]()
    for entry in links {
      let executableName = entry.executable.lastPathComponent
      var changes = [String]()
      var normalized = 0
      for dylib in entry.dylibs {
        let destination = frameworksDir.appendingPathComponent(dylib.name)
        if copied[dylib.name] == nil, !fm.fileExists(atPath: destination.path) {
          // No copy was sourced from an Xcode, and none is left over from an earlier run.
          //
          // Only the records this plugin is answerable for are fatal.  `@rpath/…` resolves through
          // the `Frameworks/` copies, so a missing one is a packaging bug; an absolute
          // `/usr/lib/swift/…` record belongs to the system runtime — the two-tier rpath design
          // deliberately leaves it alone — and no back-deployment copy of it exists to ship
          // anyway, so its absence is reported and tolerated.
          //
          // That tolerance is not optional in a universal binary: the slices disagree on the same
          // record.  `libswiftUniformTypeIdentifiers.dylib` is weak in the macOS 10.9 x86_64
          // slice (the overlay did not exist yet) and non-weak in the macOS 11.0 arm64 one (it
          // does), so "a dependency is only as weak as its strictest slice" would condemn a
          // binary that is in fact correct on every system either slice can run on.
          let reason = "\(executableName): dependency \(dylib.recordedPath) is missing"
          if dylib.isWeak || dylib.location == .system {
            warnings.append("\(reason); left to the system runtime.")
          } else {
            unresolved.append(reason)
          }
          continue
        }
        // `@rpath/…` and `/usr/lib/swift/…` records stay as they are; only what an older
        // version of this plugin re-pointed into `Frameworks/` goes back to `@rpath/…`.
        guard dylib.location == .stale else { continue }
        changes += ["-change", dylib.recordedPath, "@rpath/\(dylib.name)"]
        normalized += 1
      }
      if !changes.isEmpty {
        try run("/usr/bin/install_name_tool", arguments: changes + [entry.executable.path])
      }
      let rpathAdded = try addFallbackRPATHIfNeeded(to: entry.executable)
      if !changes.isEmpty || rpathAdded { modified.append(entry.executable) }
      patchReports.append((executableName, normalized, rpathAdded))
    }

    // ── Step 7: Re-sign, since editing load commands drops signatures ───
    // Only the executables were touched; the copies keep Apple's own signatures.
    for url in modified {
      try run("/usr/bin/codesign", arguments: ["--force", "--sign", "-", url.path])
    }

    // ── Step 8: Assemble the two legacy `.app` bundles ──────────────────
    let (appsDir, version) = try assembleAppBundles(
      packageDir: packageDir,
      buildDir: buildDir,
      executables: executablesByName,
      copiedDylibs: copied,
      sdkPath: sdkPath
    )

    // ── Step 9 (optional): Write the `.xcarchive` ───────────────────────
    // `make archiveLegacy` moves it from `Build/Products/` into the Xcode Archives folder; the
    // plugin cannot, since its write access stops at the package directory.
    if shouldArchive {
      print("📁 Writing the .xcarchive…")
      let archiveURL = try assembleXcarchive(
        packageDir: packageDir,
        appsDir: appsDir,
        version: version
      )
      print("  ✓ Archive created: \(archiveURL.path)")
    }

    // ── Step 10: Summary ────────────────────────────────────────────────
    print("")
    print("📋 Summary")
    for report in patchReports {
      print(
        "  \(padded(report.executable, to: 24))\(report.normalized) record(s) normalized to @rpath, "
          + "@loader_path/Frameworks \(report.rpathAdded ? "added" : "already present")."
      )
    }
    print("  Frameworks/ (\(frameworksDir.path)):")
    for name in copied.keys.sorted() {
      guard let candidate = chosen[name] else { continue }
      print(
        "    \(padded(name, to: 30)) minOS \(padded(candidate.minOSDescription, to: 8)) ← "
          + candidate.url.path
      )
    }
    print("  .app (\(appsDir.path)):")
    for name in appBundleNames {
      print("    \(name)")
    }
    for warning in warnings {
      print("  ⚠️  \(warning)")
    }
    print("✅ Done.")

    guard unresolved.isEmpty else {
      throw PluginError(
        "Unresolved non-weak dependency(ies):\n"
          + unresolved.map { "  \($0)" }.joined(separator: "\n")
      )
    }
  }
}

// MARK: - Mach-O Inspection

extension BundleAppsLegacyPlugin {
  /// The `libswift*.dylib` dependencies of `file`, whichever form they are recorded in:
  /// `@rpath/…` and `/usr/lib/swift/…` records are reported as they are, `@loader_path/…`
  /// records are the left-overs of an older version of this plugin.
  ///
  /// `otool -L` prints the dependency list once per architecture slice, so entries are
  /// de-duplicated by their recorded path.  Every record also names a dylib the caller has to
  /// keep shipping next to the executable, no matter which tier ends up supplying it.
  private func linkedSwiftRuntimeDylibs(of file: URL) throws -> [LinkedDylib] {
    let output = try run("/usr/bin/otool", arguments: ["-L", file.path])
    var result = [LinkedDylib]()
    var indexByName = [String: Int]()
    for line in output.split(separator: "\n") {
      let trimmed = line.trimmingCharacters(in: .whitespaces)
      // `otool -L` appends `(compatibility version …)` to every entry.
      let recordedPath = trimmed.components(separatedBy: " (").first ?? trimmed
      let location: LinkedDylib.Location
      if recordedPath.hasPrefix("@rpath/") {
        location = .rpath
      } else if recordedPath.hasPrefix("/usr/lib/swift/") {
        location = .system
      } else if recordedPath.hasPrefix("@loader_path/") {
        location = .stale
      } else {
        continue
      }
      let name = recordedPath.split(separator: "/").last.map(String.init) ?? recordedPath
      guard name.hasPrefix("libswift"), name.hasSuffix(".dylib") else { continue }
      // `otool -L` spells the flag out inside the trailing parenthesised block —
      // `(compatibility version …, current version …, weak)` — so the bare `weak` is what marks it.
      // Lazily-linked dependencies the host system supplies (`/usr/lib/swift/libswiftOSLog.dylib` on
      // macOS 10.12 and later, say) are recorded this way, and their absence has to be tolerated:
      // nothing here can ship them below 10.13, because the back-deployment runtimes predate them.
      let isWeak = trimmed.contains("weak)")
      if let index = indexByName[recordedPath] {
        // A dependency is only as weak as its strictest slice.
        if !isWeak, result[index].isWeak {
          result[index] = LinkedDylib(recordedPath: recordedPath, name: name, isWeak: false, location: location)
        }
        continue
      }
      indexByName[recordedPath] = result.count
      result.append(LinkedDylib(recordedPath: recordedPath, name: name, isWeak: isWeak, location: location))
    }
    return result
  }

  /// The rpath entry the collected copies live behind — the last resort on systems whose
  /// `/usr/lib/swift` does not exist, i.e. macOS 10.9 through 10.13.
  private var fallbackRPATH: String { "@loader_path/Frameworks" }

  /// Appends `fallbackRPATH` to the rpath list of `file` when it is missing.
  ///
  /// It is appended, never prepended, so an existing `/usr/lib/swift` entry stays in front and
  /// keeps supplying the runtime on macOS 10.14.4 and later.  Repeat runs therefore find the
  /// entry already there and change nothing.
  /// - Returns: `true` when the entry was added, `false` when the file already carried it.
  private func addFallbackRPATHIfNeeded(to file: URL) throws -> Bool {
    let existingRPATHs = try rpaths(of: file)
    guard !existingRPATHs.contains(fallbackRPATH) else { return false }
    try run("/usr/bin/install_name_tool", arguments: ["-add_rpath", fallbackRPATH, file.path])
    return true
  }

  /// The `LC_RPATH` entries of `file`, in the order dyld tries them.
  ///
  /// `otool -l` prints the list once per architecture slice, so duplicates are dropped.
  private func rpaths(of file: URL) throws -> [String] {
    let output = try run("/usr/bin/otool", arguments: ["-l", file.path])
    var result = [String]()
    var expectsPathLine = false
    for line in output.split(separator: "\n") {
      let trimmed = line.trimmingCharacters(in: .whitespaces)
      if trimmed.hasPrefix("cmd ") {
        expectsPathLine = trimmed.contains("LC_RPATH")
      } else if expectsPathLine, trimmed.hasPrefix("path ") {
        // `otool -l` appends `(offset …)` to every entry.
        let value = String(trimmed.dropFirst("path ".count)).components(separatedBy: " (offset").first ?? ""
        if !result.contains(value) { result.append(value) }
        expectsPathLine = false
      }
    }
    return result
  }
}

// MARK: - App Bundle Assembly

extension BundleAppsLegacyPlugin {
  /// Assembles both legacy `.app` bundles under `Build/Products/Legacy/`.
  ///
  /// The IME app is assembled first because the installer embeds it verbatim in its
  /// `Contents/Resources/` — the layout the legacy Xcode project produces.
  /// - Returns: The directory holding the two bundles, and the version they were stamped with
  ///   (`--archive` reports that same pair in the archive's `Info.plist`).
  private func assembleAppBundles(
    packageDir: URL,
    buildDir: URL,
    executables: [String: URL],
    copiedDylibs: [String: URL],
    sdkPath: String?
  ) throws
    -> (appsDir: URL, version: (marketing: String, build: String)) {
    let fm = FileManager.default
    let outputDir = packageDir
      .appendingPathComponent("Build")
      .appendingPathComponent("Products")
      .appendingPathComponent("Legacy")
    try fm.createDirectory(at: outputDir, withIntermediateDirectories: true)

    let imeApp = outputDir.appendingPathComponent(imeBundleName)
    let installerApp = outputDir.appendingPathComponent(installerBundleName)
    for app in [imeApp, installerApp] {
      try? fm.removeItem(at: app)
    }

    guard let imeExecutable = executables[imeExecutableName] else {
      throw PluginError("\(imeExecutableName) was not located; cannot assemble \(imeBundleName).")
    }
    guard let installerExecutable = executables[installerExecutableName] else {
      throw PluginError(
        "\(installerExecutableName) was not located; cannot assemble \(installerBundleName)."
      )
    }

    let version = try readVersionInfo(
      from: packageDir.appendingPathComponent("Release-Version.plist")
    )
    let lexiconDir = packageDir
      .appendingPathComponent("LegacyZone")
      .appendingPathComponent("LexiconBuildTrigger")
      .appendingPathComponent("Build")
    // Failing here with the fix spelled out beats the raw `copyItem` error a missing directory would
    // raise later: both build targets chain into this one, so an unbuilt lexicon stops `make
    // debugLegacy` / `make releaseLegacy` too, not just a hand-run `bundleLegacy`.
    guard fm.fileExists(atPath: lexiconDir.path) else {
      throw PluginError(
        "Lexicon assets not found at \(lexiconDir.path).\nBuild them first:\n"
          + "  make -C LegacyZone/LexiconBuildTrigger build510 collect"
      )
    }
    // Resolved once and handed to both bundles: the same toolchain assembled both,
    // so both should report the same build environment.
    let infoPlistKeys = try legacyInfoPlistAdditionalKeys(sdkPath: sdkPath)
    if let sdkName = infoPlistKeys["DTSDKName"] as? String,
       let dtXcode = infoPlistKeys["DTXcode"] as? String {
      print("🏷  Info.plist build environment: DTSDKName \(sdkName), DTXcode \(dtXcode).")
    } else {
      print("⚠️  No --sdk passed; the Info.plists will carry no DT* build-environment metadata.")
    }

    print("📦 Assembling \(imeBundleName)…")
    try assembleMainIMEApp(
      appDir: imeApp,
      packageDir: packageDir,
      buildDir: buildDir,
      executableURL: imeExecutable,
      copiedDylibs: copiedDylibs,
      lexiconDir: lexiconDir,
      version: version,
      additionalInfoPlistKeys: infoPlistKeys
    )
    print("  ✓ \(imeBundleName) assembled.")

    print("📦 Assembling \(installerBundleName)…")
    try assembleInstallerApp(
      appDir: installerApp,
      packageDir: packageDir,
      buildDir: buildDir,
      executableURL: installerExecutable,
      embeddedIMEApp: imeApp,
      copiedDylibs: copiedDylibs,
      version: version,
      additionalInfoPlistKeys: infoPlistKeys
    )
    print("  ✓ \(installerBundleName) assembled.")
    return (outputDir, version)
  }

  /// Assembles the IME app: the executable, its own copy of the Swift runtime, the resources the
  /// modern `vChewing.app` also carries, and the lexicon assets the 5.10 manifest cannot inject.
  private func assembleMainIMEApp(
    appDir: URL,
    packageDir: URL,
    buildDir: URL,
    executableURL: URL,
    copiedDylibs: [String: URL],
    lexiconDir: URL,
    version: (marketing: String, build: String),
    additionalInfoPlistKeys: [String: Any]
  ) throws {
    let fm = FileManager.default
    let contents = appDir.appendingPathComponent("Contents")
    let macOS = contents.appendingPathComponent("MacOS")
    let resources = contents.appendingPathComponent("Resources")
    let srcRes = packageDir
      .appendingPathComponent("Sources")
      .appendingPathComponent("vChewingIME_macOS")
      .appendingPathComponent("Resources")

    try fm.createDirectory(at: macOS, withIntermediateDirectories: true)
    try fm.createDirectory(at: resources, withIntermediateDirectories: true)

    // ── Executable ──
    let mainExecutable = macOS.appendingPathComponent(imeExecutableName)
    try fm.copyItem(at: executableURL, to: mainExecutable)
    let embeddedDylibs = try embedRuntimeDylibs(
      copiedDylibs, into: appDir, executable: mainExecutable
    )

    // ── PkgInfo ── (`CFBundleSignature` of the IME target: `MACV`.)
    try Data("APPLMACV".utf8).write(to: contents.appendingPathComponent("PkgInfo"))

    // ── Info.plist ──
    try processInfoPlist(
      source: srcRes.appendingPathComponent("Info.plist"),
      destination: contents.appendingPathComponent("Info.plist"),
      substitutions: [
        "$(PRODUCT_BUNDLE_IDENTIFIER)": imeBundleIdentifier,
        "$(MARKETING_VERSION)": version.marketing,
        "$(CURRENT_PROJECT_VERSION)": version.build,
        "${EXECUTABLE_NAME}": imeExecutableName,
        "${PRODUCT_NAME}": imeExecutableName,
        "${MACOSX_DEPLOYMENT_TARGET}": legacyDeploymentTarget,
      ],
      additionalKeys: additionalInfoPlistKeys
    )

    // ── Compile xcassets → Assets.car + AppIcon.icns ──
    try compileXcassets(
      input: srcRes.appendingPathComponent("Images.xcassets"),
      output: resources,
      deploymentTarget: legacyDeploymentTarget,
      appIcon: "AppIcon"
    )

    // ── Combine HiDPI menu icons → .tiff ──
    let menuIconsDir = srcRes.appendingPathComponent("MenuIcons")
    for name in ["MenuIcon-TCVIM", "MenuIcon-SCVIM"] {
      try combineHiDPI(
        base: menuIconsDir.appendingPathComponent("\(name).png"),
        retina: menuIconsDir.appendingPathComponent("\(name)@2x.png"),
        output: resources.appendingPathComponent("\(name).tiff")
      )
    }

    // ── Localization directories ──
    // The legacy distro announces itself in the About pane, which renders the bundle's
    // `NSHumanReadableCopyright`; the override lives under `LegacyZone/` for the same reason the
    // installer's does — see `assembleInstallerApp`.
    let legacyIMELocalizations = packageDir
      .appendingPathComponent("LegacyZone")
      .appendingPathComponent("IMELocalizations")
    for lproj in ["Base.lproj", "en.lproj", "ja.lproj", "zh-Hans.lproj", "zh-Hant.lproj"] {
      let src = srcRes.appendingPathComponent(lproj)
      guard fm.fileExists(atPath: src.path) else { continue }
      let destination = resources.appendingPathComponent(lproj)
      try fm.copyItem(at: src, to: destination)
      try mergeLegacyLocalizedOverrides(
        into: destination, overridesFrom: legacyIMELocalizations.appendingPathComponent(lproj)
      )
    }

    // ── Sound files ──
    for file in ["Beep.m4a", "Fart.m4a"] {
      try fm.copyItem(
        at: srcRes.appendingPathComponent("SoundFiles").appendingPathComponent(file),
        to: resources.appendingPathComponent(file)
      )
    }

    // ── Template files ──
    for file in [
      "template-exclusions.txt", "template-replacements.txt",
      "template-userphrases.txt", "template-usersymbolphrases.txt",
    ] {
      try fm.copyItem(
        at: srcRes.appendingPathComponent(file),
        to: resources.appendingPathComponent(file)
      )
    }

    // ── Keyboard layout bundle ──
    try fm.copyItem(
      at: srcRes.appendingPathComponent("vChewingKeyLayout.bundle"),
      to: resources.appendingPathComponent("vChewingKeyLayout.bundle")
    )

    // ── Root-level license and script files ──
    for file in [
      "LICENSE.txt", "LICENSE-CHT.txt", "LICENSE-CHS.txt", "LICENSE-JPN.txt",
      "fixinstall.sh", "uninstall.sh",
    ] {
      try fm.copyItem(
        at: packageDir.appendingPathComponent(file),
        to: resources.appendingPathComponent(file)
      )
    }

    // ── Resources from the build directory ──
    try copyResourceBundles(from: buildDir, into: resources)
    try copyLexiconAssets(from: lexiconDir, into: resources)

    // ── Code sign ──
    // The same three keys the modern plugin injects for its IME app; the legacy Xcode target
    // carries them in `vChewing.entitlements` itself, and the shared file deliberately leaves them
    // out (the modern plugin injects them at signing time).
    //
    // Unlike the modern plugin, no `com.apple.security.cs.disable-library-validation` is needed:
    // the dylibs embedded here are Apple's own back-deployment runtime, which library validation
    // accepts on its own terms, whereas the modern path embeds an ad-hoc-signed `libVanguard.dylib`.
    let additionalEntitlements: [String: Any] = [
      "com.apple.security.app-sandbox": true,
      "com.apple.security.network.client": true,
      "com.apple.security.files.user-selected.read-write": true,
    ]
    let processedEntitlements = try processEntitlements(
      source: srcRes.appendingPathComponent("vChewing.entitlements"),
      bundleIdentifier: imeBundleIdentifier,
      additionalEntitlements: additionalEntitlements
    )
    try codesign(at: appDir, entitlements: processedEntitlements, nestedCode: embeddedDylibs)
  }

  /// Assembles the installer app and embeds the finished IME app in its `Contents/Resources/`.
  private func assembleInstallerApp(
    appDir: URL,
    packageDir: URL,
    buildDir: URL,
    executableURL: URL,
    embeddedIMEApp: URL,
    copiedDylibs: [String: URL],
    version: (marketing: String, build: String),
    additionalInfoPlistKeys: [String: Any]
  ) throws {
    let fm = FileManager.default
    let contents = appDir.appendingPathComponent("Contents")
    let macOS = contents.appendingPathComponent("MacOS")
    let resources = contents.appendingPathComponent("Resources")
    let srcRes = packageDir
      .appendingPathComponent("Sources")
      .appendingPathComponent("Installer_macOS")
      .appendingPathComponent("Resources")

    try fm.createDirectory(at: macOS, withIntermediateDirectories: true)
    try fm.createDirectory(at: resources, withIntermediateDirectories: true)

    // ── Executable ──
    let mainExecutable = macOS.appendingPathComponent(installerExecutableName)
    try fm.copyItem(at: executableURL, to: mainExecutable)
    let embeddedDylibs = try embedRuntimeDylibs(
      copiedDylibs, into: appDir, executable: mainExecutable
    )

    // ── PkgInfo ── (`CFBundleSignature` of the installer target: `MBIN`.)
    try Data("APPLMBIN".utf8).write(to: contents.appendingPathComponent("PkgInfo"))

    // ── Info.plist ──
    // The executable is renamed on this path, so both `${EXECUTABLE_NAME}` and `${PRODUCT_NAME}`
    // have to be substituted; `LSMinimumSystemVersion` comes from the template as well and is
    // pinned to the deployment target the 5.10 binaries are actually built for.
    try processInfoPlist(
      source: srcRes.appendingPathComponent("Info.plist"),
      destination: contents.appendingPathComponent("Info.plist"),
      substitutions: [
        "$(PRODUCT_BUNDLE_IDENTIFIER)": installerBundleIdentifier,
        "$(MARKETING_VERSION)": version.marketing,
        "$(CURRENT_PROJECT_VERSION)": version.build,
        "${EXECUTABLE_NAME}": installerExecutableName,
        "${PRODUCT_NAME}": installerExecutableName,
        "${MACOSX_DEPLOYMENT_TARGET}": legacyDeploymentTarget,
      ],
      additionalKeys: additionalInfoPlistKeys
    )

    // ── Compile xcassets ──
    try compileXcassets(
      input: srcRes.appendingPathComponent("Images.xcassets"),
      output: resources,
      deploymentTarget: legacyDeploymentTarget,
      appIcon: "AppIcon"
    )

    // ── Localization directories ──
    // These are the modern installer's own directories; the legacy display names are merged in
    // afterwards, because one package target can only carry one set of `.lproj` files and the two
    // installers have to be told apart by name once both are installed. The overrides deliberately
    // live under `LegacyZone/` rather than beside these directories: `Sources/Installer_macOS` is an
    // Xcode synchronized root group, so a new sibling directory there would be swept into the modern
    // installer's copy-resources phase too. (The IME's own overrides live in the sibling
    // `LegacyZone/IMELocalizations/`; see `assembleMainIMEApp`.)
    let legacyInstallerLocalizations = packageDir
      .appendingPathComponent("LegacyZone")
      .appendingPathComponent("InstallerLocalizations")
    for lproj in ["en.lproj", "ja.lproj", "zh-Hans.lproj", "zh-Hant.lproj"] {
      let src = srcRes.appendingPathComponent(lproj)
      guard fm.fileExists(atPath: src.path) else { continue }
      let destination = resources.appendingPathComponent(lproj)
      try fm.copyItem(at: src, to: destination)
      try mergeLegacyLocalizedOverrides(
        into: destination, overridesFrom: legacyInstallerLocalizations.appendingPathComponent(lproj)
      )
    }

    // ── Embed the entire IME app ──
    // Already signed by the step above, so the outer signature seals it as it stands.
    try fm.copyItem(at: embeddedIMEApp, to: resources.appendingPathComponent(imeBundleName))

    // ── Code sign ──
    let processedEntitlements = try processEntitlements(
      source: srcRes.appendingPathComponent("vChewingInstaller.entitlements"),
      bundleIdentifier: installerBundleIdentifier
    )
    try codesign(at: appDir, entitlements: processedEntitlements, nestedCode: embeddedDylibs)
  }
}

// MARK: - App Bundle Helpers

extension BundleAppsLegacyPlugin {
  /// Copies the collected runtime into `Contents/Frameworks/` and appends the bundle-relative
  /// rpath entry that reaches it.
  ///
  /// The entry is appended, never prepended: the executables already carry `/usr/lib/swift` from
  /// SwiftPM, which has to keep winning on every macOS that ships a Swift runtime of its own.
  ///
  /// - Returns: the copies, so the caller can sign them before the enclosing bundle.
  private func embedRuntimeDylibs(
    _ dylibs: [String: URL],
    into appDir: URL,
    executable: URL
  ) throws
    -> [URL] {
    let fm = FileManager.default
    let frameworks = appDir.appendingPathComponent("Contents").appendingPathComponent("Frameworks")
    var embedded = [URL]()
    for name in dylibs.keys.sorted() {
      guard let source = dylibs[name] else { continue }
      try fm.createDirectory(at: frameworks, withIntermediateDirectories: true)
      let destination = frameworks.appendingPathComponent(name)
      try? fm.removeItem(at: destination)
      try fm.copyItem(at: source, to: destination)
      embedded.append(destination)
    }
    let existing = try rpaths(of: executable)
    try pruneForeignRPATHs(of: executable)
    guard !existing.contains(bundleFallbackRPATH) else { return embedded }
    try run("/usr/bin/install_name_tool", arguments: [
      "-add_rpath", bundleFallbackRPATH, executable.path,
    ])
    return embedded
  }

  /// Drops absolute `LC_RPATH` entries that point outside the system, so the assembled bundle does
  /// not carry the build machine's layout.
  ///
  /// SwiftPM records the toolchain that supplied the Swift runtime as an absolute rpath — here
  /// `…/swift-5.10.1-RELEASE.xctoolchain/usr/lib/swift-5.5/macosx`.  Inside a bundle that entry can
  /// never win: it sits behind `/usr/lib/swift`, and on a system without that path the target
  /// machine does not have the build machine's toolchain either.  It is still a path that only
  /// exists on the machine that ran the build, so it goes.
  ///
  /// System locations are spared — `/usr/lib/swift` is the tier that has to keep winning on every
  /// macOS that ships a Swift runtime of its own, and `/System` needs no explanation.  Entries that
  /// do not start with `/` are relative to the bundle (`@executable_path/…`, `@loader_path/…`) and
  /// are left alone.
  private func pruneForeignRPATHs(of executable: URL) throws {
    for entry in try rpaths(of: executable) where entry.hasPrefix("/") {
      guard !isSystemRPATH(entry) else { continue }
      try run("/usr/bin/install_name_tool", arguments: [
        "-delete_rpath", entry, executable.path,
      ])
      print("  − \(executable.lastPathComponent): dropped rpath \(entry)")
    }
  }

  /// Whether an absolute rpath names a location the running system owns.
  private func isSystemRPATH(_ path: String) -> Bool {
    path == "/usr/lib/swift" || path.hasPrefix("/usr/lib/") || path.hasPrefix("/System/")
  }

  /// The bundle-relative counterpart of `@loader_path/Frameworks`.
  private var bundleFallbackRPATH: String { "@executable_path/../Frameworks" }

  /// Copies every SPM resource bundle next to the built executables into `Contents/Resources/`.
  ///
  /// The 5.10 manifest declares no test targets, so unlike the modern plugin there is nothing to
  /// filter out here; the two bundles the build actually produces are the BPMFVS lookup table and
  /// the `convdict.stringmap` of `MainAssembly4Darwin`.  Each copy is then stamped (see
  /// `stampFlatBundleInfoPlist`).
  private func copyResourceBundles(from buildDir: URL, into resources: URL) throws {
    let fm = FileManager.default
    let entries = (try? fm.contentsOfDirectory(
      at: buildDir, includingPropertiesForKeys: [.isDirectoryKey]
    )) ?? []
    for entry in entries where entry.pathExtension == "bundle" {
      let destination = resources.appendingPathComponent(entry.lastPathComponent)
      if !fm.fileExists(atPath: destination.path) {
        try fm.copyItem(at: entry, to: destination)
        print("  • \(entry.lastPathComponent)")
      }
      try stampFlatBundleInfoPlist(destination)
    }
  }

  /// Gives a flat SwiftPM resource bundle the `Info.plist` it lacks.
  ///
  /// SwiftPM 5.10 lays a resource bundle out flat — the payload and nothing else — while 6.x wraps
  /// it in `Contents/` and writes a full `Contents/Info.plist`.  A directory carrying neither is
  /// accepted by `Bundle(url:)` on the systems this was tried on, but that is not a shape
  /// Foundation promises to treat as a bundle, and `ResourceLocator` resolves every resource
  /// through exactly that call.  The classic flat layout — `Info.plist` beside the payload at the
  /// root — is stamped in instead of restructuring the directory, because moving the payload under
  /// `Contents/Resources/` would take it out of the directory `Bundle.resourceURL` reports.
  ///
  /// Bundles that already carry an `Info.plist`, in either layout, are left alone.
  private func stampFlatBundleInfoPlist(_ bundle: URL) throws {
    let fm = FileManager.default
    let flat = bundle.appendingPathComponent("Info.plist")
    let structured = bundle
      .appendingPathComponent("Contents")
      .appendingPathComponent("Info.plist")
    guard !fm.fileExists(atPath: flat.path), !fm.fileExists(atPath: structured.path) else { return }
    let name = bundle.deletingPathExtension().lastPathComponent
    let plist: [String: Any] = [
      "CFBundleDevelopmentRegion": "en",
      "CFBundleIdentifier": "\(legacyResourceBundleIdentifierPrefix).\(name)",
      "CFBundleInfoDictionaryVersion": "6.0",
      "CFBundleName": name,
      "CFBundlePackageType": "BNDL",
      "CFBundleSupportedPlatforms": ["MacOSX"],
    ]
    let data = try PropertyListSerialization.data(
      fromPropertyList: plist, format: .xml, options: 0
    )
    try data.write(to: flat)
    print("  + \(bundle.lastPathComponent)/Info.plist (flat-bundle stamp)")
  }

  /// Places the factory lexicon and the associated-phrase templates produced by
  /// `LegacyZone/LexiconBuildTrigger` inside `MainAssembly4Darwin_MainAssembly4Darwin.bundle`.
  ///
  /// That bundle is what `Bundle.currentSPM` resolves, and the `.txtMap` is read from it by
  /// `LXMgr.getBundleDataPath`; the associated-phrase templates sit next to it because that is
  /// exactly where the modern build's injector plugins leave all three.  Nothing is copied flat
  /// into `Contents/Resources/` — the modern `vChewing.app` does not carry them there either, so
  /// the two builds keep the same layout.
  private func copyLexiconAssets(from lexiconDir: URL, into resources: URL) throws {
    let fm = FileManager.default
    guard fm.fileExists(atPath: lexiconDir.path) else {
      print("  ⚠️  No lexicon assets at \(lexiconDir.path) — run the LexiconBuildTrigger package first.")
      return
    }
    let spmBundle = resources.appendingPathComponent(spmResourceBundleName)
    // SwiftPM 5.10 writes a resource bundle flat — the payload sits directly inside the `.bundle`
    // — while 6.x wraps it in `Contents/Resources/`.  Whichever shape the build produced is the
    // directory `Bundle(url:)` hands back as its `resourceURL`, so that is the one to write into.
    let structuredResources = spmBundle
      .appendingPathComponent("Contents")
      .appendingPathComponent("Resources")
    let spmBundleResources = fm.fileExists(atPath: structuredResources.path)
      ? structuredResources
      : spmBundle
    for name in lexiconAssetNames {
      let source = lexiconDir.appendingPathComponent(name)
      guard fm.fileExists(atPath: source.path) else {
        print("  ⚠️  Missing lexicon asset \(name) in \(lexiconDir.path).")
        continue
      }
      try fm.copyItem(at: source, to: spmBundleResources.appendingPathComponent(name))
      print("  • \(name)")
    }
  }

  /// Reads marketing version and build version from `Release-Version.plist`.
  private func readVersionInfo(from url: URL) throws -> (marketing: String, build: String) {
    let data = try Data(contentsOf: url)
    guard let plist = try PropertyListSerialization.propertyList(
      from: data, format: nil
    ) as? [String: Any] else {
      throw PluginError("Cannot parse \(url.lastPathComponent).")
    }
    let marketing = plist["CFBundleShortVersionString"] as? String ?? "0.0.0"
    let build = plist["CFBundleVersion"] as? String ?? "0"
    return (marketing, build)
  }

  /// Reads the template Info.plist, substitutes Xcode build variables and injects additional keys.
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

  /// Merges a `LegacyZone/<…>Localizations/<lproj>/InfoPlist.strings` over the localization
  /// directory that was just copied, so the assembled bundle disagrees with the source it came from.
  ///
  /// Two callers, one per bundle, each with its own override directory:
  ///
  /// - `IMELocalizations` restates `NSHumanReadableCopyright` as `Aqua Special Build. …`. The About
  ///   pane of `SettingsCocoa` prints that key verbatim (`SettingsPanesCocoa.About.copyrightLabel`),
  ///   so this is what marks the legacy distro inside the running input method — the key itself is
  ///   read through `Bundle.localizedInfoDictionary`, which is why the marker has to be localizable.
  /// - `InstallerLocalizations` restates `CFBundleName`. The legacy installer shares its `.lproj`
  ///   directories with the modern one, and a differing name is the only thing that keeps the two
  ///   apart once both sit in `/Applications` — the shared `Info.plist` already sets
  ///   `LSHasLocalizedDisplayName`, which is what makes LaunchServices read the name out of this file
  ///   instead of off the bundle's file name. The bundle on disk therefore stays
  ///   `vChewingInstallerLegacy.app` while Finder shows the legacy name.
  ///
  /// Merging rather than replacing is deliberate: `CFEULAContent`, which the About window reads
  /// through `Bundle.localizedInfoDictionary`, has to survive the copy untouched.
  private func mergeLegacyLocalizedOverrides(
    into lprojDir: URL,
    overridesFrom overrideDir: URL
  ) throws {
    let fm = FileManager.default
    let overrideFile = overrideDir.appendingPathComponent("InfoPlist.strings")
    guard fm.fileExists(atPath: overrideFile.path) else { return }
    let destination = lprojDir.appendingPathComponent("InfoPlist.strings")
    guard fm.fileExists(atPath: destination.path) else {
      try fm.copyItem(at: overrideFile, to: destination)
      return
    }
    guard var merged = try stringsDictionary(at: destination) else {
      throw PluginError("Cannot parse \(destination.path) as a strings file.")
    }
    let overrides = try stringsDictionary(at: overrideFile) ?? [:]
    for (key, value) in overrides {
      merged[key] = value
    }
    let output = try PropertyListSerialization.data(
      fromPropertyList: merged, format: .xml, options: 0
    )
    try output.write(to: destination)
    let summary = overrides.keys.sorted()
      .map { "\($0) → \(overrides[$0] ?? "")" }
      .joined(separator: ", ")
    print("  + \(lprojDir.lastPathComponent)/InfoPlist.strings: \(summary)")
  }

  /// Reads a strings file in whichever plist form it happens to be — the repository keeps them in
  /// the old-style `.strings` syntax, while the files this plugin rewrites come back as XML.
  private func stringsDictionary(at url: URL) throws -> [String: String]? {
    let data = try Data(contentsOf: url)
    var format = PropertyListSerialization.PropertyListFormat.openStep
    return try? PropertyListSerialization.propertyList(
      from: data, options: [], format: &format
    ) as? [String: String]
  }

  /// Processes an entitlements plist by substituting `$(PRODUCT_BUNDLE_IDENTIFIER)` and injecting
  /// the entitlements the target declares through build settings rather than in the file.
  /// - Returns: a temporary file URL suitable for passing to `codesign`.
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
      .appendingPathComponent("entitlements-\(UUID().uuidString).plist")
    try output.write(to: tmp)
    return tmp
  }

  /// Compiles an `.xcassets` catalog with `actool`, producing `Assets.car` and `AppIcon.icns`.
  private func compileXcassets(
    input: URL,
    output: URL,
    deploymentTarget: String,
    appIcon: String
  ) throws {
    let partialPlist = FileManager.default.temporaryDirectory
      .appendingPathComponent("actool-partial-\(UUID().uuidString).plist")
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

  /// Combines a 1x and 2x image into a multi-resolution TIFF with `tiffutil`.
  private func combineHiDPI(base: URL, retina: URL, output: URL) throws {
    try run("/usr/bin/tiffutil", arguments: [
      "-cathidpicheck", base.path, retina.path,
      "-out", output.path,
    ])
  }

  /// Signs a code object ad-hoc with the hardened runtime. Entitlements belong to the bundle
  /// itself; nested code (the embedded runtime) gets none. Nested code is signed first so that no
  /// `--deep` is needed.
  private func codesign(at target: URL, entitlements: URL? = nil, nestedCode: [URL] = []) throws {
    for nested in nestedCode {
      try codesign(at: nested)
    }
    var arguments = ["--sign", "-", "--options", "runtime", "--force"]
    if let entitlements {
      arguments += ["--entitlements", entitlements.path]
    }
    arguments.append(target.path)
    try run("/usr/bin/codesign", arguments: arguments)
  }
}

// MARK: - .xcarchive Assembly

extension BundleAppsLegacyPlugin {
  /// Assembles an `.xcarchive` of the two legacy bundles, in the layout `BundleApps` writes for the
  /// modern distro so that Organizer reads both the same way:
  ///
  /// ```
  /// Name.xcarchive/
  ///   Info.plist
  ///   Products/Applications/vChewingInstallerLegacy.app/
  ///   dSYMs/
  ///     vChewing.app.dSYM/
  ///     vChewingInstallerLegacy.app.dSYM/
  /// ```
  ///
  /// The installer goes under `Products/Applications/` because it is the artifact that carries the
  /// IME — the IME rides inside its `Contents/Resources/` — so it is what a distributable archive is
  /// built around; the modern side archives `vChewingInstaller.app` for the same reason. dSYMs are
  /// emitted for both executables, so that a report naming either bundle can be symbolicated.
  /// `SwiftSupport/` is deliberately absent: it exists for App Store uploads of apps that ship the
  /// Swift runtime, while this archive is meant for Developer ID signing and notarization.
  ///
  /// The archive is written under `Build/Products/` and not straight into the Xcode Archives folder
  /// because a command plugin may only write inside the package directory; `make archiveLegacy`
  /// moves it from there.
  private func assembleXcarchive(
    packageDir: URL,
    appsDir: URL,
    version: (marketing: String, build: String)
  ) throws
    -> URL {
    let fm = FileManager.default

    // `vChewingInstallerLegacy-YYYY-M-D-HHMMhrs.xcarchive` — the shape `BundleApps` uses for the
    // modern distro's `vChewingInstaller-…`, and the shape Organizer expects to find.
    let now = Date()
    let calendar = Calendar.current
    let stamp = [
      "\(calendar.component(.year, from: now))",
      "\(calendar.component(.month, from: now))",
      "\(calendar.component(.day, from: now))",
      String(
        format: "%02d%02d",
        calendar.component(.hour, from: now),
        calendar.component(.minute, from: now)
      ),
    ].joined(separator: "-")
    let archiveDir = packageDir
      .appendingPathComponent("Build")
      .appendingPathComponent("Products")
      .appendingPathComponent("\(installerExecutableName)-\(stamp)hrs.xcarchive")
    try? fm.removeItem(at: archiveDir)
    try fm.createDirectory(at: archiveDir, withIntermediateDirectories: true)

    // ── Products/Applications/ ──
    let productsApps = archiveDir
      .appendingPathComponent("Products")
      .appendingPathComponent("Applications")
    try fm.createDirectory(at: productsApps, withIntermediateDirectories: true)
    try fm.copyItem(
      at: appsDir.appendingPathComponent(installerBundleName),
      to: productsApps.appendingPathComponent(installerBundleName)
    )

    // ── dSYMs/ ──
    // Moved, not copied, into the archive: `Build/Products/Legacy/` keeps the bundles themselves,
    // and the debug maps the executables carry still point at the object files under `.build`.
    let dSYMs = archiveDir.appendingPathComponent("dSYMs")
    try fm.createDirectory(at: dSYMs, withIntermediateDirectories: true)
    for name in executableNames {
      let executable = appsDir
        .appendingPathComponent("\(name).app")
        .appendingPathComponent("Contents")
        .appendingPathComponent("MacOS")
        .appendingPathComponent(name)
      try run("/usr/bin/xcrun", arguments: [
        "dsymutil", executable.path,
        "-o", dSYMs.appendingPathComponent("\(name).app.dSYM").path,
      ])
    }

    // ── Info.plist ──
    // `SigningIdentity` and `Team` are left empty on purpose: the bundles are only ad-hoc signed
    // here, and the Developer ID identity is whatever the machine doing the export has.
    let archiveInfo: [String: Any] = [
      "ArchiveVersion": 2,
      "CreationDate": now,
      "Name": installerExecutableName,
      "SchemeName": installerExecutableName,
      "ApplicationProperties": [
        "ApplicationPath": "Applications/\(installerBundleName)",
        "Architectures": try detectArchitectures(
          of: appsDir
            .appendingPathComponent(installerBundleName)
            .appendingPathComponent("Contents")
            .appendingPathComponent("MacOS")
            .appendingPathComponent(installerExecutableName)
        ),
        "CFBundleIdentifier": installerBundleIdentifier,
        "CFBundleShortVersionString": version.marketing,
        "CFBundleVersion": version.build,
        "SigningIdentity": "",
        "Team": "",
      ] as [String: Any],
    ]
    let plistData = try PropertyListSerialization.data(
      fromPropertyList: archiveInfo, format: .xml, options: 0
    )
    try plistData.write(to: archiveDir.appendingPathComponent("Info.plist"))

    return archiveDir
  }

  /// The architecture names `lipo` reports for an executable — what a legacy archive has to record,
  /// since `x86_64` and `arm64` come from two separate `swift build` runs that were `lipo`ed.
  private func detectArchitectures(of executable: URL) throws -> [String] {
    try runForStdout("/usr/bin/lipo", arguments: ["-archs", executable.path])
      .split(separator: " ")
      .map(String.init)
  }
}

// MARK: - DylibCandidate

/// One Xcode-bundled dylib, with the deployment target its Mach-O load commands record.
private struct DylibCandidate {
  let url: URL
  let minOS: RuntimeVersion?

  var minOSDescription: String { minOS?.description ?? "unknown" }
}

// MARK: - RuntimeVersion

/// A dotted version number, comparable component by component.
private struct RuntimeVersion: Comparable {
  // MARK: Lifecycle

  init?(_ text: String) {
    let parts = text.split(separator: ".").map { Int($0) ?? 0 }
    guard !parts.isEmpty else { return nil }
    var padded = parts
    while padded.count < 3 { padded.append(0) }
    self.components = padded
  }

  // MARK: Internal

  let components: [Int]

  var description: String {
    var parts = components
    while parts.count > 1, parts.last == 0 { parts.removeLast() }
    return parts.map(String.init).joined(separator: ".")
  }

  static func < (lhs: Self, rhs: Self) -> Bool {
    for (left, right) in zip(lhs.components, rhs.components) {
      if left != right { return left < right }
    }
    return false
  }
}

// MARK: - DylibCatalog

/// Every `libswift*.dylib` found in the two back-deployment runtime directories of an Xcode.
///
/// Only top-level `*Xcode*.app` entries of the search root are considered — unrelated applications
/// in `/Applications` embed `libswiftCore.dylib` copies of their own — and, inside each of them,
/// only these two directories are listed:
///
///   Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift-5.0/macosx/
///   Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift-5.5/macosx/
///
/// Those are the ones whose contents target macOS 10.9: the sibling `swift`, `swift_static` and
/// `swift-6.x` directories hold same-named dylibs built for newer deployment targets, and the
/// `iphoneos` / `watchos` / `appletvos` / `*simulator` trees hold the same names for other
/// platforms.  Nothing else is walked.  Symbolic links are never followed and candidates are
/// de-duplicated by resolved path, so a symlinked Xcode contributes only once.
private struct DylibCatalog {
  // MARK: Lifecycle

  init(searchRoot: URL) {
    var found = [String: [URL]]()
    var visited = Set<String>()
    var bundles = 0
    for bundle in Self.xcodeBundles(in: searchRoot) {
      bundles += 1
      for subpath in Self.runtimeSubpaths {
        Self.collect(from: bundle.appendingPathComponent(subpath), into: &found, visited: &visited)
      }
    }
    self.byName = found
    self.bundleCount = bundles
    self.candidateCount = found.values.reduce(0) { $0 + $1.count }
  }

  // MARK: Internal

  let bundleCount: Int
  let candidateCount: Int

  /// Candidates for `name`, best first: lowest `minOS`, then the shortest path, then
  /// lexicographically.  The oldest runtime is preferred because it is the one that still
  /// starts on the oldest supported systems.
  func preferred(named name: String) -> DylibCandidate? {
    let ranked = (byName[name] ?? [])
      .map { DylibCandidate(url: $0, minOS: minimumOSVersion(of: $0)) }
      .sorted { left, right in
        switch (left.minOS, right.minOS) {
        case let (leftValue?, rightValue?) where leftValue != rightValue:
          return leftValue < rightValue
        case (nil, _?):
          return false
        case (_?, nil):
          return true
        default:
          break
        }
        if left.url.path.count != right.url.path.count {
          return left.url.path.count < right.url.path.count
        }
        return left.url.path < right.url.path
      }
    return ranked.first
  }

  // MARK: Private

  /// The back-deployment runtime directories of an Xcode bundle, relative to the bundle root.
  private static let runtimeSubpaths = [
    "Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift-5.0/macosx",
    "Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift-5.5/macosx",
  ]

  private let byName: [String: [URL]]

  private static func xcodeBundles(in searchRoot: URL) -> [URL] {
    let fm = FileManager.default
    let entries = (try? fm.contentsOfDirectory(
      at: searchRoot, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey]
    )) ?? []
    return entries.filter { entry in
      let name = entry.lastPathComponent
      guard name.hasSuffix(".app"), name.contains("Xcode") else { return false }
      guard let values = try? entry.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]) else {
        return false
      }
      return values.isDirectory == true && values.isSymbolicLink != true
    }
  }

  /// Lists one back-deployment runtime directory.  Nothing below it is entered: the two
  /// `runtimeSubpaths` above are the complete source of truth.
  private static func collect(from directory: URL, into found: inout [String: [URL]], visited: inout Set<String>) {
    let fm = FileManager.default
    let keys: [URLResourceKey] = [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey]
    let children = (try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: keys)) ?? []
    for child in children {
      guard let values = try? child.resourceValues(forKeys: Set(keys)),
            values.isSymbolicLink != true,
            values.isRegularFile == true else { continue }
      let name = child.lastPathComponent
      guard name.hasPrefix("libswift"), name.hasSuffix(".dylib") else { continue }
      guard visited.insert(child.resolvingSymlinksInPath().path).inserted else { continue }
      found[name, default: []].append(child)
    }
  }
}

/// The deployment target recorded in the Mach-O load commands of `file`, or nil when the
/// file cannot be inspected.
///
/// `vtool -show-build` reports one block per architecture slice and per platform; the
/// minimum over all of them is taken, which is the slice that decides whether a binary can
/// still start on the oldest supported systems.  Version lines inside an `ntools` block
/// belong to the tools that produced the binary and are therefore ignored.
private func minimumOSVersion(of file: URL) -> RuntimeVersion? {
  guard let output = try? run("/usr/bin/xcrun", arguments: ["vtool", "-show-build", file.path]) else {
    return nil
  }
  var versions = [RuntimeVersion]()
  var expectsVersionLine = false
  for line in output.split(separator: "\n") {
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    if trimmed.hasPrefix("cmd ") {
      // Only the legacy `LC_VERSION_MIN_MACOSX` form carries its version on a bare
      // `version` line; `LC_BUILD_VERSION` uses `minos`.
      expectsVersionLine = trimmed.contains("LC_VERSION_MIN_MACOSX")
    } else if trimmed.hasPrefix("minos ") {
      if let version = RuntimeVersion(String(trimmed.dropFirst("minos ".count))) {
        versions.append(version)
      }
      expectsVersionLine = false
    } else if trimmed.hasPrefix("version ") {
      if expectsVersionLine, let version = RuntimeVersion(String(trimmed.dropFirst("version ".count))) {
        versions.append(version)
      }
      expectsVersionLine = false
    }
  }
  return versions.min()
}

// MARK: - Process Helpers

/// The value following `flag` in `arguments`, when present and not another flag.
private func value(of flag: String, in arguments: [String]) -> String? {
  guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else { return nil }
  let value = arguments[index + 1]
  return value.hasPrefix("--") ? nil : value
}

/// Left-aligns `text` in a column of `width` characters.
private func padded(_ text: String, to width: Int) -> String {
  guard text.count < width else { return text }
  return text + String(repeating: " ", count: width - text.count)
}

/// Runs an external process synchronously and returns its combined output.
///
/// The child's own diagnostics are folded into the thrown error, so a failing
/// `install_name_tool` / `codesign` call reports why it failed instead of staying silent.
@discardableResult
private func run(_ executable: String, arguments: [String]) throws -> String {
  let process = Process()
  process.executableURL = URL(fileURLWithPath: executable)
  process.arguments = arguments
  let pipe = Pipe()
  process.standardOutput = pipe
  process.standardError = pipe
  try process.run()
  let data = pipe.fileHandleForReading.readDataToEndOfFile()
  process.waitUntilExit()
  let output = String(data: data, encoding: .utf8)?
    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
  guard process.terminationStatus == 0 else {
    let command = ([executable] + arguments).joined(separator: " ")
    throw PluginError(
      "\(URL(fileURLWithPath: executable).lastPathComponent) exited with code "
        + "\(process.terminationStatus).\nCommand: \(command)\n\(output)"
    )
  }
  return output
}

/// Like `run(_:arguments:)`, but discards the child's stderr.
///
/// `run` deliberately folds stderr into its result so that a failing `install_name_tool` explains
/// itself. That is wrong for the toolchain queries below: `xcrun` prefixes its answers with DVT
/// diagnostics ("… DVTFilePathFSEvents: Failed to start fs event stream.") on stderr, and folding
/// those in turned `DTSDKName` into `macosx<timestamp> xcodebuild[…] …` instead of `macosx13.3`.
@discardableResult
private func runForStdout(_ executable: String, arguments: [String]) throws -> String {
  let process = Process()
  process.executableURL = URL(fileURLWithPath: executable)
  process.arguments = arguments
  let pipe = Pipe()
  process.standardOutput = pipe
  process.standardError = FileHandle.nullDevice
  try process.run()
  let data = pipe.fileHandleForReading.readDataToEndOfFile()
  process.waitUntilExit()
  let output = String(data: data, encoding: .utf8)?
    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
  guard process.terminationStatus == 0 else {
    let command = ([executable] + arguments).joined(separator: " ")
    throw PluginError(
      "\(URL(fileURLWithPath: executable).lastPathComponent) exited with code "
        + "\(process.terminationStatus).\nCommand: \(command)"
    )
  }
  return output
}

/// The extra Info.plist keys both legacy bundles get: the icon keys the modern `BundleApps` also
/// stamps, plus the `DT*` build-environment metadata (`DTXcode`, `DTSDKName`, `DTPlatformVersion`, …)
/// that Xcode normally writes through its `ProcessInfoPlistFile` step.
///
/// The modern path inherits `BundleApps`' own copy of that metadata; this leg assembles its
/// Info.plist itself, so without this it would ship a bundle with no build-environment record at
/// all — which the reference distro (`vChewing-OSX-legacy`, built by Xcode 15.4) does carry.
///
/// Xcode resolves these values from the active platform's `Info.plist` → `AdditionalInfo` template.
/// This reads that same template and fills in its `$(…)` variables from live sources, so the stamp
/// describes the SDK the executables were **really** linked against rather than whichever SDK the
/// build machine happens to default to: `--sdk …/MacOSX13.3.sdk` (what `make bundleLegacy` passes)
/// yields `DTSDKName = macosx13.3`, `DTSDKBuild = 22E230`, `DTXcode = 1540`, `DTXcodeBuild = 15F31d`,
/// `BuildMachineOSBuild = 26A428` — the same shape the reference distro's product carries.
/// `DTPlatformVersion` stays whatever the platform itself declares (14.5 on this Xcode 15.4), and
/// `DTPlatformBuild` comes out empty because that platform never defines
/// `PLATFORM_PRODUCT_BUILD_VERSION`.
///
/// `DTXcode` encodes the version as major*100 + minor*10 (15.4 → 1540), the same rule Xcode uses.
///
/// Passing no `--sdk` yields just the icon keys: without a known SDK the metadata would either be
/// wrong or reflect the build machine's default Xcode, and a bogus build-environment record is
/// worse than none.
private func legacyInfoPlistAdditionalKeys(sdkPath: String?) throws -> [String: Any] {
  var result: [String: Any] = [
    "CFBundleIconFile": "AppIcon",
    "CFBundleIconName": "AppIcon",
    // Stamped by Xcode into every product. The platform template below carries it too, but as an
    // array — which the loop at the end skips, since it only resolves string values.
    "CFBundleSupportedPlatforms": ["MacOSX"],
  ]
  guard let sdkPath, !sdkPath.isEmpty else { return result }
  let sdkDir = URL(fileURLWithPath: sdkPath)
  let sdkSettings = try readPlist(at: sdkDir.appendingPathComponent("SDKSettings.plist"))
  let sdkVersion = sdkSettings["Version"] as? String ?? ""
  let sdkName = sdkSettings["CanonicalName"] as? String ?? "macosx\(sdkVersion)"
  let sdkBuild = try runForStdout(
    "/usr/bin/xcrun", arguments: ["--sdk", sdkPath, "--show-sdk-build-version"]
  )
  // `xcodebuild -version` prints two lines: "Xcode <ver>" and "Build version <build>".
  let xcodeRaw = try runForStdout("/usr/bin/xcodebuild", arguments: ["-version"])
  var xcodeVersion = ""
  var xcodeBuild = ""
  for line in xcodeRaw.split(separator: "\n") {
    let text = String(line)
    if text.hasPrefix("Xcode ") {
      xcodeVersion = String(text.dropFirst("Xcode ".count))
    } else if text.hasPrefix("Build version ") {
      xcodeBuild = String(text.dropFirst("Build version ".count))
    }
  }
  let dtXcode: String = {
    let parts = xcodeVersion.split(separator: ".")
    let major = Int(parts.first ?? "") ?? 0
    let minor = parts.count > 1 ? (Int(parts[1]) ?? 0) : 0
    return String(major * 100 + minor * 10)
  }()
  let osBuild = try runForStdout("/usr/bin/sw_vers", arguments: ["-buildVersion"])
  let platformInfo = try platformInfoPlist(forSDKAt: sdkDir)
  let template = platformInfo["AdditionalInfo"] as? [String: Any] ?? [:]
  // The build settings the template refers to, resolved here. `PLATFORM_PRODUCT_BUILD_VERSION` has
  // no source on this platform (it does not define one), so it resolves to empty — which is what
  // the reference distro's product shows for `DTPlatformBuild` as well.
  let buildSettings = [
    "SDK_NAME": sdkName,
    "SDK_PRODUCT_BUILD_VERSION": sdkBuild,
    "PLATFORM_PRODUCT_BUILD_VERSION": "",
    "XCODE_VERSION_ACTUAL": dtXcode,
    "XCODE_PRODUCT_BUILD_VERSION": xcodeBuild,
    "MAC_OS_X_PRODUCT_BUILD_VERSION": osBuild,
    "GCC_VERSION": "com.apple.compilers.llvm.clang.1_0",
  ]
  for (key, rawValue) in template {
    // Only the build-environment keys. The template also carries `LSMinimumSystemVersion`
    // (`$($(DEPLOYMENT_TARGET_SETTING_NAME))`) and `CFBundleSupportedPlatforms`; the former must
    // stay at `legacyDeploymentTarget`, or the platform's own version would silently raise the floor.
    guard key.hasPrefix("DT") || key == "BuildMachineOSBuild" else { continue }
    guard var value = rawValue as? String else { continue }
    for (setting, replacement) in buildSettings {
      value = value.replacingOccurrences(of: "$(\(setting))", with: replacement)
    }
    // A `$(…)` that survived resolution names a setting this leg has no value for; Xcode leaves
    // those empty rather than writing the variable reference into the product.
    if value.contains("$(") { value = "" }
    result[key] = value
  }
  return result
}

/// The macOS platform's `Info.plist`, i.e. the one holding the `AdditionalInfo` template Xcode
/// stamps products from.
///
/// When the SDK sits inside an Xcode, its platform is three levels up (`…/MacOSX.platform/…/SDKs`).
/// A Command Line Tools SDK does not: it lives in a flat `…/CommandLineTools/SDKs/` directory with
/// no platform around it, and there the active developer directory's platform is the one Xcode
/// itself reads the template from. Kept as an error (not an empty dictionary) when neither can be
/// read, so a mis-paired SDK never silently produces a bundle with no build-environment record.
private func platformInfoPlist(forSDKAt sdkDir: URL) throws -> [String: Any] {
  let besideSDK = sdkDir
    .deletingLastPathComponent() // …/Developer/SDKs (Xcode) or …/CommandLineTools (CLT)
    .deletingLastPathComponent() // …/Developer (Xcode) or …/Library (CLT)
    .deletingLastPathComponent() // …/MacOSX.platform (Xcode) or …/Developer (CLT)
    .appendingPathComponent("Info.plist")
  if let dict = try? readPlist(at: besideSDK) { return dict }
  if let active = try? runForStdout("/usr/bin/xcode-select", arguments: ["-p"]) {
    let candidate = URL(fileURLWithPath: active.trimmingCharacters(in: .whitespacesAndNewlines))
      .appendingPathComponent("Platforms/MacOSX.platform/Info.plist")
    if let dict = try? readPlist(at: candidate) { return dict }
  }
  throw PluginError("Cannot read the macOS platform's Info.plist for the SDK at \(sdkDir.path).")
}

/// Reads a plist as a dictionary. Used for the toolchain's own metadata plists (`SDKSettings.plist`,
/// the platform's `Info.plist`); a missing or non-dictionary file is an error, not a silent empty.
private func readPlist(at url: URL) throws -> [String: Any] {
  guard let data = try? Data(contentsOf: url),
        let dict = try PropertyListSerialization.propertyList(
          from: data, format: nil
        ) as? [String: Any]
  else { throw PluginError("Cannot read plist at \(url.path).") }
  return dict
}

// MARK: - Swift Runtime Dylib Names

/// The Swift runtime dylibs to ship next to the legacy executables.
private let requestedDylibNames = [
  "libswiftAppKit.dylib",
  "libswiftCore.dylib",
  "libswiftCoreData.dylib",
  "libswiftCoreFoundation.dylib",
  "libswiftCoreGraphics.dylib",
  "libswiftCoreImage.dylib",
  "libswiftDarwin.dylib",
  "libswiftDispatch.dylib",
  "libswiftFoundation.dylib",
  "libswiftIOKit.dylib",
  "libswiftMetal.dylib",
  "libswiftObjectiveC.dylib",
  "libswiftQuartzCore.dylib",
  "libswiftXPC.dylib",
  "libswift_Concurrency.dylib",
  "libswiftos.dylib",
]

/// The executables the legacy build produces, and the bundles named after them.
private let imeExecutableName = "vChewing"
private let installerExecutableName = "vChewingInstallerLegacy"
private let executableNames = [imeExecutableName, installerExecutableName]

/// The `.app` bundles the plugin assembles, and the identifiers their Info.plists and entitlements
/// are stamped with. The IME keeps the mainstream identifier — both the legacy and the modern
/// builds of it are `vChewing` — while the installer is renamed so that the two can coexist.
private let imeBundleName = "\(imeExecutableName).app"
private let installerBundleName = "\(installerExecutableName).app"
private let appBundleNames = [imeBundleName, installerBundleName]
private let imeBundleIdentifier = "org.atelierInmu.inputmethod.vChewing"
private let installerBundleIdentifier = "org.atelierInmu.vChewing.vChewingInstallerLegacy"

/// The deployment target the 5.10 binaries are built for. It is written into the installer's
/// `LSMinimumSystemVersion`; the IME's Info.plist takes the same token.
///
/// **10.9, because that is the entire point of this path** — the legacy distro is the only thing
/// that has to run below macOS 10.10. Holding the floor there costs exactly three guards in
/// `vChewing_SettingsUI` — nine `NSViewController.addChild` calls, the `NSSearchField` accessors
/// `placeholderString` / `sendsWholeSearchString` / `sendsSearchStringImmediately`, and
/// `NSColor.secondaryLabelColor`; apart from those the closure compiles at 10.9 unchanged, and
/// `vChewing-OSX-Legacy` shows the 10.9-compliant shape for each. The installer prints this value
/// verbatim as the range it supports.
private let legacyDeploymentTarget = "10.9"

/// The resource bundle `Bundle.currentSPM` resolves, and therefore the one the factory lexicon has
/// to end up inside.
private let spmResourceBundleName = "MainAssembly4Darwin_MainAssembly4Darwin.bundle"

/// Identifier prefix for the flat resource bundles SwiftPM 5.10 emits without an `Info.plist`.
private let legacyResourceBundleIdentifierPrefix = "org.atelierInmu.vChewing.legacy"

/// What `LegacyZone/LexiconBuildTrigger` yields and the IME app consumes.
private let lexiconAssetNames = [
  "VanguardFactoryDict4Typing.txtMap",
  "template-associatedPhrases-cht.txt",
  "template-associatedPhrases-chs.txt",
]

// MARK: - LinkedDylib

/// One Swift runtime dependency record read from `otool -L`.
private struct LinkedDylib {
  enum Location {
    /// `@rpath/…`: resolved through the executable's rpath list, so the matching `Frameworks/`
    /// copy has to exist and a missing one is a packaging bug.
    case rpath
    /// `/usr/lib/swift/…`: the system runtime.  The record is absolute, so the rpath list cannot
    /// redirect it, and no back-deployment copy can stand in for it either — it is left exactly as
    /// recorded, and its absence on an old system is something the linker already had to tolerate.
    case system
    /// `@loader_path/…`: written by an older version of this plugin, normalized back to
    /// `@rpath/…`.  The file it names still has to be shipped next to the binary.
    case stale
  }

  let recordedPath: String
  let name: String
  let isWeak: Bool
  let location: Location
}

// MARK: - PluginError

struct PluginError: LocalizedError {
  // MARK: Lifecycle

  init(_ message: String) { self.errorDescription = message }

  // MARK: Internal

  let errorDescription: String?
}
