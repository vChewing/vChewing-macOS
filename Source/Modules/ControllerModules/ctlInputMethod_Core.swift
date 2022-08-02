// Copyright (c) 2011 and onwards The OpenVanilla Project (MIT License).
// All possible vChewing-specific modifications are of:
// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
/*
Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

1. The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

2. No trademark license is granted to use the trade names, trademarks, service
marks, or product names of Contributor, except as required to fulfill notice
requirements above.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

import Cocoa
import InputMethodKit

/// 輸入法控制模組，乃在輸入法端用以控制輸入行為的基礎型別。
///
/// IMKInputController 完全實現了相關協定所定義的內容。
/// 一般情況下，研發者不會複寫此型別，而是提供一個委任物件、
/// 藉此實現研發者想製作的方法/函式。協定方法的 IMKInputController 版本
/// 檢查委任物件是否實現了方法：若存在的話，就調用委任物件內的版本。
/// - Remark: 在輸入法的主函式中分配的 IMKServer 型別為客體應用程式創建的每個
/// 輸入會話創建一個控制器型別。因此，對於每個輸入會話，都有一個對應的 IMKInputController。
@objc(ctlInputMethod)  // 必須加上 ObjC，因為 IMK 是用 ObjC 寫的。
class ctlInputMethod: IMKInputController {
  /// 標記狀態來聲明目前是在新增使用者語彙、還是準備要濾除使用者語彙。
  static var areWeDeleting = false

  /// 目前在用的的選字窗副本。
  static var ctlCandidateCurrent: ctlCandidateProtocol = ctlCandidateUniversal.init(.horizontal)

  /// 工具提示視窗的副本。
  static let tooltipController = TooltipController()

  // MARK: -

  /// 按鍵調度模組的副本。
  var keyHandler: KeyHandler = .init()
  /// 用以記錄當前輸入法狀態的變數。
  var state: InputStateProtocol = InputState.Empty()

  // MARK: - 工具函式

  /// 指定鍵盤佈局。
  func setKeyLayout() {
    client().overrideKeyboard(withKeyboardNamed: mgrPrefs.basicKeyboardLayout)
  }

  /// 重設按鍵調度模組，會將當前尚未遞交的內容遞交出去。
  func resetKeyHandler() {
    if let state = state as? InputState.NotEmpty {
      /// 將傳回的新狀態交給調度函式。
      handle(state: InputState.Committing(textToCommit: state.composingBufferConverted))
    }
    keyHandler.clear()
    handle(state: InputState.Empty())
  }

  // MARK: - IMKInputController 方法

  /// 對用以設定委任物件的控制器型別進行初期化處理。
  ///
  /// inputClient 參數是客體應用側存在的用以藉由 IMKServer 伺服器向輸入法傳訊的物件。該物件始終遵守 IMKTextInput 協定。
  /// - Remark: 所有由委任物件實裝的「被協定要求實裝的方法」都會有一個用來接受客體物件的參數。在 IMKInputController 內部的型別不需要接受這個參數，因為已經有「client()」這個參數存在了。
  /// - Parameters:
  ///   - server: IMKServer
  ///   - delegate: 客體物件
  ///   - inputClient: 用以接受輸入的客體應用物件
  override init!(server: IMKServer!, delegate: Any!, client inputClient: Any!) {
    super.init(server: server, delegate: delegate, client: inputClient)
    keyHandler.delegate = self
    // 下述兩行很有必要，否則輸入法會在手動重啟之後無法立刻生效。
    activateServer(inputClient)
    keyHandler.ensureParser()
    resetKeyHandler()
  }

  // MARK: - IMKStateSetting 協定規定的方法

  /// 啟用輸入法時，會觸發該函式。
  /// - Parameter sender: 呼叫了該函式的客體（無須使用）。
  override func activateServer(_ sender: Any!) {
    _ = sender  // 防止格式整理工具毀掉與此對應的參數。
    UserDefaults.standard.synchronize()

    // 因為偶爾會收到與 activateServer 有關的以「強制拆 nil」為理由的報錯，
    // 所以這裡添加這句、來試圖應對這種情況。
    if keyHandler.delegate == nil { keyHandler.delegate = self }
    setValue(IME.currentInputMode.rawValue, forTag: 114514, client: client())
    keyHandler.clear()
    keyHandler.ensureParser()

    /// 必須加上下述條件，否則會在每次切換至輸入法本體的視窗（比如偏好設定視窗）時會卡死。
    /// 這是很多 macOS 副廠輸入法的常見失誤之處。
    if client().bundleIdentifier() != Bundle.main.bundleIdentifier {
      // 強制重設當前鍵盤佈局、使其與偏好設定同步。
      setKeyLayout()
      handle(state: InputState.Empty())
    }  // 除此之外就不要動了，免得在點開輸入法自身的視窗時卡死。
    (NSApp.delegate as? AppDelegate)?.checkForUpdate()
  }

  /// 停用輸入法時，會觸發該函式。
  /// - Parameter sender: 呼叫了該函式的客體（無須使用）。
  override func deactivateServer(_ sender: Any!) {
    _ = sender  // 防止格式整理工具毀掉與此對應的參數。
    keyHandler.clear()
    handle(state: InputState.Empty())
    handle(state: InputState.Deactivated())
  }

  /// 切換至某一個輸入法的某個副本時（比如威注音的簡體輸入法副本與繁體輸入法副本），會觸發該函式。
  /// - Parameters:
  ///   - value: 輸入法在系統偏好設定當中的副本的 identifier，與 bundle identifier 類似。在輸入法的 info.plist 內定義。
  ///   - tag: 標記（無須使用）。
  ///   - sender: 呼叫了該函式的客體（無須使用）。
  override func setValue(_ value: Any!, forTag tag: Int, client sender: Any!) {
    _ = tag  // 防止格式整理工具毀掉與此對應的參數。
    _ = sender  // 防止格式整理工具毀掉與此對應的參數。
    var newInputMode = InputMode(rawValue: value as? String ?? "") ?? InputMode.imeModeNULL
    switch newInputMode {
      case InputMode.imeModeCHS:
        newInputMode = InputMode.imeModeCHS
      case InputMode.imeModeCHT:
        newInputMode = InputMode.imeModeCHT
      default:
        newInputMode = InputMode.imeModeNULL
    }
    mgrLangModel.loadDataModel(newInputMode)

    if keyHandler.inputMode != newInputMode {
      UserDefaults.standard.synchronize()
      keyHandler.clear()
      keyHandler.inputMode = newInputMode
      /// 必須加上下述條件，否則會在每次切換至輸入法本體的視窗（比如偏好設定視窗）時會卡死。
      /// 這是很多 macOS 副廠輸入法的常見失誤之處。
      if client().bundleIdentifier() != Bundle.main.bundleIdentifier {
        // 強制重設當前鍵盤佈局、使其與偏好設定同步。這裡的這一步也不能省略。
        setKeyLayout()
        handle(state: InputState.Empty())
      }  // 除此之外就不要動了，免得在點開輸入法自身的視窗時卡死。
    }

    // 讓外界知道目前的簡繁體輸入模式。
    IME.currentInputMode = keyHandler.inputMode
  }

  // MARK: - IMKServerInput 協定規定的方法

  /// 該函式的回饋結果決定了輸入法會攔截且捕捉哪些類型的輸入裝置操作事件。
  ///
  /// 一個客體應用會與輸入法共同確認某個輸入裝置操作事件是否可以觸發輸入法內的某個方法。預設情況下，
  /// 該函式僅響應 Swift 的「`NSEvent.EventTypeMask = [.keyDown]`」，也就是 ObjC 當中的「`NSKeyDownMask`」。
  /// 如果您的輸入法「僅攔截」鍵盤按鍵事件處理的話，IMK 會預設啟用這些對滑鼠的操作：當組字區存在時，
  /// 如果使用者用滑鼠點擊了該文字輸入區內的組字區以外的區域的話，則該組字區的顯示內容會被直接藉由
  /// 「`commitComposition(_ message)`」遞交給客體。
  /// - Parameter sender: 呼叫了該函式的客體（無須使用）。
  /// - Returns: 返回一個 uint，其中承載了與系統 NSEvent 操作事件有關的掩碼集合（詳見 NSEvent.h）。
  override func recognizedEvents(_ sender: Any!) -> Int {
    _ = sender  // 防止格式整理工具毀掉與此對應的參數。
    let events: NSEvent.EventTypeMask = [.keyDown, .flagsChanged]
    return Int(events.rawValue)
  }

  /// 接受所有鍵鼠事件為 NSEvent，讓輸入法判斷是否要處理、該怎樣處理。
  /// - Parameters:
  ///   - event: 裝置操作輸入事件。
  ///   - sender: 呼叫了該函式的客體（無須使用）。
  /// - Returns: 回「`true`」以將該案件已攔截處理的訊息傳遞給 IMK；回「`false`」則放行、不作處理。
  @objc(handleEvent:client:) override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
    _ = sender  // 防止格式整理工具毀掉與此對應的參數。
    /// 這裡仍舊需要判斷 flags。之前使輸入法狀態卡住無法敲漢字的問題已在 KeyHandler 內修復。
    /// 這裡不判斷 flags 的話，用方向鍵前後定位光標之後，再次試圖觸發組字區時、反而會在首次按鍵時失敗。
    /// 同時注意：必須在 event.type == .flagsChanged 結尾插入 return false，
    /// 否則，每次處理這種判斷時都會觸發 NSInternalInconsistencyException。
    if event.type == .flagsChanged {
      return false
    }

    // 準備修飾鍵，用來判定是否需要利用就地新增語彙時的 Enter 鍵來砍詞。
    ctlInputMethod.areWeDeleting = event.modifierFlags.contains([.shift, .command])

    var textFrame = NSRect.zero

    let attributes: [AnyHashable: Any]? = client().attributes(
      forCharacterIndex: 0, lineHeightRectangle: &textFrame
    )

    let isTypingVertical =
      (attributes?["IMKTextOrientation"] as? NSNumber)?.intValue == 0 || false

    if client().bundleIdentifier()
      == "org.atelierInmu.vChewing.vChewingPhraseEditor"
    {
      IME.areWeUsingOurOwnPhraseEditor = true
    } else {
      IME.areWeUsingOurOwnPhraseEditor = false
    }

    let input = InputSignal(event: event, isVerticalTyping: isTypingVertical)

    // 無法列印的訊號輸入，一概不作處理。
    // 這個過程不能放在 KeyHandler 內，否則不會起作用。
    if !input.charCode.isPrintable {
      return false
    }

    /// 將按鍵行為與當前輸入法狀態結合起來、交給按鍵調度模組來處理。
    /// 再根據返回的 result bool 數值來告知 IMK「這個按鍵事件是被處理了還是被放行了」。
    let result = keyHandler.handle(input: input, state: state) { newState in
      self.handle(state: newState)
    } errorCallback: {
      clsSFX.beep()
    }
    return result
  }

  /// 有時會出現某些 App 攔截輸入法的 Ctrl+Enter / Shift+Enter 熱鍵的情況。
  /// 也就是說 handle(event:) 完全抓不到這個 Event。
  /// 這時需要在 commitComposition 這一關做一些收尾處理。
  /// - Parameter sender: 呼叫了該函式的客體（無須使用）。
  override func commitComposition(_ sender: Any!) {
    _ = sender  // 防止格式整理工具毀掉與此對應的參數。
    resetKeyHandler()
  }

  /// 生成 IMK 選字窗專用的候選字串陣列。
  /// - Parameter sender: 呼叫了該函式的客體（無須使用）。
  /// - Returns: IMK 選字窗專用的候選字串陣列。
  override func candidates(_ sender: Any!) -> [Any]! {
    _ = sender  // 防止格式整理工具毀掉與此對應的參數。
    if let state = state as? InputState.AssociatedPhrases {
      return state.candidates.map { theCandidate -> String in
        let theConverted = IME.kanjiConversionIfRequired(theCandidate.1)
        return (theCandidate.1 == theConverted) ? theCandidate.1 : "\(theConverted)(\(theCandidate.1))"
      }
    }
    if let state = state as? InputState.ChoosingCandidate {
      return state.candidates.map { theCandidate -> String in
        let theConverted = IME.kanjiConversionIfRequired(theCandidate.1)
        return (theCandidate.1 == theConverted) ? theCandidate.1 : "\(theConverted)(\(theCandidate.1))"
      }
    }
    if let state = state as? InputState.SymbolTable {
      return state.candidates.map { theCandidate -> String in
        let theConverted = IME.kanjiConversionIfRequired(theCandidate.1)
        return (theCandidate.1 == theConverted) ? theCandidate.1 : "\(theConverted)(\(theCandidate.1))"
      }
    }
    return .init()
  }
}
