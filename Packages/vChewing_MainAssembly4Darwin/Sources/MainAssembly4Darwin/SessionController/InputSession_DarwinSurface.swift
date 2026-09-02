// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import AppKit
import IMKUtils
import Shared
import Shared_DarwinImpl
import SwiftExtension
import Typewriter

// MARK: - IMKInputSessionController + SessionClientProxy

/// Darwin 端的 IMK 客戶端 proxy 直接滿足跨平台的 SessionClientProxy 協定。
#if hasFeature(RetroactiveAttribute)
  extension IMKInputSessionController: @retroactive SessionClientProxy {}
#else
  extension IMKInputSessionController: SessionClientProxy {}
#endif

// MARK: - ControllerAddrSentinel

/// 對 controller 記憶體位址做生命週期核驗的輕量包裝。
/// 僅在 controller 存活時允許解讀其位址。
public struct ControllerAddrSentinel: Sendable {
  // MARK: Lifecycle

  init(addr: UInt) {
    self.addr = addr
  }

  // MARK: Internal

  let addr: UInt

  var unwrapped: UInt? {
    if UserDefaults.pendingUnitTests {
      guard addr == 0 else { return nil }
    } else {
      guard IMKControllerLifetimeTracker.shared().isAddressAlive(addr) else { return nil }
    }
    return addr
  }
}

// MARK: - InputSession 的 Darwin 專屬表面

extension InputSession {
  // MARK: Lifecycle

  public convenience init(controller inputController: IMKInputSessionController?) {
    var controllerAddr: UInt?
    var clientProxy: (any SessionClientProxy)?
    if let inputController {
      controllerAddr = UInt(bitPattern: Unmanaged.passUnretained(inputController).toOpaque())
      clientProxy = inputController as any SessionClientProxy
    }
    self.init(
      preallocated: (),
      manuallyAssignedClientProxy: clientProxy,
      controllerAddr: controllerAddr
    )
    vCLog("InputSession constructed. ID: \(id.uuidString)")
  }

  // MARK: Public

  /// IMKInputController 副本。
  public var inputController: IMKInputSessionController? {
    guard let addr = inputControllerAssignedAddr,
          IMKControllerLifetimeTracker.shared().isAddressAlive(addr),
          let opaque = UnsafeRawPointer(bitPattern: addr)
    else { return nil }
    return Unmanaged<IMKInputSessionController>.fromOpaque(opaque).takeUnretainedValue()
  }

  /// 重新綁定至新的 IMKInputSessionController。
  public func reassign(to controller: IMKInputSessionController) {
    let newAddr = UInt(bitPattern: Unmanaged.passUnretained(controller).toOpaque())
    reassign(toAddr: newAddr)
    replacementRangeProvider = { [weak self] in
      self?.inputController?.replacementRange() ?? .init(location: NSNotFound, length: NSNotFound)
    }
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
  public func recognizedEvents() -> UInt {
    let events: NSEvent.EventTypeMask = [.keyDown, .flagsChanged, .keyUp]
    return UInt(events.rawValue)
  }

  public func showPreferences() {
    resetInputHandler()
    clearInlineDisplay()
    osCheck: if #available(macOS 14, *) {
      switch NSEvent.keyModifierFlags {
      case .option: break osCheck
      default: CtlSettingsUI.show()
      }
      NSApp.popup()
      return
    }
    CtlSettingsCocoa.show()
    NSApp.popup()
  }

  // MARK: - IMKInputController surface

  public func updateComposition() {
    inputController?.updateComposition()
  }

  public func cancelComposition() {
    inputController?.cancelComposition()
  }

  public func compositionAttributes(at range: NSRange) -> NSMutableDictionary {
    inputController?.compositionAttributes(at: range) ?? .init()
  }

  public func mark(forStyle style: Int, at range: NSRange) -> [AnyHashable: Any] {
    inputController?.mark(forStyle: style, at: range) ?? [:]
  }

  public func doCommand(by aSelector: Selector, command infoDictionary: [AnyHashable: Any]) {
    inputController?.doCommand(by: aSelector, command: infoDictionary)
  }

  public func menu() -> NSMenu? { inputController?.menu() }

  public func delegate() -> Any? { inputController?.delegate() }

  public func setDelegate(_ newDelegate: Any?) { inputController?.setDelegate(newDelegate) }

  public func server() -> IMKServer { inputController!.server() }

  /// 共用的 NSAlert 副本、用於在輸入法切換失敗時提示使用者修改系統偏好設定。
  public var sharedAlertForInputModeToggling: NSAlert {
    let alert = NSAlert()
    alert.alertStyle = .informational
    alert.messageText = "i18n:InputMode.TargetInputModeActivationRequired".i18n
    alert
      .informativeText =
      "i18n:InfoMessage.ProceedingToSystemPreferences".i18n
    alert.addButton(withTitle: "i18n:Common.OK".i18n)
    return alert
  }
}

// MARK: - NSEvent 入口

extension SessionProtocol {
  /// 接受所有鍵鼠事件為 NSEvent，讓輸入法判斷是否要處理、該怎樣處理。
  /// 然後再交給 InputHandler.handleEvent() 分診。
  /// - Parameters:
  ///   - event: 裝置操作輸入事件，可能會是 nil。
  ///   - sender: 呼叫了該函式的客體（無須使用）。
  /// - Returns: 回「`true`」以將該按鍵已攔截處理的訊息傳遞給 IMK；回「`false`」則放行、不作處理。
  public func handleNSEvent(
    _ event: NSEvent?
  )
    -> Bool {
    // 就這傳入的 NSEvent 都還有可能是 nil，Apple InputMethodKit 團隊到底在搞三小。
    guard let event else {
      resetInputHandler(forceComposerCleanup: true)
      return false
    }
    guard let newEvent = event.copyAsKBEvent else { return false }
    return handleEvent(newEvent)
  }

  /// 專門用來就地切換繁簡模式的函式。
  /// This method is non-ObjC, requiring an ObjC wrapper.
  public func toggleInputMode() {
    defer { isASCIIMode = false }
    let nowMode = IMEApp.currentInputMode
    guard nowMode != .imeModeNULL else { return }
    modeCheck: for neta in TISInputSource.allRegisteredInstancesOfThisInputMethod {
      guard !neta.isActivated else { continue }
      osCheck: if #unavailable(macOS 12) {
        neta.activate()
        if !neta.isActivated {
          break osCheck
        }
        break modeCheck
      }
      let alert = (self as? InputSession)?.sharedAlertForInputModeToggling ?? NSAlert()
      let result = alert.runModal()
      NSApp.popup()
      if result == NSApplication.ModalResponse.alertFirstButtonReturn {
        neta.activate()
      }
      return
    }
    let status = "i18n:NotificationSwitch.Revolver".i18n
    asyncOnMain(bypassAsync: UserDefaults.pendingUnitTests) {
      SessionHost.shared.notify(
        nowMode.reversed.localizedDescription + "\n" + status
      )
    }
    clientProxy?.clientSelectMode(withModeIdentifier: nowMode.reversed.rawValue)
  }
}
