// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Shared

extension LMAssembly.LMInstantiator {
  public func prepareCandidateNarrationPair(
    _ state: some IMEStateProtocol
  )
    -> (display: String, readingToNarrate: String)? {
    ensureAssociatesLoaded()
    guard let candidate = state.currentCandidate else { return nil }
    let keyChain = candidate.keyArray.joined(separator: "-")
    let hashKey = "\(keyChain)\t\(candidate.value)".hashValue
    let justReturnValue = candidate.keyArray.isEmpty
      // InputToken 結果一律唸讀 candidate value (display string)。
      || inputTokenHashesArray.contains(hashKey)
      // 不是標準情形，value 大概率是表情符號。
      || candidate.value.count != candidate.keyArray.count
      || state.type == .ofSymbolTable
    guard !justReturnValue else {
      return (candidate.value, candidate.value)
    }
    // 此時 candidate.value.count 就是 segLength。
    let segLength = candidate.keyArray.count
    switch segLength {
    case 1:
      let associatedSuffix = associatedPhrasesFor(
        pair: .init(keyArray: candidate.keyArray, value: candidate.value)
      ).first
      let readingOfChar = candidate.keyArray.joined()
      guard let associatedSuffix else {
        if state.type == .ofAssociates {
          return (candidate.value, candidate.value)
        } else {
          return (candidate.value, readingOfChar)
        }
      }
      if state.type == .ofAssociates {
        return (
          candidate.value,
          "\(candidate.value)\(associatedSuffix) 的 \(candidate.value)"
        )
      } else {
        return (
          candidate.value,
          "\(readingOfChar)\(associatedSuffix) 的 \(readingOfChar)"
        )
      }
    case 2...:
      let candidates = state.candidates.filter {
        guard $0.value.count == $0.keyArray.count else { return false }
        guard $0.keyArray.count == segLength else { return false }
        let keyChain = $0.keyArray.joined(separator: "-")
        let hashKey = "\(keyChain)\t\($0.value)".hashValue
        let isTokenCandidate = inputTokenHashesArray.contains(hashKey)
        return !isTokenCandidate && $0.value.count == $0.keyArray.count
      }
      if candidates.count == 1 {
        if state.type == .ofAssociates {
          return (candidate.value, candidate.value)
        } else {
          return (candidate.value, candidate.keyArray.joined())
        }
      }
      var readingResult = ContiguousArray<String>()
      readingResult.append(candidate.keyArray.joined())
      for (idx, char) in candidate.value.enumerated() {
        let readingOfChar = candidate.keyArray[idx]
        let charStr = char.description
        let associatedSuffixes = associatedPhrasesFor(
          pair: .init(keyArray: [readingOfChar], value: charStr)
        ).filter {
          "\(char)\($0)" != candidate.value
        }
        guard let firstMatched = associatedSuffixes.first else {
          readingResult.append("\(readingOfChar)")
          continue
        }
        if state.type == .ofAssociates {
          readingResult.append(
            "\(char)\(firstMatched) 的 \(char)"
          )
        } else {
          readingResult.append(
            "\(readingOfChar)\(firstMatched) 的 \(readingOfChar)"
          )
        }
        // The end of the current cycle.
      }
      return (candidate.value, readingResult.joined(separator: " "))
    // 檢查當前的幅長的 candidate
    default: return nil
    }
  }

  public func prepareCandidateNarrationSingle(
    _ state: some IMEStateProtocol
  )
    -> String? {
    ensureAssociatesLoaded()
    guard let candidate = state.currentCandidate else { return nil }
    let keyChain = candidate.keyArray.joined(separator: "-")
    let hashKey = "\(keyChain)\t\(candidate.value)".hashValue
    let justReturnValue = candidate.keyArray.isEmpty
      // InputToken 結果一律唸讀 candidate value (display string)。
      || inputTokenHashesArray.contains(hashKey)
      // 不是標準情形，value 大概率是表情符號。
      || candidate.value.count != candidate.keyArray.count
      || state.type == .ofSymbolTable
    guard !justReturnValue else {
      return candidate.value
    }
    // 此時 candidate.value.count 就是 segLength。
    let segLength = candidate.keyArray.count
    switch segLength {
    case 1:
      let associatedSuffix = associatedPhrasesFor(
        pair: .init(keyArray: candidate.keyArray, value: candidate.value)
      ).first
      guard let associatedSuffix else {
        return candidate.value
      }
      return "\(candidate.value)\(associatedSuffix) 的 \(candidate.value)"
    case 2...:
      let candidates = state.candidates.filter {
        guard $0.value.count == $0.keyArray.count else { return false }
        guard $0.keyArray.count == segLength else { return false }
        let keyChain = $0.keyArray.joined(separator: "-")
        let hashKey = "\(keyChain)\t\($0.value)".hashValue
        let isTokenCandidate = inputTokenHashesArray.contains(hashKey)
        return !isTokenCandidate && $0.value.count == $0.keyArray.count
      }
      if candidates.count == 1 {
        return candidate.value
      }
      var voiceOverResult = ContiguousArray<String>()
      voiceOverResult.append(candidate.value)
      for (idx, char) in candidate.value.enumerated() {
        let readingOfChar = candidate.keyArray[idx]
        let charStr = char.description
        let associatedSuffixes = associatedPhrasesFor(
          pair: .init(keyArray: [readingOfChar], value: charStr)
        ).filter {
          "\(char)\($0)" != candidate.value
        }
        guard let firstMatched = associatedSuffixes.first else {
          voiceOverResult.append("\(char)")
          continue
        }
        voiceOverResult.append(
          "\(char)\(firstMatched) 的 \(char)"
        )
        // The end of the current cycle.
      }
      return voiceOverResult.joined(separator: " ")
    // 檢查當前的幅長的 candidate
    default: return nil
    }
  }
}
