// (c) 2022 and onwards The vChewing Project (MulanPSL-2.0 License).
// ====================
// This code is released under the SPDX-License-Identifier: `MulanPSL-2.0`.

import Foundation
import Shared
import Testing

@testable import SettingsUI

// MARK: - PrefsExchangeTests

/// `PrefsExchange`（剪貼簿匯入之解析、差異計算與套用）之測試。
///
/// 隔離作法比照 `CtlSettingsUITests`：以本套件專屬 suite 覆蓋 `UserDefaults.current`
/// （`UserDefaults.unitTests` ＋ `UserDefaults.pendingUnitTests`），並於 `deinit` 復原。
///
/// 須留意：測試靶不帶 lproj 資源，故 `.i18n` 一律回傳鍵名本身——本檔之斷言因此以鍵名為預期值。
@Suite(.serialized)
final class PrefsExchangeTests {
  // MARK: Lifecycle

  init() {
    UserDefaults.unitTests = .init(
      suiteName: "org.atelierInmu.vChewing.SettingsUI.PrefsExchangeUnitTests"
    )
    UserDefaults.pendingUnitTests = true
    UserDef.resetAll()
  }

  deinit {
    // `deinit` 為 nonisolated，而 `UserDef.resetAll()` 繫於 MainActor，故僅在此復原旗標；
    // 各測試之 `init` 皆已自行 `UserDef.resetAll()`。
    UserDefaults.pendingUnitTests = false
  }

  // MARK: Internal

  // MARK: - ① 剪貼簿為空

  @Test
  func testClipboardEmpty() throws {
    let inputs: [String?] = [nil, "", " ", "\n\t  \n"]
    for input in inputs {
      switch PrefsExchange.prepare(fromClipboardString: input) {
      case .clipboardEmpty: break
      case let other: Issue.record("輸入 `\(input ?? "nil")` 未判為 clipboardEmpty，實得 `\(other)`。")
      }
    }
  }

  // MARK: - ② 非 JSON／非辭典

  @Test
  func testFailedToParseOnNonDictionaryJSON() throws {
    let inputs = ["hello", "123", "[1, 2]", "{}"]
    for input in inputs {
      switch PrefsExchange.prepare(fromClipboardString: input) {
      case let .failedToParse(detail):
        #expect(detail == nil)
      case let other: Issue.record("輸入 `\(input)` 未判為 failedToParse，實得 `\(other)`。")
      }
    }
  }

  // MARK: - ③ 無任何可辨識之鍵

  @Test
  func testFailedToParseWhenNoRecognizableKey() throws {
    let raw = #"{"__UserDefMeta": {"title": "X"}, "NoSuchKey": 1}"#
    guard case let .failedToParse(detailText) = PrefsExchange.prepare(fromClipboardString: raw),
          let detailText
    else {
      Issue.record("整包無可辨識之鍵時，應判為 failedToParse 且帶有 detail。")
      return
    }
    #expect(detailText.contains("Unknown key"))
    #expect(detailText.contains("NoSuchKey"))
    // 保留鍵已於摘除階段移除，故不應出現在失敗清單內。
    #expect(!detailText.contains(UserDef.jsonExchangeMetaKey))
  }

  /// 整包只有保留鍵時，摘除後即無載荷可言。
  @Test
  func testFailedToParseWhenPayloadIsReservedKeysOnly() throws {
    let raw = #"{"__UserDefMeta": {"title": "X"}}"#
    guard case let .failedToParse(detail) = PrefsExchange.prepare(fromClipboardString: raw) else {
      Issue.record("整包只有保留鍵時，應判為 failedToParse。")
      return
    }
    #expect(detail == nil)
  }

  // MARK: - ④ 認得但無差異

  @Test
  func testNoDifferencesAgainstDefaultValue() throws {
    let target = UserDef.kCheckUpdateAutomatically
    guard case let .bool(defaultValue) = target.dataType else {
      Issue.record("`\(target.rawValue)` 之型別假設已改變。")
      return
    }
    // 現值未寫入 `UserDefaults` 時，當前值即 `dataType` 之預設值。
    UserDefaults.current.removeObject(forKey: target.rawValue)
    let raw = "{\"\(target.rawValue)\": \(defaultValue)}"
    guard case let .noDifferences(detail) = PrefsExchange.prepare(fromClipboardString: raw) else {
      Issue.record("包內值與當前值相同時，應判為 noDifferences。")
      return
    }
    #expect(detail == nil)
  }

  /// 差異判定之跨表示法：包內布林給 `1`、當前為 `true` ⇒ 不算差異。
  @Test
  func testBoolCrossRepresentationIsNotADifference() throws {
    let target = UserDef.kShouldNotFartInLieuOfBeep
    UserDefaults.current.set(true, forKey: target.rawValue)
    let raw = "{\"\(target.rawValue)\": 1}"
    guard case let .noDifferences(detail) = PrefsExchange.prepare(fromClipboardString: raw) else {
      Issue.record("布林之跨表示法（1 ↔ true）不應被判為差異。")
      return
    }
    #expect(detail == nil)
  }

  // MARK: - ⑤ 真有差異：確認態之內容與組版

  @Test
  func testConfirmApplyingContentAndLayout() throws {
    let target = UserDef.kRespectClientAccentColor
    UserDefaults.current.set(false, forKey: target.rawValue)
    let raw = """
    {"__UserDefMeta": {"title": "測試配置", "description": "這是說明。"},
      "\(target.rawValue)": true,
      "NoSuchKey": 1}
    """
    guard case let .confirmApplying(meta, payload, changed, detail) = PrefsExchange.prepare(
      fromClipboardString: raw
    ) else {
      Issue.record("包內值與當前值不同時，應判為 confirmApplying。")
      return
    }
    #expect(meta?.title == "測試配置")
    #expect(meta?.description == "這是說明。")
    #expect(changed.map(\.rawValue) == [target.rawValue])
    // 載荷已摘除保留鍵。
    #expect(payload.keys.sorted() == ["NoSuchKey", target.rawValue].sorted())
    let expectedTitle = PrefsExchange.changedItemTitle(for: target)
    let expectedDetail = "⚠ NoSuchKey: Unknown key"
    #expect(detail == expectedDetail)

    let preparation = PrefsExchange.Preparation.confirmApplying(
      meta: meta,
      payload: payload,
      changed: changed,
      detail: detail
    )
    #expect(preparation.alertTitle == "測試配置")
    let sections = preparation.alertMessage.components(separatedBy: "\n\n")
    #expect(sections.count == 3)
    #expect(sections.first == "這是說明。")
    #expect(sections.dropFirst().first == expectedTitle)
    #expect(
      sections.last
        == "i18n:Settings.ImportConfigFromClipboard.IgnoredKeys.Header".i18n + "\n" + expectedDetail
    )
    #expect(preparation.alertMessage.hasPrefix("這是說明。\n\n"))
  }

  /// `meta` 缺席時：標題與說明各自退化。
  @Test
  func testConfirmApplyingWithoutMetaUsesFallbacks() throws {
    let target = UserDef.kIsDebugModeEnabled
    UserDefaults.current.set(false, forKey: target.rawValue)
    let raw = "{\"\(target.rawValue)\": true}"
    guard case let .confirmApplying(meta, payload, changed, detail) = PrefsExchange.prepare(
      fromClipboardString: raw
    ) else {
      Issue.record("包內值與當前值不同時，應判為 confirmApplying。")
      return
    }
    #expect(meta == nil)
    #expect(detail == nil)
    let preparation = PrefsExchange.Preparation.confirmApplying(
      meta: meta,
      payload: payload,
      changed: changed,
      detail: detail
    )
    #expect(preparation.alertTitle == "i18n:AssistantConfig.Meta.Unspecified".i18n)
    // 無失敗項時僅兩段，且不含「未被接受之鍵」之附註。
    #expect(
      preparation.alertMessage
        == "i18n:AssistantConfig.Meta.NoDescription".i18n + "\n\n"
        + PrefsExchange.changedItemTitle(for: target)
    )
  }

  /// 各態之標題與訊息皆有對應之 i18n 鍵（測試靶下即鍵名本身）。
  @Test
  func testAlertTextsPerState() throws {
    #expect(
      PrefsExchange.Preparation.clipboardEmpty.alertTitle
        == "i18n:Settings.ImportConfigFromClipboard.ClipboardEmpty.AlertTitle".i18n
    )
    #expect(
      PrefsExchange.Preparation.clipboardEmpty.alertMessage
        == "i18n:Settings.ImportConfigFromClipboard.ClipboardEmpty.AlertMessage".i18n
    )
    let failed = PrefsExchange.Preparation.failedToParse(detail: "⚠ NoSuchKey: Unknown key")
    #expect(
      failed.alertTitle == "i18n:Settings.ImportConfigFromClipboard.FailedToParse.AlertTitle".i18n
    )
    #expect(
      failed.alertMessage
        == "i18n:Settings.ImportConfigFromClipboard.FailedToParse.AlertMessage".i18n + "\n\n"
        + "i18n:Settings.ImportConfigFromClipboard.IgnoredKeys.Header".i18n + "\n"
        + "⚠ NoSuchKey: Unknown key"
    )
    let noDifference = PrefsExchange.Preparation.noDifferences(detail: nil)
    #expect(
      noDifference.alertTitle == "i18n:Settings.ImportConfigFromClipboard.NoDifferences.AlertTitle".i18n
    )
    #expect(
      noDifference.alertMessage
        == "i18n:Settings.ImportConfigFromClipboard.NoDifferences.AlertMessage".i18n
    )
  }

  // MARK: - ⑥ 套用確實寫入

  @Test
  func testApplyPayloadWritesIntoUserDefaults() throws {
    let target = UserDef.kRespectClientAccentColor
    UserDefaults.current.set(false, forKey: target.rawValue)
    let result = PrefsExchange.applyPayload([target.rawValue: true, "NoSuchKey": 1])
    #expect(result.successes == [target.rawValue])
    #expect(result.failures.map(\.key) == ["NoSuchKey"])
    #expect(UserDefaults.current.object(forKey: target.rawValue) as? Bool == true)
  }

  /// 開發者分頁之檔案／拖放路徑所走之收尾：解碼 → 摘除保留鍵 → 逐鍵驗證 → 和解。
  @Test
  func testApplyPrefsJSONFromDataStripsReservedKeys() throws {
    let target = UserDef.kIsDebugModeEnabled
    let json = """
    {"__UserDefMeta": {"title": "X"}, "\(target.rawValue)": true, "NoSuchKey": 1}
    """
    let result = PrefsExchange.applyPrefsJSONFromData(Data(json.utf8))
    #expect(result.successes == [target.rawValue])
    #expect(result.failures.map(\.key) == ["NoSuchKey"])
    #expect(UserDefaults.current.object(forKey: target.rawValue) as? Bool == true)
    // 解不出 JSON 時，不得崩潰、亦不得誤判為成功。
    let broken = PrefsExchange.applyPrefsJSONFromData(Data("hello".utf8))
    #expect(broken.successes.isEmpty)
    #expect(broken.failures.map(\.key) == ["(root)"])
  }

  // MARK: - ⑦ 標題之取值

  @Test
  func testChangedItemTitleFallsBackToRawValue() throws {
    // 無 `.strings` 條目、亦無 `metaData` 之鍵 ⇒ 退回 `rawValue`。
    #expect(PrefsExchange.changedItemTitle(for: .kMaxCandidateLength) == "MaxCandidateLength")
    // 有條目之鍵 ⇒ 非 `rawValue`（測試靶無 lproj 資源時即 i18n 鍵名本身）。
    let candidateKeysTitle = PrefsExchange.changedItemTitle(for: .kCandidateKeys)
    #expect(candidateKeysTitle != UserDef.kCandidateKeys.rawValue)
    #expect(candidateKeysTitle == "i18n:UserDef.kCandidateKeys.shortTitle")
  }
}
