// (c) 2026 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation
import Testing

@testable import Hotenka

enum HotenkaTestSupport {
  // MARK: Internal

  static let packageRootURL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()

  static let testDataURL = packageRootURL
    .appendingPathComponent("Tests")
    .appendingPathComponent("HotenkaTestDictData")

  static let sampleInput = "为中华崛起而读书"

  static func ensureStringMapFixture() throws -> URL {
    let outputURL = testDataURL.appendingPathComponent("convdict.stringmap")
    try stringMapFixtureData().write(to: outputURL, options: .atomic)
    return outputURL
  }

  static func stringMapFixtureData() throws -> Data {
    try Hotenka.StringMap.serialize(from: canonicalDictionary(loadSourceDictionary()))
  }

  static func verifySampleConversion(
    using converter: HotenkaChineseConverter,
    sourceLocation: SourceLocation = #_sourceLocation
  ) {
    let result1 = converter.convert(sampleInput, to: .zhHantTW)
    let result2 = converter.convert(result1, to: .zhHantKX)
    let result3 = converter.convert(result2, to: .zhHansJP)
    #expect(result1 == "為中華崛起而讀書", sourceLocation: sourceLocation)
    #expect(result2 == "爲中華崛起而讀書", sourceLocation: sourceLocation)
    #expect(result3 == "為中華崛起而読書", sourceLocation: sourceLocation)
  }

  // MARK: Private

  private static func canonicalDictionary(
    _ store: [String: [String: String]]
  )
    -> [String: [String: String]] {
    var ordered: [String: [String: String]] = [:]
    for dictType in DictType.allCases {
      let key = dictType.rawKeyString
      let entries = (store[key] ?? [:]).sorted {
        $0.key.utf8.lexicographicallyPrecedes($1.key.utf8)
      }
      var sub: [String: String] = [:]
      for (k, v) in entries { sub[k] = v }
      ordered[key] = sub
    }
    return ordered
  }

  private static func loadSourceDictionary() -> [String: [String: String]] {
    var store: [String: [String: String]] = [:]
    for dictType in DictType.allCases {
      store[dictType.rawKeyString] = [:]
    }

    let baseURL = testDataURL
    guard let enumerator = FileManager.default.enumerator(
      at: baseURL,
      includingPropertiesForKeys: nil,
      options: [.skipsHiddenFiles]
    ) else { return store }

    let files = (enumerator.allObjects as? [URL] ?? [])
      .filter { $0.pathExtension == "txt" }
      .sorted { $0.path < $1.path }

    for fileURL in files {
      let name = fileURL.deletingPathExtension().lastPathComponent
      guard store[name] != nil else { continue }
      guard let content = try? String(contentsOfFile: fileURL.path, encoding: .utf8)
      else { continue }
      for line in content.split(whereSeparator: \.isNewline) {
        let cols = line.split(separator: "\t", maxSplits: 1)
        guard cols.count == 2 else { continue }
        store[name]?[String(cols[0])] = String(cols[1])
      }
    }

    return store
  }
}
