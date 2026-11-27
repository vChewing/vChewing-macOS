// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation
import Homa
import LXAssemblyMaterials4Tests
import Shared
import Testing

import HomaSharedTestComponents
@testable import LexiconAssembly
@testable import LibVanguard
@testable import Tekkon

// copilot 候選窗對 CNS 補充供給之上限（P368）：狂打之未完成讀音以「合法前綴之全體補全」為
// 桶，CNS 開啟時每個鍵再各取全字庫之全部字 ⇒ 單一按鍵即數千格候選。上限須落於供給端，
// 且只施用於本窗——標準選字窗與組字器之查詢不受限。

// MARK: - IH.CNSCopilotSupply

extension LibVanguardTestsRoot.InputHandlerTests {
  @Test("IH-CNSCopilotSupply-001 Copilot window caps the CNS supply at 200")
  func test_IH_CNSCopilotSupply_001_CopilotWindowCapsCNSSupply() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    clearTestPOM()

    // 三個 ㄎ 族讀音、每個各供 100 個 CNS 字 ⇒ 桶查詢若不受限即得 300 個 CNS 候選。
    let cnsChars: [String] = (0 ..< 300).compactMap { Unicode.Scalar(0x3400 + $0).map(String.init) }
    let readings = ["ㄎㄚ", "ㄎㄜ", "ㄎㄞ"]
    let perReading = cnsChars.count / readings.count
    let cnsTypeID: Int32 = 7
    let chtTypeID: Int32 = 6
    let entriesByKey: [(String, [(value: String, probability: Double, typeID: Int32)])] =
      readings.enumerated().map { index, reading in
        let slice = cnsChars[(index * perReading) ..< ((index + 1) * perReading)]
        var entries: [(value: String, probability: Double, typeID: Int32)] =
          [(value: Self.copilotSupplyCoreChar, probability: -5, typeID: chtTypeID)]
        entries += slice.map { (value: $0, probability: -11, typeID: cnsTypeID) }
        return (reading, entries)
      }
    let textMap = Self.makeCNSSupplyTextMap(entriesByKey)

    defer {
      testLX?.disconnectFactoryDictionary()
      #expect(testLX?.connectToTestFactoryDictionary(textMapData: LXATestsData.textMapTestCoreLXData) == true)
      testHandler.prefs.cns11643Enabled = false
      testHandler.prefs.furiousTypingEnabled4Zhuyin = false
      testHandler.prefs.useSCPCTypingMode = false
      testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
      testHandler.prefs.keyboardParser = KeyboardParser.ofStandard.rawValue
      testHandler.ensureKeyboardParser()
      testHandler.currentLM.syncPrefs()
      testHandler.clear()
    }

    testLX?.disconnectFactoryDictionary()
    #expect(testLX?.connectToTestFactoryDictionary(textMapData: textMap) == true)
    testHandler.clear()
    testHandler.prefs.keyboardParser = KeyboardParser.ofStandard.rawValue
    testHandler.ensureKeyboardParser()
    testHandler.prefs.useSCPCTypingMode = false
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = false
    testHandler.prefs.cns11643Enabled = true
    testHandler.prefs.furiousTypingEnabled4Zhuyin = true
    testHandler.currentLM.syncPrefs()

    // 大千排列：`d`＝ㄎ，即單一聲母、注拼槽內為合法前綴。
    typeSentence("d")

    let candidateValues = testSession.state.candidates.map(\.value)
    let cnsSupplied = candidateValues.filter { cnsChars.contains($0) }
    // 核心候選照舊供給（上限只砍補充資料）。
    #expect(candidateValues.contains(Self.copilotSupplyCoreChar))
    // 補充供給仍存在（並非整批關掉 CNS）。
    #expect(!cnsSupplied.isEmpty)
    // 上限即本窗之政策值：300 個 CNS 字被截到 200。
    #expect(cnsSupplied.count == 200)
  }

  /// 標準選字窗（固化之後）不受該上限影響：同一批讀音之 CNS 字仍全額供給。
  @Test("IH-CNSCopilotSupply-002 Standard window keeps the full CNS supply")
  func test_IH_CNSCopilotSupply_002_StandardWindowKeepsFullCNSSupply() throws {
    guard let testHandler else {
      Issue.record("testHandler is nil.")
      return
    }
    clearTestPOM()

    let cnsChars: [String] = (0 ..< 300).compactMap { Unicode.Scalar(0x3400 + $0).map(String.init) }
    let readings = ["ㄎㄚ", "ㄎㄜ", "ㄎㄞ"]
    let perReading = cnsChars.count / readings.count
    let cnsTypeID: Int32 = 7
    let chtTypeID: Int32 = 6
    let entriesByKey: [(String, [(value: String, probability: Double, typeID: Int32)])] =
      readings.enumerated().map { index, reading in
        let slice = cnsChars[(index * perReading) ..< ((index + 1) * perReading)]
        var entries: [(value: String, probability: Double, typeID: Int32)] =
          [(value: Self.copilotSupplyCoreChar, probability: -5, typeID: chtTypeID)]
        entries += slice.map { (value: $0, probability: -11, typeID: cnsTypeID) }
        return (reading, entries)
      }
    let textMap = Self.makeCNSSupplyTextMap(entriesByKey)

    defer {
      testLX?.disconnectFactoryDictionary()
      #expect(testLX?.connectToTestFactoryDictionary(textMapData: LXATestsData.textMapTestCoreLXData) == true)
      testHandler.prefs.cns11643Enabled = false
      testHandler.prefs.useSCPCTypingMode = false
      testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
      testHandler.prefs.keyboardParser = KeyboardParser.ofStandard.rawValue
      testHandler.ensureKeyboardParser()
      testHandler.currentLM.syncPrefs()
      testHandler.clear()
    }

    testLX?.disconnectFactoryDictionary()
    #expect(testLX?.connectToTestFactoryDictionary(textMapData: textMap) == true)
    testHandler.clear()
    testHandler.prefs.keyboardParser = KeyboardParser.ofStandard.rawValue
    testHandler.ensureKeyboardParser()
    testHandler.prefs.useSCPCTypingMode = false
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = false
    testHandler.prefs.cns11643Enabled = true
    testHandler.currentLM.syncPrefs()

    // 非狂打：直接以讀音查詢，走標準路徑（不受 copilot 窗之上限影響）。
    let grams = testHandler.currentLM.unigramsFor(keyArray: ["ㄎㄚ"])
    let cnsSupplied = grams.map(\.current).filter { cnsChars.contains($0) }
    #expect(cnsSupplied.count == perReading)
  }

  // MARK: Private

  private static let copilotSupplyCoreChar = "可"

  /// 以「值、機率、型別」個體列砌出 TextMap（與共用夾具之格式相同）。
  private static func makeCNSSupplyTextMap(
    _ entriesByKey: [(String, [(value: String, probability: Double, typeID: Int32)])]
  )
    -> String {
    var valueLines: [String] = []
    var keyLines: [String] = []
    for (key, entries) in entriesByKey {
      let startLine = valueLines.count
      entries.forEach { entry in
        let probabilityText = entry.probability.description.hasSuffix(".0")
          ? String(entry.probability.description.dropLast(2))
          : entry.probability.description
        valueLines.append("\(entry.value)\t\(probabilityText)\t\(entry.typeID)")
      }
      keyLines.append("\(key)\t\(startLine)\t\(entries.count)")
    }
    var result = ""
    result += "#PRAGMA:VANGUARD_HOMA_LEXICON_HEADER\n"
    result += "VERSION\t2.0\n"
    result += "TYPE\tTYPING\n"
    result += "READING_SEPARATOR\t-\n"
    result += "ENTRY_COUNT\t\(valueLines.count)\n"
    result += "KEY_COUNT\t\(keyLines.count)\n"
    result += "#PRAGMA:VANGUARD_HOMA_LEXICON_VALUES\n"
    valueLines.forEach { result += $0 + "\n" }
    result += "#PRAGMA:VANGUARD_HOMA_LEXICON_KEY_LINE_MAP\n"
    keyLines.forEach { result += $0 + "\n" }
    return result
  }
}
