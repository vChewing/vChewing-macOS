// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

// 打字模式閘門層之測試（`typingMode` 之真值表 ＋ 兩顆狂打閘門之家族歸屬）。
//
// 本檔只驗「閘門」，不驗任何狂打行為——後者見 `InputHandlerTests_Cases1.swift` 之
// IH155 以降。此處之四支測試即「本 phase 之行為變動為零」之主要證據：
// ① 五值真值表（含新值之可達條件）；② `isPinyinFamilyTypingMode` 於注音側**仍為假**；
// ③ 兩顆閘門之家族歸屬（拼音專屬 vs 通用）；④ 注音側新偏好之出廠預設為 `false`。

import Foundation
import Shared
import Tekkon
import Testing

@testable import LibVanguard

extension LibVanguardTestsRoot.InputHandlerTests {
  /// 逐格走 `typingMode` 之真值表。
  ///
  /// 維度：注拼槽之鍵盤家族（拼音／注音）× 兩顆狂打開關（各 2）× 逐字選字（2）× 磁帶（2）。
  /// 磁帶優先於一切，故磁帶為真時其餘維度皆無關。
  @Test("[IH701] TypingMode 真值表")
  func test_IH701_TypingModeTruthTable() throws {
    guard let testHandler else {
      Issue.record("testHandler 為 nil。")
      return
    }
    let saved = (
      cassette: testHandler.prefs.cassetteEnabled,
      scpc: testHandler.prefs.useSCPCTypingMode,
      pinyin: testHandler.prefs.furiousTypingEnabled4Pinyin,
      zhuyin: testHandler.prefs.furiousTypingEnabled4Zhuyin
    )
    defer {
      testHandler.prefs.cassetteEnabled = saved.cassette
      testHandler.prefs.useSCPCTypingMode = saved.scpc
      testHandler.prefs.furiousTypingEnabled4Pinyin = saved.pinyin
      testHandler.prefs.furiousTypingEnabled4Zhuyin = saved.zhuyin
    }

    for isPinyinComposer in [true, false] {
      testHandler.composer.ensureParser(arrange: isPinyinComposer ? .ofHanyuPinyin : .ofDachen)
      for pinyinFurious in [true, false] {
        for zhuyinFurious in [true, false] {
          for scpc in [true, false] {
            for cassette in [true, false] {
              testHandler.prefs.cassetteEnabled = cassette
              testHandler.prefs.useSCPCTypingMode = scpc
              testHandler.prefs.furiousTypingEnabled4Pinyin = pinyinFurious
              testHandler.prefs.furiousTypingEnabled4Zhuyin = zhuyinFurious

              let expected: TypingMode = if cassette {
                .cassette
              } else if isPinyinComposer {
                (pinyinFurious && !scpc) ? .pinyinFuriousTyping : .pinyinKeyblock
              } else {
                (zhuyinFurious && !scpc) ? .zhuyinFuriousTyping : .bopomofoKeyblock
              }
              let context = "pinyinComposer=\(isPinyinComposer) 4P=\(pinyinFurious) "
                + "4Z=\(zhuyinFurious) scpc=\(scpc) cassette=\(cassette)"
              #expect(testHandler.typingMode == expected, "\(context)")
            }
          }
        }
      }
    }
  }

  /// **紅線之固化物**：`isPinyinFamilyTypingMode` 之語意恆為「注拼槽是否為拼音」，
  /// **不因狂打開關而變**。此為鍵盤佈局翻譯之守衛——一破即注音完全打不出字。
  @Test("[IH702] isPinyinFamilyTypingMode 於注音側恆為假（含狂注開啟時）")
  func test_IH702_IsPinyinFamilyTypingModeStaysFalseForZhuyin() throws {
    guard let testHandler else {
      Issue.record("testHandler 為 nil。")
      return
    }
    let saved = (
      cassette: testHandler.prefs.cassetteEnabled,
      scpc: testHandler.prefs.useSCPCTypingMode,
      pinyin: testHandler.prefs.furiousTypingEnabled4Pinyin,
      zhuyin: testHandler.prefs.furiousTypingEnabled4Zhuyin
    )
    defer {
      testHandler.prefs.cassetteEnabled = saved.cassette
      testHandler.prefs.useSCPCTypingMode = saved.scpc
      testHandler.prefs.furiousTypingEnabled4Pinyin = saved.pinyin
      testHandler.prefs.furiousTypingEnabled4Zhuyin = saved.zhuyin
    }
    testHandler.prefs.cassetteEnabled = false
    testHandler.prefs.useSCPCTypingMode = false

    // 注音排列：無論狂注開關為何，皆不得被判為拼音系。
    testHandler.composer.ensureParser(arrange: .ofDachen)
    for zhuyinFurious in [true, false] {
      testHandler.prefs.furiousTypingEnabled4Zhuyin = zhuyinFurious
      testHandler.prefs.furiousTypingEnabled4Pinyin = true // 對照：拼音側開著也不得影響
      #expect(!testHandler.isPinyinFamilyTypingMode, "zhuyinFurious=\(zhuyinFurious)")
      #expect(testHandler.isFuriousTypingModeEffective == zhuyinFurious)
    }

    // 拼音排列：恆為真。
    testHandler.composer.ensureParser(arrange: .ofHanyuPinyin)
    for pinyinFurious in [true, false] {
      testHandler.prefs.furiousTypingEnabled4Pinyin = pinyinFurious
      #expect(testHandler.isPinyinFamilyTypingMode, "pinyinFurious=\(pinyinFurious)")
    }
  }

  /// 兩顆閘門之家族歸屬：`isPinyinFuriousTypingModeEffective` 必須**拼音專屬**。
  @Test("[IH703] 兩顆閘門之家族歸屬")
  func test_IH703_GateFamilyMembership() throws {
    guard let testHandler else {
      Issue.record("testHandler 為 nil。")
      return
    }
    let saved = (
      cassette: testHandler.prefs.cassetteEnabled,
      scpc: testHandler.prefs.useSCPCTypingMode,
      pinyin: testHandler.prefs.furiousTypingEnabled4Pinyin,
      zhuyin: testHandler.prefs.furiousTypingEnabled4Zhuyin
    )
    defer {
      testHandler.prefs.cassetteEnabled = saved.cassette
      testHandler.prefs.useSCPCTypingMode = saved.scpc
      testHandler.prefs.furiousTypingEnabled4Pinyin = saved.pinyin
      testHandler.prefs.furiousTypingEnabled4Zhuyin = saved.zhuyin
    }
    testHandler.prefs.cassetteEnabled = false
    testHandler.prefs.useSCPCTypingMode = false

    // 拼音狂打：兩顆皆真。
    testHandler.composer.ensureParser(arrange: .ofHanyuPinyin)
    testHandler.prefs.furiousTypingEnabled4Pinyin = true
    testHandler.prefs.furiousTypingEnabled4Zhuyin = false
    #expect(testHandler.isFuriousTypingModeEffective)
    #expect(testHandler.isPinyinFuriousTypingModeEffective)

    // 注音狂打：通用閘門為真、**拼音專屬閘門為假**。
    testHandler.composer.ensureParser(arrange: .ofDachen)
    testHandler.prefs.furiousTypingEnabled4Pinyin = false
    testHandler.prefs.furiousTypingEnabled4Zhuyin = true
    #expect(testHandler.isFuriousTypingModeEffective)
    #expect(!testHandler.isPinyinFuriousTypingModeEffective)

    // 兩側皆關：兩顆皆假。
    testHandler.prefs.furiousTypingEnabled4Zhuyin = false
    #expect(!testHandler.isFuriousTypingModeEffective)
    #expect(!testHandler.isPinyinFuriousTypingModeEffective)

    // 非注音組字之打字方法：通用閘門為假（與 `currentTypingMethod` 之閘）。
    testHandler.prefs.furiousTypingEnabled4Zhuyin = true
    testHandler.currentTypingMethod = .codePoint
    #expect(!testHandler.isFuriousTypingModeEffective)
    #expect(!testHandler.isPinyinFuriousTypingModeEffective)
    testHandler.currentTypingMethod = .vChewingFactory
  }

  /// 注音側新偏好之出廠預設為 `false` ⇒ `zhuyinFuriousTyping` 於正式情境不可達；
  /// 且 `hasFuriousFrontPending` 於注音側**仍為假**（P254 未動它——見 P256）。
  @Test("[IH704] 注音狂打之出廠不可達性與 hasFuriousFrontPending 之現狀")
  func test_IH704_ZhuyinFuriousIsUnreachableAndPendingStaysFalse() throws {
    guard let testHandler else {
      Issue.record("testHandler 為 nil。")
      return
    }
    let saved = (
      cassette: testHandler.prefs.cassetteEnabled,
      scpc: testHandler.prefs.useSCPCTypingMode,
      pinyin: testHandler.prefs.furiousTypingEnabled4Pinyin,
      zhuyin: testHandler.prefs.furiousTypingEnabled4Zhuyin
    )
    defer {
      testHandler.prefs.cassetteEnabled = saved.cassette
      testHandler.prefs.useSCPCTypingMode = saved.scpc
      testHandler.prefs.furiousTypingEnabled4Pinyin = saved.pinyin
      testHandler.prefs.furiousTypingEnabled4Zhuyin = saved.zhuyin
      testHandler.composer.clear()
    }
    // 出廠預設：`UserDef.kFuriousTypingEnabled4Zhuyin.dataType == .bool(false)`。
    if case let .bool(defaultValue) = UserDef.kFuriousTypingEnabled4Zhuyin.dataType {
      #expect(!defaultValue)
    } else {
      Issue.record("kFuriousTypingEnabled4Zhuyin 之 dataType 非 .bool。")
    }

    testHandler.prefs.cassetteEnabled = false
    testHandler.prefs.useSCPCTypingMode = false
    testHandler.composer.ensureParser(arrange: .ofDachen)
    testHandler.prefs.furiousTypingEnabled4Pinyin = false
    testHandler.prefs.furiousTypingEnabled4Zhuyin = false
    // 出廠狀態下仍為注音鍵盤模式。
    #expect(testHandler.typingMode == .bopomofoKeyblock)

    // 手動開啟注音狂打（正式情境下唯一之觸及途徑：手改 defaults 或匯入配置包）：
    // `typingMode` 確實會回傳新值——此為**已知界線**，以斷言釘住而非隱藏。
    testHandler.prefs.furiousTypingEnabled4Zhuyin = true
    #expect(testHandler.typingMode == .zhuyinFuriousTyping)
    // 惟 P254 尚未動 `hasFuriousFrontPending`（其注音分支屬 P256）⇒ 仍為假。
    testHandler.composer.receiveKey(fromString: "1") // ㄅ
    #expect(!testHandler.hasFuriousFrontPending)
    testHandler.prefs.furiousTypingEnabled4Zhuyin = false
  }
}
