// (c) 2026 and onwards The vChewing Project (MIT-NTL License).
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

// MARK: - LMMgrMigrateTests

@Suite(.serialized)
struct LMMgrMigrateTests {
  // MARK: Internal

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

  /// 建立一對空的舊／新使用者資料目錄。
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
