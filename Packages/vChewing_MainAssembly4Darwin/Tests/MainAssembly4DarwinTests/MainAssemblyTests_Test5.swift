// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation
import Testing

@testable import MainAssembly4Darwin

extension MainAssemblyTests {
  /// 測試 CapsLock 中英切換場景下 performServerActivation 的快速路徑。
  ///
  /// 當副本已處於活動狀態、為當前副本、且 inputHandler 存在時，
  /// 重複呼叫 performServerActivation 不應重新建構 inputHandler。
  @Test
  func test501_ActivationFastPath_SkipsInitInputHandler() throws {
    // 確保 testSession 已初期化且處於活動狀態。
    #expect(testSession.isActivated)
    #expect(testSession.inputHandler != nil)

    // 將 testSession 設為 current（模擬正常啟用狀態）。
    InputSession.current = testSession

    // 記錄當前 inputHandler 的身份（使用 ObjectIdentifier）。
    let handlerBefore = testSession.inputHandler
    let identityBefore = ObjectIdentifier(handlerBefore!)

    // 模擬 CapsLock 切換回來：呼叫 performServerActivation。
    // 由於 isActivated == true、Self.current?.id == id、inputHandler != nil，
    // 應命中快速路徑，不會呼叫 initInputHandler()。
    testSession.performServerActivation()

    // 驗證 inputHandler 未被重新建構。
    let handlerAfter = testSession.inputHandler
    let identityAfter = ObjectIdentifier(handlerAfter!)
    #expect(
      identityBefore == identityAfter,
      "快速路徑不應重新建構 inputHandler，但 inputHandler 身份已變更。"
    )

    // 驗證副本仍處於活動狀態。
    #expect(testSession.isActivated)
    #expect(testSession.state.type == .ofEmpty)
  }

  /// 測試 performServerDeactivation 對當前副本為 no-op。
  ///
  /// 當 Self.current?.id == self.id 時，performServerDeactivation 應提前返回，
  /// 不改變 isActivated 狀態，也不重設 inputHandler。
  @Test
  func test502_DeactivationIsNoOpForCurrentSession() throws {
    #expect(testSession.isActivated)
    #expect(testSession.inputHandler != nil)

    InputSession.current = testSession

    let handlerBefore = testSession.inputHandler

    // 呼叫 deactivation；因 Self.current?.id == id，應為 no-op。
    testSession.performServerDeactivation()

    // 驗證 isActivated 未被改變（仍為 true）。
    #expect(
      testSession.isActivated,
      "performServerDeactivation 對當前副本應為 no-op，isActivated 不應被改變。"
    )

    // 驗證 inputHandler 仍然存在。
    #expect(testSession.inputHandler != nil)
    let handlerAfter = testSession.inputHandler
    #expect(
      ObjectIdentifier(handlerBefore!) == ObjectIdentifier(handlerAfter!),
      "performServerDeactivation 對當前副本不應影響 inputHandler。"
    )
  }

  /// 測試快速路徑下的反覆啟用不會累積額外開銷。
  ///
  /// 模擬使用者快速按壓 CapsLock 多次切換中英的場景：
  /// 連續呼叫 performServerActivation 多次，驗證每次都命中快速路徑。
  @Test
  func test503_RapidReactivation_MaintainsHandlerIdentity() throws {
    #expect(testSession.isActivated)
    InputSession.current = testSession

    let identityBefore = ObjectIdentifier(testSession.inputHandler!)

    // 模擬 20 次快速切換（每次 deactivate + activate）。
    for _ in 0 ..< 20 {
      testSession.performServerDeactivation() // no-op（current session）
      testSession.performServerActivation() // 快速路徑
    }

    let identityAfter = ObjectIdentifier(testSession.inputHandler!)
    #expect(
      identityBefore == identityAfter,
      "經過 20 次快速切換後，inputHandler 不應被重新建構。"
    )
    #expect(testSession.isActivated)
    #expect(testSession.state.type == .ofEmpty)
  }

  /// 回歸：CapsLock 切換中英文時會走 resetInputHandler。
  /// reset 時提交內容必須包含尚未遞交的 mixed ASCII buffer。
  @Test
  func test504_CapsLockResetCommitsPendingMixedASCIIBuffer() throws {
    testSession.resetInputHandler(forceComposerCleanup: true)
    testClient.clear()
    testHandler.prefs.mixedAlphanumericalEnabled = true

    typeSentenceOrCandidates("abc")

    #expect(testSession.state.type == .ofInputting)
    #expect(testSession.state.displayedText == "abc")
    #expect(testClient.toString().isEmpty)

    // 模擬 CapsLock 切換路徑中的 resetInputHandler() 行為。
    testSession.resetInputHandler()

    #expect(testClient.toString() == "abc")
    #expect(testSession.state.type == .ofEmpty)
  }

  /// 狂拼 copilot 候選窗的 tooltip：就地選字需 Shift＋選字鍵（IH117C 語義不變），
  /// 候選窗以專屬 Shift 提示取代「⚡️ 快速候選」（T2）。
  @Test
  func test505_FuriousCopilotWindowTooltipShowsShiftHint() throws {
    let customGrams: [Homa.Gram] = [
      .init(keyArray: ["ㄕˋ"], value: "世測", score: 9),
      .init(keyArray: ["ㄐㄧㄝˋ"], value: "界測", score: 8.5),
      .init(keyArray: ["ㄉㄚˋ"], value: "大測", score: 8),
      .init(keyArray: ["ㄓㄢˋ"], value: "戰測", score: 8),
    ]
    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.furiousTypingEnabled = false
      testHandler.prefs.keyboardParser = KeyboardParser.ofStandard.rawValue
      testHandler.ensureKeyboardParser()
      testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
      testSession.resetInputHandler(forceComposerCleanup: true)
    }
    customGrams.forEach {
      testHandler.currentLM.insertTemporaryData(unigram: $0, isFiltering: false)
    }
    testSession.resetInputHandler(forceComposerCleanup: true)
    testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
    testHandler.ensureKeyboardParser()
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = false
    testHandler.prefs.furiousTypingEnabled = true
    testHandler.currentLM.syncPrefs()

    // 「shijiedaz」：前段自動 chop 提交（世測界測大測），注拼槽暫存「z」。
    typeSentenceOrCandidates("shijiedaz")

    #expect(testSession.state.type == .ofInputting)
    #expect(testSession.isFuriousCopilotCandidateWindowVisible)
    #expect(!testSession.state.candidates.isEmpty)
    // 專屬 Shift 提示： HoldShiftToSelect（測試環境無 l10n 資源、`.i18n` 回退為原鍵名，故以鍵名斷言）。
    #expect(testSession.candidateToolTip(shortened: false).contains("HoldShiftToSelect"))
    // `shortened: true` 的場合無須測試了。
  }

  /// 康熙轉換的「一對多」攔截與字詞消歧：
  /// - 單字「才／參／核」直接原樣返回（各具多義，字典不再無條件取單一義項）。
  /// - 字詞層：常見義項詞（天才／參加／核心）維持原字；罕見義項詞（剛才／人參／核實）
  ///   仍轉古典字形（剛纔／人蔘／覈實）。
  /// - 對照組：異體字正寫（為→爲、吃→喫）仍正常轉換、資料庫仍生效。
  @Test
  func test506_KangXiConversionKeepsSingleCaiAsIs() throws {
    // 單字攔截
    #expect(ChineseConverter.cnvTradToKangXi("才") == "才")
    #expect(ChineseConverter.cnvTradToKangXi("參") == "參")
    #expect(ChineseConverter.cnvTradToKangXi("核") == "核")
    // 字詞層：常見義項維持原字（語料已移除破壞性單字對映）
    #expect(ChineseConverter.cnvTradToKangXi("天才") == "天才")
    #expect(ChineseConverter.cnvTradToKangXi("參加") == "參加")
    #expect(ChineseConverter.cnvTradToKangXi("核心") == "核心")
    // 字詞層：罕見義項仍轉古典字形（語料補消歧條目）
    #expect(ChineseConverter.cnvTradToKangXi("剛才") == "剛纔")
    #expect(ChineseConverter.cnvTradToKangXi("人參") == "人蔘")
    #expect(ChineseConverter.cnvTradToKangXi("核實") == "覈實")
    // 對照組：異體字正寫與資料庫仍生效
    #expect(ChineseConverter.cnvTradToKangXi("為") == "爲")
    #expect(ChineseConverter.cnvTradToKangXi("吃") == "喫")
  }
}

extension MainAssemblyTests {
  /// 狂拼 copilot 候選窗與 JKHL（VIM 式候選導航）重詮釋的隔離（P166）：
  /// copilot 窗為唯讀顯示（選取走 Shift+選字鍵），其顯示中 JKHL 不得把字母鍵
  /// （H/J/K/L）轉為方向鍵——否則 zh/ch/sh 的第二個 romaji「h」會被轉成
  /// LeftArrow、誤觸狂拼「觸發鍵固化」、提早提交未完成讀音並開出正常選字窗
  /// （修復前實測：buffer 清空、keys=1、state=ofCandidates）。
  /// 本測試鎖定縱排與橫排兩種選字窗情境：修復後「h」皆維持字母（buffer「sh」）、
  /// 組字器零改動、copilot 窗持續可見。
  @Test
  func test507_FuriousCopilotWindowIgnoresJKHLReinterpretation() throws {
    let customGrams: [Homa.Gram] = [
      .init(keyArray: ["ㄙㄢ"], value: "三測", score: 9),
      .init(keyArray: ["ㄕˋ"], value: "是測", score: 8.5),
      .init(keyArray: ["ㄕㄜˋ"], value: "社測", score: 8),
    ]
    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
      testHandler.prefs.furiousTypingEnabled = false
      testHandler.prefs.candidateStateJKHLBehavior = 0
      testHandler.prefs.useHorizontalCandidateList = true
      testHandler.prefs.keyboardParser = KeyboardParser.ofStandard.rawValue
      testHandler.ensureKeyboardParser()
      testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
      testSession.resetInputHandler(forceComposerCleanup: true)
    }
    customGrams.forEach {
      testHandler.currentLM.insertTemporaryData(unigram: $0, isFiltering: false)
    }
    testHandler.prefs.furiousTypingEnabled = true
    testHandler.prefs.candidateStateJKHLBehavior = 1 // JKHL 行為 1：HL 翻行列
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = false
    for isVertical in [false, true] {
      testSession.resetInputHandler(forceComposerCleanup: true)
      testHandler.prefs.keyboardParser = KeyboardParser.ofHanyuPinyin.rawValue
      testHandler.ensureKeyboardParser()
      testHandler.prefs.useHorizontalCandidateList = !isVertical
      testHandler.currentLM.syncPrefs()
      handleKeyEvent(.init(chars: "s"))
      #expect(testHandler.composer.romajiBuffer == "s")
      #expect(testSession.isFuriousCopilotCandidateWindowVisible)
      // 修復前：JKHL 把「h」轉為方向鍵 → 固化 → 正常選字窗誤開。
      handleKeyEvent(.init(chars: "h", keyCode: 4))
      #expect(testHandler.composer.romajiBuffer == "sh", "JKHL 不得把字母鍵 h 轉為方向鍵（isVertical=\(isVertical)）")
      #expect(testHandler.assembler.keys.isEmpty)
      #expect(testSession.state.type == .ofInputting)
      #expect(testSession.isFuriousCopilotCandidateWindowVisible)
    }
  }
}
