// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import AppKit
import CandidateWindow
import LangModelAssembly
import Megrez
import Shared
import Tekkon

// MARK: - InputHandler

/// InputHandler 輸入調度模組。
public final class InputHandler: InputHandlerProtocol {
  // MARK: Lifecycle

  /// 初期化。
  public init(
    lm: LMAssembly.LMInstantiator,
    pref: PrefMgrProtocol,
    errorCallback: ((_ message: String) -> ())? = nil,
    notificationCallback: ((_ message: String) -> ())? = nil
  ) {
    self.prefs = pref
    self.currentLM = lm
    self.errorCallback = errorCallback
    self.notificationCallback = notificationCallback
    /// 組字器初期化。因為是首次初期化變數，所以這裡不能用 ensureCompositor() 代勞。
    self.compositor = Megrez.Compositor(with: currentLM, separator: "-")
    /// 同步組字器單個詞的幅位長度上限。
    compositor.maxSpanLength = prefs.maxCandidateLength
    /// 注拼槽初期化。
    ensureKeyboardParser()
  }

  // MARK: Public

  public static var keySeparator: String { Megrez.Compositor.theSeparator }

  /// 委任物件 (SessionCtl)，以便呼叫其中的函式。
  public var session: (SessionProtocol & CtlCandidateDelegate)?
  public var prefs: PrefMgrProtocol
  public var errorCallback: ((String) -> ())?
  public var notificationCallback: ((String) -> ())?

  /// 用來記錄「叫出選字窗前」的游標位置的變數。
  public var backupCursor: Int?
  /// 當前的打字模式。
  public var currentTypingMethod: TypingMethod = .vChewingFactory

  /// 半衰模組的衰減指數
  public let kEpsilon: Double = 0.000_001

  public var strCodePointBuffer = "" // 內碼輸入專用組碼區
  public var calligrapher = "" // 磁帶專用組筆區
  public var composer: Tekkon.Composer = .init() // 注拼槽
  public var compositor: Megrez.Compositor // 組字器

  public var currentLM: LMAssembly.LMInstantiator {
    didSet {
      compositor.langModel = currentLM
      clear()
    }
  }
}
