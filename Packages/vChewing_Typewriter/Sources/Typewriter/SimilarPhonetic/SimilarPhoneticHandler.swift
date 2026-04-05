// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import LangModelAssembly
import Shared

// MARK: - SimilarPhoneticHandler

/// 近音表建立器。給定一個注音讀音，查詢詞庫並產生排列好的 `[SimilarPhoneticRow]`。
public enum SimilarPhoneticHandler {

  /// 給定一個注音讀音（含聲調），建立排列好的近音表列陣列。
  ///
  /// 排列順序：
  /// 1. 精確音（原聲調）← 藍底，固定第一列
  /// 2. 精確音其他聲調（1→2→3→4→˙，跳過原聲調）
  /// 3. 近音韻母各聲調（1→2→3→4→˙）
  /// 4. 近音聲母各聲調（1→2→3→4→˙）
  ///
  /// 無候選字的讀音整列省略。
  ///
  /// - Parameters:
  ///   - phonetic: 原始注音讀音（如 "ㄘㄢ"、"ㄇㄡˊ"）。
  ///   - lm: 詞庫查詢物件。
  /// - Returns: 排列好的近音表列，第一列為藍底列（原聲調）。若詞庫查不到任何候選則返回空陣列。
  public static func buildRows(
    for phonetic: String,
    lm: LMAssembly.LMInstantiator
  ) -> [SimilarPhoneticRow] {
    let (base, _) = SimilarPhoneticRules.splitTone(phonetic)

    // Step 1: 精確音各聲調（原聲調先、其餘依序）
    var orderedReadings: [String] = SimilarPhoneticRules.allReadings(of: phonetic)

    // Step 2: 近音韻母各聲調
    if let nearVowelBase = SimilarPhoneticRules.nearVowelBase(for: base) {
      orderedReadings += SimilarPhoneticRules.allToneMarkers.map { nearVowelBase + $0 }
    }

    // Step 3: 近音聲母各聲調
    if let nearConsonantBase = SimilarPhoneticRules.nearConsonantBase(for: base) {
      orderedReadings += SimilarPhoneticRules.allToneMarkers.map { nearConsonantBase + $0 }
    }

    // Step 4: 查詢詞庫，過濾空列，組成結果
    var rows: [SimilarPhoneticRow] = []
    var seenPhonetics: Set<String> = []
    for reading in orderedReadings {
      guard !seenPhonetics.contains(reading) else { continue }
      seenPhonetics.insert(reading)
      let candidates = lm.unigramsFor(keyArray: [reading]).map(\.value)
      guard !candidates.isEmpty else { continue }
      rows.append(SimilarPhoneticRow(phonetic: reading, candidates: candidates))
    }

    return rows
  }
}
