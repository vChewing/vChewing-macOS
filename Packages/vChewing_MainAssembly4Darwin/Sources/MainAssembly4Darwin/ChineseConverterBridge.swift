// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation

extension ChineseConverter {
  // MARK: Public

  private static let hotenkaSingleton: HotenkaChineseConverter? = {
    guard let path = LMMgr.getBundleDataPath("convdict", ext: "stringmap") else { return nil }
    return try? HotenkaChineseConverter(stringMapPath: path)
  }()

  /// CrossConvert.
  ///
  /// - Parameter string: Text in Original Script.
  /// - Returns: Text converted to Different Script.
  public static func crossConvert(_ string: String) -> String {
    switch IMEApp.currentInputMode {
    case .imeModeCHS:
      return hotenkaSingleton?.convert(string, to: .zhHantTW) ?? string
    case .imeModeCHT:
      return hotenkaSingleton?.convert(string, to: .zhHansCN) ?? string
    default:
      return string
    }
  }

  /// 針對磁帶模式的敲字內容做繁簡轉換操作。具體轉換結果受輸入法偏好設定所影響。
  /// - Parameter string: 轉換對象，會被直接修改。
  public static func cassetteConvert(_ string: inout String) {
    // 0 為不轉換，1 為全轉換，2 為僅轉簡，3 為僅轉繁。
    switch PrefMgr.shared.forceCassetteChineseConversion {
    case 1:
      switch IMEApp.currentInputMode {
      case .imeModeCHS: string = hotenkaSingleton?.convert(string, to: .zhHansCN) ?? string
      case .imeModeCHT: string = hotenkaSingleton?.convert(string, to: .zhHantTW) ?? string
      case .imeModeNULL: break
      }
    case 2: if IMEApp.currentInputMode == .imeModeCHS {
        string = hotenkaSingleton?.convert(string, to: .zhHansCN) ?? string
      }
    case 3: if IMEApp.currentInputMode == .imeModeCHT {
        string = hotenkaSingleton?.convert(string, to: .zhHantTW) ?? string
      }
    default: return
    }
  }

  public static func cnvTradToKangXi(_ strObj: String) -> String {
    hotenkaSingleton?.convert(strObj, to: .zhHantKX) ?? strObj
  }

  public static func cnvTradToJIS(_ strObj: String) -> String {
    // 該轉換是由康熙繁體轉換至日語當用漢字的，所以需要先跑一遍康熙轉換。
    let strObj = cnvTradToKangXi(strObj)
    var result = hotenkaSingleton?.convert(strObj, to: .zhHansJP) ?? strObj
    processKanjiRepeatSymbol(target: &result)
    return result
  }

  /// 影響繁簡轉換結果的 config 快照；任一項變動都會使對應快取條目失效。
  private struct KanjiConversionConfig: Equatable {
    static var current: Self {
      .init(
        cassetteEnabled: PrefMgr.shared.cassetteEnabled,
        forceCassetteChineseConversion: PrefMgr.shared.forceCassetteChineseConversion,
        inputMode: IMEApp.currentInputMode,
        chineseConversionEnabled: PrefMgr.shared.chineseConversionEnabled,
        shiftJISShinjitaiOutputEnabled: PrefMgr.shared.shiftJISShinjitaiOutputEnabled
      )
    }

    var cassetteEnabled: Bool
    var forceCassetteChineseConversion: Int
    var inputMode: Shared.InputMode
    var chineseConversionEnabled: Bool
    var shiftJISShinjitaiOutputEnabled: Bool
  }

  /// 繁簡轉換結果的快取（keyed by 原始字串），僅供 kanjiConversionIfRequired 使用。
  /// 每個條目帶 config 快照；快照一變即視為 miss 並覆寫。容量封頂 4096 筆，滿時整池清空。
  private static var kanjiConversionCache: [String: (result: String, config: KanjiConversionConfig)] = [:]
  private static let kanjiConversionCacheLock = NSLock()

  public static func kanjiConversionIfRequired(_ text: String) -> String {
    kanjiConversionCacheLock.withLock {
      let config = KanjiConversionConfig.current
      if let cached = kanjiConversionCache[text], cached.config == config {
        return cached.result
      }
      let result = performKanjiConversionIfRequired(text)
      if kanjiConversionCache.count >= 4_096 { kanjiConversionCache.removeAll() }
      kanjiConversionCache[text] = (result: result, config: config)
      return result
    }
  }

  private static func performKanjiConversionIfRequired(_ text: String) -> String {
    var text = text
    if PrefMgr.shared.cassetteEnabled { cassetteConvert(&text) }
    guard IMEApp.currentInputMode == .imeModeCHT else { return text }
    switch (
      PrefMgr.shared.chineseConversionEnabled,
      PrefMgr.shared.shiftJISShinjitaiOutputEnabled
    ) {
    case (false, true): return Self.cnvTradToJIS(text)
    case (true, false): return Self.cnvTradToKangXi(text)
    // 本來這兩個開關不該同時開啟的，但萬一被同時開啟了的話就這樣處理：
    case (true, true): return Self.cnvTradToJIS(text)
    case (false, false): return text
    }
  }
}
