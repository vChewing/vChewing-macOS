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

// MARK: - VanguardTrie.Trie.EntryType

extension VanguardTrie.Trie.EntryType {
  fileprivate var defaultScore: Double {
    switch self {
    case .zhuyinwen: return -1
    case .cns: return -11
    case .symbolPhrases: return -13
    case .letterPunctuations: return -10
    default: return -9.9
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

  public static func connectFactoryDictionary(
    textMapPath: String,
    dropPreviousConnection: Bool = true,
    completionHandler: (@Sendable (Bool) -> ())? = nil
  ) {
    if dropPreviousConnection {
      disconnectFactoryDictionary()
    }

    guard let resolvedTextMapPath = resolveTextMapPath(from: textMapPath) else {
      vCLMLog("Factory TextMap path not found: \(textMapPath)")
      completionHandler?(false)
      return
    }

    if !Self.asyncLoadingUserData {
      do {
        let textMapData = try Data(contentsOf: URL(fileURLWithPath: resolvedTextMapPath), options: [.mappedIfSafe])
        factoryTrie = try VanguardTrie.TextMapTrie(data: textMapData)
        vCLMLog("Factory TextMap loading complete: \(resolvedTextMapPath)")
        completionHandler?(true)
        return
      } catch {
        vCLMLog("Factory TextMap loading failed: \(error.localizedDescription)")
        factoryTrie = nil
        completionHandler?(false)
        return
      }
    } else {
      LMAssembly.fileHandleQueue.async {
        do {
          let textMapData = try Data(contentsOf: URL(fileURLWithPath: resolvedTextMapPath), options: [.mappedIfSafe])
          let newTrie = try VanguardTrie.TextMapTrie(data: textMapData)
          factoryTrie = newTrie
          vCLMLog("Factory TextMap async loading complete: \(resolvedTextMapPath)")
          completionHandler?(true)
        } catch {
          vCLMLog("Factory TextMap async loading failed: \(error.localizedDescription)")
          factoryTrie = nil
          completionHandler?(false)
        }
      }
      return
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
    return readings
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
      entryType: .letterPunctuations,
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
        entryType: isCHS ? .chs : .cht
      )
    case .strictSuperset:
      return factoryStrictSupersetUnigramsFor(
        subsetKey: key,
        subsetKeyArray: keyArray,
        entryType: isCHS ? .chs : .cht
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
    entryType: VanguardTrie.Trie.EntryType
  )
    -> [Homa.Gram] {
    if key == "_punctuation_list" { return [] }
    guard let trie = Self.factoryTrie else { return [] }
    if config.partialMatchEnabled {
      return factoryPartiallyMatchedUnigramsFor(
        queryKeyArray: keyArray,
        entryType: entryType,
        trie: trie
      )
    }
    let nodes = trie.getNodes(
      keyArray: keyArray,
      filterType: [],
      partiallyMatch: false,
      longerSegment: false
    )
    let entries = nodes.flatMap(\.entries)
    return makeFactoryUnigrams(
      entries: entries,
      keyArray: keyArray,
      sourceKey: key,
      entryType: entryType,
      includeHalfWidthVariants: true
    )
  }

  func factoryStrictSupersetUnigramsFor(
    subsetKey: String,
    subsetKeyArray: [String],
    entryType: VanguardTrie.Trie.EntryType
  )
    -> [Homa.Gram] {
    if subsetKey == "_punctuation_list" { return [] }
    guard let trie = Self.factoryTrie else { return [] }
    let nodes = trie.getNodes(
      keyArray: subsetKeyArray,
      filterType: [],
      partiallyMatch: false,
      longerSegment: true
    )

    return nodes.flatMap { node in
      let nodeKeyArray = node.readingKey.split(separator: "-").map(String.init)
      return makeFactoryUnigrams(
        entries: node.entries,
        keyArray: nodeKeyArray,
        sourceKey: node.readingKey,
        entryType: entryType,
        includeHalfWidthVariants: true
      )
    }
  }

  func factoryPartiallyMatchedUnigramsFor(
    queryKeyArray: [String],
    entryType: VanguardTrie.Trie.EntryType,
    trie: VanguardTrie.TextMapTrie
  )
    -> [Homa.Gram] {
    let queriedGrams = trie.queryGrams(
      queryKeyArray,
      filterType: entryType,
      partiallyMatch: true
    )
    return makeFactoryUnigrams(
      queriedGrams: queriedGrams,
      entryType: entryType,
      includeHalfWidthVariants: true
    )
  }

  func factoryChoppedUnigramsFor(
    keyArray: [String],
    entryType: VanguardTrie.Trie.EntryType
  )
    -> [Homa.Gram] {
    guard let trie = Self.factoryTrie else { return [] }
    let entryGroups = trie.getEntryGroups(
      keysChopped: keyArray,
      filterType: entryType,
      partiallyMatch: config.partialMatchEnabled
    )
    guard !entryGroups.isEmpty else { return [] }
    return entryGroups.flatMap { group in
      makeFactoryUnigrams(
        entries: group.entries,
        keyArray: group.keyArray,
        sourceKey: group.keyArray.joined(separator: "-"),
        entryType: entryType,
        includeHalfWidthVariants: true
      )
    }
  }

  func factoryChoppedCoreUnigramsFor(
    keyArray: [String],
    strategy: LMAssembly.LMInstantiator.FactoryCoreLookupStrategy
  )
    -> [Homa.Gram] {
    let entryType: VanguardTrie.Trie.EntryType = isCHS ? .chs : .cht
    switch strategy {
    case .configuredLookup:
      return factoryChoppedUnigramsFor(keyArray: keyArray, entryType: entryType)
    case .strictSuperset:
      guard let trie = Self.factoryTrie else { return [] }
      let entryGroups = trie.getEntryGroups(
        keysChopped: keyArray,
        filterType: [],
        partiallyMatch: false
      )
      return entryGroups.flatMap { group in
        guard group.keyArray.count > keyArray.count else { return [] as [Homa.Gram] }
        return makeFactoryUnigrams(
          entries: group.entries,
          keyArray: group.keyArray,
          sourceKey: group.keyArray.joined(separator: "-"),
          entryType: entryType,
          includeHalfWidthVariants: true
        )
      }
    }
  }

  internal func factoryCNSFilterThreadFor(key: String) -> String? {
    if key == "_punctuation_list" { return nil }
    guard let trie = Self.factoryTrie else { return nil }
    let nodes = trie.getNodes(
      keyArray: [key],
      filterType: [],
      partiallyMatch: false,
      longerSegment: false
    )
    let result = nodes.flatMap(\.entries)
      .filter { $0.typeID == .cns }
      .map(\.value)
    return result.isEmpty ? nil : result.joined(separator: "\t")
  }

  func hasFactoryCoreUnigramsFor(keyArray: [String]) -> Bool {
    guard let trie = Self.factoryTrie else { return false }
    let entryType: VanguardTrie.Trie.EntryType = isCHS ? .chs : .cht
    if config.partialMatchEnabled {
      return trie.hasGrams(
        keyArray,
        filterType: entryType,
        partiallyMatch: true
      )
    }
    let nodes = trie.getNodes(
      keyArray: keyArray,
      filterType: [],
      partiallyMatch: false,
      longerSegment: false
    )
    return nodes.flatMap(\ .entries).contains(where: { $0.typeID == entryType })
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

  /// Automatically generated half-width punctuation aliases should stay selectable,
  /// but must rank behind the lexicon's canonical full-width entry.
  private static let generatedHalfWidthPunctuationPenalty = 0.0001

  /// TextMap build output normalizes raw kana weights, so suppression must key off
  /// the entry value's script rather than a hard-coded probability bucket.
  private static func isKanaSyllableValue(_ value: String) -> Bool {
    guard !value.isEmpty else { return false }
    return value.unicodeScalars.allSatisfy { scalar in
      switch scalar.value {
      case 0x3031 ... 0x3035, // 假名迭代符號 (Kana Iteration Marks: ゝゞヽヾ〵)
           0x3040 ... 0x309F, // 平假名 (Hiragana)
           0x30A0 ... 0x30FF, // 片假名 (Katakana)
           0x31F0 ... 0x31FF, // 片假名拼音擴展 (Katakana Phonetic Extensions)
           0xFF66 ... 0xFF9F, // 半形片假名 (Half-width Katakana)
           0x1AFF0 ... 0x1AFFF, // 假名擴展-B (Kana Extended-B, 含閩南語假名等)
           0x1B000 ... 0x1B16F: // 假名補充 & 擴展-A (Hentaigana / Historic)
        return true
      default:
        return false
      }
    }
  }

  private func makeFactoryUnigrams(
    entries: [VanguardTrie.Trie.Entry],
    keyArray: [String],
    sourceKey: String,
    entryType: VanguardTrie.Trie.EntryType,
    includeHalfWidthVariants: Bool
  )
    -> [Homa.Gram] {
    var grams: [Homa.Gram] = []
    var extraHalfWidthGrams: [Homa.Gram] = []
    for entry in entries where entry.typeID == entryType {
      if entryType == .nonKanji,
         config.suppressFactoryUnigramsOfKanaSyllables,
         Self.isKanaSyllableValue(entry.value) {
        continue
      }

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
    entryType: VanguardTrie.Trie.EntryType,
    includeHalfWidthVariants: Bool
  )
    -> [Homa.Gram] {
    var grams: [Homa.Gram] = []
    var extraHalfWidthGrams: [Homa.Gram] = []
    for queriedGram in queriedGrams {
      if entryType == .nonKanji,
         config.suppressFactoryUnigramsOfKanaSyllables,
         Self.isKanaSyllableValue(queriedGram.value) {
        continue
      }

      var score = queriedGram.probability
      if score > 0 {
        score *= -1
      }

      grams.append(.init(keyArray: queriedGram.keyArray, value: queriedGram.value, score: score))

      let sourceKey = queriedGram.keyArray.joined(separator: "-")
      guard includeHalfWidthVariants, sourceKey.contains("_punctuation") else { continue }
      let halfWidthValue = queriedGram.value.applyingTransformFW2HW(reverse: false)
      if halfWidthValue != queriedGram.value {
        extraHalfWidthGrams.append(
          .init(
            keyArray: queriedGram.keyArray,
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
