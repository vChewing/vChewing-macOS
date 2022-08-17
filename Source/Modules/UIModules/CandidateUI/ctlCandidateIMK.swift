// Copyright (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation
import InputMethodKit

public class ctlCandidateIMK: IMKCandidates, ctlCandidateProtocol {
  public var currentLayout: CandidateLayout = .horizontal
  private let defaultIMKSelectionKey: [UInt16: String] = [
    18: "1", 19: "2", 20: "3", 21: "4", 23: "5", 22: "6", 26: "7", 28: "8", 25: "9",
  ]
  public weak var delegate: ctlCandidateDelegate? {
    didSet {
      reloadData()
    }
  }

  public var visible: Bool = false {
    didSet {
      if visible {
        show()
      } else {
        hide()
      }
    }
  }

  public var windowTopLeftPoint: NSPoint {
    get {
      let frameRect = candidateFrame()
      return NSPoint(x: frameRect.minX, y: frameRect.maxY)
    }
    set {
      DispatchQueue.main.asyncAfter(deadline: DispatchTime.now()) {
        self.set(windowTopLeftPoint: newValue, bottomOutOfScreenAdjustmentHeight: 0)
      }
    }
  }

  public var keyLabels: [CandidateKeyLabel] = ["1", "2", "3", "4", "5", "6", "7", "8", "9"]
    .map {
      CandidateKeyLabel(key: $0, displayedText: $0)
    }

  public var keyLabelFont: NSFont = NSFont.monospacedDigitSystemFont(
    ofSize: 14, weight: .medium
  )
  public var candidateFont: NSFont = NSFont.systemFont(ofSize: 18)
  public var tooltip: String = ""

  var keyCount = 0
  var displayedCandidates = [String]()

  public func specifyLayout(_ layout: CandidateLayout = .horizontal) {
    currentLayout = layout
    switch currentLayout {
      case .horizontal:
        setPanelType(kIMKScrollingGridCandidatePanel)
      case .vertical:
        setPanelType(kIMKSingleColumnScrollingCandidatePanel)
    }
    // 設為 true 表示先交給 ctlIME 處理
    setAttributes([IMKCandidatesSendServerKeyEventFirst: true])
  }

  public required init(_ layout: CandidateLayout = .horizontal) {
    super.init(server: theServer, panelType: kIMKScrollingGridCandidatePanel)
    specifyLayout(layout)
    visible = false
    // guard let currentTISInputSource = currentTISInputSource else { return }  // 下面兩句都沒用，所以註釋掉。
    // setSelectionKeys([18, 19, 20, 21, 23, 22, 26, 28, 25])  // 這句是壞的，用了反而沒有選字鍵。
    // setSelectionKeysKeylayout(currentTISInputSource)  // 這句也是壞的，沒有卵用。
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  public func reloadData() {
    // guard let delegate = delegate else { return }  // 下文無效，所以這句沒用。
    // 既然下述函式無效，那中間這段沒用的也都砍了。
    // setCandidateData(candidates)  // 該函式無效。
    keyCount = selectionKeys().count
    selectedCandidateIndex = 0
    update()
  }

  /// 幹話：這裡很多函式內容亂寫也都無所謂了，因為都被 IMKCandidates 代管執行。
  /// 對於所有 IMK 選字窗的選字判斷動作，不是在 keyHandler 中，而是在 `ctlIME_Core` 中。

  private var currentPageIndex: Int = 0

  private var pageCount: Int {
    guard let delegate = delegate else {
      return 0
    }
    let totalCount = delegate.candidateCountForController(self)
    let keyLabelCount = keyLabels.count
    return totalCount / keyLabelCount + ((totalCount % keyLabelCount) != 0 ? 1 : 0)
  }

  public func showNextPage() -> Bool {
    guard delegate != nil else { return false }
    if pageCount == 1 { return highlightNextCandidate() }
    if currentPageIndex + 1 >= pageCount { clsSFX.beep() }
    currentPageIndex = (currentPageIndex + 1 >= pageCount) ? 0 : currentPageIndex + 1
    if selectedCandidateIndex == candidates(self).count - 1 { return false }
    selectedCandidateIndex = min(selectedCandidateIndex + keyCount, candidates(self).count - 1)
    switch currentLayout {
      case .horizontal:
        moveDown(self)
      case .vertical:
        moveRight(self)
    }
    return true
  }

  public func showPreviousPage() -> Bool {
    guard delegate != nil else { return false }
    if pageCount == 1 { return highlightPreviousCandidate() }
    if currentPageIndex == 0 { clsSFX.beep() }
    currentPageIndex = (currentPageIndex == 0) ? pageCount - 1 : currentPageIndex - 1
    if selectedCandidateIndex == 0 { return true }
    selectedCandidateIndex = max(selectedCandidateIndex - keyCount, 0)
    switch currentLayout {
      case .horizontal:
        moveUp(self)
      case .vertical:
        moveLeft(self)
    }
    return true
  }

  public func highlightNextCandidate() -> Bool {
    guard let delegate = delegate else { return false }
    selectedCandidateIndex =
      (selectedCandidateIndex + 1 >= delegate.candidateCountForController(self))
      ? 0 : selectedCandidateIndex + 1
    switch currentLayout {
      case .horizontal:
        moveRight(self)
        return true
      case .vertical:
        moveDown(self)
        return true
    }
  }

  public func highlightPreviousCandidate() -> Bool {
    guard let delegate = delegate else { return false }
    selectedCandidateIndex =
      (selectedCandidateIndex == 0)
      ? delegate.candidateCountForController(self) - 1 : selectedCandidateIndex - 1
    switch currentLayout {
      case .horizontal:
        moveLeft(self)
        return true
      case .vertical:
        moveUp(self)
        return true
    }
  }

  public func candidateIndexAtKeyLabelIndex(_ index: Int) -> Int {
    guard let delegate = delegate else {
      return Int.max
    }

    let result = currentPageIndex * keyLabels.count + index
    return result < delegate.candidateCountForController(self) ? result : Int.max
  }

  public var selectedCandidateIndex: Int {
    get {
      selectedCandidate()
    }
    set {
      selectCandidate(withIdentifier: newValue)
    }
  }

  public func set(windowTopLeftPoint: NSPoint, bottomOutOfScreenAdjustmentHeight height: CGFloat) {
    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now()) {
      self.doSet(
        windowTopLeftPoint: windowTopLeftPoint, bottomOutOfScreenAdjustmentHeight: height
      )
    }
  }

  func doSet(windowTopLeftPoint: NSPoint, bottomOutOfScreenAdjustmentHeight height: CGFloat) {
    var adjustedPoint = windowTopLeftPoint
    var adjustedHeight = height

    var screenFrame = NSScreen.main?.visibleFrame ?? NSRect.zero
    for screen in NSScreen.screens {
      let frame = screen.visibleFrame
      if windowTopLeftPoint.x >= frame.minX, windowTopLeftPoint.x <= frame.maxX,
        windowTopLeftPoint.y >= frame.minY, windowTopLeftPoint.y <= frame.maxY
      {
        screenFrame = frame
        break
      }
    }

    if adjustedHeight > screenFrame.size.height / 2.0 {
      adjustedHeight = 0.0
    }

    let windowSize = candidateFrame().size

    // bottom beneath the screen?
    if adjustedPoint.y - windowSize.height < screenFrame.minY {
      adjustedPoint.y = windowTopLeftPoint.y + adjustedHeight + windowSize.height
    }

    // top over the screen?
    if adjustedPoint.y >= screenFrame.maxY {
      adjustedPoint.y = screenFrame.maxY - 1.0
    }

    // right
    if adjustedPoint.x + windowSize.width >= screenFrame.maxX {
      adjustedPoint.x = screenFrame.maxX - windowSize.width
    }

    // left
    if adjustedPoint.x < screenFrame.minX {
      adjustedPoint.x = screenFrame.minX
    }

    setCandidateFrameTopLeft(adjustedPoint)
  }

  override public func interpretKeyEvents(_ eventArray: [NSEvent]) {
    // 鬼知道為什麼這個函式接收的參數是陣列，但經過測試卻發現這個函式收到的陣列往往內容只有一個。
    // 這也可能是 Objective-C 當中允許接收內容為 nil 的一種方式。
    guard !eventArray.isEmpty else { return }
    var eventArray = eventArray
    let event = eventArray[0]
    let input = InputSignal(event: event)
    guard let delegate = delegate else { return }
    if input.isEsc || input.isBackSpace || input.isDelete || (input.isShiftHold && !input.isSpace) {
      _ = delegate.sharedEventHandler(event)
    } else if input.isSymbolMenuPhysicalKey || input.isSpace {
      if input.isShiftHold {
        switch currentLayout {
          case .horizontal:
            moveUp(self)
          case .vertical:
            moveLeft(self)
        }
      } else {
        switch currentLayout {
          case .horizontal:
            moveDown(self)
          case .vertical:
            moveRight(self)
        }
      }
    } else if input.isTab {
      switch currentLayout {
        case .horizontal:
          if input.isShiftHold {
            moveLeft(self)
          } else {
            moveRight(self)
          }
        case .vertical:
          if input.isShiftHold {
            moveUp(self)
          } else {
            moveDown(self)
          }
      }
    } else {
      if let newChar = defaultIMKSelectionKey[event.keyCode] {
        /// 根據 KeyCode 重新換算一下選字鍵的 NSEvent，糾正其 Character 數值。
        /// 反正 IMK 選字窗目前也沒辦法修改選字鍵。
        let newEvent = NSEvent.keyEvent(
          with: event.type,
          location: event.locationInWindow,
          modifierFlags: event.modifierFlags,
          timestamp: event.timestamp,
          windowNumber: event.windowNumber,
          context: nil,
          characters: newChar,
          charactersIgnoringModifiers: event.charactersIgnoringModifiers ?? event.characters ?? "",
          isARepeat: event.isARepeat,
          keyCode: event.keyCode
        )
        if let newEvent = newEvent {
          /// 這裡不用診斷了，檢出的內容都是經過轉換之後的正確 NSEvent。
          eventArray = Array(eventArray.dropFirst(0))
          eventArray.insert(newEvent, at: 0)
        }
        perform(Selector(("handleKeyboardEvent:")), with: newEvent)
        return
      }

      if mgrPrefs.useSCPCTypingMode {
        if !input.isReservedKey {
          _ = delegate.sharedEventHandler(event)
          return
        }
      }

      if delegate.isAssociatedPhrasesState,
        !input.isPageUp, !input.isPageDown, !input.isCursorForward, !input.isCursorBackward,
        !input.isCursorClockLeft, !input.isCursorClockRight, !input.isSpace,
        !input.isEnter || !mgrPrefs.alsoConfirmAssociatedCandidatesByEnter
      {
        _ = delegate.sharedEventHandler(event)
        return
      }
      super.interpretKeyEvents(eventArray)
    }
  }
}

// MARK: - Generate TISInputSource Object

/// 該參數只用來獲取 "com.apple.keylayout.ABC" 對應的 TISInputSource，
/// 所以少寫了很多在這裡用不到的東西。
/// 想參考完整版的話，請洽該專案內的 IME.swift。
var currentTISInputSource: TISInputSource? {
  var result: TISInputSource?
  let list = TISCreateInputSourceList(nil, true).takeRetainedValue() as! [TISInputSource]
  let matchedTISString = "com.apple.keylayout.ABC"
  for source in list {
    guard let ptrCat = TISGetInputSourceProperty(source, kTISPropertyInputSourceCategory) else { continue }
    let category = Unmanaged<CFString>.fromOpaque(ptrCat).takeUnretainedValue()
    guard category == kTISCategoryKeyboardInputSource else { continue }
    guard let ptrSourceID = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) else { continue }
    let sourceID = String(Unmanaged<CFString>.fromOpaque(ptrSourceID).takeUnretainedValue())
    if sourceID == matchedTISString { result = source }
  }
  return result
}
