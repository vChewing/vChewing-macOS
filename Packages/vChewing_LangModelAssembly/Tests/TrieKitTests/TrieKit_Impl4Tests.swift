// (c) 2025 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation
import Homa
import Testing
@testable import TrieKit

// MARK: - TrieKitTestSuite

protocol TrieKitTestSuite {}

extension TrieKitTestSuite {
  static func makeAssemblerUsingMockLM() -> Homa.Assembler {
    .init(
      gramQuerier: { keyArray in
        let flatKeys = keyArray.map(\.first)
        return [
          Homa.Gram(
            keyArray: flatKeys,
            current: flatKeys.joined(separator: "-"),
            previous: nil,
            probability: -1
          ),
        ]
      }
    )
  }

  static func mustDone(_ task: @escaping () throws -> ()) -> Bool {
    do {
      try task()
      return true
    } catch {
      return false
    }
  }

  static func mustFail(_ task: @escaping () throws -> ()) -> Bool {
    do {
      try task()
      return false
    } catch {
      return true
    }
  }

  static func measureTime(_ task: @escaping () throws -> ()) rethrows -> Double {
    let startTime = Date.now.timeIntervalSince1970
    try task()
    return Date.now.timeIntervalSince1970 - startTime
  }
}

// MARK: - TestLM4Trie

final class TestLM4Trie {
  // MARK: Lifecycle

  init(trie: VanguardTrieProtocol) {
    self.trie = trie
  }

  // MARK: Internal

  var readingSeparator: Character { trie.readingSeparator }

  func hasGrams(
    _ keys: [String],
    partiallyMatch: Bool = false,
    partiallyMatchedKeysHandler: ((Set<[String]>) -> ())? = nil
  )
    -> Bool {
    guard !keys.isEmpty else { return false }
    return trie.hasGrams(
      keys,
      filterType: .langNeutral,
      partiallyMatch: partiallyMatch,
      partiallyMatchedKeysHandler: partiallyMatchedKeysHandler
    )
  }

  func queryGrams(
    _ keys: [String],
    partiallyMatch: Bool = false,
    partiallyMatchedKeysPostHandler: ((Set<[String]>) -> ())? = nil
  )
    -> [Homa.Gram] {
    guard !keys.isEmpty else { return [] }
    return trie.queryGrams(
      keys,
      filterType: .langNeutral,
      partiallyMatch: partiallyMatch,
      partiallyMatchedKeysPostHandler: partiallyMatchedKeysPostHandler
    ).map {
      Homa.Gram(
        keyArray: $0.keyArray,
        current: $0.value,
        previous: $0.previous,
        probability: $0.probability
      )
    }
  }

  func queryGrams(
    _ keys: [Homa.PossibleKey],
    partiallyMatch: Bool = false,
    partiallyMatchedKeysPostHandler: ((Set<[String]>) -> ())? = nil
  )
    -> [Homa.Gram] {
    queryGrams(
      keys.map(\.first),
      partiallyMatch: partiallyMatch,
      partiallyMatchedKeysPostHandler: partiallyMatchedKeysPostHandler
    )
  }

  // MARK: Private

  private let trie: VanguardTrieProtocol
}
