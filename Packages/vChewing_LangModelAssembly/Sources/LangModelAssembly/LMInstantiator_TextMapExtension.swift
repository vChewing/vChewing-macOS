// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation
import Homa
import SwiftExtension
import TrieKit

// MARK: - LMAssembly.LMInstantiator.CoreColumn

extension LMAssembly.LMInstantiator {
  enum CoreColumn: Int32 {
    case theDataCHS = 1
    case theDataCHT = 2
    case theDataCNS = 3
    case theDataMISC = 4
    case theDataSYMB = 5
    case theDataCHEW = 6

    // MARK: Internal

    var defaultScore: Double {
      switch self {
      case .theDataCHEW: return -1
      case .theDataCNS: return -11
      case .theDataSYMB: return -13
      case .theDataMISC: return -10
      default: return -9.9
      }
    }

    // MARK: Fileprivate

    fileprivate var textMapTypeIDs: Set<Int32> {
      switch self {
      case .theDataCHS: return [5]
      case .theDataCHT: return [6]
      case .theDataCNS: return [7]
      case .theDataMISC: return [4, 8]
      case .theDataSYMB: return [9]
      case .theDataCHEW: return [10]
      }
    }

    fileprivate var trieEntryType: VanguardTrie.Trie.EntryType {
      .init(rawValue: textMapTypeIDs.reduce(into: Int32(0)) { $0 |= $1 })
    }
  }
}

// MARK: - Factory Dictionary Lifecycle

extension LMAssembly.LMInstantiator {
  public enum FactoryCoreLookupStrategy {
    /// Route through the normal factory lookup path, respecting current config switches
    /// such as `partialMatchEnabled`.
    case configuredLookup
    /// Return only longer complete-key matches. This is independent from partial match.
    case strictSuperset
  }

  @discardableResult
  public static func connectFactoryDictionary(
    textMapPath: String,
    dropPreviousConnection: Bool = true
  )
    -> Bool {
    if dropPreviousConnection {
      disconnectFactoryDictionary()
    }

    guard let resolvedTextMapPath = resolveTextMapPath(from: textMapPath) else {
      vCLMLog("Factory TextMap path not found: \(textMapPath)")
      return false
    }

    if !Self.asyncLoadingUserData {
      do {
        let textMapData = try Data(contentsOf: URL(fileURLWithPath: resolvedTextMapPath), options: [.mappedIfSafe])
        factoryTrie = try VanguardTrie.TextMapTrie(data: textMapData)
        vCLMLog("Factory TextMap loading complete: \(resolvedTextMapPath)")
        return true
      } catch {
        vCLMLog("Factory TextMap loading failed: \(error.localizedDescription)")
        factoryTrie = nil
        return false
      }
    } else {
      LMAssembly.fileHandleQueue.async {
        do {
          let textMapData = try Data(contentsOf: URL(fileURLWithPath: resolvedTextMapPath), options: [.mappedIfSafe])
          let newTrie = try VanguardTrie.TextMapTrie(data: textMapData)
          factoryTrie = newTrie
          vCLMLog("Factory TextMap async loading complete: \(resolvedTextMapPath)")
        } catch {
          vCLMLog("Factory TextMap async loading failed: \(error.localizedDescription)")
          factoryTrie = nil
        }
      }
      return true
    }
  }

  public static func disconnectFactoryDictionary() {
    factoryTrie = nil
  }

  @discardableResult
  public static func connectToTestFactoryDictionary(
    textMapData: String
  )
    -> Bool {
    guard !textMapData.isEmpty else { return false }
    guard !textMapData.contains("#PRAGMA:VANGUARD_REVLOOKUP_TSV") else {
      vCLMLog("External revlookup fixtures are no longer supported.")
      return false
    }

    do {
      factoryTrie = try VanguardTrie.TextMapTrie(data: Data(textMapData.utf8))
      return true
    } catch {
      vCLMLog("Factory TextMap test fixture loading failed: \(error.localizedDescription)")
      factoryTrie = nil
      return false
    }
  }

  public static func getFactoryReverseLookupData(with kanji: String) -> [String]? {
    guard let readings = factoryTrie?.reverseLookup(for: kanji) else { return nil }
    return readings.map { restorePhonabetFromASCII($0) }
  }

  func getHaninSymbolMenuUnigrams() -> [Homa.Gram] {
    guard let trie = Self.factoryTrie else { return [] }
    let nodes = trie.getNodes(
      keyArray: ["_punctuation_list"],
      filterType: [],
      partiallyMatch: false,
      longerSegment: false
    )
    let entries = nodes.flatMap(\.entries)
    return makeFactoryUnigrams(
      entries: entries,
      keyArray: ["_punctuation_list"],
      sourceKey: "_punctuation_list",
      column: .theDataMISC,
      includeHalfWidthVariants: false
    )
  }

  public func factoryCoreUnigramsFor(
    key: String,
    keyArray: [String],
    strategy: FactoryCoreLookupStrategy = .configuredLookup
  )
    -> [Homa.Gram] {
    switch strategy {
    case .configuredLookup:
      return factoryUnigramsFor(
        key: key,
        keyArray: keyArray,
        column: isCHS ? .theDataCHS : .theDataCHT
      )
    case .strictSuperset:
      return factoryStrictSupersetUnigramsFor(
        subsetKey: key,
        subsetKeyArray: keyArray,
        column: isCHS ? .theDataCHS : .theDataCHT
      )
    }
  }

  @available(*, deprecated, message: "Use strategy: .strictSuperset or .configuredLookup instead of onlyFindSupersets.")
  public func factoryCoreUnigramsFor(
    key: String,
    keyArray: [String],
    onlyFindSupersets: Bool
  )
    -> [Homa.Gram] {
    factoryCoreUnigramsFor(
      key: key,
      keyArray: keyArray,
      strategy: onlyFindSupersets ? .strictSuperset : .configuredLookup
    )
  }

  func factoryUnigramsFor(
    key: String,
    keyArray: [String],
    column: LMAssembly.LMInstantiator.CoreColumn
  )
    -> [Homa.Gram] {
    if key == "_punctuation_list" { return [] }
    guard let trie = Self.factoryTrie else { return [] }
    if config.partialMatchEnabled {
      return factoryPartiallyMatchedUnigramsFor(
        queryKeyArray: keyArray,
        column: column,
        trie: trie
      )
    }
    let encryptedKeyArray = keyArray.map { Self.convertPhonabetToASCII($0) }
    let nodes = trie.getNodes(
      keyArray: encryptedKeyArray,
      filterType: [],
      partiallyMatch: false,
      longerSegment: false
    )
    let entries = nodes.flatMap(\.entries)
    let encryptedKey = Self.convertPhonabetToASCII(key)
    return makeFactoryUnigrams(
      entries: entries,
      keyArray: keyArray,
      sourceKey: encryptedKey,
      column: column,
      includeHalfWidthVariants: true
    )
  }

  func factoryStrictSupersetUnigramsFor(
    subsetKey: String,
    subsetKeyArray: [String],
    column: LMAssembly.LMInstantiator.CoreColumn
  )
    -> [Homa.Gram] {
    if subsetKey == "_punctuation_list" { return [] }
    guard let trie = Self.factoryTrie else { return [] }
    let encryptedKeyArray = subsetKeyArray.map { Self.convertPhonabetToASCII($0) }
    let nodes = trie.getNodes(
      keyArray: encryptedKeyArray,
      filterType: [],
      partiallyMatch: false,
      longerSegment: true
    )

    return nodes.flatMap { node in
      let nodeKeyArray = Self.restorePhonabetFromASCII(node.readingKey)
        .split(separator: "-").map(String.init)
      return makeFactoryUnigrams(
        entries: node.entries,
        keyArray: nodeKeyArray,
        sourceKey: node.readingKey,
        column: column,
        includeHalfWidthVariants: true
      )
    }
  }

  func factoryPartiallyMatchedUnigramsFor(
    queryKeyArray: [String],
    column: LMAssembly.LMInstantiator.CoreColumn,
    trie: VanguardTrie.TextMapTrie
  )
    -> [Homa.Gram] {
    let encryptedKeyArray = queryKeyArray.map { Self.convertPhonabetToASCII($0) }
    let queriedGrams = trie.queryGrams(
      encryptedKeyArray,
      filterType: column.trieEntryType,
      partiallyMatch: true
    )
    return makeFactoryUnigrams(
      queriedGrams: queriedGrams,
      includeHalfWidthVariants: true
    )
  }

  internal func factoryCNSFilterThreadFor(key: String) -> String? {
    if key == "_punctuation_list" { return nil }
    guard let trie = Self.factoryTrie else { return nil }
    let encryptedKeyArray = [Self.convertPhonabetToASCII(key)]
    let nodes = trie.getNodes(
      keyArray: encryptedKeyArray,
      filterType: [],
      partiallyMatch: false,
      longerSegment: false
    )
    let cnsTypeIDs = CoreColumn.theDataCNS.textMapTypeIDs
    let result = nodes.flatMap(\.entries)
      .filter { cnsTypeIDs.contains($0.typeID.rawValue) }
      .map(\.value)
    return result.isEmpty ? nil : result.joined(separator: "\t")
  }

  func hasFactoryCoreUnigramsFor(keyArray: [String]) -> Bool {
    guard let trie = Self.factoryTrie else { return false }
    let encryptedKeyArray = keyArray.map { Self.convertPhonabetToASCII($0) }
    let column = isCHS ? CoreColumn.theDataCHS : CoreColumn.theDataCHT
    if config.partialMatchEnabled {
      return trie.hasGrams(
        encryptedKeyArray,
        filterType: column.trieEntryType,
        partiallyMatch: true
      )
    }
    let typeIDs = column.textMapTypeIDs
    let nodes = trie.getNodes(
      keyArray: encryptedKeyArray,
      filterType: [],
      partiallyMatch: false,
      longerSegment: false
    )
    return nodes.flatMap(\.entries).contains(where: { typeIDs.contains($0.typeID.rawValue) })
  }

  func checkCNSConformation(for unigram: Homa.Gram, keyArray: [String]) -> Bool {
    guard unigram.current.count == keyArray.count else { return true }
    let chars = unigram.current.map(\.description)
    for (index, key) in keyArray.enumerated() {
      guard !key.hasPrefix("_") else { continue }
      guard let matchedResult = factoryCNSFilterThreadFor(key: key) else { continue }
      guard matchedResult.contains(chars[index]) else { return false }
    }
    return true
  }

  // MARK: - Phonabet ↔ ASCII Encryption

  fileprivate static func convertPhonabetToASCII(_ incoming: String) -> String {
    PhonabetCipher.convertPhonabetToASCII(incoming)
  }

  fileprivate static func restorePhonabetFromASCII(_ incoming: String) -> String {
    PhonabetCipher.restorePhonabetFromASCII(incoming)
  }

  /// Automatically generated half-width punctuation aliases should stay selectable,
  /// but must rank behind the lexicon's canonical full-width entry.
  private static let generatedHalfWidthPunctuationPenalty = 0.0001

  private func makeFactoryUnigrams(
    entries: [VanguardTrie.Trie.Entry],
    keyArray: [String],
    sourceKey: String,
    column: CoreColumn,
    includeHalfWidthVariants: Bool
  )
    -> [Homa.Gram] {
    var grams: [Homa.Gram] = []
    var extraHalfWidthGrams: [Homa.Gram] = []
    for entry in entries where column.textMapTypeIDs.contains(entry.typeID.rawValue) {
      var score = entry.probability
      if score > 0 {
        score *= -1
      }

      grams.append(.init(keyArray: keyArray, value: entry.value, score: score))

      guard includeHalfWidthVariants, sourceKey.contains("_punctuation") else { continue }
      let halfWidthValue = entry.value.applyingTransformFW2HW(reverse: false)
      if halfWidthValue != entry.value {
        extraHalfWidthGrams.append(
          .init(
            keyArray: keyArray,
            value: halfWidthValue,
            score: score - Self.generatedHalfWidthPunctuationPenalty
          )
        )
      }
    }

    grams.append(contentsOf: extraHalfWidthGrams)
    return grams
  }

  private func makeFactoryUnigrams(
    queriedGrams: [(keyArray: [String], value: String, probability: Double, previous: String?)],
    includeHalfWidthVariants: Bool
  )
    -> [Homa.Gram] {
    var grams: [Homa.Gram] = []
    var extraHalfWidthGrams: [Homa.Gram] = []
    for queriedGram in queriedGrams {
      var score = queriedGram.probability
      if score > 0 {
        score *= -1
      }

      let restoredKeyArray = queriedGram.keyArray.map { Self.restorePhonabetFromASCII($0) }
      grams.append(.init(keyArray: restoredKeyArray, value: queriedGram.value, score: score))

      let sourceKey = queriedGram.keyArray.joined(separator: "-")
      guard includeHalfWidthVariants, sourceKey.contains("_punctuation") else { continue }
      let halfWidthValue = queriedGram.value.applyingTransformFW2HW(reverse: false)
      if halfWidthValue != queriedGram.value {
        extraHalfWidthGrams.append(
          .init(
            keyArray: restoredKeyArray,
            value: halfWidthValue,
            score: score - Self.generatedHalfWidthPunctuationPenalty
          )
        )
      }
    }

    grams.append(contentsOf: extraHalfWidthGrams)
    return grams
  }

  private static func resolveTextMapPath(from incomingPath: String) -> String? {
    let manager = FileManager.default
    let incomingURL = URL(fileURLWithPath: incomingPath)

    if incomingURL.pathExtension == "txtMap", manager.isReadableFile(atPath: incomingURL.path) {
      return incomingURL.path
    }

    let sameStem = incomingURL.deletingPathExtension().appendingPathExtension("txtMap")
    if manager.isReadableFile(atPath: sameStem.path) {
      return sameStem.path
    }

    let fixedName = incomingURL.deletingLastPathComponent()
      .appendingPathComponent("VanguardFactoryDict4Typing")
      .appendingPathExtension("txtMap")
    if manager.isReadableFile(atPath: fixedName.path) {
      return fixedName.path
    }

    return nil
  }
}
