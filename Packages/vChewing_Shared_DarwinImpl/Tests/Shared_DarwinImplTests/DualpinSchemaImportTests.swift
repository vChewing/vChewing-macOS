// (c) 2022 and onwards The vChewing Project (MulanPSL-2.0 License).
// ====================
// This code is released under the SPDX-License-Identifier: `MulanPSL-2.0`.

import Arimitsu
import Foundation
@testable import Shared
@testable import Shared_DarwinImpl
import Testing

/// `DualpinSchemaStore`（雙拼方案匯入）之測試。
///
/// 測試隔離比照 `PrefMgrReconciliationTests`：以本套件專屬 suite 覆蓋 `UserDefaults.current`
/// （`UserDefaults.unitTests` ＋ `UserDefaults.pendingUnitTests`），並於 `deinit` 復原開關。
/// `DualpinSchemaStore` 內部一律走 `PrefMgr.shared`，而 `@AppProperty.container` 係即時解析
/// `UserDefaults.current`，故上述覆蓋足以隔離其寫入。
@Suite(.serialized)
final class DualpinSchemaImportTests {
  // MARK: Lifecycle

  init() {
    UserDefaults.unitTests = .init(suiteName: "org.atelierInmu.vChewing.SharedDarwinImpl.UnitTests")
    UserDefaults.pendingUnitTests = true
    UserDef.resetAll()
  }

  deinit {
    UserDefaults.pendingUnitTests = false
  }

  // MARK: Internal

  /// 合法方案（此處以內建微軟雙拼之 JSON 原文為例）應匯入成功，且：
  /// 原文入偏好、雙拼方案切至「自訂雙拼」（連帶開啟拼音模式與雙拼模式）。
  @Test
  func testImportAcceptsUsableSchema() throws {
    let url = try writeTemporarySchemaFile(contents: Data(DualpinParser.mspySchemaJSON.utf8))
    defer { cleanUpTemporarySchemaFile(at: url) }
    let outcome = DualpinSchemaStore.importSchema(from: url)
    guard case let .success(rawID, title) = outcome else {
      Issue.record("應匯入成功，實得：\(outcome)。")
      return
    }
    #expect(rawID == DualpinParser.mspy.rawID)
    #expect(!title.isEmpty)
    #expect(PrefMgr.shared.dualpinSchemaJSON == DualpinParser.mspySchemaJSON)
    #expect(DualpinSchemaStore.currentParser?.rawID == DualpinParser.mspy.rawID)
    #expect(DualpinSchemaStore.currentTitle == title)
    // 匯入即切至「自訂雙拼」（雙拼方案槽），並開啟拼音模式與雙拼模式。
    #expect(PrefMgr.shared.keyboardParser4Dualpin == KeyboardParser.ofDualpinCustom.rawValue)
    #expect(PrefMgr.shared.pinyinTypingEnabled)
    #expect(PrefMgr.shared.dualpinEnabledForPinyinTyping)
  }

  /// 檔案不存在（或無法讀取）時報 `.unreadable`。
  @Test
  func testImportRejectsUnreadableFile() {
    let url = URL(fileURLWithPath: "/nonexistent-\(UUID().uuidString).json")
    #expect(DualpinSchemaStore.importSchema(from: url) == .failure(.unreadable))
  }

  /// 超過 `maximumImportByteCount` 時報 `.tooLarge`（且不進入解碼）。
  @Test
  func testImportRejectsOversizedFile() throws {
    let contents = Data(repeating: 0x20, count: DualpinSchemaStore.maximumImportByteCount + 1)
    let url = try writeTemporarySchemaFile(contents: contents)
    defer { cleanUpTemporarySchemaFile(at: url) }
    #expect(DualpinSchemaStore.importSchema(from: url) == .failure(.tooLarge))
  }

  /// 非雙拼方案之 JSON（含無法解碼為 UTF-8 之資料）時報 `.malformed`。
  @Test
  func testImportRejectsMalformedContent() throws {
    let url = try writeTemporarySchemaFile(contents: Data("這不是方案。".utf8))
    defer { cleanUpTemporarySchemaFile(at: url) }
    #expect(DualpinSchemaStore.importSchema(from: url) == .failure(.malformed))
    let badEncoding = try writeTemporarySchemaFile(contents: Data([0xFF, 0xFE, 0xFD]))
    defer { cleanUpTemporarySchemaFile(at: badEncoding) }
    #expect(DualpinSchemaStore.importSchema(from: badEncoding) == .failure(.malformed))
  }

  /// 校驗未過時報 `.invalid`，且錯誤碼逐條轉述引擎之結論。
  ///
  /// 此處以「冒用內建方案之 `rawID`、但內容與內建方案不再相等」之方案觸發 `E9`：
  /// 內建方案校驗自身時不算相衝，惟自備方案冒用內建 `rawID` 仍屬相衝。
  @Test
  func testImportRejectsSchemaClaimingBuiltinRawID() throws {
    var parser = DualpinParser.mspy
    parser.rawTitle = "冒名方案"
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let json = try #require(String(data: try encoder.encode(parser), encoding: .utf8))
    let url = try writeTemporarySchemaFile(contents: Data(json.utf8))
    defer { cleanUpTemporarySchemaFile(at: url) }
    let outcome = DualpinSchemaStore.importSchema(from: url)
    guard case let .failure(.invalid(issues)) = outcome else {
      Issue.record("應因校驗未過而失敗，實得：\(outcome)。")
      return
    }
    #expect(!issues.isEmpty)
    #expect(issues.contains { $0.code == "E9" })
    #expect(issues.allSatisfy { !$0.detail.isEmpty })
    // 匯入失敗不得留下任何痕跡。
    #expect(PrefMgr.shared.dualpinSchemaJSON.isEmpty)
  }

  /// 狀態文案：未匯入、失敗、成功三態各安其位。
  @Test
  func testStatusTextReflectsOutcome() {
    #expect(
      DualpinSchemaStore.statusText(after: nil, schemaJSON: "")
        == "i18n:Settings.DualpinScheme.Status.None".i18n
    )
    #expect(
      DualpinSchemaStore.statusText(after: .failure(.tooLarge), schemaJSON: "")
        == "i18n:Settings.DualpinScheme.Status.TooLarge".i18n
    )
    #expect(
      DualpinSchemaStore.statusText(
        after: .success(rawID: "dualPin.Test", title: "測試"),
        schemaJSON: ""
      )
        == String(
          format: "i18n:Settings.DualpinScheme.Status.Imported:%@".i18n,
          arguments: ["測試"]
        )
    )
    // 匯入後重繪（`outcome` 為 `nil`）時，改以偏好現值推斷標題。
    let url = writeTemporarySchemaFileOrNil(contents: Data(DualpinParser.gbt17SchemaJSON.utf8))
    defer { if let url { cleanUpTemporarySchemaFile(at: url) } }
    guard let url, case .success = DualpinSchemaStore.importSchema(from: url) else { return }
    let redrawn = DualpinSchemaStore.statusText(
      after: nil,
      schemaJSON: PrefMgr.shared.dualpinSchemaJSON
    )
    #expect(redrawn.contains(DualpinSchemaStore.currentTitle ?? "\u{0}"))
  }

  /// 選單標題：自訂方案一律示固定名稱，不綴方案標題——該選單內容無法即時生效，
  /// 綴了反而誤導（SettingsUI 需重進頁面、SettingsCocoa 更難觸發更新）。
  @Test
  func testMenuNameDoesNotAppendSchemaTitle() throws {
    let before = KeyboardParser.ofDualpinCustom.localizedMenuName
    #expect(before == "i18n:KeyboardLayout.DualpinCustom".i18n)
    let url = try writeTemporarySchemaFile(contents: Data(DualpinParser.gbt17SchemaJSON.utf8))
    defer { cleanUpTemporarySchemaFile(at: url) }
    let outcome = DualpinSchemaStore.importSchema(from: url)
    guard case let .success(_, title) = outcome else {
      Issue.record("應匯入成功，實得：\(outcome)。")
      return
    }
    #expect(KeyboardParser.ofDualpinCustom.localizedMenuName == before)
    #expect(!before.contains(title))
  }

  // MARK: Private

  /// 於暫存目錄建一份方案檔，回傳其 URL。
  private func writeTemporarySchemaFile(contents: Data) throws -> URL {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("DualpinSchemaImportTests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let url = directory.appendingPathComponent("schema.json")
    try contents.write(to: url)
    return url
  }

  /// 同上，但建檔失敗時回 `nil`（供不以 `throws` 宣告之測試使用）。
  private func writeTemporarySchemaFileOrNil(contents: Data) -> URL? {
    try? writeTemporarySchemaFile(contents: contents)
  }

  private func cleanUpTemporarySchemaFile(at url: URL) {
    try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
  }
}
