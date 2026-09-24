// (c) 2022 and onwards The vChewing Project (MulanPSL-2.0 License).
// ====================
// This code is released under the SPDX-License-Identifier: `MulanPSL-2.0`.

import Foundation

// MARK: - PrefsExchange

/// 「自剪貼簿匯入（由配置助手生成的）配置資料」之解析、差異計算與套用——與介面無關之部分。
///
/// 三條匯入路徑（開發者分頁之檔案匯入、其拖放、一般分頁之剪貼簿匯入）共用此處之收尾：
/// 解碼 → 摘除中介辭典 → 逐鍵驗證 → 和解（`PrefMgr.reconcileAfterExternalPrefsImport()`）。
/// 本檔僅用 Foundation：剪貼簿之讀取與 alert 之組版留給兩介面各自自理。
public enum PrefsExchange {
  // MARK: Public

  /// 匯入前之預備結果（「已套用」一態由呼叫端自行持有，故不在本列舉內）。
  public enum Preparation {
    case clipboardEmpty
    case failedToParse(detail: String?)
    case noDifferences(detail: String?)
    case confirmApplying(
      meta: UserDef.ExchangeMeta?,
      payload: [String: Any],
      changed: [UserDef],
      detail: String?
    )
  }

  /// 自剪貼簿字串準備一次匯入：解析 → 摘除中介辭典 → 與當前設定逐鍵 diff。
  ///
  /// 本函式為純查詢，不寫入 `UserDefaults`——「取消即完全不寫入」之保證由此而來。
  /// - Parameter raw: 剪貼簿之字串內容；`nil`（＝剪貼簿內沒有文字）亦為合法輸入。
  /// - Returns: 依態分流之預備結果。
  public static func prepare(fromClipboardString raw: String?) -> Preparation {
    guard let raw, !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      return .clipboardEmpty
    }
    guard let jsonObj = try? JSONSerialization.jsonObject(with: Data(raw.utf8)),
          let root = jsonObj as? [String: Any], !root.isEmpty
    else { return .failedToParse(detail: nil) }
    let destructured = UserDef.destructureExchange(root)
    // 整包只有中介辭典等保留鍵時，摘除後即無任何可辨識之內容。
    guard !destructured.payload.isEmpty else { return .failedToParse(detail: nil) }
    let (changed, result) = UserDef.diffAgainstCurrent(destructured.payload)
    let detail = detailText(of: result)
    // 一個鍵都不認得（鍵名全滅）與「認得但無差異」係兩回事，故分開處理。
    if changed.isEmpty, result.successes.isEmpty { return .failedToParse(detail: detail) }
    if changed.isEmpty { return .noDifferences(detail: detail) }
    return .confirmApplying(
      meta: destructured.meta,
      payload: destructured.payload,
      changed: changed,
      detail: detail
    )
  }

  /// 檔案／拖放路徑：解碼 → 摘除中介辭典 → 逐鍵驗證 → 和解。三條路徑共用此收尾。
  /// - Parameter data: 偏好交換格式之 JSON 內容。
  /// - Returns: 逐鍵之匯入結果。
  @discardableResult
  public static func applyPrefsJSONFromData(_ data: Data) -> UserDef.ImportResult {
    let (_, result) = UserDef.importFromExchangeJSON(data)
    return reconciled(result)
  }

  /// 套用已解析之載荷（剪貼簿路徑：載荷已於 `prepare` 階段摘除中介辭典）。
  /// - Parameter payload: 已摘除保留鍵之扁平辭典。
  /// - Returns: 逐鍵之匯入結果。
  @discardableResult
  public static func applyPayload(_ payload: [String: Any]) -> UserDef.ImportResult {
    reconciled(UserDef.importFromDictionary(payload))
  }

  /// 單一偏好鍵之可讀標題（供 alert 之清單）。
  ///
  /// 本倉有少數鍵（如 `MaxCandidateLength`）無 `.strings` 條目，其 `.i18n` 會原封不動回傳鍵名
  /// （仍以 `i18n:` 起頭），屆時逕退回 `rawValue`，以免在 alert 內露出 i18n 鍵名。
  /// 惟測試靶等不帶 lproj 資源之行程對**所有**鍵皆回傳鍵名，故退化條件以「本行程確實帶有語系資源」
  /// 為前提（此類無 `.strings` 條目之鍵在本倉亦無 `metaData`，故兩側之退化結果一致）。
  /// - Parameter userDef: 目標偏好鍵。
  /// - Returns: 本地化標題；無從取得時為該鍵之 `rawValue`。
  public static func changedItemTitle(for userDef: UserDef) -> String {
    guard let titleKey = userDef.metaData?.shortTitle, !titleKey.isEmpty else {
      return userDef.rawValue
    }
    let localized = titleKey.i18n
    guard !localized.isEmpty else { return userDef.rawValue }
    if localized == titleKey, hasLocalizationTables { return userDef.rawValue }
    return localized
  }

  // MARK: Private

  /// 本行程是否帶有語系資源（`*.lproj/Localizable.strings`）。
  private static var hasLocalizationTables: Bool {
    Bundle.main.path(forResource: "Localizable", ofType: "strings") != nil
  }

  /// 失敗清單之逐行文字（格式照既有慣例）；無失敗時為 `nil`。
  /// 標題（「下列項目未被接受：」）由 `alertMessage` 統一加上，故此處只回原始逐行內容。
  private static func detailText(of result: UserDef.ImportResult) -> String? {
    let body = result.failures.map { "⚠ \($0.key): \($0.reason)" }.joined(separator: "\n")
    return body.isEmpty ? nil : body
  }

  /// 「未被接受之鍵」之附註；空者為 `nil`。
  private static func ignoredKeysNote(_ body: String?) -> String? {
    guard let body, !body.isEmpty else { return nil }
    return "i18n:Settings.ImportConfigFromClipboard.IgnoredKeys.Header".i18n + "\n" + body
  }

  /// 僅在確有成功寫入時才啟動和解——無寫入即無推式副作用可補。
  private static func reconciled(_ result: UserDef.ImportResult) -> UserDef.ImportResult {
    if !result.successes.isEmpty { PrefMgr.shared.reconcileAfterExternalPrefsImport() }
    return result
  }
}

extension PrefsExchange.Preparation {
  /// 依態組版之 alert 標題。
  public var alertTitle: String {
    switch self {
    case .clipboardEmpty:
      return "i18n:Settings.ImportConfigFromClipboard.ClipboardEmpty.AlertTitle".i18n
    case .failedToParse:
      return "i18n:Settings.ImportConfigFromClipboard.FailedToParse.AlertTitle".i18n
    case .noDifferences:
      return "i18n:Settings.ImportConfigFromClipboard.NoDifferences.AlertTitle".i18n
    case let .confirmApplying(meta, _, _, _):
      // 配置之名稱由助手提供（非 i18n 鍵），故僅在非空時取用、且照原樣呈現。
      if let title = meta?.title, !title.isEmpty { return title }
      return "i18n:AssistantConfig.Meta.Unspecified".i18n
    }
  }

  /// 依態組版之 alert 訊息。
  ///
  /// `confirmApplying` 態之組版為三段（次序固定）：配置說明 → 受影響之偏好鍵標題（逐行）
  /// → 未被接受之鍵（僅在確有內容時）。第三段係為免「部分鍵被靜默丟棄」。
  public var alertMessage: String {
    switch self {
    case .clipboardEmpty:
      return "i18n:Settings.ImportConfigFromClipboard.ClipboardEmpty.AlertMessage".i18n
    case let .failedToParse(detail):
      return "i18n:Settings.ImportConfigFromClipboard.FailedToParse.AlertMessage".i18n
        + (PrefsExchange.ignoredKeysNote(detail).map { "\n\n" + $0 } ?? "")
    case let .noDifferences(detail):
      return "i18n:Settings.ImportConfigFromClipboard.NoDifferences.AlertMessage".i18n
        + (PrefsExchange.ignoredKeysNote(detail).map { "\n\n" + $0 } ?? "")
    case let .confirmApplying(meta, _, changed, detail):
      var sections = [String]()
      if let description = meta?.description, !description.isEmpty {
        // 說明由助手提供（非 i18n 鍵），故照原樣呈現。
        sections.append(description)
      } else {
        sections.append("i18n:AssistantConfig.Meta.NoDescription".i18n)
      }
      sections.append(changed.map { PrefsExchange.changedItemTitle(for: $0) }.joined(separator: "\n"))
      PrefsExchange.ignoredKeysNote(detail).map { sections.append($0) }
      return sections.joined(separator: "\n\n")
    }
  }
}
