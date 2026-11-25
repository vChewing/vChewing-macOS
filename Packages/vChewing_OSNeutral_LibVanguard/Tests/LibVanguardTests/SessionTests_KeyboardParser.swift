// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation
import Shared
import SwiftExtension
import Testing

@testable import LibVanguard

// 排列偏好於啟用時之對帳（P364）。

// MARK: - SS.KeyboardParser

extension LibVanguardTestsRoot.InputHandlerTests.Session {
  /// 三支「排列」下拉皆直寫 `UserDefaults`（SwiftUI 之 `@AppStorage`、AppKit 之預設值繫結），
  /// 故注拼槽不會自行得知改動；於 `performServerActivation` 對帳，令切回客體即生效。
  @Test("SS-KeyboardParser-001 Activation reconciles a stale composer parser")
  func test_SS_KeyboardParser_001_ActivationReconciles() {
    testSession.prefs.pinyinTypingEnabled = false
    testSession.prefs.keyboardParser4Zhuyin = KeyboardParser.ofStandard.rawValue
    testSession.inputHandler?.ensureKeyboardParser()
    #expect(testSession.inputHandler?.composer.parser == .ofDachen)

    // 只改偏好、不經啟用：注拼槽仍是舊排列。
    testSession.prefs.keyboardParser4Zhuyin = KeyboardParser.ofDachen26.rawValue
    #expect(testSession.inputHandler?.composer.parser == .ofDachen)

    // 一次啟用即對帳（啟用時組字器與注拼槽皆為空，重建無損）。
    InputSession.current = nil
    testSession.performServerActivation()
    #expect(testSession.inputHandler?.composer.parser == .ofDachen26)

    // 還原，免污染同套房其他用例共用之宿主偏好。
    testSession.prefs.keyboardParser4Zhuyin = KeyboardParser.ofStandard.rawValue
    testSession.inputHandler?.ensureKeyboardParser()
    #expect(testSession.inputHandler?.composer.parser == .ofDachen)
  }
}
