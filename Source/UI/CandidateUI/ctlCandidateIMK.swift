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
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  public func reloadData() {
    guard let delegate = delegate else { return }
    let candidates = delegate.candidatesForController(self).map { theCandidate -> String in
      let theConverted = IME.kanjiConversionIfRequired(theCandidate.1)
      return (theCandidate.1 == theConverted) ? theCandidate.1 : "\(theConverted)(\(theCandidate.1))"
    }
    setCandidateData(candidates)
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
    pageDownAndModifySelection(self)
    return true
  }

  public func showPreviousPage() -> Bool {
    guard delegate != nil else { return false }
    if pageCount == 1 { return highlightPreviousCandidate() }
    if currentPageIndex == 0 { clsSFX.beep() }
    currentPageIndex = (currentPageIndex == 0) ? pageCount - 1 : currentPageIndex - 1
    if selectedCandidateIndex == 0 { return true }
    selectedCandidateIndex = max(selectedCandidateIndex - keyCount, 0)
    pageUpAndModifySelection(self)
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
    guard !eventArray.isEmpty else { return }
    let event = eventArray[0]
    let input = InputSignal(event: event)
    guard let delegate = delegate else { return }
    if input.isEsc || input.isBackSpace || input.isDelete || input.isShiftHold {
      _ = delegate.handleDelegateEvent(event)
    } else {
      super.interpretKeyEvents(eventArray)
    }
  }
}
