// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation
import Homa
import Testing

@testable import LexiconAssembly

// MARK: - LXFacadeGramCacheInvalidationTests

/// 檢索快取（`unigramLRUCache`；其內容為 gram——含 POM 供應之 bigram／trigram——
/// 故不以 unigram 名之）的作廢契約測試。
///
/// 病灶（Phase 242）：`LXFacade.replaceData(textData:for:save:)` 與
/// `LXFacade.loadUserSymbolData(path:)` 會熱置換使用者子語言模組的資料，卻未作廢
/// `unigramsFor` 的 LRU 快取。同一行程內，只要某讀音在資料變更**之前**被查過一次，
/// 變更後的查詢就會持續拿到變更前的結果——直到其他狀態（`config`／原廠辭典世代／
/// POM 世代／磁帶世代／額外掛載來源世代）恰巧變動而順帶作廢快取為止。
///
/// 磁帶（cassette）資料為**靜態**、而查詢快取為**逐實例**，靜態端無法逐一通知既有實例，
/// 故改以 `cassetteGeneration` 併入指紋；本檔一併為該路徑立下契約。
@Suite(.serialized)
struct LXFacadeGramCacheInvalidationTests {
  @Test
  func testReplaceDataInvalidatesGramCache() {
    defer { LXAssembly.LXFacade.disconnectFactoryDictionary() }
    let lx = LXAssembly.LXFacade(isCHS: false)
    let keyArray = ["ㄉㄜ˙", "ㄉㄜ˙", "ㄉㄜ˙"]
    let value = "乂乂乂"

    // ① 先查一次，令快取記住此讀音當下的結果（此時查無資料）。
    #expect(lx.lxQuerier.grams(for: keyArray).isEmpty)

    // ② 熱置換使用者詞語：加入該讀音下的詞條。
    lx.replaceData(
      textData: "\(value) \(keyArray.joined(separator: "-")) 0.0\n",
      for: .thePhrases,
      save: false
    )

    // ③ 同一讀音必須立即反映新資料，不得回傳置換前的空結果。
    #expect(lx.lxQuerier.grams(for: keyArray).map(\.current) == [value])
  }

  @Test
  func testCassetteReloadInvalidatesGramCache() throws {
    let originalAsyncLoading = LXAssembly.LXFacade.asyncLoadingUserData
    LXAssembly.LXFacade.asyncLoadingUserData = false
    defer {
      LXAssembly.LXFacade.asyncLoadingUserData = originalAsyncLoading
      LXAssembly.LXFacade.lxCassette.clear()
    }

    let cinURL = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent("Phase242_CassetteReload.cin")

    func writeCINTables(_ pairs: [(key: String, value: String)]) throws {
      let body = pairs.map { "\($0.key) \($0.value)" }.joined(separator: "\n")
      let text = """
      %ename Phase242Fixture
      %cname 快取作廢契約測試
      %selkey 1234567890
      %chardef begin
      \(body)
      %chardef end
      """
      try text.write(to: cinURL, atomically: true, encoding: .utf8)
    }

    try writeCINTables([("a", "甲")])
    LXAssembly.LXFacade.loadCassetteData(path: cinURL.path)

    let lx = LXAssembly.LXFacade(isCHS: false)
    lx.setOptions { $0.isCassetteEnabled = true }

    // ① 先查一次，令快取記住第一份磁帶的內容。
    let before = lx.lxQuerier.grams(for: ["a"]).map(\.current)
    #expect(before.contains("甲"))

    // ② 以同一路徑換上另一份磁帶（讀音不變、內容全異）。
    try writeCINTables([("a", "乙")])
    LXAssembly.LXFacade.loadCassetteData(path: cinURL.path)

    // ③ 同一讀音必須立即反映新磁帶，不得回傳舊磁帶的「甲」。
    let after = lx.lxQuerier.grams(for: ["a"]).map(\.current)
    #expect(after.contains("乙"))
    #expect(!after.contains("甲"))
  }
}
