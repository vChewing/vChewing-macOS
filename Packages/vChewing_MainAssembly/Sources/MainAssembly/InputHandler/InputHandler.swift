// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation
import LangModelAssembly
import Shared
import Shared_DarwinImpl
import Typewriter

// MARK: - InputHandler

/// InputHandler 輸入調度模組。
public final class InputHandler: InputHandlerProtocol {
  // MARK: Lifecycle

  /// 初期化。
  public init(
    lm: LMAssembly.LMInstantiator,
    pref: PrefMgrProtocol,
    errorCallback: ((_ message: String) -> ())? = nil,
    filterabilityChecker: ((_ state: IMEStateData) -> Bool)? = nil,
    notificationCallback: ((_ message: String) -> ())? = nil,
    pomSaveCallback: (() -> ())? = nil
  ) {
    self.prefs = pref
    self.currentLM = lm
    self.pomSaveCallback = pomSaveCallback
    self.errorCallback = errorCallback
    self.filterabilityChecker = filterabilityChecker
    self.notificationCallback = notificationCallback
    /// 組字器初期化。因為是首次初期化變數，所以這裡不能用 ensureCompositor() 代勞。
    self.assembler = Assembler(with: currentLM, separator: "-")
    /// 同步組字器單個詞的幅節長度上限。
    assembler.maxSegLength = prefs.maxCandidateLength
    /// 注拼槽初期化。
    ensureKeyboardParser()
  }

  // MARK: Public

  public typealias State = IMEState
  public typealias Session = InputSession

  public static var keySeparator: String { Assembler.theSeparator }

  public var isJISKeyboard: (() -> Bool)? = { IMEApp.isKeyboardJIS }

  /// 委任物件 (SessionCtl)，以便呼叫其中的函式。
  public weak var session: Session?
  public var prefs: PrefMgrProtocol
  public var errorCallback: ((String) -> ())?
  public var notificationCallback: ((String) -> ())?
  public var pomSaveCallback: (() -> ())?
  public var filterabilityChecker: ((_ state: IMEStateData) -> Bool)?
  public var narrator: (any SpeechNarratorProtocol)? = SpeechSputnik.shared

  /// 用來記錄「叫出選字窗前」的游標位置的變數。
  public var backupCursor: Int?
  /// 當前的打字模式。
  public var currentTypingMethod: TypingMethod = .vChewingFactory

  public var strCodePointBuffer = "" // 內碼輸入專用組碼區
  public var calligrapher = "" // 磁帶專用組筆區
  public var composer: Composer = .init() // 注拼槽
  public var assembler: Assembler // 組字器

  public var currentLM: LMAssembly.LMInstantiator {
    didSet {
      assembler.langModel = currentLM
      clear()
    }
  }
}
