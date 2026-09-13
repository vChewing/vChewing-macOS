// (c) 2025 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

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

  /// Braille ASCII（SimBraille）對映表：Unicode 點字字元 (U+2800–U+283F) → 可列印 ASCII 字元 (32–95)。
  private static let mapASCII4BrailleCells: [String: String] = [
    Braille.blank.rawValue: " ",
    Braille.d1.rawValue: "A",
    Braille.d2.rawValue: "1",
    Braille.d12.rawValue: "B",
    Braille.d3.rawValue: "'",
    Braille.d13.rawValue: "K",
    Braille.d23.rawValue: "2",
    Braille.d123.rawValue: "L",
    Braille.d4.rawValue: "@",
    Braille.d14.rawValue: "C",
    Braille.d24.rawValue: "I",
    Braille.d124.rawValue: "F",
    Braille.d34.rawValue: "/",
    Braille.d134.rawValue: "M",
    Braille.d234.rawValue: "S",
    Braille.d1234.rawValue: "P",
    Braille.d5.rawValue: "\"",
    Braille.d15.rawValue: "E",
    Braille.d25.rawValue: "3",
    Braille.d125.rawValue: "H",
    Braille.d35.rawValue: "9",
    Braille.d135.rawValue: "O",
    Braille.d235.rawValue: "6",
    Braille.d1235.rawValue: "R",
    Braille.d45.rawValue: "^",
    Braille.d145.rawValue: "D",
    Braille.d245.rawValue: "J",
    Braille.d1245.rawValue: "G",
    Braille.d345.rawValue: ">",
    Braille.d1345.rawValue: "N",
    Braille.d2345.rawValue: "T",
    Braille.d12345.rawValue: "Q",
    Braille.d6.rawValue: ",",
    Braille.d16.rawValue: "*",
    Braille.d26.rawValue: "5",
    Braille.d126.rawValue: "<",
    Braille.d36.rawValue: "-",
    Braille.d136.rawValue: "U",
    Braille.d236.rawValue: "8",
    Braille.d1236.rawValue: "V",
    Braille.d46.rawValue: ".",
    Braille.d146.rawValue: "%",
    Braille.d246.rawValue: "[",
    Braille.d1246.rawValue: "$",
    Braille.d346.rawValue: "+",
    Braille.d1346.rawValue: "X",
    Braille.d2346.rawValue: "!",
    Braille.d12346.rawValue: "&",
    Braille.d56.rawValue: ";",
    Braille.d156.rawValue: ":",
    Braille.d256.rawValue: "4",
    Braille.d1256.rawValue: "\\",
    Braille.d356.rawValue: "0",
    Braille.d1356.rawValue: "Z",
    Braille.d2356.rawValue: "7",
    Braille.d12356.rawValue: "(",
    Braille.d456.rawValue: "_",
    Braille.d1456.rawValue: "?",
    Braille.d2456.rawValue: "W",
    Braille.d12456.rawValue: "]",
    Braille.d3456.rawValue: "#",
    Braille.d13456.rawValue: "Y",
    Braille.d23456.rawValue: ")",
    Braille.d123456.rawValue: "=",
  ]

  /// 將組字結果以 Braille ASCII（SimBraille）編碼遞交：逐點字字元對映為可列印 ASCII 字元。
  public func convertToASCIIBraille(
    smashedPairs: [(key: String, value: String)],
    extraInsertion: (reading: String, cursor: Int)? = nil
  )
    -> String {
    convertToBraille(smashedPairs: smashedPairs, extraInsertion: extraInsertion).map {
      Self.mapASCII4BrailleCells[$0.description] ?? $0.description
    }.joined()
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
