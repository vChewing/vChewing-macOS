// (c) 2026 and onwards The vChewing Project (MulanPSL-2.0 License).
// ====================
// This code is released under the SPDX-License-Identifier: `MulanPSL-2.0`.

import Foundation
import IMKUtils
import Shared
import SwiftExtension

// MARK: - 排列 → 螢幕鍵盤佈局

extension UserDef {
  /// 注音／拼音排列所對應之螢幕鍵盤佈局（TIS 識別碼之候選，依偏好序）。
  ///
  /// 「直接設定」之按鈕一向是「設排列 ＋ 設佈局」兩件事一起做（大千 ⇒ `ZhuyinBopomofo`、
  /// 倚天 ⇒ `ZhuyinEten`），故選排列時亦須把客體之鍵盤佈局一併帶上——那才是螢幕鍵盤／
  /// 客體鍵位所見者（`InputSession.setKeyLayout()` 之唯一出口）。P364。
  ///
  /// - Note: 唯音自帶之五個 Ukelele 佈局可能以「佈局 bundle 所宣告之識別碼」或「鬆散檔
  ///   所推導之 `org.unknown.*` 識別碼」其一現身，故各給兩案、由呼叫端探測。
  public static func screenKeyboardLayoutCandidates(for parser: KeyboardParser) -> [String] {
    switch parser {
    case .ofDachen26, .ofStandard:
      return ["com.apple.keylayout.ZhuyinBopomofo"]
    case .ofETen, .ofETen26:
      return [
        "org.atelierInmu.vChewing.keyLayouts.vchewingeten",
        "org.unknown.keylayout.vChewingETen",
        "com.apple.keylayout.ZhuyinEten",
      ]
    case .ofIBM:
      return [
        "org.atelierInmu.vChewing.keyLayouts.vchewingibm",
        "org.unknown.keylayout.vChewingIBM",
      ]
    case .ofMiTAC:
      return [
        "org.atelierInmu.vChewing.keyLayouts.vchewingmitac",
        "org.unknown.keylayout.vChewingMiTAC",
      ]
    case .ofFakeSeigyou:
      return [
        "org.atelierInmu.vChewing.keyLayouts.vchewingfakeseigyou",
        "org.unknown.keylayout.vChewingFakeSeigyou",
      ]
    case .ofDualpinCustom, .ofDualpinGBT17, .ofDualpinMSPY, .ofHanyuPinyin,
         .ofHualuoPinyin, .ofSecondaryPinyin,
         .ofUniversalPinyin, .ofWadeGilesPinyin, .ofYalePinyin:
      return ["com.apple.keylayout.ABC"]
    // 精業（`ofSeigyou`）不提供螢幕鍵盤支援；許氏／星光／劉氏亦無對位之 Ukelele 佈局。
    case .ofAlvinLiu, .ofHsu, .ofSeigyou, .ofStarlight:
      return []
    }
  }

  /// 於當前環境解析出可用的佈局識別碼；無對應、或候選皆未安裝時回 `nil`（呼叫端即不動原值）。
  public static func resolvedScreenKeyboardLayout(for parser: KeyboardParser) -> String? {
    let available = Set(IMKHelper.allowedBasicLayoutsAsTISInputSources.compactMap { $0?.id })
    guard !available.isEmpty else { return nil }
    return screenKeyboardLayoutCandidates(for: parser).first { available.contains($0) }
  }
}
