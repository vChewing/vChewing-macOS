// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation

// MARK: - CandidateTextService

public struct CandidateTextService: Codable {
  // MARK: Lifecycle

  public init?(key: String, definedValue: String, param: String = #"%s"#, reading: [String] = []) {
    guard !key.isEmpty, !definedValue.isEmpty, definedValue.first != "#" else { return nil }
    self.candidateText = param
    self.key = key.replacingOccurrences(of: #"%s"#, with: param)
    self.reading = reading
    let rawKeyHasParam = self.key != key
    self.definedValue = definedValue.replacingOccurrences(of: #"%s"#, with: param)

    // Handle Symbol Menu Title
    var newMenuTitle = self.key
    if param.count == 1, let strUTFCharCode = param.first?.codePoint, rawKeyHasParam {
      newMenuTitle = "\(self.key) (\(strUTFCharCode))"
    }
    self.menuTitle = newMenuTitle

    // Start parsing rawValue
    var temporaryRawValue = definedValue
    var finalServiceValue: ServiceValue?
    let fetchedTypeHeader = temporaryRawValue.prefix(5)
    guard fetchedTypeHeader.count == 5 else { return nil }
    for _ in 0 ..< 5 {
      temporaryRawValue.removeFirst()
    }
    switch fetchedTypeHeader.uppercased() {
    case #"@SEL:"#:
      finalServiceValue = .selector(temporaryRawValue)
    case #"@URL:"#, #"@WEB:"#:
      let encodedParam = param
        .addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed)
      guard let encodedParam = encodedParam else { return nil }
      let rawURLStr = temporaryRawValue.replacingOccurrences(of: #"%s"#, with: encodedParam)
      guard let components = URLComponents(string: rawURLStr),
            let scheme = components.scheme?.lowercased() else { return nil }
      switch scheme {
      case "http", "https":
        // 必須有 host
        guard components.host != nil, let url = components.url else { return nil }
        finalServiceValue = .url(url)
      // 在解析階段明確拒絕其他 scheme（例如 mailto/data/javascript）。
      // 僅允許處理 `http` 與 `https` URL。
      case "file":
        // 'file' scheme 被刻意拒絕，不予處理。
        // 此舉可防止 IME 透過候選詞服務直接存取本機檔案，
        // 降低潛在的本機檔案存取風險。
        return nil
      default:
        return nil
      }
    default: return nil
    }
    guard let finalServiceValue = finalServiceValue else { return nil }
    self.value = finalServiceValue
    let finalSanityCheckResult = Self.finalSanityCheck?(self) ?? true
    if !finalSanityCheckResult { return nil }
  }

  // MARK: Public

  public enum ServiceValueType: Int {
    case url = 0
    case selector = 1
  }

  public enum ServiceValue: Codable {
    case url(URL)
    case selector(String)
  }

  public static var finalSanityCheck: ((Self) -> Bool)?

  /// 允許被 selector 服務執行的 selector 名稱清單（必須由使用方註冊，
  /// 例如 `MainAssembly`）。當此集合為空時，selector 檢查將採取預設拒絕策略。
  public static var allowedSelectorSet: Set<String> = []

  public let key: String
  public let reading: [String]
  public let menuTitle: String
  public let definedValue: String
  public let value: ServiceValue
  public let candidateText: String

  /// 測試用便捷輔助函式，用於啟用／停用最終完整性檢查。
  /// 啟用時將設定一個預設拒絕的完整性檢查，根據預先註冊在 `allowedSelectorSet` 中的
  /// 白名單來驗證 URL scheme 與 selector。
  public static func enableFinalSanityCheck() {
    Self.finalSanityCheck = defaultFinalSanityCheck
  }

  public static func disableFinalSanityCheck() {
    Self.finalSanityCheck = nil
  }

  // MARK: Internal

  /// 預設的最終完整性檢查實作。強制執行預設拒絕策略：
  /// 僅允許 `http` 與 `https` 以及經過允許的 selector；
  /// `http/https` 必須具有 host；`file` scheme 在解析時即被明確拒絕。
  internal static func defaultFinalSanityCheck(_ target: Self) -> Bool {
    let allowedURLSchemes: Set<String> = ["http", "https"]
    let allowedSelectors: Set<String> = Self.allowedSelectorSet
    switch target.value {
    case let .url(url):
      guard let scheme = url.scheme?.lowercased() else { return false }
      if allowedURLSchemes.contains(scheme) {
        if scheme == "http" || scheme == "https" { return url.host != nil }
        return true
      }
      // 'file' scheme 預設不被允許（在解析時即拒絕），因此
      // 預設完整性檢查不會接受 'file' URL。
      // 所有其餘 scheme 都會被拒絕。
      return false
    case let .selector(strSelector):
      // 當 candidateText 仍為佔位符號時，copy selector 仍具意義；
      // 否則，selector 必須存在於允許集合中。
      guard target.candidateText == "%s" else { return allowedSelectors.contains(strSelector) }
      if allowedSelectors.contains(strSelector) {
        if strSelector.hasPrefix("copyRuby") || strSelector.hasPrefix("copyInline") {
          return !target.reading.joined().isEmpty
        }
        return true
      }
      return false
    }
  }
}

// MARK: RawRepresentable

extension CandidateTextService: RawRepresentable {
  public init?(rawValue: String) {
    let cells = rawValue.components(separatedBy: "\t")
    guard cells.count == 2 else { return nil }
    self.init(key: cells[0], definedValue: cells[1])
  }

  public var rawValue: String {
    "\(key)\t\(definedValue)"
  }

  public init?(rawValue: String, param: String, reading: [String]) {
    let cells = rawValue.components(separatedBy: "\t")
    guard cells.count >= 2 else { return nil }
    self.init(key: cells[0], definedValue: cells[1], param: param, reading: reading)
  }
}

// MARK: - Extensions

extension Array where Element == CandidateTextService {
  public var rawRepresentation: [String] {
    map(\.rawValue)
  }
}

extension Array where Element == String {
  public func parseIntoCandidateTextServiceStack(
    candidate: String = #"%s"#, reading: [String] = []
  )
    -> [CandidateTextService] {
    compactMap { rawValue in
      CandidateTextService(rawValue: rawValue, param: candidate, reading: reading)
    }
  }
}
