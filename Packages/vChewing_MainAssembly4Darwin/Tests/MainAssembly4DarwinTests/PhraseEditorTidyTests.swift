// (c) 2026 and onwards The vChewing Project (MulanPSL-2.0 License).
// ====================
// This code is released under the SPDX-License-Identifier: `MulanPSL-2.0`.

import Foundation
import Shared
import Testing

@testable import MainAssembly4Darwin

// MARK: - PhraseEditorTidyTests

/// 「整理」路徑（`tagOverrides` 之純函式部分）之兩條契約（P335）。
///
/// ① 帶 `#NGRAM` 之列原樣放行——不判原廠配對、不追加 `#𝙾𝚟𝚎𝚛𝚛𝚒𝚍𝚎`；
/// ② 兩格以下之列原樣保留——舊制會把這類列連同其斷行一併丟棄。
/// 配對查詢以閉包注入，故本套房不依賴辭典之連線狀態。
@Suite(.serialized)
final class PhraseEditorTidyTests {
  @Test
  func nGramRowIsLeftUntouchedEvenWhenPairExists() {
    let source = "的 ㄉㄜ˙ -1.497 #NGRAM:在|* #手調"
    let result = LXMgr.applyOverrideTags(to: source) { _, _ in true }
    #expect(result == source + "\n", "n-gram 列不得被追加標記、亦不得被改寫。")
  }

  @Test
  func nGramRowIsRecognizedRegardlessOfCaseOrPosition() {
    for line in [
      "的 ㄉㄜ˙ -1.497 #ngram:在|*",
      "的 ㄉㄜ˙ -1.497 #手調 #Ngram:在|*",
      "的 ㄉㄜ˙ #NGRAM:在|*",
    ] {
      let result = LXMgr.applyOverrideTags(to: line) { _, _ in true }
      #expect(result == line + "\n", "應視為 n-gram 列：\(line)")
    }
  }

  @Test
  func shortLinesArePreservedInsteadOfDropped() {
    let source = "#\n封堵 ㄈㄥ-ㄉㄨˇ"
    let result = LXMgr.applyOverrideTags(to: source) { _, _ in false }
    #expect(result == "#\n封堵 ㄈㄥ-ㄉㄨˇ\n", "兩格以下之列不得被丟棄。")
  }

  @Test
  func ordinaryRowStillGetsTheOverrideMarker() {
    let source = "不下 ㄅㄨˋ-ㄒㄧㄚˋ -114.514"
    let result = LXMgr.applyOverrideTags(to: source) { _, _ in true }
    #expect(result == source + " #𝙾𝚟𝚎𝚛𝚛𝚒𝚍𝚎\n")
  }

  @Test
  func ordinaryRowWithoutFactoryPairStaysAsIs() {
    let source = "封堵 ㄈㄥ-ㄉㄨˇ"
    let result = LXMgr.applyOverrideTags(to: source) { _, _ in false }
    #expect(result == source + "\n")
  }
}
