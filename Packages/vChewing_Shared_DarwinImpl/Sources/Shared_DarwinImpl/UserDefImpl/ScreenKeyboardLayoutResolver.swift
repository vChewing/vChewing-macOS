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
  /// - Note: 唯音自帶之六個 Ukelele 佈局有兩種識別碼形制：同綑之私有佈局
  ///   （`<bundleID>.keylayout.*`，跨一次登入週期後方對客體可見）與鬆散檔推導者
  ///   （`org.unknown.*`）。目前候選只收後者，理由見下表首條註。
  public static func screenKeyboardLayoutCandidates(for parser: KeyboardParser) -> [String] {
    // - Important: 候選只收「此刻對客體可見」者：Apple 之佈局，與鬆散檔推導之
    //   `org.unknown.*`。同綑之私有佈局（`<bundleID>.keylayout.*`）雖自 P365 起隨 app 出貨，
    //   但其登記須**跨一次登入週期**才對其他行程可見；在此之前客體查無此 ID、遂退回 ABC
    //   （實測 2026-11-26）。待切換時機有配套（例如提示使用者重啟）再改收私有 ID。
    switch parser {
    case .ofDachen26, .ofStandard:
      return [
        "com.apple.keylayout.ZhuyinBopomofo",
        "org.unknown.keylayout.vChewingDachen",
      ]
    case .ofETen, .ofETen26:
      return [
        "com.apple.keylayout.ZhuyinEten",
        "org.unknown.keylayout.vChewingETen",
      ]
    case .ofIBM:
      return [
        "org.unknown.keylayout.vChewingIBM",
      ]
    case .ofMiTAC:
      return [
        "org.unknown.keylayout.vChewingMiTAC",
      ]
    case .ofSeigyou:
      // 精業自本版起有專屬佈局（偽精業之小改款：介母與ㄦ共四鍵不同）。
      return [
        "org.unknown.keylayout.vChewingSeigyou",
      ]
    case .ofFakeSeigyou:
      return [
        "org.unknown.keylayout.vChewingFakeSeigyou",
      ]
    case .ofDualpinCustom, .ofDualpinGBT17, .ofDualpinMSPY, .ofHanyuPinyin,
         .ofHualuoPinyin, .ofSecondaryPinyin,
         .ofUniversalPinyin, .ofWadeGilesPinyin, .ofYalePinyin:
      return ["com.apple.keylayout.ABC"]
    // 許氏／星光／劉氏無對位之 Ukelele 佈局。
    case .ofAlvinLiu, .ofHsu, .ofStarlight:
      return []
    }
  }

  /// 於當前環境解析出可用之佈局識別碼。
  ///
  /// - Note: 私有佈局在同一登入內雖已見於 TIS，客體仍可能解析不了（退回 ABC），須跨一次登入
  ///   週期方可用——故本解析**不得**只憑「本行程看得到」就認定立即生效。
  /// 於當前環境解析出可用的佈局識別碼；無對應、或候選皆未安裝時回 `nil`（呼叫端即不動原值）。
  public static func resolvedScreenKeyboardLayout(for parser: KeyboardParser) -> String? {
    let available = Set(IMKHelper.allowedBasicLayoutsAsTISInputSources.compactMap { $0?.id })
    guard !available.isEmpty else { return nil }
    return screenKeyboardLayoutCandidates(for: parser).first { available.contains($0) }
  }
}
