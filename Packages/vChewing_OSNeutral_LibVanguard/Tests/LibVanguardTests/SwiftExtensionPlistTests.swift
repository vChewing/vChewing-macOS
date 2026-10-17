// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation
@testable import LibVanguard
import Testing

// 歸入本測試目標唯一根 suite（見 `LibVanguardTests_Root.swift`）；各 suite 自持 `TestEnvironment`（P316），故可並行。
extension LibVanguardTestsRoot {
  /// `NSDictionary.loadOldStylePlistDictionary(atPath:)` 之三系統一致性。
  ///
  /// 該擴充之所以存在，是因為兩個原生入口各缺一角：`init(contentsOfFile:)` 三系統皆被列為棄用，
  /// `init(contentsOf:error:)` 則只有 Darwin 才有。故以 `PropertyListSerialization` 收口——
  /// 而 `PropertyListSerialization` 對 old-style plist（`.strings`）之支援需實測，
  /// 這正是本 suite 的職責：它在 Linux 與 WinNT 之 CI 上亦會跑，能擋住「只有 Darwin 可行」的寫法。
  @Suite("SwiftExtensionPlistTests")
  struct SwiftExtensionPlistTests {
    // MARK: Internal

    /// 舊式 property list（含註解與跳脫字元）能否讀成字典。
    @Test
    func testLoadingOldStylePlistWithComments() throws {
      let content = """
      /* 這是 old-style plist 之註解，`.strings` 檔常帶此形制。 */
      "hello" = "你好";
      // 行註解亦須容許。
      "quote" = "He said \\"hi\\"";
      "count" = "3";
      """
      let url = try writeTemporaryOldStylePlist(content)
      defer { try? FileManager.default.removeItem(at: url) }

      let loaded = NSDictionary.loadOldStylePlistDictionary(atPath: url.path) as? [String: String]
      #expect(loaded?["hello"] == "你好")
      #expect(loaded?["quote"] == "He said \"hi\"")
      #expect(loaded?["count"] == "3")
    }

    /// 檔案不存在時須得 `nil`，不得拋錯、亦不得回空字典。
    @Test
    func testLoadingMissingPlistReturnsNil() {
      let path = FileManager.default.temporaryDirectory
        .appendingPathComponent("vChewing-missing-\(UUID().uuidString).strings").path
      #expect(NSDictionary.loadOldStylePlistDictionary(atPath: path) == nil)
    }

    /// 內容不是 property list 時須得 `nil`（而非半套結果）。
    @Test
    func testLoadingGarbageReturnsNil() throws {
      let url = try writeTemporaryOldStylePlist("這不是 property list，衹是一行字。")
      defer { try? FileManager.default.removeItem(at: url) }
      #expect(NSDictionary.loadOldStylePlistDictionary(atPath: url.path) == nil)
    }

    // MARK: Private

    // MARK: - 輔助

    private func writeTemporaryOldStylePlist(_ content: String) throws -> URL {
      let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("vChewing-plist-\(UUID().uuidString).strings")
      try content.write(to: url, atomically: true, encoding: .utf8)
      return url
    }
  }
}
