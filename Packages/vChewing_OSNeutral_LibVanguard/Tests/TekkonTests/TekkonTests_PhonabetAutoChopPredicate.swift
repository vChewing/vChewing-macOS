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

  /// 素材檔內之資料列總數（**未**過濾）。與 `rows.count` 併用即得「解析損失率」。
  ///
  /// 此值與 `rows` 之存在理由：**語料讀不到時必須大聲失敗**。P261 之 CI 實錄——Windows
  /// 之語料整批讀不到（`rows == []`），而當時之靶全以列舉為主，遂只在兩處下界斷言上失手。
  static var rawRowCount: Int { parsed.raw }

  /// 診斷訊息（空字串代表載入成功）。
  static var diagnostic: String { parsed.report }

  /// 自素材檔解析 `testTable4DynamicLayouts` 之內容。僅解析一次，`rows` 與 `rawRowCount` 共用。
  static var rows: [Row] { parsed.rows }

  /// 載入診斷（供失敗訊息引用）。**非 Darwin 之靶不得再靜默失敗**：Windows 之 `#filePath`
  /// 形制與非 Darwin 之 Foundation 尚待實測，故凡失敗一律附上嘗試過的路徑與失敗原因。
  static var loadReport: String { parsed.report }

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

  /// 鍵面字元之地面真值（靜態注音排列之按鍵域）。
  ///
  /// 實查自素材檔之 1485 列 × 5 動態排列：其鍵面字元僅 `0-9` 與 `a-z`。**反引號與空格不在其列**
  /// 它在素材檔內只作「無此鍵」之標記（`` `NULL``），而本型別先前把兩者一併當成候選鍵，遂使
  /// `staticKeys(for:)` 之反推把反引號登記成某注音符號之按鍵 ⇒ 由合法讀音之前綴生成出**不可鍵入**
  /// 之鍵序，判準對該鍵之反應即隨平台而異。**此為靶之輸入域缺陷，非判準之缺陷。**
  static func isKeyCharacter(_ ch: Character) -> Bool {
    ch.isASCII && (ch.isLetter || ch.isNumber)
  }

  // MARK: Private

  private static let parsed: (rows: [Row], raw: Int, report: String) = {
    var loadedRows: [Row] = []
    var raw = 0
    // 素材檔之候選路徑。**第一個是正解**（`#filePath` 之目錄 ＋ 相對路徑），其餘為跨平台保險：
    // Windows 之 `#filePath` 形制與非 Darwin 之 Foundation 皆未在本機實測過，而此靶先前在該平台
    // 是**靜默**失敗（只以魔數下界間接失手）⇒ 寧可多試幾條並把結果全數回報。
    let anchorDir = (#filePath as NSString).deletingLastPathComponent as String
    let candidates: [String] = [
      URL(fileURLWithPath: anchorDir).appendingPathComponent("TestAssets_Tekkon/Tekkon_TestData.swift").path,
      (anchorDir as NSString).appendingPathComponent("TestAssets_Tekkon/Tekkon_TestData.swift"),
      (anchorDir as NSString).appendingPathComponent("TestAssets_Tekkon\\Tekkon_TestData.swift"),
      (anchorDir as NSString).appendingPathComponent("TestAssets_Tekkon: Tekkon_TestData.swift"),
    ]
    var attempts: [String] = []
    var text: String?
    for candidate in candidates {
      let exists = FileManager.default.fileExists(atPath: candidate)
      guard let data = try? Data(contentsOf: URL(fileURLWithPath: candidate)) else {
        attempts.append("FAIL(absent, exists=\(exists)) \(candidate)")
        continue
      }
      // 讀到了但解不成 UTF-8 時**不中斷**——可能只是挑錯了檔（例如同名的目錄），續試其餘候選。
      guard let decoded = String(data: data, encoding: String.Encoding.utf8) else {
        attempts.append("FAIL(not-utf8, bytes=\(data.count)) \(candidate)")
        continue
      }
      attempts.append("OK(bytes=\(data.count)) \(candidate)")
      text = decoded
      break
    }
    func giveUp(_ why: String) -> (rows: [Row], raw: Int, report: String) {
      ([Row](), 0, "#filePath=\(#filePath)\n" + why + "\n" + attempts.joined(separator: "\n"))
    }
    guard let text else { return giveUp("素材檔全數候選路徑讀取失敗。") }
    // 行尾正規化：素材檔在版控內為 LF，但 Windows 之 checkout 可能改寫為 CRLF。
    let lines = text.replacingOccurrences(of: "\r\n", with: "\n")
      .replacingOccurrences(of: "\r", with: "\n")
      .components(separatedBy: "\n")
    guard let start = lines.firstIndex(where: { $0.contains("let testTable4DynamicLayouts = \"\"\"") }),
          let end = lines[start...].firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "\"\"\"" })
    else { return giveUp("已讀到 \(text.count) 字元，但找不到表格之起訖錨點（前 120 字：\(text.prefix(120))）。") }
    // `start + 1` 為表頭列（`$READING Dachen26 …`），故自 `start + 2` 起。
    for line in lines[(start + 2) ..< end] {
      raw += 1
      let parts: [String] = line.split(separator: " ").map { String($0).replacingOccurrences(of: "_", with: " ") }
      guard parts.count == 6 else { continue }
      let reading: String = parts[0]
      let cells: [String] = Array(parts[1...])
      // 校驗閘：任何單元格若含鍵面字元以外之字元即整列剔除。實查素材檔之此類單元格只有兩種：
      // ① 以反引號起始者（`` `NULL``、`` `vezf``…，標記「本排列無此鍵」）；② 尾端帶一空格者
      // （`m `、`too `…，源自素材檔之 `__` ⇒ 空 cell）。**兩者皆為「不適用」之標記，非按鍵。**
      // 不設此閘時，該等字元會被當成按鍵餵給判準——而判準對「非注音按鍵」之反應無定義，
      // 各平台遂各自為政（P261 之 CI 實錄：Linux 誤切 7366 次、Windows 語料整批讀不到）。
      guard cells.allSatisfy({ cell in cell.allSatisfy(Self.isKeyCharacter) }) else { continue }
      loadedRows.append(Row(reading: reading, cells: cells))
    }
    return (loadedRows, raw, "已解析：raw=\(raw)、kept=\(loadedRows.count)。")
  }()

  /// 單一按鍵之候選集（靜態注音排列之鍵面字元）。
  private static let candidateKeys: [Character] =
    Array("0123456789").filter(isKeyCharacter) + Array("abcdefghijklmnopqrstuvwxyz")
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
    #expect(
      !AutoChopCorpus.rows.isEmpty,
      "語料解析失敗——素材檔路徑或格式已變：\n\(AutoChopCorpus.diagnostic)"
    )
    var offenders: [String] = []
    var steps = 0

    for (index, layout) in AutoChopCorpus.layouts.enumerated() {
      for row in AutoChopCorpus.rows {
        let cell = row.cells[index]
        guard cell.allSatisfy(AutoChopCorpus.isKeyCharacter) else { continue }
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
      // 靶之輸入域不變式：反推所得之按鍵一律須為鍵面字元。**此行即本 phase 之迴歸釘**——
      // 先前之候選鍵含反引號與空格，反推遂把它們登記成某注音符號之按鍵，而由合法讀音之前綴
      // 生成出**不可鍵入**之鍵序（CI 實錄：Linux 誤切 7366 次，全數為該等鍵）。
      #expect(
        keyMap.values.allSatisfy { AutoChopCorpus.isKeyCharacter(Character(String($0))) },
        "\(layout.name) 之反推鍵表含非鍵面字元：\(keyMap.values.map { String($0) }.sorted())"
      )
      for reading in allPrefixes.sorted() {
        let keys: [Character] = reading.compactMap { ch in
          ch.unicodeScalars.first.flatMap { keyMap[$0] }.map { Character(String($0)) }
        }
        guard keys.count == reading.count else { continue }
        var composer = Tekkon.Composer(arrange: layout.parser)
        for (step, key) in keys.enumerated() {
          steps += 1
          if composer.shouldAutoChopPhonabets(byTyping: key) {
            let shown = key.isASCII && !key
              .isWhitespace ? "\(key)" : "U+\(String(key.unicodeScalars.first!.value, radix: 16, uppercase: true))"
            offenders.append("\(layout.name)/\(reading)/拍\(step)/鍵`\(shown)`")
          }
          composer.receiveKey(fromScalar: key.unicodeScalars.first)
        }
      }
    }

    // 下界改以**結構**表達，不再釘死魔數：語料須幾近全數解析成功、且受檢步數須成規模。
    #expect(
      AutoChopCorpus.rawRowCount > 1_000,
      "素材檔之資料列僅 \(AutoChopCorpus.rawRowCount)：\n\(AutoChopCorpus.diagnostic)"
    )
    // 實測剔除率 38/1485 ＝ 2.56%（全為上揭兩種「不適用」標記）；門檻取 95% 以為餘裕，
    // 意在攔住「整批讀不到」與「大規模解析失敗」，而非逐列計較。
    #expect(
      AutoChopCorpus.rows.count >= AutoChopCorpus.rawRowCount * 95 / 100,
      "語料解析損失過大：\(AutoChopCorpus.rows.count) / \(AutoChopCorpus.rawRowCount)"
    )
    #expect(steps > 20_000, "受檢步數僅 \(steps)：\n\(AutoChopCorpus.diagnostic)")
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
        guard cell.allSatisfy(AutoChopCorpus.isKeyCharacter) else { continue }
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

    // 同上：交界數之下界為結構量（0 即語料未載入）；「不得漏切」由 `missed` 承擔。
    #expect(checked > 0, "受檢交界僅 \(checked)：\n\(AutoChopCorpus.diagnostic)")
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
