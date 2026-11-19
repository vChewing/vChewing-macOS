// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Homa
import Shared

// MARK: - LXAssembly.FactoryPunctuation

extension LXAssembly {
  /// 原廠標點子語言模組。
  ///
  /// 與 `LXCoreEX` 等子模組並列：資料已自原廠辭典抽離，改由
  /// `Shared.PunctuationData` 載入，供 `LXFacade` 在一般查詢中合流。
  /// 其分數恆為 0；不對外掛載，也不參與使用者資料。
  public final class FactoryPunctuation: @unchecked Sendable {
    // MARK: Lifecycle

    public init(records: [PunctuationData.Record] = PunctuationData.records) {
      var base = [String: [Homa.Gram]]()
      var all = [String: [Homa.Gram]]()
      records.forEach { record in
        let baseGram = Homa.Gram(
          keyArray: [record.key],
          current: record.value,
          probability: record.score
        )
        base[record.key, default: []].append(baseGram)
        all[record.key, default: []].append(baseGram)
        // 與原廠 TextMap 管線一致：全形標點另補半形變體，分數略低於本體。
        let halfWidthValue = record.value.applyingTransformFW2HW(reverse: false)
        guard halfWidthValue != record.value else { return }
        all[record.key, default: []].append(
          Homa.Gram(
            keyArray: [record.key],
            current: halfWidthValue,
            probability: record.score - 0.0001
          )
        )
      }
      self.baseGramsByKey = base
      self.gramsByKey = all
    }

    // MARK: Public

    public static let shared = FactoryPunctuation()

    public var isEmpty: Bool { gramsByKey.isEmpty }

    public var keyCount: Int { gramsByKey.count }

    public func hasUnigramsFor(keyArray: [String]) -> Bool {
      guard keyArray.count == 1, let key = keyArray.first else { return false }
      return gramsByKey[key] != nil
    }

    public func unigramsFor(keyArray: [String]) -> [Homa.Gram] {
      guard keyArray.count == 1, let key = keyArray.first else { return [] }
      return gramsByKey[key] ?? []
    }

    /// 僅回傳資料檔原值，不含自動補出的半形變體。
    public func baseUnigramsFor(keyArray: [String]) -> [Homa.Gram] {
      guard keyArray.count == 1, let key = keyArray.first else { return [] }
      return baseGramsByKey[key] ?? []
    }

    // MARK: Private

    private let baseGramsByKey: [String: [Homa.Gram]]
    private let gramsByKey: [String: [Homa.Gram]]
  }
}
