// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

// 注音狂打自動切音節判準：**生產實作**之回歸靶。
//
// 本檔之前身是 `Tests/TekkonTests/TekkonTests_AutoChopPredicate.swift`（P251 之術前驗證靶）——
// 當時判準尚未落地，故該檔自帶一份「測試端參考實作」與四個版本之對照。判準已於 P255 移入生產碼
// （`Tekkon.Composer.shouldAutoChopPhonabets(byTyping:)`，自 P261 起實作與本靶同住 `Tekkon`），
// 故**參考實作已刪**，改由本檔直接
// 驅動生產實作，杜絕「兩份各自演化之判準」。
//
// 四項地面真相（與 P251 之結論逐項對應）：
//   ① 合法單音節編碼之**每一個中途前綴**皆不得觸發切音節；
//   ② 音節交界處**必須**切（殘餘漏切率 < 5%）；
//   ③ 單聲母縮寫（`ess`＝ㄍㄋㄋ）須得三顆鍵；
//   ④ 動態排列之逐槽覆寫（大千26 `qquu`＝ㄅㄚ）之四拍不得被切斷。
//
// 語料（1485 列 × 5 動態排列）**不另抄一份**，而是自 `Tests/TekkonTests/TestAssets_Tekkon/`
// 之素材檔按 `#filePath` 就地解析——故語料仍為單一正本。

import Foundation
import Tekkon
import Testing

// MARK: - AutoChopCorpus

enum AutoChopCorpus {
  // MARK: Internal

  struct Row: Sendable {
    var reading: String
    var cells: [String]
  }

  static let layouts: [(name: String, parser: Tekkon.MandarinParser)] = [
    ("Dachen26", .ofDachen26),
    ("ETen26", .ofETen26),
    ("Hsu", .ofHsu),
    ("Starlight", .ofStarlight),
    ("AlvinLiu", .ofAlvinLiu),
  ]

  static let staticLayouts: [(name: String, parser: Tekkon.MandarinParser)] = [
    ("Dachen", .ofDachen), ("ETen", .ofETen), ("IBM", .ofIBM),
    ("MiTAC", .ofMiTAC), ("Seigyou", .ofSeigyou), ("FakeSeigyou", .ofFakeSeigyou),
  ]

  /// 自素材檔解析 `testTable4DynamicLayouts` 之內容。
  static let rows: [Row] = {
    let assetURL = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent() // …/Tests/TekkonTests
      .appendingPathComponent("TestAssets_Tekkon/Tekkon_TestData.swift")
    guard let data = try? Data(contentsOf: assetURL),
          let text = String(data: data, encoding: String.Encoding.utf8) else { return [] }
    let lines = text.components(separatedBy: "\n")
    guard let start = lines.firstIndex(where: { $0.contains("let testTable4DynamicLayouts = \"\"\"") }),
          let end = lines[start...].firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "\"\"\"" })
    else { return [] }
    // `start + 1` 為表頭列（`$READING Dachen26 …`），故自 `start + 2` 起。
    return lines[(start + 2) ..< end].compactMap { line in
      let parts = line.split(separator: " ").map { $0.replacingOccurrences(of: "_", with: " ") }
      guard parts.count == 6 else { return nil }
      return Row(reading: String(parts[0]), cells: Array(parts[1...]).map(String.init))
    }
  }()

  /// 由靜態排列之鍵表反推「注音符號 → 按鍵」。
  ///
  /// **不**取用 Tekkon 之 internal 鍵表——改以純公開 API 逐鍵探測：把每個候選鍵餵進一枚空
  /// `Composer`，看它填入哪個槽。靜態排列是一鍵一注音，故此探測即其鍵表之逆。
  /// 同一符號多鍵時取候選序中最早者（與 P251 之「字典序最小」同義）。
  static func staticKeys(for parser: Tekkon.MandarinParser) -> [Unicode.Scalar: Unicode.Scalar] {
    var result: [Unicode.Scalar: Unicode.Scalar] = [:]
    for ch in candidateKeys {
      guard let scalar = ch.unicodeScalars.first else { continue }
      var composer = Tekkon.Composer(arrange: parser)
      composer.receiveKey(fromScalar: scalar)
      let slots = [composer.consonant, composer.semivowel, composer.vowel, composer.intonation]
      let filled = slots.filter { !$0.isEmpty }
      guard filled.count == 1, let phonabet = filled.first else { continue }
      if result[phonabet.scalarValue] == nil { result[phonabet.scalarValue] = scalar }
    }
    return result
  }

  // MARK: Private

  /// 單一按鍵之候選集（靜態注音排列之鍵面字元）。
  private static let candidateKeys: [Character] =
    Array("0123456789abcdefghijklmnopqrstuvwxyz;,./-=[]\\'` ")
}

// MARK: - PhonabetAutoChopPredicateTests

@Suite("自動切音節判準（生產實作之回歸靶）", .serialized)
struct PhonabetAutoChopPredicateTests {
  // MARK: Internal

  /// ① 合法單音節編碼之每一個中途前綴皆不得觸發切音節。
  ///
  /// 覆蓋 **11 個排列**：5 個動態排列用素材之 1485 列編碼；6 個靜態排列用其鍵表反推全部前綴。
  @Test("判準不得在單一音節內誤切")
  func phonabetAutoChopNeverFiresWithinASyllable() {
    #expect(!AutoChopCorpus.rows.isEmpty, "語料解析失敗——素材檔路徑或格式已變")
    var offenders: [String] = []
    var steps = 0

    for (index, layout) in AutoChopCorpus.layouts.enumerated() {
      for row in AutoChopCorpus.rows {
        let cell = row.cells[index]
        guard !cell.hasPrefix("`") else { continue }
        var composer = Tekkon.Composer(arrange: layout.parser)
        for (step, key) in cell.enumerated() {
          steps += 1
          if composer.shouldAutoChopPhonabets(byTyping: key) {
            offenders.append("\(layout.name)/\(row.reading)/拍\(step)/鍵`\(key)`")
          }
          composer.receiveKey(fromScalar: key.unicodeScalars.first)
        }
      }
    }

    // 前綴集由 `allReadings` 就地推導——索引本身刻意不暴露 `allPrefixes`（P252 之裁定：
    // 只答「是否為前綴」一問），故本靶自行展開、再逐條以 `isPrefix` 交叉驗證。
    let allReadings = Tekkon.SyllableIndex.shared(parser: .ofDachen).readings
    var allPrefixes: Set<String> = []
    for reading in allReadings {
      for length in 1 ... reading.count { allPrefixes.insert(String(reading.prefix(length))) }
    }
    for layout in AutoChopCorpus.staticLayouts {
      let keyMap = AutoChopCorpus.staticKeys(for: layout.parser)
      for reading in allPrefixes.sorted() {
        let keys: [Character] = reading.compactMap { ch in
          ch.unicodeScalars.first.flatMap { keyMap[$0] }.map { Character(String($0)) }
        }
        guard keys.count == reading.count else { continue }
        var composer = Tekkon.Composer(arrange: layout.parser)
        for (step, key) in keys.enumerated() {
          steps += 1
          if composer.shouldAutoChopPhonabets(byTyping: key) {
            offenders.append("\(layout.name)/\(reading)/拍\(step)/鍵`\(key)`")
          }
          composer.receiveKey(fromScalar: key.unicodeScalars.first)
        }
      }
    }

    #expect(steps > 29_000, "受檢步數僅 \(steps)")
    #expect(offenders.isEmpty, "誤切 \(offenders.count) 次：\(offenders.prefix(10))")
  }

  /// ② 音節交界處必須切。地面真相：A ＝ 一完整合法讀音；本鍵若**不能**把 A 延伸成更長之
  /// 合法前綴，則 A 須先固化 ⇒ 必切。
  @Test("判準須在音節交界處切分")
  func phonabetAutoChopFiresAtJunctions() {
    let index = Tekkon.SyllableIndex.shared(parser: .ofDachen)
    var checked = 0
    var missed = 0
    var sample: [String] = []

    for (colIndex, layout) in AutoChopCorpus.layouts.enumerated() {
      var keys: Set<Character> = []
      var states: [Tekkon.Composer] = []
      for row in AutoChopCorpus.rows {
        let cell = row.cells[colIndex]
        guard !cell.hasPrefix("`") else { continue }
        cell.forEach { keys.insert($0) }
        var composer = Tekkon.Composer(arrange: layout.parser)
        for key in cell { composer.receiveKey(fromScalar: key.unicodeScalars.first) }
        states.append(composer)
      }
      for composer in states {
        let preContent = composer.getComposition()
        for key in keys.sorted() {
          var probe = composer
          probe.receiveKey(fromScalar: key.unicodeScalars.first)
          let postContent = probe.getComposition()
          // 於**當前狀態**下寫入聲調槽者（聲調鍵／空格）由既有管線固化，不屬本案（照 P251 之守衛）。
          guard probe.intonation.value == composer.intonation.value else { continue }
          let greedy = index.isPrefix(postContent) && postContent.count > preContent.count
          guard !greedy else { continue }
          checked += 1
          if !composer.shouldAutoChopPhonabets(byTyping: key) {
            missed += 1
            if sample.count < 5 { sample.append("\(layout.name)/\(preContent)+`\(key)`") }
          }
        }
      }
    }

    #expect(checked > 100_000, "受檢交界僅 \(checked)")
    // P251 之實測為 2.19%；此處以 5% 為上限——殘餘之成因（與 `qquu` 之逐槽覆寫在局部
    // 可觀測量上同構）已證不可由局部判準分離，屬**已知界線**。
    let rate = Double(missed) * 100 / Double(max(checked, 1))
    #expect(rate < 5, "漏切率 \(rate)%（\(missed)/\(checked)）；樣本：\(sample)")
  }

  /// ③ 單聲母縮寫：`ess`（大千：ㄍ＝`e`、ㄋ＝`s`）須得三顆鍵。
  @Test("單聲母縮寫須成三個單符號音節")
  func singlePhonabetAbbreviationIsCommittedAsThreeKeys() {
    #expect(type("ess", parser: .ofDachen) == ["ㄍ", "ㄋ", "ㄋ"])
    #expect(type("ss", parser: .ofDachen) == ["ㄋ", "ㄋ"])
    // 反向護欄：完整讀音不得被切碎。
    #expect(type("1u0", parser: .ofDachen) == ["ㄅㄧㄢ"])
  }

  /// ④ 動態排列之逐槽覆寫：大千26 `qquu`＝ㄅㄚ 之四拍不得被切斷。
  @Test("大千26 之逐槽覆寫不得被切斷")
  func dachen26SlotOverwriteSurvivesThePredicate() {
    var composer = Tekkon.Composer(arrange: .ofDachen26)
    var verdicts: [Bool] = []
    for key in "qquu" {
      verdicts.append(composer.shouldAutoChopPhonabets(byTyping: key))
      composer.receiveKey(fromScalar: key.unicodeScalars.first)
    }
    #expect(verdicts == [false, false, false, false], "實得：\(verdicts)")
    #expect(composer.getComposition() == "ㄅㄚ")
  }

  // MARK: Private

  /// 以生產判準實際驅動一次輸入，回傳送入組字器之音節序列。
  private func type(_ keys: String, parser: Tekkon.MandarinParser) -> [String] {
    var composer = Tekkon.Composer(arrange: parser)
    var committed: [String] = []
    for key in keys {
      let chopped = composer.shouldAutoChopPhonabets(byTyping: key)
      if chopped, let reading = composer.phonabetKeyForQuery(pronounceableOnly: true) {
        committed.append(reading)
        composer.clear()
      }
      composer.receiveKey(fromScalar: key.unicodeScalars.first)
    }
    if let last = composer.phonabetKeyForQuery(pronounceableOnly: true) { committed.append(last) }
    return committed
  }
}
