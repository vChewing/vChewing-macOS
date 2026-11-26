// (c) 2026 and onwards The vChewing Project (MulanPSL-2.0 License).
// ====================
// This code is released under the SPDX-License-Identifier: `MulanPSL-2.0`.

import Foundation
import IMKUtils
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
    // 客體在重開機（重新登入）前會把私有 ID 退回 ABC，故候選暫以 Apple 與鬆散檔推導者為主。
    let dachen = UserDef.screenKeyboardLayoutCandidates(for: .ofStandard)
    #expect(dachen.first == "com.apple.keylayout.ZhuyinBopomofo")
    #expect(!dachen.contains { $0.hasPrefix(IMKHelper.inputMethodBundleIdentifier + ".keylayout.") })
    // 倚天：Apple 之 `ZhuyinEten` 優先（客體認得），鬆散檔推導者作後備。
    let eten = UserDef.screenKeyboardLayoutCandidates(for: .ofETen)
    #expect(eten.first == "com.apple.keylayout.ZhuyinEten")
    #expect(eten.last == "org.unknown.keylayout.vChewingETen")
  }

  @Test
  func bundledArrangementsCarryBothIdentifierShapes() {
    for parser in [KeyboardParser.ofIBM, .ofMiTAC, .ofFakeSeigyou] {
      let candidates = UserDef.screenKeyboardLayoutCandidates(for: parser)
      #expect(candidates.count == 1)
      #expect(candidates[0].hasPrefix("org.unknown.keylayout."))
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
    for parser in [KeyboardParser.ofHsu, .ofStarlight, .ofAlvinLiu] {
      #expect(UserDef.screenKeyboardLayoutCandidates(for: parser).isEmpty)
    }
  }

  @Test
  func seigyouMapsToItsOwnLayout() {
    // P365：精業自偽精業之小改款獨立成第六份佈局。
    #expect(
      UserDef.screenKeyboardLayoutCandidates(for: .ofSeigyou)
        == ["org.unknown.keylayout.vChewingSeigyou"]
    )
  }

  @Test
  func onlyMistakenPrivateIdentifiersAreRepaired() {
    let prefix = IMKHelper.inputMethodBundleIdentifier + ".keylayout."
    // 誤寫入之私有 ID → 映回鬆散檔推導者（客體認得）。
    #expect(
      IMKHelper.migratedBasicKeyboardLayoutIdentifier(prefix + "vChewingMiTAC")
        == "org.unknown.keylayout.vChewingMiTAC"
    )
    // 其餘值一律原樣——**不得**把既有的舊識別碼改寫成私有 ID。
    for value in [
      "org.unknown.keylayout.vChewingETen",
      "org.atelierInmu.vChewing.keyLayouts.vchewingibm",
      "com.apple.keylayout.ZhuyinBopomofo",
      "whatever",
    ] {
      #expect(IMKHelper.migratedBasicKeyboardLayoutIdentifier(value) == value)
    }
  }

  @Test
  func privateIdentifiersStayOutOfTheWhitelist() {
    // 私有佈局在同一登入內客體解析不了（退回 ABC，跨登入後方可用），故暫不收進選單值域。
    let bundled = IMKHelper.bundledKeyLayoutIdentifiers
    #expect(bundled.count == 6)
    #expect(Set(bundled).isDisjoint(with: Set(IMKHelper.arrDynamicBasicKeyLayouts)))
  }
}
