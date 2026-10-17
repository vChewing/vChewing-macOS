// (c) 2022 and onwards The vChewing Project (MulanPSL-2.0 License).
// ====================
// This code is released under the SPDX-License-Identifier: `MulanPSL-2.0`.

import Arimitsu
import Foundation
@testable import Shared
@testable import Shared_DarwinImpl
import Testing

/// `DualpinSchemaStore` 之序列化與儲存（`serialize`／`save`）之測試。
///
/// 測試隔離比照 `DualpinSchemaImportTests`：以本套件專屬 suite 覆蓋 `OSUtils.defaultsStore`。
@Suite(.serialized)
final class DualpinSchemaSerializationTests {
  // MARK: Lifecycle

  init() {
    OSUtils.defaultsStore = InMemoryDefaultsStore()
    OSUtils.isRunningUnitTests = true
    UserDef.resetAll()
  }

  deinit {
    OSUtils.isRunningUnitTests = false
  }

  // MARK: Internal

  // MARK: - ① 序列化之形

  /// `$schema` 必置首，且其餘頂層鍵依 `CodingKeys` 之宣告序。
  @Test
  func testSerializePutsSchemaURLFirstAndKeepsCodingKeyOrder() throws {
    let text = try #require(
      DualpinSchemaStore.serialize(
        DualpinParser.mspy,
        schemaURLString: DualpinSchemaStore.canonicalSchemaURLString
      )
    )
    let topLevelKeys = Self.topLevelKeys(of: text)
    #expect(topLevelKeys.first == "$schema")
    #expect(
      Array(topLevelKeys.dropFirst().prefix(5))
        == ["rawID", "rawTitle", "localizedTitle", "initials", "finals"]
    )
    let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
    #expect(lines.first == "{")
    #expect(lines.dropFirst().first?.contains(DualpinSchemaStore.canonicalSchemaURLString) == true)
    #expect(text.hasSuffix("}\n"))
    // 巢狀之鍵另有更深之縮排（2 空格之倍數）。
    let nested = text.split(separator: "\n").filter { $0.hasPrefix("    \"") }
    #expect(!nested.isEmpty)
  }

  /// 未指定 `$schema` 時退回官網之 canonical URL；序列化之結果可被引擎原樣解回
  /// （`$schema` 非引擎之 `CodingKeys`，解碼時自然略過）。
  @Test
  func testSerializeRoundTripsThroughTheDecoder() throws {
    let text = try #require(DualpinSchemaStore.serialize(DualpinParser.gbt17))
    #expect(text.contains(DualpinSchemaStore.canonicalSchemaURLString))
    let decoded = try JSONDecoder().decode(DualpinParser.self, from: Data(text.utf8))
    #expect(decoded == DualpinParser.gbt17)
    #expect(decoded.alphabet == DualpinParser.gbt17.alphabet)
  }

  /// `$schema` 之讀取：有值則取、空字串與缺席一律視同無。
  @Test
  func testSchemaURLStringReader() throws {
    let url = "https://example.com/dualpin/custom.schema.json"
    let withSchema = #"{"$schema":"\#(url)","rawID":"dualPin.Test"}"#
    #expect(DualpinSchemaStore.schemaURLString(inJSON: withSchema) == url)
    let emptySchema = #"{"$schema":"","rawID":"dualPin.Test"}"#
    #expect(DualpinSchemaStore.schemaURLString(inJSON: emptySchema) == nil)
    #expect(DualpinSchemaStore.schemaURLString(inJSON: #"{"rawID":"dualPin.Test"}"#) == nil)
  }

  // MARK: - ② 儲存之守門

  /// 校驗未過（`rawID` 與內建相衝 ⇒ `E9`）時一律不寫偏好。
  @Test
  func testSaveRejectsInvalidParserWithoutWritingPreferences() throws {
    PrefMgr.shared.dualpinSchemaJSON = ""
    let conflicting = DualpinParser(
      rawID: DualpinParser.mspy.rawID,
      rawTitle: "Test",
      initials: DualpinParser.mspy.initials,
      finals: DualpinParser.mspy.finals,
      nullOnset: DualpinParser.mspy.nullOnset
    )
    let outcome = DualpinSchemaStore.save(conflicting)
    guard case let .failure(.invalid(issues)) = outcome else {
      Issue.record("應因 E9 而拒收，實得：\(outcome)。")
      return
    }
    #expect(issues.contains { $0.code == "E9" })
    #expect(PrefMgr.shared.dualpinSchemaJSON.isEmpty)
  }

  /// 校驗通過時寫入偏好、切至「自訂雙拼」、連帶開啟拼音模式與雙拼模式。
  @Test
  func testSaveWritesPreferencesAndSwitchesToCustom() throws {
    PrefMgr.shared.dualpinSchemaJSON = ""
    let parser = DualpinParser(
      rawID: "dualPin.Test",
      rawTitle: "Test",
      initials: DualpinParser.gbt17.initials,
      finals: DualpinParser.gbt17.finals,
      nullOnset: DualpinParser.gbt17.nullOnset
    )
    let outcome = DualpinSchemaStore.save(
      parser,
      schemaURLString: DualpinSchemaStore.canonicalSchemaURLString
    )
    guard case .success = outcome else {
      Issue.record("應儲存成功，實得：\(outcome)。")
      return
    }
    #expect(DualpinSchemaStore.currentParser?.rawID == "dualPin.Test")
    #expect(PrefMgr.shared.keyboardParser4Dualpin == KeyboardParser.ofDualpinCustom.rawValue)
    #expect(PrefMgr.shared.pinyinTypingEnabled)
    #expect(PrefMgr.shared.dualpinEnabledForPinyinTyping)
    #expect(PrefMgr.shared.dualpinSchemaJSON.contains("\"$schema\""))
    #expect(DualpinSchemaStore.currentSchemaURLString == DualpinSchemaStore.canonicalSchemaURLString)
  }

  // MARK: Private

  /// 取出頂層鍵（縮排恰為 2 空格者）。
  private static func topLevelKeys(of json: String) -> [String] {
    json.split(separator: "\n").compactMap { line -> String? in
      guard line.hasPrefix("  \""), let colon = line.range(of: "\":") else { return nil }
      return String(line[line.index(line.startIndex, offsetBy: 3) ..< colon.lowerBound])
    }
  }
}
