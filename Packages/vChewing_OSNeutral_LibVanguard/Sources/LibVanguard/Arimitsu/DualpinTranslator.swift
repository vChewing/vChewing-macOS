// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation

// MARK: - DualpinTranslator

/// 雙拼之鍵序翻譯狀態機。
///
/// 本型別只管「鍵 → 碼 → 詞幹集合」之純邏輯：不知組音區、不知候選、不知鈴聲、不知主機。
/// 任何與主機有關之舉措（固化前一首節、入組音區、出聲）皆由 `DualpinTypewriter` 依本型別
/// 回報之 `Action` 施作。此係 OS 中立性之硬約束：本模組內**永不**發聲。
///
/// 狀態只有兩態：`idle` 與 `pending(firstKey:)`。兩鍵之間**無**計時器、**無**自動確認；
/// 唯有得碼、失配、或外力沖刷（`flush()`）方離 `pending`。
public struct DualpinTranslator: Hashable, Sendable {
  // MARK: Lifecycle

  public init(alphabet: Set<Character>, codeToStems: [String: [String]]) {
    self.alphabet = alphabet
    self.codeToStems = codeToStems
    self.firstKeys = Set(codeToStems.keys.compactMap(\.first))
  }

  /// 以校驗報告建構。
  ///
  /// `report.codeToStems` 依設計只含主碼，方案宣告之別名另存於 `report.aliasCodeToStems`；
  /// 此處須將兩者併攏，否則別名碼在打字的當下形同虛設（方案作者寫了、方案校驗也收了，
  /// 唯獨不吃鍵）。同一碼若同時是某詞幹之主碼與他詞幹之別名，該碼即成重碼——本即允許。
  public init(report: DualpinValidationReport, alphabet: Set<Character>) {
    var merged = report.codeToStems
    for (code, aliasStems) in report.aliasCodeToStems.sorted(by: { $0.key < $1.key }) {
      let existing = merged[code] ?? []
      merged[code] = existing + aliasStems.filter { !existing.contains($0) }
    }
    self.init(alphabet: alphabet, codeToStems: merged)
  }

  // MARK: Public

  /// 一次 `ingest(_:)` 之結果。
  public enum Action: Hashable, Sendable {
    /// 該鍵不屬於本方案之鍵位空間：請上層照舊處理（聲調鍵、符號鍵皆走此徑）。
    case passthrough
    /// 該鍵已收為待配之首鍵：僅更新顯示，**不得**進入組音區。
    case bufferOnly(firstKey: Character)
    /// 兩鍵湊成一碼；`stems` 為該碼之全部詞幹（重碼時多於一條）。
    case translate(firstKey: Character, secondKey: Character, stems: [String])
    /// 兩鍵不成碼：上層應出聲示警並丟棄此二鍵，**不得**使其落為原文。
    case invalid(firstKey: Character, secondKey: Character)
    /// 該鍵不可能開啟任何碼（如微軟雙拼之 `a`／`e`／`;`：三者皆只能居次鍵之位）：上層應出聲
    /// 示警並逕行丟棄該鍵，**不得**使其落為原文、亦**不得**使其成為待配之首鍵。
    case invalidFirstKey(firstKey: Character)
  }

  /// 本方案可用之鍵。
  public let alphabet: Set<Character>
  /// 可居首鍵之鍵（即「至少有一碼起於該鍵」者）。
  ///
  /// ★ P310：無碼起於其鍵者（微軟雙拼之 `a`／`e`／`;`）永不成碼，`ingest` 見之即回
  /// `invalidFirstKey`，不使之入 `pending`。本集合由 `codeToStems` 反推，故別名碼亦在列。
  public let firstKeys: Set<Character>
  /// 碼 → 詞幹集合。
  public let codeToStems: [String: [String]]
  /// 待配之首鍵；`nil` 表 `idle`。
  public private(set) var pendingFirstKey: Character?
  /// 最近一次得碼時，除首選以外之其餘詞幹。由組音區固化時一併併入查詢鍵列。
  public private(set) var siblingStems: [String] = []

  /// 顯示於組字緩衝區末端之待配首鍵。空字串表無可顯示者。
  public var displayText: String { pendingFirstKey.map(String.init) ?? "" }
  /// 是否無待配之鍵。
  public var isIdle: Bool { pendingFirstKey == nil }
  /// 是否有待配之鍵。
  public var isPending: Bool { pendingFirstKey != nil }

  /// 收一鍵。
  ///
  /// - Parameter key: 已正規化為小寫之鍵。
  /// - Returns: 本次之動作。`.translate` 時，`siblingStems` 已同步更新。首鍵若不可能開啟任何
  ///   碼，則回 `invalidFirstKey`（★ P310）——該鍵不入 `pending`，狀態仍為 `idle`。
  public mutating func ingest(_ key: Character) -> Action {
    guard alphabet.contains(key) else { return .passthrough }
    guard let first = pendingFirstKey else {
      // ★ P310：首鍵若不可能開啟任何碼（如微軟雙拼之 `a`／`e`／`;`），其存在永不成碼——收下
      // 只會令次鍵必不成碼（乃至使後續之中斷鍵落於「有素材待結算、實則無物可結算」之窘境），
      // 故當場示警並丟棄之。別名碼亦計入 `firstKeys`，故別名所增之輸入不受此限。
      guard firstKeys.contains(key) else { return .invalidFirstKey(firstKey: key) }
      pendingFirstKey = key
      siblingStems = []
      return .bufferOnly(firstKey: key)
    }
    pendingFirstKey = nil
    let code = String(first) + String(key)
    guard let stems = codeToStems[code], let primary = stems.first else {
      return .invalid(firstKey: first, secondKey: key)
    }
    siblingStems = Array(stems.dropFirst())
    return .translate(firstKey: first, secondKey: key, stems: [primary] + siblingStems)
  }

  /// 沖刷待配之鍵。
  ///
  /// 呼叫時機：確認鍵（空格／回車）、方向鍵、輸入法切換、游標移動。因雙拼之「一碼一音節」
  /// 語義，此處不作任何固化，只丟棄待配之首鍵。
  ///
  /// 駐留之重碼詞幹**不**隨之一併丟棄：該等詞幹屬於「已進注拼槽、尚未固化」之音節，
  /// 其生命週期與該音節相同（見 `consumeSiblingStems()` 與 `resetAll()`）。
  public mutating func flush() {
    pendingFirstKey = nil
  }

  /// 沖刷全部狀態（含駐留之重碼詞幹）。
  ///
  /// 呼叫時機：整個組字歷程遭廢棄（`InputHandler.clear()`）。
  public mutating func resetAll() {
    pendingFirstKey = nil
    siblingStems = []
  }

  /// 併走並清空先前駐留之重碼詞幹。
  public mutating func consumeSiblingStems() -> [String] {
    defer { siblingStems = [] }
    return siblingStems
  }

  /// 以該鍵為首鍵之諸碼所譯出之諸詞幹（依碼序、去重）。
  ///
  /// 首鍵尚未成碼，故本清單即「該鍵能開啟哪些音節」之全部可能。狂打之 copilot 窗須於
  /// 首鍵一按下時即成立（事主 2026-10-13），其讀音桶即由此推算——若等次鍵成碼才出窗，
  /// 使用者在按下首鍵後、次鍵前的空窗期內全無候選可參考。
  public func stemsStarting(with firstKey: Character) -> [String] {
    var seen = Set<String>()
    var result: [String] = []
    for code in codeToStems.keys.sorted() where code.count == 2 && code.first == firstKey {
      for stem in codeToStems[code] ?? [] where seen.insert(stem).inserted {
        result.append(stem)
      }
    }
    return result
  }
}
