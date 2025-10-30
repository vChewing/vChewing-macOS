// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import InputMethodKit

// MARK: - SessionCtl

/// 輸入法控制模組，乃在輸入法端用以控制輸入行為的基礎型別。
///
/// IMKInputController 完全實現了相關協定所定義的內容。
/// 一般情況下，研發者不會複寫此型別，而是提供一個委任物件、
/// 藉此實現研發者想製作的方法/函式。協定方法的 IMKInputController 版本
/// 檢查委任物件是否實現了方法：若存在的話，就調用委任物件內的版本。
/// - Remark: 在輸入法的主函式中分配的 IMKServer 型別為客體應用程式創建的每個
/// 輸入會話創建一個控制器型別。因此，對於每個輸入會話，都有一個對應的 IMKInputController。
@objc(SessionCtl) // 必須加上 ObjC，因為 IMK 是用 ObjC 寫的。
public class SessionCtl: IMKInputController {
  // MARK: Lifecycle

  /// 對用以設定委任物件的控制器型別進行初期化處理。
  override public init() {
    super.init()
    Self.currentInputController = self
  }

  /// 對用以設定委任物件的控制器型別進行初期化處理。
  ///
  /// inputClient 參數是客體應用側存在的用以藉由 IMKServer 伺服器向輸入法傳訊的物件。該物件始終遵守 IMKTextInput 協定。
  /// - Remark: 所有由委任物件實裝的「被協定要求實裝的方法」都會有一個用來接受客體物件的參數。在 IMKInputController 內部的型別不需要接受這個參數，因為已經有「client()」這個參數存在了。
  /// - Parameters:
  ///   - server: IMKServer
  ///   - delegate: 客體物件
  ///   - inputClient: 用以接受輸入的客體應用物件
  override public init!(server: IMKServer!, delegate: Any!, client inputClient: Any!) {
    super.init(server: server, delegate: delegate, client: inputClient)
    Self.currentInputController = self
  }

  // MARK: Public

  public private(set) static weak var currentInputController: SessionCtl?

  public private(set) var core: InputSession?
}

// MARK: - IMKStateSetting 協定規定的方法

extension SessionCtl {
  /// 啟用輸入法時，會觸發該函式。
  /// - Parameter sender: 呼叫了該函式的客體。
  override public func activateServer(_ sender: Any!) {
    super.activateServer(sender)
    autoreleasepool {
      Self.currentInputController = self
      core = .init(controller: self, client: client)
      core?.activateServer(sender)
    }
  }

  /// 停用輸入法時，會觸發該函式。
  /// - Parameter sender: 呼叫了該函式的客體（無須使用）。
  override public func deactivateServer(_ sender: Any!) {
    core?.deactivateServer(sender)
    core = nil
    super.deactivateServer(sender)
  }

  /// 切換至某一個輸入法的某個副本時（比如威注音的簡體輸入法副本與繁體輸入法副本），會觸發該函式。
  /// - Remark: 當系統呼叫 activateServer() 的時候，setValue() 會被自動呼叫。
  /// 但是，手動呼叫 activateServer() 的時候，setValue() 不會被自動呼叫。
  /// - Parameters:
  ///   - value: 輸入法在系統偏好設定當中的副本的 identifier，與 bundle identifier 類似。在輸入法的 info.plist 內定義。
  ///   - tag: 標記（無須使用）。
  ///   - sender: 呼叫了該函式的客體（無須使用）。
  override public func setValue(_ value: Any!, forTag tag: Int, client sender: Any!) {
    core?.setValue(value, forTag: tag, client: sender)
    super.setValue(value, forTag: tag, client: sender)
  }
}

// MARK: - IMKServerInput 協定規定的方法（僅部分）

extension SessionCtl {
  /// 接受所有鍵鼠事件為 NSEvent，讓輸入法判斷是否要處理、該怎樣處理。
  /// 然後再交給 InputHandler.handleEvent() 分診。
  /// - Parameters:
  ///   - event: 裝置操作輸入事件，可能會是 nil。
  ///   - sender: 呼叫了該函式的客體（無須使用）。
  /// - Returns: 回「`true`」以將該按鍵已攔截處理的訊息傳遞給 IMK；回「`false`」則放行、不作處理。
  @objc(handleEvent:client:)
  override public func handle(
    _ event: NSEvent?,
    client sender: Any?
  )
    -> Bool {
    core?.handleNSEvent(event, client: sender) ?? false
  }

  /// 該函式的回饋結果決定了輸入法會攔截且捕捉哪些類型的輸入裝置操作事件。
  ///
  /// 一個客體應用會與輸入法共同確認某個輸入裝置操作事件是否可以觸發輸入法內的某個方法。預設情況下，
  /// 該函式僅響應 Swift 的「`NSEvent.EventTypeMask = [.keyDown]`」，也就是 ObjC 當中的「`NSKeyDownMask`」。
  /// 如果您的輸入法「僅攔截」鍵盤按鍵事件處理的話，IMK 會預設啟用這些對滑鼠的操作：當組字區存在時，
  /// 如果使用者用滑鼠點擊了該文字輸入區內的組字區以外的區域的話，則該組字區的顯示內容會被直接藉由
  /// 「`commitComposition(_ message)`」遞交給客體。
  /// - Parameter sender: 呼叫了該函式的客體（無須使用）。
  /// - Returns: 返回一個 uint，其中承載了與系統 NSEvent 操作事件有關的掩碼集合（詳見 NSEvent.h）。
  override public func recognizedEvents(_ sender: Any!) -> Int {
    if let preparedResult = core?.recognizedEvents(sender) { return preparedResult }
    let events: NSEvent.EventTypeMask = [.keyDown, .flagsChanged, .keyUp]
    return Int(events.rawValue)
  }

  /// 有時會出現某些 App 攔截輸入法的 Ctrl+Enter / Shift+Enter 熱鍵的情況。
  /// 也就是說 handle(event:) 完全抓不到這個 Event。
  /// 這時需要在 commitComposition 這一關做一些收尾處理。
  /// - Parameter sender: 呼叫了該函式的客體（無須使用）。
  override public func commitComposition(_ sender: Any!) {
    core?.commitComposition(sender)
    // super.commitComposition(sender)  // 這句不要引入，否則每次切出輸入法時都會死當。
  }

  /// 指定輸入法要遞交出去的內容（雖然 InputMethodKit 可能並不會真的用到這個函式）。
  /// - Parameter sender: 呼叫了該函式的客體（無須使用）。
  /// - Returns: 字串內容，或者 nil。
  override public func composedString(_ sender: Any!) -> Any! {
    core?.composedString(sender)
  }

  /// 輸入法要被換掉或關掉的時候，要做的事情。
  /// 不過好像因為 IMK 的 Bug 而並不會被執行。
  override public func inputControllerWillClose() {
    // 下述兩行用來防止尚未完成拼寫的注音內容被遞交出去。
    core?.inputControllerWillClose()
  }

  /// 指定標記模式下被高亮的部分。
  override public func selectionRange() -> NSRange {
    core?.selectionRange() ?? .zero
  }

  /// 該函式僅用來取消任何輸入法浮動視窗的顯示。
  override public func hidePalettes() {
    core?.hidePalettes()
  }
}
