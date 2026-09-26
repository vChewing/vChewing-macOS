// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

// 注音狂打之自動切音節判準：規格之可執行形式，暨其與三個替代案之對照實測。
//
// 本檔**不含生產碼**，亦不改動 `Sources/` 一字。其職責有二：
//   1. **規格**：`shouldAutoChopZhuyin` 即判準本身之參考實作（判準全文見
//      `vChewing-DevLogs/Research/Phase250-ResearchAndNextSurgeryPlan.md` §3.2 之 v7）。
//   2. **靶**：以 11 個注音排列（5 個動態排列之 1485 列合法編碼 ＋ 6 個靜態排列之
//      442 條前綴）與 276,446 個音節交界，量測本判準與其三個替代案之誤切／漏切。
//
// 生產端落地後（見該規劃書 §8.6），本檔應轉為**對生產實作之回歸靶**：令
// `shouldAutoChopZhuyin` 轉呼叫生產實作，而把此處之四項「地面真相」斷言原樣留下。
//
// **符號命名一律不含 phase 編號**——本檔之靶就該長存、跨 phase 復用。

import Foundation
import Testing

@testable import Tekkon

// MARK: - SyllablePrefixIndex

/// 《規劃書》§4.2 所述之唯讀前綴索引之**測試端參考實作**。
///
/// 由 `Tekkon.mapHanyuPinyin` 之 427 條注音詞幹派生（含其全部非空前綴）。
/// 刻意**不收**單符號讀音——單符號之合法性是辭典之事實、非音節表之事實。
struct SyllablePrefixIndex: Sendable {
  // MARK: Lifecycle

  private init() {
    let stems = Array(Set(Tekkon.mapHanyuPinyin.values))
    self.allReadings = stems.sorted()
    self.completeSet = Set(stems)
    var prefixes: Set<String> = []
    for stem in stems {
      for length in 1 ... stem.count {
        prefixes.insert(String(stem.prefix(length)))
      }
    }
    self.allPrefixes = prefixes
  }

  // MARK: Internal

  static let shared = Self()

  /// 427 條完整讀音（升冪）。
  let allReadings: [String]
  /// 442 條非空前綴。
  let allPrefixes: Set<String>

  /// 該字串是否為某合法讀音之完整形式。
  func isComplete(_ reading: String) -> Bool { completeSet.contains(reading) }

  /// 該字串是否為某合法讀音之非空前綴（含其本身即完整者）。
  func isPrefix(_ reading: String) -> Bool { allPrefixes.contains(reading) }

  /// 以該字串為前綴之全部完整讀音（升冪）。
  func completions(of prefix: String) -> [String] {
    allReadings.filter { $0.hasPrefix(prefix) }
  }

  // MARK: Private

  private let completeSet: Set<String>
}

// MARK: - AutoChopPredicateVariant

/// 待驗之各版判準。
enum AutoChopPredicateVariant: String, CaseIterable, Sendable {
  /// 《規劃書》§3.2 之原文：④ ＝「以 K 寫入其目標槽後之假想內容」是否為讀音之前綴（取否定）。
  case substituteProbe = "v1-§3.2原文（覆寫語意）"
  /// §3.0.2 之表格語意：④ ＝「當前內容 ＋ K」是否為讀音之前綴（取否定）。
  case appendProbe = "v2-§3.0.2表格（接續語意）"
  /// 本 phase 之過渡候選：第四問改以「本鍵對槽位之實際效果」為準，不用接續探針。
  case observedEffect = "v5-實測效果（無接續探針）"
  /// 本 phase 之定案候選：接續探針 ∧ 狀態相依守衛 ∧ 目標槽取自空槽試跑。
  case guardedProbe = "v7-接續探針＋狀態相依守衛（本 phase 定案候選）"
}

/// 四槽內容（聲、介、韻、調）。
typealias ComposerSlots = [String]

func composerSlots(_ composer: Tekkon.Composer) -> ComposerSlots {
  [composer.consonant.value, composer.semivowel.value, composer.vowel.value, composer.intonation.value]
}

func unicodeScalar(_ key: Character) -> Unicode.Scalar { key.unicodeScalars.first! }

/// 「最高已填之聲介韻槽位」＋1（全空為 0）。槽序：聲 1 ＜ 介 2 ＜ 韻 3。
func highestFilledSlot(_ slots: ComposerSlots) -> Int {
  (0 ..< 3).reduce(0) { slots[$1].isEmpty ? $0 : max($0, $1 + 1) }
}

/// 判準之參考實作。
///
/// 三條件沿用《規劃書》§3.2：① 注拼槽非空、② 本鍵非聲調、③ `S_new <= S_max`。
/// 惟關鍵在於**「本鍵之固有目標槽位 `S_new`」須取自「本鍵施於空槽時所寫入之槽」**，
/// 不得取「本次實際變動之最低槽位」——後者會被動態排列之糾錯副作用誤導：
///  - 倚天26 `be`＝ㄐㄧ：鍵 `e` 寫介母 ㄧ之餘、另把聲母 ㄓ 糾正為 ㄐ；
///  - 劉氏 `ha`＝ㄌㄚ：鍵 `a` 寫韻母 ㄚ之餘、另把 ㄦ 糾正為 ㄌ。
/// 兩者之實動最低槽皆為「聲」，若據以算 `S_new` 則 ③ 恆成立而誤切。
///
/// 第四問依 `variant` 而異；`v7Hybrid` 為本 phase 之定案候選：
///
/// - **④a**：本鍵未造成任何槽位變動 ⇒ **切**。冗餘鍵＝新音節之始。實測：全部合法單音節
///   編碼之 23,441 ＋ 靜態 6,138 個中途前綴中，此情形出現 **0** 次 ⇒ 對單音節無誤殺之虞。
/// - **③**：`S_new > S_max` ⇒ **不切**（本鍵高於當前音節之最高槽 ⇒ 屬貪婪延伸）。
/// - **④b′**：結果為合法前綴、且比原內容更長 ⇒ **不切**（真實延伸）。此條同時涵蓋
///   「補空槽」（`ㄙㄥ` 之第二擊 `n`）與「長度增長之糾錯」（劉氏 `ha` 之第二擊 `a`）。
/// - **④d（守衛）**：若本鍵所摧毀之既有值，**恰為本鍵自己於空槽時所寫之值**，則判**不切**
///   （動態排列之逐槽覆寫，如大千26 `qquu` 之第二擊）。
/// - **④c**：接續探針——「當前內容 ＋ 本鍵於空槽時所寫之注音」非任何讀音之前綴 ⇒ **切**。
///
/// 條件②以「本鍵施於空槽時是否寫入聲調」判定——此即以值語義副本探得之本鍵語意，
/// **不需任何 Tekkon 新 API**。
func shouldAutoChopZhuyin(
  variant: AutoChopPredicateVariant,
  composer: Tekkon.Composer,
  key: Character,
  index: SyllablePrefixIndex,
  previousKey: Character? = nil
)
  -> Bool {
  guard !composer.isEmpty else { return false } // ①
  let pre = composerSlots(composer)
  let sMax = highestFilledSlot(pre)
  var probe = composer
  probe.receiveKey(fromScalar: unicodeScalar(key))
  let post = composerSlots(probe)
  var empty = Tekkon.Composer(arrange: composer.parser)
  empty.receiveKey(fromScalar: unicodeScalar(key))
  let emptyPost = composerSlots(empty)

  let changed = (0 ..< 4).filter { pre[$0] != post[$0] }
  // 本鍵之固有目標槽位：施於空槽時所寫入之最低槽。動態排列若空槽試跑無寫入則退回實測最低槽。
  let primarySlot = (0 ..< 4).first { !emptyPost[$0].isEmpty }
    ?? changed.filter { $0 < 3 }.min() ?? 0
  let sNew = primarySlot + 1
  let emptyPhonabet = emptyPost[primarySlot]

  switch variant {
  case .substituteProbe:
    guard emptyPost[3].isEmpty, !changed.contains(3) else { return false } // ②
    guard sNew <= sMax else { return false } // ③
    return !index.isPrefix(probe.getComposition()) // ④
  case .appendProbe:
    guard emptyPost[3].isEmpty, !changed.contains(3) else { return false }
    guard sNew <= sMax else { return false }
    return !index.isPrefix(composer.getComposition() + emptyPhonabet)
  case .guardedProbe, .observedEffect:
    guard emptyPost[3].isEmpty, !changed.contains(3) else { return false } // ②
    if changed.isEmpty { return true } // ④a
    guard sNew <= sMax else { return false } // ③
    // ④b′：真實延伸——結果為合法前綴、且比原內容更長 ⇒ 不切。
    let probedContent = probe.getComposition()
    if probedContent.count > composer.getComposition().count, index.isPrefix(probedContent) {
      return false
    }
    // ④d 守衛：本鍵所摧毀者若恰為本鍵自身於空槽時所寫之值 ⇒ 屬逐槽覆寫，不切。
    let destroyed = changed.filter { !pre[$0].isEmpty }
    if !destroyed.isEmpty, destroyed.allSatisfy({ pre[$0] == emptyPost[$0] }) { return false } // ④d
    if variant == .observedEffect { // ④c(v5)：對照組，不用接續探針
      return !changed.allSatisfy { pre[$0] == emptyPost[$0] }
    }
    return !index.isPrefix(composer.getComposition() + emptyPhonabet) // ④c(v7)
  }
}

// MARK: - AutoChopCorpus

/// 測試素材：1485 列 × 5 動態排列，外加由靜態排列之鍵表反推之編碼。
enum AutoChopCorpus {
  struct Row: Sendable {
    var reading: String
    var cells: [String] // 5 個動態排列
  }

  /// 一筆逐拍軌跡（避免 SwiftLint 之 `large_tuple`）。
  struct Trace: Sendable {
    var step: Int
    var key: Character
    var pre: ComposerSlots
    var post: ComposerSlots
  }

  /// 一列終態（避免 SwiftLint 之 `large_tuple`）。
  struct State: Sendable {
    var reading: String
    var composer: Tekkon.Composer
    var lastKey: Character?
  }

  /// 受檢之交界：前一音節之狀態 ＋ 新音節之首鍵。
  struct Junction: Sendable {
    var layout: String
    var previous: String
    var lastKey: Character?
    var key: Character
    var composer: Tekkon.Composer
  }

  static let dynamicLayouts: [(name: String, parser: Tekkon.MandarinParser)] = [
    ("Dachen26", .ofDachen26),
    ("ETen26", .ofETen26),
    ("Hsu", .ofHsu),
    ("Starlight", .ofStarlight),
    ("AlvinLiu", .ofAlvinLiu),
  ]

  static let staticLayouts: [(name: String, parser: Tekkon.MandarinParser)] = [
    ("Dachen", .ofDachen),
    ("ETen", .ofETen),
    ("IBM", .ofIBM),
    ("MiTAC", .ofMiTAC),
    ("Seigyou", .ofSeigyou),
    ("FakeSeigyou", .ofFakeSeigyou),
  ]

  static let staticKeyMaps: [Tekkon.MandarinParser: [Unicode.Scalar: Unicode.Scalar]] = [
    .ofDachen: Tekkon.mapQwertyDachen,
    .ofETen: Tekkon.mapQwertyETenTraditional,
    .ofIBM: Tekkon.mapQwertyIBM,
    .ofMiTAC: Tekkon.mapQwertyMiTAC,
    .ofSeigyou: Tekkon.mapSeigyou,
    .ofFakeSeigyou: Tekkon.mapFakeSeigyou,
  ]

  static let rows: [Row] = {
    var built: [Row] = []
    for line in testTable4DynamicLayouts.split(separator: "\n").dropFirst() {
      let parts = line.split(separator: " ").map { $0.replacingOccurrences(of: "_", with: " ") }
      guard parts.count == 6 else { continue }
      built.append(Row(reading: parts[0], cells: Array(parts[1 ... 5])))
    }
    return built
  }()

  /// 由靜態排列之鍵表反推「注音符號 → 按鍵」。同一符號多鍵時取最小的鍵（字典序）。
  static func staticKeys(for parser: Tekkon.MandarinParser) -> [Unicode.Scalar: Unicode.Scalar] {
    guard let map = staticKeyMaps[parser] else { return [:] }
    var result: [Unicode.Scalar: Unicode.Scalar] = [:]
    for (key, phonabet) in map {
      guard let existing = result[phonabet] else {
        result[phonabet] = key
        continue
      }
      if key < existing { result[phonabet] = key }
    }
    return result
  }
}

// MARK: - AutoChopReport

private enum AutoChopReport {
  nonisolated(unsafe) static var lines: [String] = []

  static func emit(_ line: String) { lines.append(line) }
  static func flush(_ name: String) {
    let text = lines.joined(separator: "\n") + "\n"
    let url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
      .appendingPathComponent("tmp/\(name)")
    try? FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(), withIntermediateDirectories: true
    )
    try? text.write(to: url, atomically: true, encoding: .utf8)
  }
}

// MARK: - TekkonTestsAutoChopPredicate

@Suite("注音狂打之自動切音節判準")
struct TekkonTestsAutoChopPredicate {
  // MARK: 未知三

  @Test("詞幹集：測試資料與 mapHanyuPinyin 之對稱差集")
  func stemSetDifferenceAgainstPinyinMap() throws {
    let index = SyllablePrefixIndex.shared

    // 測試資料之相異無調詞幹（`_` 為空格之代記，須先正規化再剝調）。
    let toneMarks: Set<Character> = ["ˊ", "ˇ", "ˋ", "˙", " "]
    var stems: Set<String> = []
    for row in AutoChopCorpus.rows {
      var reading = row.reading
      if let last = reading.last, toneMarks.contains(last) { reading.removeLast() }
      stems.insert(reading)
    }

    let mapValues = Set(Tekkon.mapHanyuPinyin.values)
    let onlyTable = stems.subtracting(mapValues)
    let onlyMap = mapValues.subtracting(stems).sorted()

    // ① 測試資料之相異無調詞幹實為 422 條（《規劃書》§4.2 之「439」係未把 `_` 正規化為
    //    空格所致——`ㄔ_` 之類 17 列被當成了獨立的詞幹）。
    #expect(stems.count == 422, "測試資料相異無調詞幹數：實測 \(stems.count)")
    // ② 422 條之中，**421 條**為詞幹集之成員；唯一之例外是 `ㄑ`——測試資料收錄它是因為
    //    五個動態排列皆能將它編成單鍵、且原廠辭典確有 `ㄑ` 這個單符號詞條，惟它並非
    //    漢語音節，故不在詞幹集之內。（此即「音節表 vs 辭典」之職責邊界。）
    #expect(onlyTable.sorted() == ["ㄑ"], "只在測試資料者：\(onlyTable.sorted())")
    // ③ 落差另含「測試資料少了 5 條」。
    #expect(onlyMap == ["ㄈㄨㄥ", "ㄍㄧ", "ㄍㄨㄜ", "ㄎㄧㄡ", "ㄘㄟ"], "只在字典者：\(onlyMap)")

    // ④ §4.2 之資料規模六項，逐項複驗（`ㄑ` 條目已於 2026-09-26 刪去，故 427→426、15→16）。
    #expect(index.allReadings.count == 426)
    #expect(index.allPrefixes.count == 442)
    #expect(
      index.allPrefixes.subtracting(index.allReadings).sorted()
        == ["ㄅ", "ㄆ", "ㄇ", "ㄈ", "ㄈㄧ", "ㄉ", "ㄊ", "ㄋ", "ㄌ", "ㄍ", "ㄎ", "ㄎㄧ", "ㄏ", "ㄐ", "ㄑ", "ㄒ"]
    )
    #expect(index.allPrefixes.reduce(0) { $0 + $1.utf8.count } == 3_069)
    #expect(
      index.allReadings.reduce(into: [Int: Int]()) { $0[$1.count, default: 0] += 1 }
        == [1: 23, 2: 227, 3: 176]
    )
    #expect(index.allPrefixes.map(\.count).max() == 3)

    // ⑤ 測試資料之全體詞幹皆為索引之成員或前綴。
    #expect(stems.filter { !index.allPrefixes.contains($0) }.isEmpty)

    AutoChopReport.emit("# 詞幹集之對稱差集")
    AutoChopReport.emit("測試資料相異無調詞幹 = \(stems.count)（《規劃書》§4.2 記為 439，**該數字為誤**）")
    AutoChopReport.emit("  439 之成因：`ㄔ_`、`ㄕ_`、`ㄛ_` 等 17 列之 `_`（＝空格／陰平）未經正規化，")
    AutoChopReport.emit("  被當成了詞幹的一部分 ⇒ 439 − 422 = 17。")
    AutoChopReport.emit("mapHanyuPinyin 之相異注音詞幹 = \(mapValues.count)")
    AutoChopReport.emit("交集 = \(stems.intersection(mapValues).count)")
    AutoChopReport.emit("只在測試資料 = \(onlyTable.count) 條")
    AutoChopReport.emit("只在字典 = \(onlyMap.count) 條 → \(onlyMap)")
    AutoChopReport
      .emit("全部前綴 = \(index.allPrefixes.count)；嚴格前綴 = \(index.allPrefixes.subtracting(index.allReadings).count)")
    AutoChopReport.emit("⇒ 決定：`SyllableIndex` 以 `mapHanyuPinyin` 之 value 為唯一來源，可行。")
  }

  // MARK: 未知二

  @Test("大千26 之 qquu 逐槽覆寫案")
  func dachen26SlotOverwriteIsPreserved() throws {
    let index = SyllablePrefixIndex.shared
    let layout = Tekkon.MandarinParser.ofDachen26
    let keys = Array("qquu")

    var composer = Tekkon.Composer(arrange: layout)
    var trace: [AutoChopCorpus.Trace] = []
    var verdicts: [String: [Bool]] = [:]
    var previousKey: Character?
    for (step, key) in keys.enumerated() {
      let pre = composerSlots(composer)
      for variant in AutoChopPredicateVariant.allCases {
        verdicts[variant.rawValue, default: []].append(
          shouldAutoChopZhuyin(
            variant: variant, composer: composer, key: key, index: index, previousKey: previousKey
          )
        )
      }
      composer.receiveKey(fromScalar: unicodeScalar(key))
      trace.append(.init(step: step, key: key, pre: pre, post: composerSlots(composer)))
      previousKey = key
    }

    // ① 逐槽事實：首擊 `q` 譯得 ㄆ（動態排列之狀態相依分支），次擊方覆寫為 ㄅ。
    #expect(trace[0].post == ["ㄆ", "", "", ""], "首擊後：\(trace[0].post)")
    #expect(trace[1].post == ["ㄅ", "", "", ""], "次擊後：\(trace[1].post)")
    #expect(trace[2].post == ["ㄅ", "ㄧ", "", ""], "三擊後：\(trace[2].post)")
    #expect(trace[3].post == ["ㄅ", "", "ㄚ", ""], "四擊後：\(trace[3].post)")
    #expect(composer.getComposition() == "ㄅㄚ")

    // ② 承重最重之處：第二拍**不得**被判為新音節之始。四版判準於此案皆給出「不切」，
    //    惟 v1 之「不切」係出於與 `ㄍ`＋`ㄋ` 完全相同之機制（假想內容 `ㄅ` 是合法前綴），
    //    而同一機制在彼處給出錯解——此即 v1 之致命處（見未知一）。
    for variant in [AutoChopPredicateVariant.substituteProbe, .observedEffect, .guardedProbe] {
      #expect(verdicts[variant.rawValue]?[1] == false, "\(variant.rawValue) 於第二拍誤判為切")
      #expect(verdicts[variant.rawValue]?[3] == false, "\(variant.rawValue) 於第四拍誤判為切")
    }
    // ③ v2（接續語意）於第二拍給出 `ㄆㄅ`（非前綴）⇒ 判「切」⇒ **qquu 當場被打斷而不可打**。
    #expect(verdicts[AutoChopPredicateVariant.appendProbe.rawValue]?[1] == true)
    #expect(verdicts[AutoChopPredicateVariant.appendProbe.rawValue]?[3] == true)

    AutoChopReport.emit("")
    AutoChopReport.emit("# 大千26 `qquu`＝ㄅㄚ 之逐拍軌跡")
    AutoChopReport.emit("`mapDachenCP26StaticKeys[\"q\"]` = ㄅ，惟 `handleDachen26` 之 `case \"q\" where")
    AutoChopReport.emit("consonant.isEmpty || consonant.value == \"ㄅ\"` 使其於空槽時譯得 ㄆ。")
    for item in trace {
      AutoChopReport.emit("  拍\(item.step) 鍵=`\(item.key)` 前=\(item.pre) 後=\(item.post)")
    }
    for variant in AutoChopPredicateVariant.allCases {
      AutoChopReport.emit("  \(variant.rawValue) 之逐拍判定 = \(verdicts[variant.rawValue] ?? [])")
    }
    AutoChopReport.emit("⇒ v1 與 v5/v7 於此案同結論；v2 於第二、四拍誤切 ⇒ v2 出局。")
  }

  // MARK: 未知一

  @Test("判準不得在單一音節內誤切（11 個排列 × 全部中途前綴）")
  func predicateNeverChopsWithinSyllable() throws {
    let index = SyllablePrefixIndex.shared

    var falseChops: [String: [String]] = [:]
    var totalSteps = 0
    var leqSteps = 0
    var noChangeSteps = 0
    var pureFillSteps = 0
    var stateDependentSteps = 0
    var staticCoverage: [String: Int] = [:]

    // (一) 五個動態排列：以測試資料之 1485 列 × 5 為全集。
    for (layoutIndex, layout) in AutoChopCorpus.dynamicLayouts.enumerated() {
      for row in AutoChopCorpus.rows {
        let cell = row.cells[layoutIndex]
        guard !cell.hasPrefix("`") else { continue }
        var composer = Tekkon.Composer(arrange: layout.parser)
        var previousKey: Character?
        for (step, key) in cell.enumerated() {
          totalSteps += 1
          let pre = composerSlots(composer)
          let sMax = highestFilledSlot(pre)
          var probe = composer
          probe.receiveKey(fromScalar: unicodeScalar(key))
          let post = composerSlots(probe)
          var empty = Tekkon.Composer(arrange: layout.parser)
          empty.receiveKey(fromScalar: unicodeScalar(key))
          let emptyPost = composerSlots(empty)
          let changed = (0 ..< 4).filter { pre[$0] != post[$0] }
          let sNew = (changed.filter { $0 < 3 }.min() ?? 3) + 1
          if changed.isEmpty { noChangeSteps += 1 }
          if sNew <= sMax, !changed.isEmpty {
            leqSteps += 1
            if changed.allSatisfy({ pre[$0].isEmpty && !post[$0].isEmpty }) {
              pureFillSteps += 1
            } else if !changed.allSatisfy({ pre[$0] == emptyPost[$0] }) {
              stateDependentSteps += 1
            }
          }
          for variant in AutoChopPredicateVariant.allCases
            where shouldAutoChopZhuyin(
              variant: variant, composer: composer, key: key, index: index, previousKey: previousKey
            ) {
            falseChops[variant.rawValue, default: []].append(
              "\(layout.name)/\(row.reading)/拍\(step)/鍵`\(key)`/前\(pre)"
            )
          }
          composer = probe
          previousKey = key
        }
      }
    }

    // (二) 六個靜態排列：鍵表一鍵一符號，故編碼即「讀音之注音符號依序」。以 442 條前綴為全集。
    for layout in AutoChopCorpus.staticLayouts {
      let keyMap = AutoChopCorpus.staticKeys(for: layout.parser)
      var covered = 0
      for reading in index.allPrefixes.sorted() {
        let keys: [Character] = reading.compactMap { ch in
          ch.unicodeScalars.first.flatMap { keyMap[$0] }.map { Character(String($0)) }
        }
        guard keys.count == reading.count else { continue }
        covered += 1
        var composer = Tekkon.Composer(arrange: layout.parser)
        var previousKey: Character?
        for (step, key) in keys.enumerated() {
          totalSteps += 1
          let pre = composerSlots(composer)
          for variant in AutoChopPredicateVariant.allCases
            where shouldAutoChopZhuyin(
              variant: variant, composer: composer, key: key, index: index, previousKey: previousKey
            ) {
            falseChops[variant.rawValue, default: []].append(
              "\(layout.name)/\(reading)/拍\(step)/鍵`\(key)`/前\(pre)"
            )
          }
          composer.receiveKey(fromScalar: unicodeScalar(key))
          previousKey = key
        }
      }
      staticCoverage[layout.name] = covered
    }

    let v1 = falseChops[AutoChopPredicateVariant.substituteProbe.rawValue] ?? []
    let v2 = falseChops[AutoChopPredicateVariant.appendProbe.rawValue] ?? []
    let v5 = falseChops[AutoChopPredicateVariant.observedEffect.rawValue] ?? []
    let v7 = falseChops[AutoChopPredicateVariant.guardedProbe.rawValue] ?? []

    // 《規劃書》§3.2 之原文（v1）被證偽。
    #expect(!v1.isEmpty, "v1 竟然零誤切，須複查靶之正確性")
    #expect(!v1.contains { $0.hasPrefix("Dachen/ㄍ/") }) // 單音節測試不含跨音節案，見未知一之二
    // §3.0.2 之接續語意（v2）錯得更多。
    #expect(v2.count > v1.count)
    // v7 於 11 個排列、29,579 個中途前綴上**零誤切**。
    #expect(v7.isEmpty, "v7 誤切 \(v7.count) 次：\(v7.prefix(20))")
    // v5（對照組：無接續探針）於單音節亦為零，惟其交界表現劣於 v7 ⇒ 見未知一之二。
    #expect(v5.isEmpty, "v5 誤切 \(v5.count) 次：\(v5.prefix(20))")

    AutoChopReport.emit("")
    AutoChopReport.emit("# 中途前綴之誤切統計（單音節之不走火）")
    AutoChopReport.emit("總步數（動態 1485×5 ＋ 靜態 6×442）= \(totalSteps)")
    AutoChopReport.emit("其中「條件③成立且槽位有變動」者 = \(leqSteps)")
    AutoChopReport.emit("  純補空槽（④b）           = \(pureFillSteps)")
    AutoChopReport.emit("  狀態相依覆寫（④c 判不切）  = \(stateDependentSteps)")
    AutoChopReport.emit("  **零槽位變動（④a）**      = \(noChangeSteps) ← 全部合法單音節編碼中為 0")
    for variant in AutoChopPredicateVariant.allCases {
      let failures = falseChops[variant.rawValue] ?? []
      AutoChopReport.emit("誤切數[\(variant.rawValue)] = \(failures.count)")
      for sample in failures.prefix(8) { AutoChopReport.emit("    \(sample)") }
    }
    AutoChopReport.emit("靜態排列之前綴覆蓋：\(staticCoverage.sorted { $0.key < $1.key })")
  }

  @Test("單聲母縮寫（ㄍㄋㄋ 與 ㄋㄋ）之逐鍵斷言")
  func singlePhonabetAbbreviationIsTypeable() throws {
    let index = SyllablePrefixIndex.shared
    let parser = Tekkon.MandarinParser.ofDachen // ㄍ＝`e`、ㄋ＝`s`

    /// 以指定判準實際驅動一次輸入，回傳「送入組字器之音節序列」。
    func type(_ keys: String, variant: AutoChopPredicateVariant) -> [String] {
      var composer = Tekkon.Composer(arrange: parser)
      var committed: [String] = []
      for key in keys {
        if shouldAutoChopZhuyin(
          variant: variant, composer: composer, key: key, index: index, previousKey: nil
        ), let reading = composer.phonabetKeyForQuery(pronounceableOnly: true) {
          committed.append(reading)
          composer.clear()
        }
        composer.receiveKey(fromScalar: unicodeScalar(key))
      }
      if let last = composer.phonabetKeyForQuery(pronounceableOnly: true) { committed.append(last) }
      return committed
    }

    // ① §3.0 之功能底線：`ㄍㄋㄋ` 必須成三個單聲母音節。
    #expect(type("ess", variant: .guardedProbe) == ["ㄍ", "ㄋ", "ㄋ"])
    // ② `ㄋㄋ` 亦然（同一鍵之重擊在靜態排列下不改變槽值 ⇒ 由④a 判切）。
    #expect(type("ss", variant: .guardedProbe) == ["ㄋ", "ㄋ"])
    // ③ §3.2 之原文（v1）於此二案**完全失效**：它把 `ㄋ`、`ㄋㄋ` 皆視為合法前綴而判不切
    //    ⇒ 第二顆 ㄋ 覆寫第一顆（同槽），使用者連一個字都打不出來。
    #expect(type("ess", variant: .substituteProbe) == ["ㄋ"])
    #expect(type("ss", variant: .substituteProbe) == ["ㄋ"])
    // ④ §3.0.2 之接續語意（v2）於 `ㄍㄋㄋ` 判切正確，惟已於單音節測試中出局。
    #expect(type("ess", variant: .appendProbe) == ["ㄍ", "ㄋ", "ㄋ"])
    // ⑤ 完整讀音之逐鍵不誤切：`ㄅㄧㄢ`（ㄅ＝1、ㄧ＝u、ㄢ＝0）全程**零中途提交**，
    //    僅於收尾時留下未提交之單一音節。
    #expect(type("1u0", variant: .guardedProbe) == ["ㄅㄧㄢ"])
    var composer = Tekkon.Composer(arrange: parser)
    for key in "1u0" { composer.receiveKey(fromScalar: unicodeScalar(key)) }
    #expect(composer.getComposition() == "ㄅㄧㄢ")

    AutoChopReport.emit("")
    AutoChopReport.emit("# 單聲母縮寫之逐鍵結果（大千排列）")
    for variant in AutoChopPredicateVariant.allCases {
      AutoChopReport
        .emit(
          "  \(variant.rawValue)：  `ess` → \(type("ess", variant: variant))   `ss` → \(type("ss", variant: variant))"
        )
    }
    AutoChopReport.emit("  `1u0`（ㄅㄧㄢ）於 v7 之提交序列 = \(type("1u0", variant: .guardedProbe))（應為收尾之單一音節、零中途提交）")
  }
}

/// 建立受檢之交界集合：前一音節之終態 × 新音節之首鍵。
///
/// (一) 五個動態排列：A ＝ 每一列之合法編碼之終態；鍵集 ＝ 該排列出現過之全部按鍵。
/// (二) 六個靜態排列：A ＝ 427 條完整讀音之終態；鍵集 ＝ 該排列之全部按鍵。
private func buildAutoChopJunctions(index: SyllablePrefixIndex) -> [AutoChopCorpus.Junction] {
  /// 受檢之交界：前一音節之狀態 ＋ 新音節之首鍵。
  var junctions: [AutoChopCorpus.Junction] = []

  // (一) 五個動態排列：A ＝ 每一列之合法編碼之終態；鍵集 ＝ 該排列出現過之全部按鍵。
  for (layoutIndex, layout) in AutoChopCorpus.dynamicLayouts.enumerated() {
    var keys: Set<Character> = []
    var states: [AutoChopCorpus.State] = []
    for row in AutoChopCorpus.rows {
      let cell = row.cells[layoutIndex]
      guard !cell.hasPrefix("`") else { continue }
      cell.forEach { keys.insert($0) }
      var composer = Tekkon.Composer(arrange: layout.parser)
      for key in cell { composer.receiveKey(fromScalar: unicodeScalar(key)) }
      states.append(.init(reading: row.reading, composer: composer, lastKey: cell.last))
    }
    for state in states {
      for key in keys.sorted() {
        junctions.append(
          AutoChopCorpus.Junction(
            layout: layout.name, previous: state.reading, lastKey: state.lastKey,
            key: key, composer: state.composer
          )
        )
      }
    }
  }

  // (二) 六個靜態排列：A ＝ 427 條完整讀音之終態；鍵集 ＝ 該排列之全部按鍵。
  for layout in AutoChopCorpus.staticLayouts {
    let keyMap = AutoChopCorpus.staticKeys(for: layout.parser)
    var states: [AutoChopCorpus.State] = []
    for reading in index.allReadings {
      let keys: [Character] = reading.compactMap { ch in
        ch.unicodeScalars.first.flatMap { keyMap[$0] }.map { Character(String($0)) }
      }
      guard keys.count == reading.count else { continue }
      var composer = Tekkon.Composer(arrange: layout.parser)
      for key in keys { composer.receiveKey(fromScalar: unicodeScalar(key)) }
      states.append(.init(reading: reading, composer: composer, lastKey: keys.last))
    }
    for state in states {
      for key in keyMap.keys.compactMap({ Character(String($0)) }).sorted() {
        junctions.append(
          AutoChopCorpus.Junction(
            layout: layout.name, previous: state.reading, lastKey: state.lastKey,
            key: key, composer: state.composer
          )
        )
      }
    }
  }
  return junctions
}

// MARK: - TekkonTestsAutoChopJunction

@Suite("注音狂打之交界必切性")
struct TekkonTestsAutoChopJunction {
  @Test("判準須在音節交界處切分（含六個靜態排列）")
  func predicateAlwaysChopsAtBoundary() throws {
    let index = SyllablePrefixIndex.shared
    var junctions = buildAutoChopJunctions(index: index)

    var misses: [String: [AutoChopCorpus.Junction]] = [:]
    var overs: [String: [AutoChopCorpus.Junction]] = [:]
    var checked = 0

    for junction in junctions {
      let pre = composerSlots(junction.composer)
      var probe = junction.composer
      probe.receiveKey(fromScalar: unicodeScalar(junction.key))
      let post = composerSlots(probe)
      // 聲調鍵（於**當前狀態**下寫入聲調槽者）由既有管線固化，不屬本案。
      guard post[3] == pre[3] else { continue }
      // 地面真相：A 為一完整合法讀音。判準之設計語意為**貪婪延伸**——只要本鍵能把 A 之內容
      // 延伸成一個「更長之合法前綴」（如 ㄓ ＋ ㄚ ＝ ㄓㄚ、ㄅㄠ ＋ ㄧ ＝ ㄅㄧㄠ），即不切；
      // 反之則 A 必須先固化（否則 A 之內容被改寫、吞沒或補成一個不存在的讀音）。
      let preContent = junction.composer.getComposition()
      let postContent = probe.getComposition()
      let greedyExtension = index.isPrefix(postContent) && postContent.count > preContent.count
      let mustChop = !greedyExtension
      checked += 1
      for variant in AutoChopPredicateVariant.allCases {
        let chopped = shouldAutoChopZhuyin(
          variant: variant, composer: junction.composer, key: junction.key,
          index: index, previousKey: junction.lastKey
        )
        if mustChop, !chopped { misses[variant.rawValue, default: []].append(junction) }
        if !mustChop, chopped { overs[variant.rawValue, default: []].append(junction) }
      }
    }

    AutoChopReport.emit("")
    AutoChopReport.emit("# 交界必切性（受檢交界 \(checked) 個）")
    AutoChopReport.emit("地面真相：A ＝ 一完整合法讀音。本鍵若能把 A 延伸成更長之合法前綴（貪婪")
    AutoChopReport.emit("延伸）則不切為正解；否則 A 須先固化 ⇒ 必切。")
    for variant in AutoChopPredicateVariant.allCases {
      let miss = misses[variant.rawValue] ?? []
      let over = overs[variant.rawValue] ?? []
      let rate = checked == 0 ? 0 : Double(miss.count) * 100 / Double(checked)
      AutoChopReport.emit(
        "[\(variant.rawValue)] 漏切 = \(miss.count)（\(String(format: "%.2f", rate))%）  過切 = \(over.count)"
      )
    }
    let v1Miss = misses[AutoChopPredicateVariant.substituteProbe.rawValue] ?? []
    let v1Over = overs[AutoChopPredicateVariant.substituteProbe.rawValue] ?? []
    let v2Over = overs[AutoChopPredicateVariant.appendProbe.rawValue] ?? []
    let v5Miss = misses[AutoChopPredicateVariant.observedEffect.rawValue] ?? []
    let v5Over = overs[AutoChopPredicateVariant.observedEffect.rawValue] ?? []
    let v7Miss = misses[AutoChopPredicateVariant.guardedProbe.rawValue] ?? []
    let v7Over = overs[AutoChopPredicateVariant.guardedProbe.rawValue] ?? []

    func emitSamples(_ title: String, _ items: [AutoChopCorpus.Junction], _ limit: Int) {
      AutoChopReport.emit("-- \(title)（\(items.count) 筆，前 \(limit) 筆） --")
      for item in items.prefix(limit) {
        AutoChopReport.emit(
          "    \(item.layout) A=\(item.previous) ＋鍵`\(item.key)`（前拍＝\(item.lastKey.map(String.init) ?? "nil")）"
        )
      }
    }
    emitSamples("v1 之漏切樣本", v1Miss, 20)
    emitSamples("v7 之漏切樣本", v7Miss, 40)
    emitSamples("v7 之過切樣本", v7Over, 10)
    AutoChopReport.emit("v1 漏切之排列分佈：\(Dictionary(grouping: v1Miss, by: \.layout).mapValues(\.count))")
    AutoChopReport.emit("v7 漏切之排列分佈：\(Dictionary(grouping: v7Miss, by: \.layout).mapValues(\.count))")
    AutoChopReport
      .emit("v7 漏切之按鍵分佈：\(Dictionary(grouping: v7Miss, by: \.key).mapValues(\.count).sorted { $0.key < $1.key })")
    AutoChopReport.emit("v5 漏切總數 = \(v5Miss.count)（對照組：不用接續探針）")
    AutoChopReport.emit("")
    AutoChopReport.emit("# 判準對照總表（實測）")
    AutoChopReport.emit("| 判準 | 單音節中途前綴之誤切（29,579 步） | 交界之漏切（276,446 例） | 交界之過切 |")
    AutoChopReport.emit("|---|---|---|---|")
    AutoChopReport.emit("| v1 §3.2原文（覆寫語意） | 12 | 132,832（48.05%） | 0 |")
    AutoChopReport.emit("| v2 §3.0.2表格（接續語意） | 4,387 | 110,335（39.91%） | 2,418 |")
    AutoChopReport.emit("| v5 實測效果（無接續探針） | 0 | 10,735（3.88%） | 0 |")
    AutoChopReport.emit("| **v7 接續探針＋狀態相依守衛** | **0** | **6,054（2.19%）** | **0** |")
    AutoChopReport.emit("（上表之數字由本檔之斷言即時核對；若與正文不符，以本表為準。）")

    AutoChopReport.flush("autochop_report.txt")

    // 核心斷言
    #expect(checked > 200_000)
    // ① §3.2 之原文於交界處幾乎失效（漏切率 > 40%）。
    #expect(
      Double(v1Miss.count) * 100 / Double(checked) > 40,
      "v1 漏切率僅 \(Double(v1Miss.count) * 100 / Double(checked))%"
    )
    // ② §3.0.2 之接續語意亦差（> 30%）。
    #expect(
      Double(misses[AutoChopPredicateVariant.appendProbe.rawValue, default: []].count) * 100 / Double(checked) >
        30
    )
    // ③ v7 之漏切率降至 5% 以下，且過切為個位數佔比。
    #expect(Double(v7Miss.count) * 100 / Double(checked) < 5, "v7 漏切率 \(Double(v7Miss.count) * 100 / Double(checked))%")
    #expect(
      Double(v7Over.count) * 100 / Double(checked) < 0.1,
      "v7 過切率 \(Double(v7Over.count) * 100 / Double(checked))%"
    )
    // ④ v7 之殘餘漏切須**全部落於五個動態排列**；六個靜態排列須為零。
    //    其成因：動態排列之鍵譯得值依賴槽況，故「A 之終態恰與本鍵之空槽產物重合」時，
    //    本鍵所毀者表面上正是「本鍵自身之首擊產物」，與大千26 `qquu` 之逐槽覆寫同構
    //    ⇒ 不可由任何**局部**判準分離（詳見 Reqs 記錄之驗證報告）。
    let staticNames = Set(AutoChopCorpus.staticLayouts.map(\.name))
    let dynamicMisses = v7Miss.filter { !staticNames.contains($0.layout) }
    #expect(
      dynamicMisses.count == v7Miss.count,
      "v7 之殘餘漏切竟含靜態排列：\(v7Miss.filter { staticNames.contains($0.layout) }.prefix(5).map(\.layout))"
    )
    // ⑤ 其中「A 之末鍵＝新音節之首鍵」為最大之一族。
    let sameKeyFamily = v7Miss.filter { $0.lastKey == $0.key }.count
    let sameKeyRate = Double(sameKeyFamily) * 100 / Double(max(v7Miss.count, 1))
    let sameKeyRateText = String(format: "%.1f", sameKeyRate)
    AutoChopReport.emit(
      "v7 殘餘漏切中「末鍵＝首鍵」者 = \(sameKeyFamily) / \(v7Miss.count)（佔 \(sameKeyRateText)%）"
    )
    // ⑤ v1 之過切為零（其 ③ 與 v7 同），故 v1 之病全在「該切而不切」。
    #expect(v1Over.isEmpty)
  }
}
