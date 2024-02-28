// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation

public struct CandidateTextService: Codable {
  public enum ServiceValueType: Int {
    case url = 0
    case selector = 1
  }

  public enum ServiceValue: Codable {
    case url(URL)
    case selector(String)
  }

  public let key: String
  public let reading: [String]
  public let menuTitle: String
  public let definedValue: String
  public let value: ServiceValue
  public let candidateText: String

  public static var finalSanityCheck: ((CandidateTextService) -> Bool)?

  public init?(key: String, definedValue: String, param: String = #"%s"#, reading: [String] = []) {
    guard !key.isEmpty, !definedValue.isEmpty, definedValue.first != "#" else { return nil }
    candidateText = param
    self.key = key.replacingOccurrences(of: #"%s"#, with: param)
    self.reading = reading
    let rawKeyHasParam = self.key != key
    self.definedValue = definedValue.replacingOccurrences(of: #"%s"#, with: param)

    // Handle Symbol Menu Title
    var newMenuTitle = self.key
    if param.count == 1, let strUTFCharCode = param.first?.codePoint, rawKeyHasParam {
      newMenuTitle = "\(self.key) (\(strUTFCharCode))"
    }
    menuTitle = newMenuTitle

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
    case #"@WEB:"#, #"@URL:"#:
      let encodedParam = param.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed)
      guard let encodedParam = encodedParam else { return nil }
      let newURL = URL(string: temporaryRawValue.replacingOccurrences(of: #"%s"#, with: encodedParam))
      guard let newURL = newURL else { return nil }
      finalServiceValue = .url(newURL)
    default: return nil
    }
    guard let finalServiceValue = finalServiceValue else { return nil }
    value = finalServiceValue
    let finalSanityCheckResult = Self.finalSanityCheck?(self) ?? true
    if !finalSanityCheckResult { return nil }
  }
}

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

public extension Array where Element == CandidateTextService {
  var rawRepresentation: [String] {
    map(\.rawValue)
  }
}

public extension Array where Element == String {
  func parseIntoCandidateTextServiceStack(
    candidate: String = #"%s"#, reading: [String] = []
  ) -> [CandidateTextService] {
    compactMap { rawValue in
      CandidateTextService(rawValue: rawValue, param: candidate, reading: reading)
    }
  }
}
