// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation
@testable import Shared
import Testing

@Suite("vChewing_Shared_UserDefExchange_Tests", .serialized)
final class UserDefExchangeTests {
  // MARK: Lifecycle

  init() {
    UserDefaults.unitTests = .init(suiteName: "org.atelierInmu.vChewing.Shared.UnitTests")
    UserDefaults.pendingUnitTests = true
    UserDef.resetAll()
  }

  deinit {
    // `deinit` 為 nonisolated，而 `UserDef.resetAll()` 繫於 MainActor，故僅在此復原旗標；
    // 各測試之 `init` 皆已自行 `UserDef.resetAll()`。
    UserDefaults.pendingUnitTests = false
  }

  // MARK: Internal

  /// §3.1 命名紀律。
  @Test
  func testNamingDisciplineOfRawValues() {
    for userDef in UserDef.allCases {
      #expect(
        !userDef.rawValue.hasPrefix("__"),
        "\(userDef) 之 rawValue 不得以 `__` 開頭（該前綴保留給交換格式之中介鍵）"
      )
    }
    #expect(UserDef.jsonExchangeMetaKey.hasPrefix(UserDef.jsonExchangeReservedKeyPrefix))
    #expect(UserDef.jsonExchangeReservedKeyPrefix == "__")
    #expect(UserDef.jsonExchangeMetaKey == "__UserDefMeta")
  }

  /// §3.2 匯出端不得輸出任何 `__` 起頭之鍵，且所有鍵皆為真偏好鍵。
  @Test
  func testExportAsJSONNeverEmitsReservedKeys() throws {
    UserDefaults.current.set(true, forKey: UserDef.kUseRearCursorMode.rawValue)
    UserDefaults.current.set(120, forKey: UserDef.kCandidateListTextSize.rawValue)
    let data = try #require(UserDef.exportAsJSON())
    let jsonObj = try JSONSerialization.jsonObject(with: data)
    let dict = try #require(jsonObj as? [String: Any])
    let allKeys = Set(UserDef.allCases.map(\.rawValue))
    for key in dict.keys {
      #expect(!key.hasPrefix(UserDef.jsonExchangeReservedKeyPrefix))
      #expect(allKeys.contains(key))
    }
    #expect(dict[UserDef.kUseRearCursorMode.rawValue] as? Bool == true)
  }

  /// §3.3 `destructureExchange` 之六種情形。
  @Test
  func testDestructureExchange() {
    let root: [String: Any] = [
      "__UserDefMeta": [
        "title": "微軟新注音風格配置",
        "description": "對齊微軟新注音 2003 之行為。",
        "author": "某人",
        "count": 42,
      ],
      "__Foo": "bar",
      UserDef.kUseRearCursorMode.rawValue: true,
      UserDef.kCandidateListTextSize.rawValue: 18,
    ]
    let destructured = UserDef.destructureExchange(root)
    #expect(destructured.meta?.title == "微軟新注音風格配置")
    #expect(destructured.meta?.description == "對齊微軟新注音 2003 之行為。")
    #expect(destructured.meta?.extras["author"] == "某人")
    #expect(destructured.meta?.extras["count"] == nil)
    #expect(destructured.payload.keys.allSatisfy { !$0.hasPrefix("__") })
    #expect(destructured.payload.count == 2)
    #expect(destructured.payload[UserDef.kUseRearCursorMode.rawValue] as? Bool == true)

    // 中介辭典缺席：不視為錯誤。
    #expect(UserDef.destructureExchange([UserDef.kUseRearCursorMode.rawValue: true]).meta == nil)

    // 中介辭典不是辭典：摘除之、記一筆警告、不使整包失敗。
    for malformed in ["abc", 42] as [Any] {
      let broken = UserDef.destructureExchange([
        UserDef.jsonExchangeMetaKey: malformed,
        UserDef.kUseRearCursorMode.rawValue: true,
      ])
      #expect(broken.meta != nil)
      #expect(!(broken.meta?.warnings.isEmpty ?? true))
      #expect(broken.payload[UserDef.jsonExchangeMetaKey] == nil)
      let result = UserDef.importFromDictionary(broken.payload)
      #expect(result.successes == [UserDef.kUseRearCursorMode.rawValue])
      #expect(result.failures.isEmpty)
    }
  }

  /// §3.4 字串清洗：截斷至 512 字元、濾除控制字元。
  @Test
  func testExchangeMetaStringSanitization() {
    let overlongTitle = String(repeating: "あ", count: 600)
    let meta = UserDef.destructureExchange([
      UserDef.jsonExchangeMetaKey: [
        "title": overlongTitle,
        "description": "第一行\n第二行\r\t第三行",
      ],
    ]).meta
    #expect(meta?.title?.count == 512)
    #expect(!(meta?.warnings.isEmpty ?? true))
    let description = meta?.description ?? ""
    #expect(description == "第一行第二行第三行")
    #expect(
      !description.contains {
        $0.unicodeScalars.contains { CharacterSet.controlCharacters.contains($0) }
      }
    )
  }

  /// §3.5 `importFromDictionary` 之四類結果。
  @Test
  func testImportFromDictionary() {
    let result = UserDef.importFromDictionary([
      UserDef.kUseRearCursorMode.rawValue: true,
      UserDef.kCassettePath.rawValue: "/tmp/whatever",
      UserDef.kCandidateListTextSize.rawValue: 9_999,
      "Nope": 1,
    ])
    #expect(result.successes == [UserDef.kUseRearCursorMode.rawValue])
    let reasons = Dictionary(uniqueKeysWithValues: result.failures.map { ($0.key, $0.reason) })
    #expect(reasons[UserDef.kCassettePath.rawValue] == "Blacklisted key")
    #expect(reasons["Nope"] == "Unknown key")
    #expect(reasons[UserDef.kCandidateListTextSize.rawValue] != nil)
    #expect(UserDefaults.current.object(forKey: UserDef.kUseRearCursorMode.rawValue) as? Bool == true)
    #expect(UserDefaults.current.object(forKey: UserDef.kCandidateListTextSize.rawValue) == nil)
  }

  /// §3.6 `importFromJSON` 即 `importFromDictionary` 之薄殼。
  @Test
  func testImportFromJSONIsThinShell() throws {
    let json = """
    {
      "UseRearCursorMode": true,
      "CandidateListTextSize": 9999,
      "CassettePath": "/tmp/whatever",
      "Nope": 1
    }
    """
    let data = try #require(json.data(using: .utf8))
    let viaJSON = UserDef.importFromJSON(data)
    UserDef.resetAll()
    let decodedObj = try JSONSerialization.jsonObject(with: data)
    let decoded = try #require(decodedObj as? [String: Any])
    let viaDict = UserDef.importFromDictionary(decoded)
    #expect(viaJSON.successes.sorted() == viaDict.successes.sorted())
    #expect(
      viaJSON.failures.map { "\($0.key):\($0.reason)" }.sorted()
        == viaDict.failures.map { "\($0.key):\($0.reason)" }.sorted()
    )

    let invalid = UserDef.importFromJSON(Data("not json".utf8))
    #expect(invalid.successes.isEmpty)
    #expect(invalid.failures.count == 1)
    #expect(invalid.failures.first?.key == "(root)")
    #expect(invalid.failures.first?.reason == "Invalid JSON format")
  }

  /// §3.7 `importFromExchangeJSON` 之完整路徑。
  @Test
  func testImportFromExchangeJSON() throws {
    let json = """
    {
      "__UserDefMeta": { "title": "T", "description": "D" },
      "__Foo": 1,
      "UseRearCursorMode": true
    }
    """
    let data = try #require(json.data(using: .utf8))
    let outcome = UserDef.importFromExchangeJSON(data)
    #expect(outcome.meta?.title == "T")
    #expect(outcome.meta?.description == "D")
    #expect(outcome.result.successes == [UserDef.kUseRearCursorMode.rawValue])
    #expect(outcome.result.failures.isEmpty)
    #expect(UserDefaults.current.object(forKey: UserDef.kUseRearCursorMode.rawValue) as? Bool == true)

    let invalid = UserDef.importFromExchangeJSON(Data("{{".utf8))
    #expect(invalid.meta == nil)
    #expect(invalid.result.successes.isEmpty)
    #expect(invalid.result.failures.count == 1)
    #expect(invalid.result.failures.first?.key == "(root)")
    #expect(invalid.result.failures.first?.reason == "Invalid JSON format")
  }

  /// §3.8 `diffAgainstCurrent` 之同值／值域外／黑名單／真差異四類。
  @Test
  func testDiffAgainstCurrent() {
    UserDefaults.current.set(true, forKey: UserDef.kIsDebugModeEnabled.rawValue)
    UserDefaults.current.set(2_024.0, forKey: UserDef.kDeltaOfCalendarYears.rawValue)

    // 同值不算差異（含跨表示法：JSON 1 對 Bool true、JSON 2024 對 Double 2024.0）。
    let same = UserDef.diffAgainstCurrent([
      UserDef.kIsDebugModeEnabled.rawValue: 1,
      UserDef.kDeltaOfCalendarYears.rawValue: 2_024,
    ])
    #expect(same.changed.isEmpty)
    #expect(same.result.failures.isEmpty)
    #expect(same.result.successes.count == 2)

    // 值域外不算差異。
    let outOfRange = UserDef.diffAgainstCurrent([UserDef.kCandidateListTextSize.rawValue: 9_999])
    #expect(outOfRange.changed.isEmpty)
    #expect(outOfRange.result.failures.count == 1)
    #expect(outOfRange.result.failures.first?.key == UserDef.kCandidateListTextSize.rawValue)

    // 黑名單不算差異。
    let blacklisted = UserDef.diffAgainstCurrent([UserDef.kCassettePath.rawValue: "/tmp/whatever"])
    #expect(blacklisted.changed.isEmpty)
    #expect(blacklisted.result.failures.count == 1)
    #expect(blacklisted.result.failures.first?.reason == "Blacklisted key")

    // 真有差異者進 `changed`，且已排序；不得寫入 UserDefaults。
    let real = UserDef.diffAgainstCurrent([
      UserDef.kUseRearCursorMode.rawValue: true,
      UserDef.kUseHorizontalCandidateList.rawValue: false,
    ])
    #expect(real.changed.map(\.rawValue) == real.changed.map(\.rawValue).sorted())
    #expect(real.changed == [.kUseHorizontalCandidateList, .kUseRearCursorMode])
    #expect(UserDefaults.current.object(forKey: UserDef.kUseRearCursorMode.rawValue) == nil)
    #expect(UserDefaults.current.object(forKey: UserDef.kUseHorizontalCandidateList.rawValue) == nil)
  }

  /// 不變式：**凡 `metaData.options` 宣告之選項值，逐鍵驗證皆須接受**。
  ///
  /// 動機（2026-09-24，Phase 241 施工時查得之既有缺陷）：三條鍵之 `options` 曾超出
  /// `validNumeralValueRange`（`kSpecifiedNotifyUIColorScheme` 之 -1、
  /// `kForceCassetteChineseConversion` 之 3、`kNumPadCharInputBehavior` 之 3／4／5），
  /// 而 `validateAndApply` 對整數一律以該值域把關 ⇒ **連 app 自己匯出的偏好包都會被拒**
  /// （使用者於介面內選了那些選項、匯出後再匯入即失敗）。本測試即以「選項 ⊆ 值域」為不變式，
  /// 使日後新增選項而忘了放寬值域時當場轉紅。
  @Test
  func testEveryDeclaredOptionIsAcceptedByValidator() {
    var checked = 0
    for userDef in UserDef.allCases {
      guard let options = userDef.metaData?.options, !options.isEmpty else { continue }
      for value in options.keys.sorted() {
        let outcome = UserDef.diffAgainstCurrent([userDef.rawValue: value])
        #expect(
          outcome.result.failures.isEmpty,
          "「\(userDef)」之選項 \(value) 竟被逐鍵驗證拒絕：\(outcome.result.failures)"
        )
        checked += 1
      }
    }
    #expect(checked >= 40, "受檢之選項數過少：\(checked)")
  }

  /// 三條曾與值域不一致之鍵，其值域之現行定版（絆線：日後動值域即會轉紅、須複查本註）。
  @Test
  func testFormerlyMismatchedRanges() {
    #expect(UserDef.kSpecifiedNotifyUIColorScheme.validNumeralValueRange == -1 ... 1)
    #expect(UserDef.kForceCassetteChineseConversion.validNumeralValueRange == 0 ... 3)
    #expect(UserDef.kNumPadCharInputBehavior.validNumeralValueRange == 0 ... 5)
    // 逐鍵驗證亦須接受其值域之兩端。
    for (userDef, range) in [
      (UserDef.kSpecifiedNotifyUIColorScheme, -1 ... 1),
      (UserDef.kForceCassetteChineseConversion, 0 ... 3),
      (UserDef.kNumPadCharInputBehavior, 0 ... 5),
    ] {
      for value in [range.lowerBound, range.upperBound] {
        let outcome = UserDef.diffAgainstCurrent([userDef.rawValue: value])
        #expect(outcome.result.failures.isEmpty, "「\(userDef)」之 \(value) 被拒")
      }
      let outside = range.upperBound + 1
      let rejected = UserDef.diffAgainstCurrent([userDef.rawValue: outside])
      #expect(rejected.result.failures.count == 1, "「\(userDef)」之 \(outside) 竟被接受")
    }
  }
}
