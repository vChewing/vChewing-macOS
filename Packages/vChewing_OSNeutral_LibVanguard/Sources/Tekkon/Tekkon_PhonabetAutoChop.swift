// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

// MARK: - Phonabet Auto-Chop Predicate

extension Tekkon.Composer {
  /// 本鍵是否應先自動切音節（**規格 v7，六條**；實作即該規格之逐條移植）。
  ///
  /// - Note: 本判準是**注拼槽狀態之純函式**——不讀 handler、不讀 session、不讀偏好，
  ///   故得零成本驅動數十萬次（自 P261 起其回歸靶住在 `Tests/TekkonTests/`）。
  ///   **生產側之呼叫者僅 `BPMFFullMatchTypewriter.performPhonabetAutoChopIfNeeded` 一處**：
  ///   判準在此、只回裁決；執行（寫入組字器／清注拼槽／補回本鍵）在彼。
  ///
  /// - Important: 本判準之**權威規格**（逐條理由、四則對照實例、三條已知界線）住在
  ///   vChewing 開發倉之 `Research/Phase250-ResearchAndNextSurgeryPlan.md` §3.2（v7）——
  ///   該檔**不在本套件內**，故本檔以摘要自持：任何修訂都不得只動此處之實作而不動該正本，
  ///   亦不得只動正本而不動此處。摘要：
  ///
  /// - **①** 注拼槽非空。
  /// - **②** 本鍵非聲調鍵（以「本鍵施於空槽時是否寫入聲調」判之）。
  /// - **④a** 本鍵未造成任何槽位變動 ⇒ **切**（冗餘鍵＝新音節之始）。
  /// - **③** 固有目標槽 `S_new ≦ S_max`——`S_new` **取自「本鍵施於空槽時所寫入之首個非空槽」**，
  ///   不得取「本次實際變動之最低槽」：後者會被動態排列之糾錯副作用（倚天26 `be`＝ㄐㄧ：
  ///   鍵 `e` 寫介母 ㄧ之餘另把 ㄓ 糾正為 ㄐ）誤導而使條件失效。
  /// - **④b′** 結果為合法前綴且比原內容更長 ⇒ **不切**（真實延伸）。
  /// - **④d** 本鍵所摧毀之各槽值恰為本鍵空槽試跑之產物 ⇒ **不切**（動態排列之逐槽覆寫）。
  /// - **④c** 否則以接續探針定之：`當前讀音字串 ＋ emptyPost[S_new]` 非任何讀音之前綴 ⇒ **切**。
  ///
  /// - Parameter key: 本拍之按鍵（單一字元）。
  public func shouldAutoChopPhonabets(byTyping key: Character) -> Bool {
    guard !isEmpty else { return false } // ①
    guard let scalar = key.unicodeScalars.first else { return false }
    let pre = phonabetAutoChopSlots()
    let sMax = phonabetAutoChopHighestFilledSlot(pre) // 由 self 呼叫
    var probe = self
    probe.receiveKey(fromScalar: scalar)
    let post = probe.phonabetAutoChopSlots()
    var empty = Tekkon.Composer(arrange: parser)
    empty.receiveKey(fromScalar: scalar)
    let emptyPost = empty.phonabetAutoChopSlots()

    let changed = (0 ..< 4).filter { pre[$0] != post[$0] }
    let primarySlot = (0 ..< 4).first { !emptyPost[$0].isEmpty }
      ?? changed.filter { $0 < 3 }.min() ?? 0
    let sNew = primarySlot + 1
    let emptyPhonabet = emptyPost[primarySlot]

    guard emptyPost[3].isEmpty, !changed.contains(3) else { return false } // ②
    if changed.isEmpty { return true } // ④a
    guard sNew <= sMax else { return false } // ③
    let index = Tekkon.SyllableIndex.shared(parser: parser)
    let probedContent = probe.getComposition()
    if probedContent.count > getComposition().count, index.isPrefix(probedContent) {
      return false // ④b′
    }
    let destroyed = changed.filter { !pre[$0].isEmpty }
    if !destroyed.isEmpty, destroyed.allSatisfy({ pre[$0] == emptyPost[$0] }) { return false } // ④d
    return !index.isPrefix(getComposition() + emptyPhonabet) // ④c
  }

  /// 四槽內容（聲／介／韻／調）。
  private func phonabetAutoChopSlots() -> [String] {
    [consonant.value, semivowel.value, vowel.value, intonation.value]
  }

  /// 「最高已填之聲介韻槽位」＋1（全空為 0）。槽序：聲 1 ＜ 介 2 ＜ 韻 3。
  private func phonabetAutoChopHighestFilledSlot(_ slots: [String]) -> Int {
    (0 ..< 3).reduce(0) { slots[$1].isEmpty ? $0 : max($0, $1 + 1) }
  }
}
