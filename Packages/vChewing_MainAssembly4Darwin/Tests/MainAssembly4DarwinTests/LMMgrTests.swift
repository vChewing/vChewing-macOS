// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation
import Shared
import Testing

@testable import MainAssembly4Darwin

// MARK: - LMMgrTests

/// LMMgr（Darwin 宿主的使用者資料管理器）單元測試。
///
/// 收納原 `MainAssemblyTests` 的 001 家族——使用者資料沙盒 IO、磁帶快取路徑與退路、
/// iCloud 指引、符號連結解析、使用者資料夾規格空值判定——與原 `LMMgrMigrateTests`
/// 的位元組級使用者資料遷移。測試編號沿用原檔，便於與歷史紀錄對照。
@Suite(.serialized)
final class LMMgrTests {
  // MARK: Lifecycle

  init() {
    UserDefaults.unitTests = .init(suiteName: "org.atelierInmu.vChewing.MainAssembly.UnitTests")
    UserDefaults.pendingUnitTests = true
    UserDef.resetAll()
    // 生產路徑的 LMMgr.shared 已改由 phraseEditorDelegateProvider 延遲實體化；
    // 測試需要其 KVO 觀察器在場以錄製路徑失效警示，故在此顯式武裝。
    _ = LMMgr.shared
    LMMgr.prepareForUnitTests()
    LMMgr.resetRecordedPathInvalidityAlerts()
  }

  deinit {
    mainSync {
      LMMgr.resetAfterUnitTests()
      LMMgr.resetRecordedPathInvalidityAlerts()
    }
    UserDefaults.unitTests?.removeSuite(named: "org.atelierInmu.vChewing.MainAssembly.UnitTests")
    UserDefaults.pendingUnitTests = false
  }

  // MARK: Internal

  @Test
  func test011_LMMgr_UnitTestSandboxIO() throws {
    let directories = [
      (label: "default", url: LMMgr.unitTestDataURL(isDefaultFolder: true)),
      (label: "custom", url: LMMgr.unitTestDataURL(isDefaultFolder: false)),
    ]
    let fileManager = FileManager.default

    for (label, folderURL) in directories {
      let path = folderURL.path
      var isDirectory = ObjCBool(false)
      #expect(
        fileManager.fileExists(atPath: path, isDirectory: &isDirectory),
        "Missing \(label) folder at: \(path)"
      )
      #expect(isDirectory.boolValue, "Path is not directory for \(label) folder at: \(path)")
      #expect(
        fileManager.isReadableFile(atPath: path),
        "Unreadable \(label) folder at: \(path)"
      )
      #expect(
        fileManager.isWritableFile(atPath: path),
        "Unwritable \(label) folder at: \(path)"
      )

      let payload = "io-check-\(UUID().uuidString)"
      let fileURL = folderURL.appendingPathComponent("io-check-\(UUID().uuidString).txt")

      try Data(payload.utf8).write(to: fileURL, options: [.atomic])
      let readBack = try String(contentsOf: fileURL, encoding: .utf8)
      #expect(readBack == payload, "Mismatched content for \(label) folder at: \(path)")
      try fileManager.removeItem(at: fileURL)
    }
  }

  @Test
  func test012_LMMgr_CassetteCacheUsesUnitTestSandbox() {
    let expectedURL = LMMgr.unitTestDataURL(isDefaultFolder: true).appendingPathComponent("Cassettes")
    #expect(LMMgr.cassetteCacheDirectoryURL.path == expectedURL.path)
  }

  @Test
  func test013_LMMgr_CassettePathFallsBackToCachedCopy() throws {
    let fileManager = FileManager.default
    let externalURL = LMMgr.unitTestDataURL(isDefaultFolder: false)
      .appendingPathComponent("phase25-fallback-\(UUID().uuidString).cin2")
    let cacheURL = LMMgr.cassetteCacheDirectoryURL.appendingPathComponent(externalURL.lastPathComponent)

    defer {
      try? fileManager.removeItem(at: externalURL)
      try? fileManager.removeItem(at: cacheURL)
      LMMgr.resetCassettePath()
    }

    try fileManager.createDirectory(
      at: LMMgr.cassetteCacheDirectoryURL,
      withIntermediateDirectories: true
    )
    try Data("phase25-fallback".utf8).write(to: externalURL, options: [.atomic])
    #expect(LMMgr.importCassetteFileToCache(from: externalURL))

    PrefMgr.shared.cassettePath = externalURL.path
    try fileManager.removeItem(at: externalURL)

    #expect(LMMgr.cassettePath() == cacheURL.path)

    // Verify that a path-invalidity alert was captured (instead of a blocking modal).
    let cassetteAlerts = LMMgr.recordedPathInvalidityAlerts.filter {
      $0.infoText.contains(externalURL.lastPathComponent)
    }
    #expect(
      !cassetteAlerts.isEmpty,
      "Expected a cassette-path-invalidity alert for \(externalURL.lastPathComponent)."
    )
  }

  @Test
  func test014_LMMgr_ResetCassettePathKeepsDirectCacheSource() throws {
    let fileManager = FileManager.default
    let cacheURL = LMMgr.cassetteCacheDirectoryURL
      .appendingPathComponent("phase25-direct-cache-\(UUID().uuidString).cin2")

    defer {
      try? fileManager.removeItem(at: cacheURL)
      LMMgr.resetCassettePath()
    }

    try fileManager.createDirectory(
      at: LMMgr.cassetteCacheDirectoryURL,
      withIntermediateDirectories: true
    )
    try Data("phase25-direct-cache".utf8).write(to: cacheURL, options: [.atomic])

    PrefMgr.shared.cassettePath = cacheURL.path
    LMMgr.resetCassettePath()

    #expect(fileManager.fileExists(atPath: cacheURL.path))
  }

  @Test
  func test015_LMMgr_ResetCassettePathRemovesImportedCacheCopy() throws {
    let fileManager = FileManager.default
    let externalURL = LMMgr.unitTestDataURL(isDefaultFolder: false)
      .appendingPathComponent("phase25-reset-\(UUID().uuidString).cin2")
    let cacheURL = LMMgr.cassetteCacheDirectoryURL.appendingPathComponent(externalURL.lastPathComponent)

    defer {
      try? fileManager.removeItem(at: externalURL)
      try? fileManager.removeItem(at: cacheURL)
      LMMgr.resetCassettePath()
    }

    try fileManager.createDirectory(
      at: LMMgr.cassetteCacheDirectoryURL,
      withIntermediateDirectories: true
    )
    try Data("phase25-reset".utf8).write(to: externalURL, options: [.atomic])
    #expect(LMMgr.importCassetteFileToCache(from: externalURL))

    PrefMgr.shared.cassettePath = externalURL.path
    LMMgr.resetCassettePath()

    #expect(fileManager.fileExists(atPath: externalURL.path))
    #expect(!fileManager.fileExists(atPath: cacheURL.path))
  }

  @Test
  func test016_LMMgr_CassetteAccessFailureAddsICloudGuidanceForCloudDocsPaths() {
    let mirroredPath = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
      .appendingPathComponent("Library", isDirectory: true)
      .appendingPathComponent("Mobile Documents", isDirectory: true)
      .appendingPathComponent("com~apple~CloudDocs", isDirectory: true)
      .appendingPathComponent("phase25-guidance.cin2")
      .path
    let advice = "i18n:LMMgr.pathInvalidityFound.iCloudDriveManagedPathAdvice".i18n
    let privacySuggestion = "i18n:LMMgr.pathInvalidityFound.suggestVerifyingSystemPrivacySettings".i18n
    let description = LMMgr.cassetteAccessFailureDescription(path: mirroredPath)

    #expect(description.contains(advice))
    #expect(description.contains(privacySuggestion))
  }

  @Test
  func test017_LMMgr_CassetteAccessFailureAddsICloudGuidanceForMirroredFoldersWhenSyncEnabled() {
    let originalOverride = LMMgr.iCloudPathDetectionOverride
    LMMgr.iCloudPathDetectionOverride = { candidatePath in
      candidatePath.contains("/Documents/")
    }
    defer { LMMgr.iCloudPathDetectionOverride = originalOverride }

    let mirroredPath = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
      .appendingPathComponent("Documents", isDirectory: true)
      .appendingPathComponent("phase25-mirrored-guidance.cin2")
      .path
    let advice = "i18n:LMMgr.pathInvalidityFound.iCloudDriveManagedPathAdvice".i18n
    let privacySuggestion = "i18n:LMMgr.pathInvalidityFound.suggestVerifyingSystemPrivacySettings".i18n
    let description = LMMgr.cassetteAccessFailureDescription(path: mirroredPath)

    #expect(description.contains(advice))
    #expect(description.contains(privacySuggestion))
  }

  @Test
  func test018_LMMgr_CassetteAccessFailureSkipsICloudGuidanceOutsideMirroredFolders() {
    let originalOverride = LMMgr.iCloudPathDetectionOverride
    LMMgr.iCloudPathDetectionOverride = { _ in false }
    defer { LMMgr.iCloudPathDetectionOverride = originalOverride }

    let localPath = LMMgr.unitTestDataURL(isDefaultFolder: false)
      .appendingPathComponent("phase25-local-guidance.cin2")
      .path
    let base = "i18n:LMMgr.accessFailure.cassette.description".i18n
    let advice = "i18n:LMMgr.pathInvalidityFound.iCloudDriveManagedPathAdvice".i18n
    let privacySuggestion = "i18n:LMMgr.pathInvalidityFound.suggestVerifyingSystemPrivacySettings".i18n
    let description = LMMgr.cassetteAccessFailureDescription(path: localPath)

    #expect(description.contains(base))
    #expect(!description.contains(advice))
    #expect(description.contains(privacySuggestion))
  }

  @Test
  func test019_LMMgr_ResolveUserSpecifiedURLResolvesCassetteSymlink() throws {
    let fileManager = FileManager.default
    let baseURL = LMMgr.unitTestDataURL(isDefaultFolder: false)
    let targetURL = baseURL.appendingPathComponent("phase25-real-\(UUID().uuidString).cin2")
    let symlinkURL = baseURL.appendingPathComponent("phase25-link-\(UUID().uuidString).cin2")

    defer {
      try? fileManager.removeItem(at: symlinkURL)
      try? fileManager.removeItem(at: targetURL)
    }

    try Data("phase25-symlink-target".utf8).write(to: targetURL, options: [.atomic])
    try fileManager.createSymbolicLink(atPath: symlinkURL.path, withDestinationPath: targetURL.path)

    let resolvedURL = LMMgr.resolveUserSpecifiedURL(symlinkURL)

    #expect(resolvedURL.path == targetURL.standardizedFileURL.path)
  }

  @Test
  func test020_LMMgr_ResolveUserSpecifiedURLResolvesUserDataFolderSymlink() throws {
    let fileManager = FileManager.default
    let baseURL = LMMgr.unitTestDataURL(isDefaultFolder: false)
    let targetURL = baseURL.appendingPathComponent("phase25-real-folder-\(UUID().uuidString)", isDirectory: true)
    let symlinkURL = baseURL.appendingPathComponent("phase25-link-folder-\(UUID().uuidString)", isDirectory: true)

    defer {
      try? fileManager.removeItem(at: symlinkURL)
      try? fileManager.removeItem(at: targetURL)
    }

    try fileManager.createDirectory(at: targetURL, withIntermediateDirectories: true)
    try fileManager.createSymbolicLink(atPath: symlinkURL.path, withDestinationPath: targetURL.path)

    let resolvedURL = LMMgr.resolveUserSpecifiedURL(symlinkURL)

    #expect(resolvedURL.path == targetURL.standardizedFileURL.path)
  }

  // 單元測試模式下 dataFolderPath() 會提早跳入測試沙盒，無法直接驅動其產品分支；
  // 故直接測試空值判定函式與合規性驗證器的行為（空字串不得被解讀成 "/" 而誤報失效）。

  @Test
  func test021_LMMgr_EmptyUserDataFolderSpecIsEffectivelyUnset() {
    // AppProperty 初次初始化會把空字串預設值寫入 prefs，使「從未指定」看起來像「指定了空路徑」。
    // 空字串與其補尾斜槓產物 "/" 皆必須視為「未指定」。
    #expect(LMMgr.userDataFolderPathIsEffectivelyUnset(""))
    #expect(LMMgr.userDataFolderPathIsEffectivelyUnset("/"))
    #expect(!LMMgr.userDataFolderPathIsEffectivelyUnset("/Users/Shared/vChewing/"))
    #expect(!LMMgr.userDataFolderPathIsEffectivelyUnset("~"))
  }

  @Test
  func test022_LMMgr_EmptyUserDataFolderSpecSkipsValidityAlert() {
    LMMgr.resetRecordedPathInvalidityAlerts()
    defer { LMMgr.resetRecordedPathInvalidityAlerts() }
    Broadcaster.shared.clearLmMgrDataFolderPathInvalidity()

    // 空值（nil／空字串）＝「尚未指定自訂目錄」：視為合規、不得觸發失效警示。
    #expect(LMMgr.checkIfSpecifiedUserDataFolderValid(""))
    #expect(LMMgr.checkIfSpecifiedUserDataFolderValid(nil))
    #expect(LMMgr.recordedPathInvalidityAlerts.isEmpty)

    // 真實存在且可寫入的目錄依然照常通過。
    #expect(
      LMMgr.checkIfSpecifiedUserDataFolderValid(LMMgr.unitTestDataURL(isDefaultFolder: true).path)
    )
    #expect(LMMgr.recordedPathInvalidityAlerts.isEmpty)
  }

  @Test
  func test023_LMMgr_AppPropertyAutoSeedsEmptyDefaultIntoPrefs() {
    // 前提驗證：AppProperty 的 init 會在 key 缺席時把預設值寫入 prefs——這使「從未手動指定」
    // 的 kUserDataFolderSpecified 以空字串形式存在於 prefs，成為被誤讀成 "/" 的來源。
    let defaults = UserDefaults.current
    defaults.removeObject(forKey: UserDef.kUserDataFolderSpecified.rawValue)
    defer { defaults.removeObject(forKey: UserDef.kUserDataFolderSpecified.rawValue) }
    _ = PrefMgr() // 每次實體化皆會重新觸發所有 @AppProperty 的 seeding。
    #expect(defaults.string(forKey: UserDef.kUserDataFolderSpecified.rawValue) == "")
  }

  // MARK: - 使用者資料遷移

  @Test
  func testMigratePreservesInvalidUTF8() throws {
    // migrateUserDataFrom 全程以位元組進行：非法 UTF-8 位元組原樣保留（不再經 String 解碼成 U+FFFD）。
    let (oldDir, newDir) = try Self.makeDirs()
    defer {
      try? FileManager.default.removeItem(at: oldDir)
      try? FileManager.default.removeItem(at: newDir)
    }

    let type = LMAssembly.ReplacableUserDataType.theAssociates
    let mode = Shared.InputMode.imeModeCHT
    let oldURL = LMMgr.userDictDataURL(mode: mode, type: type, basePath: oldDir.path)
    let newURL = LMMgr.userDictDataURL(mode: mode, type: type, basePath: newDir.path)

    let newBytes = Array("芳 苑 鄰 香\n".utf8)
    let oldBytes: [UInt8] = Array("芳 芳香 苑\n".utf8) + [0xFF, 0xFE]
    try Data(newBytes).write(to: newURL)
    try Data(oldBytes).write(to: oldURL)

    let migrated = LMMgr.migrateUserDataFrom(oldPath: oldDir.path, to: newDir.path)
    #expect(migrated == 1)
    let merged = try Data(contentsOf: newURL)
    #expect(Array(merged) == newBytes + [0x0A] + oldBytes)
  }

  @Test
  func testMigrateSkipsWhitespaceOnlyOldFile() throws {
    // 舊檔全為空白／斷行時跳過合併（byte 層級空檔判斷，對齊 CharacterSet.whitespacesAndNewlines）。
    let (oldDir, newDir) = try Self.makeDirs()
    defer {
      try? FileManager.default.removeItem(at: oldDir)
      try? FileManager.default.removeItem(at: newDir)
    }

    let type = LMAssembly.ReplacableUserDataType.theAssociates
    let mode = Shared.InputMode.imeModeCHT
    let oldURL = LMMgr.userDictDataURL(mode: mode, type: type, basePath: oldDir.path)
    let newURL = LMMgr.userDictDataURL(mode: mode, type: type, basePath: newDir.path)

    let newBytes = Array("芳 苑 鄰 香\n".utf8)
    let oldBytes: [UInt8] = Array("\u{3000} \t\n\u{00A0}\u{2028}".utf8) // 全為空白／斷行字元
    try Data(newBytes).write(to: newURL)
    try Data(oldBytes).write(to: oldURL)

    let migrated = LMMgr.migrateUserDataFrom(oldPath: oldDir.path, to: newDir.path)
    #expect(migrated == 0)
    let merged = try Data(contentsOf: newURL)
    #expect(Array(merged) == newBytes) // 舊檔未合併，新檔原樣。
  }

  // MARK: Private

  private static func makeDirs() throws -> (old: URL, new: URL) {
    let oldDir = FileManager.default.temporaryDirectory
      .appendingPathComponent("vChewingTest_migrate_old_\(UUID().uuidString)")
    let newDir = FileManager.default.temporaryDirectory
      .appendingPathComponent("vChewingTest_migrate_new_\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: oldDir, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: newDir, withIntermediateDirectories: true)
    return (oldDir, newDir)
  }
}
