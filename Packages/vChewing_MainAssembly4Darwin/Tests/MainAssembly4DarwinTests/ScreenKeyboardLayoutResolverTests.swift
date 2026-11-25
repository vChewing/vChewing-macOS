// (c) 2026 and onwards The vChewing Project (MulanPSL-2.0 License).
// ====================
// This code is released under the SPDX-License-Identifier: `MulanPSL-2.0`.

import Foundation
import Shared
import Testing

@testable import MainAssembly4Darwin

// MARK: - ScreenKeyboardLayoutResolverTests

/// 護欄：排列 → 螢幕鍵盤佈局之對位（P364）。
///
/// 「直接設定」之按鈕一向是「設排列 ＋ 設佈局」一起做；三支排列下拉若只設排列，
/// 客體之鍵盤佈局仍停在舊值——`activateServer` 之覆寫因此永遠送出舊的 Ukelele 佈局。
@Suite(.serialized)
final class ScreenKeyboardLayoutResolverTests {
  @Test
  func standardAndEtenPreferTheAppleLayouts() {
    #expect(
      UserDef.screenKeyboardLayoutCandidates(for: .ofStandard)
        == ["com.apple.keylayout.ZhuyinBopomofo"]
    )
    // 倚天：唯音自帶者優先，Apple 之 `ZhuyinEten` 作最後後備（它係 TCIM 之私有佈局）。
    let eten = UserDef.screenKeyboardLayoutCandidates(for: .ofETen)
    #expect(eten.first?.contains("vchewingeten") == true)
    #expect(eten.last == "com.apple.keylayout.ZhuyinEten")
  }

  @Test
  func bundledArrangementsCarryBothIdentifierShapes() {
    for parser in [KeyboardParser.ofIBM, .ofMiTAC, .ofFakeSeigyou] {
      let candidates = UserDef.screenKeyboardLayoutCandidates(for: parser)
      #expect(candidates.count == 2)
      #expect(candidates[0].hasPrefix("org.atelierInmu.vChewing.keyLayouts."))
      #expect(candidates[1].hasPrefix("org.unknown.keylayout."))
    }
  }

  @Test
  func pinyinFamilyMapsToASCIICapableLayout() {
    for parser in [KeyboardParser.ofHanyuPinyin, .ofWadeGilesPinyin, .ofDualpinMSPY] {
      #expect(UserDef.screenKeyboardLayoutCandidates(for: parser) == ["com.apple.keylayout.ABC"])
    }
  }

  @Test
  func arrangementsWithoutAnyLayoutMapToNothing() {
    for parser in [KeyboardParser.ofSeigyou, .ofHsu, .ofStarlight, .ofAlvinLiu] {
      #expect(UserDef.screenKeyboardLayoutCandidates(for: parser).isEmpty)
    }
  }
}
