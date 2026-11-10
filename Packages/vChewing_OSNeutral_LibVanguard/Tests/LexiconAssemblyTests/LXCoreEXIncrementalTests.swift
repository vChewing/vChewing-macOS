// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

// 使用者子語言模組之**增量收列**（P346）。
//
// 既有路徑是「寫檔之後整檔重載」：把上萬列重解析一遍（逐列取前兩格、轉注音、建索引、排序）。
// 增量收列只解析**新的一列**，其餘索引不動。本套房釘死三件事：
// ① 增量收列之結果與「整檔重載」逐位元組等價；
// ② 移出（NUL 覆寫 + 除名）之結果與整檔重載後之查詢結果等價；
// ③ 異常輸入（註解列、格數不足）不收、且記憶體狀態原樣。

import Foundation
import Homa
import Testing

@testable import LexiconAssembly

// MARK: - LXCoreEXIncrementalTests

@Suite(.serialized)
struct LXCoreEXIncrementalTests {
  // MARK: Internal

  @Test("增量收列之結果與整檔重載等價")
  func incrementalInsertMatchesFullReload() {
    let baseText = """
    # 𝙵𝙾𝚁𝙼𝙰𝚃
    甲 ㄐㄧㄚ 0.0
    乙 ㄧˇ -1.5
    丙 ㄅㄧㄥˇ
    甲 ㄐㄧㄚ -2.0
    """
    let newRowA = "家主 ㄐㄧㄚ-ㄓㄨ 0.0"
    let newRowB = "丁 ㄉㄧㄥ"

    var incremental = makeStore(text: baseText)
    let insertedA = incremental.insertRow(newRowA)
    let insertedB = incremental.insertRow(newRowB)
    #expect(insertedA)
    #expect(insertedB)

    let fullText = baseText + "\n" + newRowA + "\n" + newRowB + "\n"
    let reloaded = makeStore(text: fullText)

    #expect(incremental.strData == reloaded.strData, "增量收列之後，記憶體內容須與整檔重載逐位元組相同。")
    #expect(incremental.dictRepresented == reloaded.dictRepresented, "索引內容須與整檔重載相同。")
    #expect(incremental.count == reloaded.count)
    for keyChain in ["ㄐㄧㄚ", "ㄧˇ", "ㄅㄧㄥˇ", "ㄐㄧㄚ-ㄓㄨ", "ㄉㄧㄥ"] {
      #expect(
        incremental.unigramsFor(key: keyChain).map(\.current).sorted()
          == reloaded.unigramsFor(key: keyChain).map(\.current).sorted(),
        "讀音 \(keyChain) 之查詢結果須與整檔重載相同。"
      )
    }
  }

  @Test("增量收列：新鍵插在既有鍵之中，二分搜尋仍可命中")
  func incrementalInsertKeepsKeyOrderSearchable() {
    var store = makeStore(text: "")
    // 刻意以非字典序插入，驗證「附加鍵位元組 ＋ 依鍵插入 entry」仍維持有序。
    for key in ["ㄅㄧㄥˇ", "ㄚ", "ㄐㄧㄚ-ㄓㄨ", "ㄧˇ", "ㄗ"] {
      let inserted = store.insertRow("值\(key.hashValue.magnitude % 10) \(key)")
      #expect(inserted)
    }
    for key in ["ㄅㄧㄥˇ", "ㄚ", "ㄐㄧㄚ-ㄓㄨ", "ㄧˇ", "ㄗ"] {
      #expect(store.hasUnigramsFor(key: key), "鍵 \(key) 應可被二分搜尋命中。")
    }
    #expect(store.count == 5)
  }

  @Test("增量收列：既有內容缺斷行時先補一個斷行")
  func incrementalInsertRepairsMissingTrailingNewline() {
    var store = makeStore(text: "甲 ㄐㄧㄚ")
    let inserted = store.insertRow("乙 ㄧˇ")
    #expect(inserted)
    #expect(store.strData == "甲 ㄐㄧㄚ\n乙 ㄧˇ\n")
  }

  @Test("增量收列：註解列與格數不足者一律不收、記憶體不變")
  func incrementalInsertRejectsInvalidRows() {
    var store = makeStore(text: "甲 ㄐㄧㄚ\n")
    let originalText = store.strData
    let commentRejected = store.insertRow("# 這是註解")
    let shortRowRejected = store.insertRow("只有一格")
    let emptyRejected = store.insertRow("")
    #expect(!commentRejected)
    #expect(!shortRowRejected)
    #expect(!emptyRejected)
    #expect(store.strData == originalText, "不合格之列不得留下任何位元組。")
    #expect(store.count == 1)
  }

  @Test("移出一列：命中列以 NUL 覆寫且自索引除名")
  func removeRowBleachesAndDropsEntry() {
    let text = "甲 ㄐㄧㄚ 0.0\n乙 ㄧˇ 0.0\n"
    var store = makeStore(text: text)
    #expect(store.unigramsFor(key: "ㄐㄧㄚ").map(\.current) == ["甲"])

    let removed = store.removeRow(matching: ["甲", "ㄐㄧㄚ"])
    #expect(removed)
    #expect(store.unigramsFor(key: "ㄐㄧㄚ").isEmpty, "移出之後，該讀音不得再有條目。")
    #expect(!store.hasUnigramsFor(key: "ㄐㄧㄚ"))
    #expect(store.count == 1)
    // 記憶體內容與落盤端之 NUL 覆寫同語義。
    let expected = String(repeating: "\u{0}", count: "甲 ㄐㄧㄚ".utf8.count) + " 0.0\n乙 ㄧˇ 0.0\n"
    #expect(store.strData == expected)
  }

  @Test("移出一列：查無此列時回傳假、記憶體不變")
  func removeRowReportsMiss() {
    var store = makeStore(text: "甲 ㄐㄧㄚ 0.0\n")
    let originalText = store.strData
    let miss = store.removeRow(matching: ["乙", "ㄧˇ"])
    #expect(!miss)
    #expect(store.strData == originalText)
  }

  @Test("移出一列：只看前兩格，權重與標記格不影響判定")
  func removeRowIgnoresTrailingCells() {
    var store = makeStore(text: "甲 ㄐㄧㄚ 0.0 #𝙾𝚟𝚎𝚛𝚛𝚒𝚍𝚎\n")
    let removed = store.removeRow(matching: ["甲", "ㄐㄧㄚ", "0.0", "#𝙾𝚟𝚎𝚛𝚛𝚒𝚍𝚎"])
    #expect(removed)
    #expect(store.unigramsFor(key: "ㄐㄧㄚ").isEmpty)
  }

  @Test("同一讀音下只移出被指名的那一列")
  func removeRowOnlyTouchesTheNamedPair() {
    var store = makeStore(text: "甲 ㄐㄧㄚ 0.0\n假 ㄐㄧㄚ 0.0\n")
    let removed = store.removeRow(matching: ["假", "ㄐㄧㄚ"])
    #expect(removed)
    #expect(store.unigramsFor(key: "ㄐㄧㄚ").map(\.current) == ["甲"])
    #expect(store.count == 1)
  }

  // MARK: Private

  /// 以「整檔重載」建構一份使用者片語模組（`reverse` 為真，與 `lxUserPhrases` 同）。
  private func makeStore(text: String) -> LXAssembly.LXCoreEX {
    var store = LXAssembly.LXCoreEX(
      reverse: true,
      consolidate: false,
      defaultScore: { _ in 0 },
      forceDefaultScore: false
    )
    store.replaceData(textData: text)
    return store
  }
}
