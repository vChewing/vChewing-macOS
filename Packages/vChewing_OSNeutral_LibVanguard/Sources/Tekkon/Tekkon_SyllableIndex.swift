// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation

// MARK: - Tekkon.SyllableIndex

extension Tekkon {
  /// 漢語音節之唯讀前綴索引。
  ///
  /// 由 `Tekkon.mapHanyuPinyin` 之注音詞幹（426 條）派生，含其全部非空前綴（442 條）。
  /// 它只回答**一問**：「此串是否還可能延伸成某個合法讀音」——即前綴之成員資格。
  ///
  /// - Important: 本型別**不**回答「此串在辭典內有無詞條」。那是辭典（`LXFacade` 之查詢鏈）
  ///   之職責，兩者職責分明、互不替代。
  ///
  /// - Important: 本型別**不**收錄單符號讀音（21 個聲母、16 個韻母）。單符號之合法性是
  ///   **辭典之事實**、不是**音節表之事實**：原廠辭典確實收錄了這些單符號詞條，但其中 14 個
  ///   聲母（`ㄅ ㄆ ㄇ ㄈ ㄉ ㄊ ㄋ ㄌ ㄍ ㄎ ㄏ ㄐ ㄑ ㄒ`）並非獨立音節，只是各自一族之嚴格前綴。
  ///   故 `isComplete("ㄍ") == false` 而 `isPrefix("ㄍ") == true`。把單符號硬塞進來會使
  ///   「426」這個可稽核數字失去意義，並讓「可否提交」之判斷誤用 `isComplete`。
  ///
  /// - Important: **排列中立**。注音是排列中立之表記，故 426 條詞幹對所有 `MandarinParser`
  ///   皆相同，今日全部排列共用同一份索引。`shared(parser:)` 之 `parser` 參數為**未來之
  ///   擴充位**——若某排列真有專屬之讀音集，屆時只需改本型別之建構，不必改簽名。
  ///
  /// 用法：
  /// ```swift
  /// let index = Tekkon.SyllableIndex.shared(parser: .ofDachen)
  /// index.isPrefix("ㄍ")      // true —— 還能延伸成 ㄍㄚ、ㄍㄜ…
  /// index.isPrefix("ㄍㄋ")    // false —— 不可能再延伸
  /// index.isComplete("ㄍ")    // false —— ㄍ 非獨立音節
  /// index.isComplete("ㄍㄚ")  // true
  /// ```
  public struct SyllableIndex: Sendable {
    // MARK: Lifecycle

    private init(parser: MandarinParser) {
      self.parser = parser
      let stems = Self.canonicalReadings
      self.readings = stems
      self.completeSet = Set(stems)
      var prefixes: Set<String> = []
      prefixes.reserveCapacity(stems.count * 2)
      for stem in stems {
        for length in 1 ... stem.count {
          prefixes.insert(String(stem.prefix(length)))
        }
      }
      self.prefixSet = prefixes
    }

    // MARK: Public

    /// 全部完整讀音（426 條；升冪）。
    ///
    /// 此即**排列中立之正本**，亦是 `readings` 之來源。供測試與防漂移比對。
    public static var allReadings: [String] { canonicalReadings }

    /// 本索引持有之完整讀音（升冪）。今日恆等於 `Self.allReadings`。
    public let readings: [String]

    /// 取得共用之索引。
    ///
    /// 快取範式與 `Tekkon.PinyinTrie.shared(parser:)` 一致：`NSLock` ＋
    /// `nonisolated(unsafe) private static var`（`Tekkon` 靶不受
    /// `defaultIsolation(MainActor.self)` 規範，故此處為 SE-0412 意義下之全域可變共享狀態，
    /// 必須明示其同步責任在本型別之 `sharedCacheLock`）。
    ///
    /// - Parameter parser: 本索引被要求服務之排列。今日不影響內容（見型別說明）。
    public static func shared(parser: MandarinParser) -> Self {
      sharedCacheLock.lock()
      defer { sharedCacheLock.unlock() }
      if let cached = sharedCache {
        return cached
      }
      let created = Self(parser: parser)
      sharedCache = created
      return created
    }

    /// 清除共用快取。供測試使用。
    public static func clearSharedCache() {
      sharedCacheLock.lock()
      sharedCache = nil
      sharedCacheLock.unlock()
    }

    /// 該字串是否為某合法讀音之**完整**形式。
    ///
    /// - Warning: **不得**以本函式當作「當前注拼槽可否提交」之依據。單聲母／單韻母乃原廠
    ///   辭典之合法詞條，若以 `isComplete` 為閘則單聲母縮寫打法全滅。「可否提交」之依據是
    ///   呼叫端之切音節判準（見 `Research/Phase250-ResearchAndNextSurgeryPlan.md` §3.2）。
    public func isComplete(_ reading: String) -> Bool {
      completeSet.contains(reading)
    }

    /// 該字串是否為某合法讀音之**非空**前綴（含其本身即完整者）。空字串恆為 `false`。
    public func isPrefix(_ reading: String) -> Bool {
      prefixSet.contains(reading)
    }

    // MARK: Internal

    /// 以該字串為前綴之全部完整讀音（升冪，內容穩定）。
    ///
    /// 以 `allReadings.filter { $0.hasPrefix(prefix) }` 實作——426 條線性掃描，**非熱路徑**
    /// （只在前綴不完整時才需列舉）。
    ///
    /// - Note: 對外暫緩公開（`internal`）。目前之生產端消費者（自動切音節判準）只用
    ///   `isPrefix`，故不預先承諾此 API 之形狀；待真有消費者時再升為 `public`。
    func completions(of prefix: String) -> [String] {
      readings.filter { $0.hasPrefix(prefix) }
    }

    // MARK: Private

    private static let sharedCacheLock = NSLock()
    // `Tekkon` 靶不受 `defaultIsolation(MainActor.self)` 規範，故此處為 SE-0412 意義下的
    // 全域可變共享狀態：必須以 `nonisolated(unsafe)` 明示其同步責任在本型別的 `sharedCacheLock`。
    nonisolated(unsafe) private static var sharedCache: Self?

    /// 讀音詞幹之唯一來源：`mapHanyuPinyin` 之 value（注音），去重後升冪。
    ///
    /// 之所以以它為正本：它是引擎既有之權威表，`MandarinParser.allPossibleReadings` 亦以它
    /// 為注音側之來源。實測：動態排列測試資料之 422 條無調詞幹中，**421 條**為本表之成員，
    /// 餘下 1 條為 `ㄑ`——該表收錄它是因為五個動態排列皆能將它編成單鍵，且原廠辭典確有
    /// `ㄑ` 這個單符號詞條；惟它並非漢語音節，故**不在**本表之內。此即本型別之職責邊界
    /// （音節表 vs 辭典）在資料上之現形。
    private static var canonicalReadings: [String] {
      Array(Set(Tekkon.mapHanyuPinyin.values)).sorted()
    }

    /// 本索引被要求服務之排列（診斷用；今日不影響內容）。
    private let parser: MandarinParser

    private let completeSet: Set<String>
    private let prefixSet: Set<String>
  }
}
