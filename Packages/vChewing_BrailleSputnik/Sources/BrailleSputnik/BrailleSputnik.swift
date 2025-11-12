// (c) 2022 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Tekkon

// MARK: - BrailleSputnik

public final class BrailleSputnik {
  // MARK: Lifecycle

  public init(standard: BrailleStandard) {
    self.standard = standard
  }

  // MARK: Public

  public var standard: BrailleStandard

  // MARK: Internal

  static var sharedComposer = Tekkon.Composer("", arrange: .ofDachen, correction: true)

  var staticData: BrailleProcessingUnit {
    switch standard {
    case .of1947: return Self.staticData1947
    case .of2018: return Self.staticData2018
    }
  }

  // MARK: Private

  private static let staticData1947: BrailleProcessingUnit = BrailleProcessingUnit1947()
  private static let staticData2018: BrailleProcessingUnit = BrailleProcessingUnit2018()
}

extension BrailleSputnik {
  public func convertToBraille(
    smashedPairs: [(key: String, value: String)],
    extraInsertion: (reading: String, cursor: Int)? = nil
  )
    -> String {
    var convertedStack: [String?] = []
    var processedKeysCount = 0
    var extraInsertion = extraInsertion
    smashedPairs.forEach { key, value in
      let subKeys = key.split(separator: "\t")
      switch subKeys.count {
      case 0: return
      case 1:
        guard !key.isEmpty else { break }
        let isPunctuation: Bool = key.first == "_" // 檢查是不是標點符號。
        if isPunctuation {
          convertedStack.append(convertPunctuationToBraille(value))
        } else {
          var key = key.description
          fixToneOne(target: &key)
          convertedStack.append(convertPhonabetReadingToBraille(key, value: value))
        }
        processedKeysCount += 1
      default:
        // 這種情形就是詞音配對不一致的典型情形，此時僅處理注音讀音。
        subKeys.forEach { subKey in
          var subKey = subKey.description
          fixToneOne(target: &subKey)
          convertedStack.append(convertPhonabetReadingToBraille(subKey))
          processedKeysCount += 1
        }
      }
      if let theExtraInsertion = extraInsertion, processedKeysCount == theExtraInsertion.cursor {
        convertedStack.append(convertPhonabetReadingToBraille(theExtraInsertion.reading))
        extraInsertion = nil
      }
    }
    return convertedStack.compactMap(\.?.description).joined()
  }

  private func fixToneOne(target key: inout String) {
    for char in key {
      guard Tekkon.Phonabet(char.description).type != .null else { return }
    }
    if let lastChar = key.last?.description, Tekkon.Phonabet(lastChar).type != .intonation {
      key += " "
    }
  }

  public func convertPunctuationToBraille(_ givenTarget: any StringProtocol) -> String? {
    staticData.mapPunctuations[givenTarget.description]
  }

  public func convertPhonabetReadingToBraille(
    _ rawReading: any StringProtocol,
    value referredValue: String? = nil
  )
    -> String? {
    var resultStack = ""
    // 检查特殊情形。
    guard !staticData.handleSpecialCases(target: &resultStack, value: referredValue)
    else { return resultStack }
    Self.sharedComposer.clear()
    rawReading.forEach { char in
      Self.sharedComposer.receiveKey(fromPhonabet: char.unicodeScalars.first)
    }
    let consonant = Self.sharedComposer.consonant.value
    let semivowel = Self.sharedComposer.semivowel.value
    let vowel = Self.sharedComposer.vowel.value
    let intonation = Self.sharedComposer.intonation.value
    if !consonant.isEmpty {
      resultStack.append(staticData.mapConsonants[consonant] ?? "")
    }
    let combinedVowels = Self.sharedComposer.semivowel.value + Self.sharedComposer.vowel.value
    if combinedVowels.count == 2 {
      resultStack.append(staticData.mapCombinedVowels[combinedVowels] ?? "")
    } else {
      resultStack.append(staticData.mapSemivowels[semivowel] ?? "")
      resultStack.append(staticData.mapVowels[vowel] ?? "")
    }
    // 聲調處理。
    if let intonationSpecialCaseMetResult = staticData
      .mapIntonationSpecialCases[vowel + intonation] {
      resultStack.append(intonationSpecialCaseMetResult.last?.description ?? "")
    } else {
      resultStack.append(staticData.mapIntonations[intonation] ?? "")
    }
    return resultStack
  }
}
