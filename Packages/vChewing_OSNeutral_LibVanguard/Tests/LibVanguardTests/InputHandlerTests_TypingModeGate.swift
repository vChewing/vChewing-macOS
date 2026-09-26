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
  /// 但該值一旦被手工觸及，其「前方待確認讀音」閘門**與拼音側同構**（P256 交付）——
  /// 注拼槽內有未完成音節即成立。
  @Test("[IH704] 注音狂打之出廠不可達性與前方待確認讀音閘門")
  func test_IH704_ZhuyinFuriousIsUnreachableButPendingGateWorks() throws {
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
    // P256 已交付 `hasFuriousFrontPending` 之注音分支（P254 時此處尚為假，其反轉即
    // P256 之交付內容）：注拼槽內有未完成音節 ⇒ 前方待確認讀音成立、顯示源即該音節。
    testHandler.composer.receiveKey(fromString: "1") // ㄅ
    #expect(testHandler.hasFuriousFrontPending)
    #expect(testHandler.furiousFrontUnfinishedReading == "ㄅ")
    testHandler.prefs.furiousTypingEnabled4Zhuyin = false
  }

  /// 打字方式熱鍵之效果須在**下一拍按鍵**即反映進語言模組之注音文抑制旗標。
  ///
  /// 熱鍵之動作即 `PrefMgr.shared.pinyinTypingEnabled.toggle()` ＋ `ensureKeyboardParser()`
  /// （`IMEMenuSputnik`）；而 `syncPrefs()` 於**每一次分診之頂端**執行
  /// （`InputHandler_TriageInput.swift`）⇒「切換後之下一拍」即「下一次 `triageInput`」。
  /// 本靶以真實之分診釘住該語義：切換與分診之間旗標**必須仍是舊值**（證明它由分診頂端
  /// 刷新、而非偏好之寫入即時連動），分診之後**必須已跟上**。
  ///
  /// 測資令兩側狂打開關**相反**，故旗標必然隨熱鍵反向翻轉——若實作誤認「當前打字方式」
  /// 或只看拼音側，本靶即轉紅。
  @Test("[IH705] 打字方式熱鍵於下一拍即反映進注音文抑制旗標")
  func test_IH705_TypingModeHotKeyReflectsOnNextBeat() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    let saved = (
      pinyin: testHandler.prefs.pinyinTypingEnabled,
      furious4Pinyin: testHandler.prefs.furiousTypingEnabled4Pinyin,
      furious4Zhuyin: testHandler.prefs.furiousTypingEnabled4Zhuyin
    )
    defer {
      testHandler.prefs.pinyinTypingEnabled = saved.pinyin
      testHandler.prefs.furiousTypingEnabled4Pinyin = saved.furious4Pinyin
      testHandler.prefs.furiousTypingEnabled4Zhuyin = saved.furious4Zhuyin
      testHandler.currentLM.syncPrefs()
      testSession.resetInputHandler(forceComposerCleanup: true)
    }
    testHandler.prefs.cassetteEnabled = false
    testHandler.prefs.useSCPCTypingMode = false
    // 拼音側狂打關、注音側狂打開 ⇒ 抑制旗標隨「當前打字方式」反向。
    testHandler.prefs.furiousTypingEnabled4Pinyin = false
    testHandler.prefs.furiousTypingEnabled4Zhuyin = true

    testHandler.prefs.pinyinTypingEnabled = true
    testHandler.currentLM.syncPrefs() // 起點：拼音側狂打關 ⇒ 不抑制。
    #expect(!testHandler.currentLM.config.shouldSuppressFactoryZhuyinwenData)

    // 熱鍵：切換打字方式，不動兩顆鍵盤排列槽。
    testHandler.prefs.pinyinTypingEnabled.toggle()
    #expect(!testHandler.prefs.pinyinTypingEnabled)
    // 尚未分診 ⇒ 旗標仍為舊值（本行即「由分診頂端刷新」之釘子）。
    #expect(!testHandler.currentLM.config.shouldSuppressFactoryZhuyinwenData)

    // 下一拍：任一按鍵之分診即令旗標跟上（注音側狂打開 ⇒ 抑制）。
    _ = testHandler.triageInput(event: KBEvent.KeyEventData(chars: "e").asEvent)
    #expect(testHandler.currentLM.config.shouldSuppressFactoryZhuyinwenData)

    // 反向再切一次：同一拍內即回復。
    testHandler.prefs.pinyinTypingEnabled.toggle()
    _ = testHandler.triageInput(event: KBEvent.KeyEventData(chars: "e").asEvent)
    #expect(!testHandler.currentLM.config.shouldSuppressFactoryZhuyinwenData)
  }

  /// 逐字選字（SCPC）與磁帶模式下**不啟用狂打特性**——本靶驗其中一項：
  /// 拼音連打之自動切音節須於 SCPC 下停用（注音側之孿生函式由狂打閘門把守；
  /// 拼音側因歷史緣故無閘門，此即該閘之固化物）。磁帶不經本型別
  /// （`handleComposition` 之打字模式分派：`.cassette` → `CassetteTypewriter`），
  /// 故無從在同一個靶內驅動，僅以註解記之。
  @Test("[IH706] SCPC 下拼音不自動切音節")
  func test_IH706_SCPCDisablesPinyinAutoChop() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler and testSession at least one of them is nil.")
      return
    }
    let savedParser = testHandler.prefs.keyboardParser
    let savedFurious4Pinyin = testHandler.prefs.furiousTypingEnabled4Pinyin
    defer {
      testHandler.prefs.useSCPCTypingMode = false
      testHandler.prefs.keyboardParser = savedParser
      testHandler.prefs.furiousTypingEnabled4Pinyin = savedFurious4Pinyin
      testHandler.ensureKeyboardParser()
      testSession.resetInputHandler(forceComposerCleanup: true)
    }
    testHandler.prefs.cassetteEnabled = false
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.ensureKeyboardParser()
    testHandler.prefs.furiousTypingEnabled4Pinyin = true

    // ① 對照組：SCPC 關 ⇒ 自動切音節照常（`gao` 不可能延伸為 `gaol` ⇒ 切出 `ㄍㄠ`、
    //    尾段字母留在注拼槽）。
    testHandler.prefs.useSCPCTypingMode = false
    testHandler.currentLM.syncPrefs()
    testSession.resetInputHandler(forceComposerCleanup: true)
    typeSentence("gaol")
    #expect(testHandler.assembler.actualKeys == ["ㄍㄠ"], "實得：\(testHandler.assembler.actualKeys)")
    #expect(testHandler.composer.romajiBuffer == "l", "實得：\(testHandler.composer.romajiBuffer)")

    // ② 實驗組：SCPC 開 ⇒ 不切，整段留在注拼槽（狂打特性不生效）。
    testHandler.prefs.useSCPCTypingMode = true
    testHandler.currentLM.syncPrefs()
    testSession.resetInputHandler(forceComposerCleanup: true)
    #expect(testHandler.typingMode == .pinyinKeyblock)
    typeSentence("gaol")
    #expect(testHandler.assembler.actualKeys.isEmpty, "實得：\(testHandler.assembler.actualKeys)")
    #expect(testHandler.composer.romajiBuffer == "gaol", "實得：\(testHandler.composer.romajiBuffer)")
  }
}
