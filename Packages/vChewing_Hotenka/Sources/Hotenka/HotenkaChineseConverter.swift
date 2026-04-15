// (c) 2026 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation

// MARK: - DictType

public enum DictType: Int, CaseIterable {
  case zhHantTW = 0
  case zhHantHK = 1
  case zhHansSG = 2
  case zhHansJP = 3
  case zhHantKX = 4
  case zhHansCN = 5

  // MARK: Public

  public var rawKeyString: String {
    switch self {
    case .zhHantTW: return "zh2TW"
    case .zhHantHK: return "zh2HK"
    case .zhHansSG: return "zh2SG"
    case .zhHansJP: return "zh2JP"
    case .zhHantKX: return "zh2KX"
    case .zhHansCN: return "zh2CN"
    }
  }

  public static func match(rawKeyString: String) -> Self? {
    Self.allCases.first { $0.rawKeyString == rawKeyString }
  }
}

// MARK: - Hotenka

public enum Hotenka {}

// MARK: - HotenkaChineseConverter

public final class HotenkaChineseConverter {
  // MARK: Lifecycle

  public init(stringMapPath: String) throws {
    let stringMap = try Hotenka.StringMap(fileURL: URL(fileURLWithPath: stringMapPath))
    self.stringMap = stringMap
    self.maximumKeyLengths = Self.makeMaximumKeyLengths(from: stringMap)
  }

  public init(stringMap: Hotenka.StringMap) {
    self.stringMap = stringMap
    self.maximumKeyLengths = Self.makeMaximumKeyLengths(from: stringMap)
  }

  // MARK: Public

  public func convert(_ input: String, to dictType: DictType) -> String {
    let normalizedInput = input.precomposedStringWithCanonicalMapping
    let maximumKeyLength = maximumKeyLengths[dictType.rawValue]
    guard maximumKeyLength > 0 else { return normalizedInput }

    var result = String()
    result.reserveCapacity(normalizedInput.utf8.count)
    var currentIndex = normalizedInput.startIndex

    while currentIndex < normalizedInput.endIndex {
      let remainingCount = normalizedInput.distance(
        from: currentIndex,
        to: normalizedInput.endIndex
      )
      var candidateLength = min(maximumKeyLength, remainingCount)
      var matchedValue: String?
      var matchedEndIndex = currentIndex

      while candidateLength > 0 {
        let candidateEndIndex = normalizedInput.index(currentIndex, offsetBy: candidateLength)
        let candidateKey = String(normalizedInput[currentIndex ..< candidateEndIndex])

        if let value = stringMap.query(dict: dictType, key: candidateKey) {
          matchedValue = value
          matchedEndIndex = candidateEndIndex
          break
        }

        candidateLength -= 1
      }

      if let matchedValue {
        result.append(matchedValue)
        currentIndex = matchedEndIndex
      } else {
        result.append(normalizedInput[currentIndex])
        currentIndex = normalizedInput.index(after: currentIndex)
      }
    }

    return result
  }

  public func query(dict dictType: DictType, key: String) -> String? {
    stringMap.query(dict: dictType, key: key.precomposedStringWithCanonicalMapping)
  }

  // MARK: Internal

  struct DebugProfile {
    let stringMapStorageBytes: Int
    let retainedIndexBytes: Int
    let maximumKeyLengthTableBytes: Int
  }

  func debugProfile() -> DebugProfile {
    let maximumKeyLengthTableBytes = maximumKeyLengths.count * MemoryLayout<Int>.stride
    return DebugProfile(
      stringMapStorageBytes: stringMap.storageByteCount,
      retainedIndexBytes: maximumKeyLengthTableBytes,
      maximumKeyLengthTableBytes: maximumKeyLengthTableBytes
    )
  }

  // MARK: Private

  private let stringMap: Hotenka.StringMap
  private let maximumKeyLengths: [Int]

  private static func makeMaximumKeyLengths(from stringMap: Hotenka.StringMap) -> [Int] {
    DictType.allCases.map { dictType in
      stringMap.maximumKeyLength(for: dictType)
    }
  }
}
