// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import CandidateWindow
import Shared

/// 威注音自用的 IMKCandidates 型別。因為有用到 bridging header，所以無法弄成 Swift Package。
public class CtlCandidateIMK: IMKCandidates, CtlCandidateProtocol {
  public var tooltip: String = ""
  public var locale: String = ""
  public var useLangIdentifier: Bool = false
  public var currentLayout: NSUserInterfaceLayoutOrientation = .horizontal
  public static let defaultIMKSelectionKey: [UInt16: String] = [
    18: "1", 19: "2", 20: "3", 21: "4", 23: "5", 22: "6", 26: "7", 28: "8", 25: "9",
  ]
  public var delegate: CtlCandidateDelegate? {
    didSet {
      reloadData()
    }
  }

  public var visible: Bool {
    get { isVisible() }
    set { newValue ? show() : hide() }
  }

  public var windowTopLeftPoint: NSPoint {
    get {
      let frameRect = candidateFrame()
      return NSPoint(x: frameRect.minX, y: frameRect.maxY)
    }
    set {
      DispatchQueue.main.async {
        self.set(windowTopLeftPoint: newValue, bottomOutOfScreenAdjustmentHeight: 0)
      }
    }
  }

  public var candidateFont = NSFont.systemFont(ofSize: 16) {
    didSet {
      if #available(macOS 10.14, *) { setFontSize(candidateFont.pointSize) }
      var attributes = attributes()
      // FB11300759: Set "NSAttributedString.Key.font" doesn't work.
      attributes?[NSAttributedString.Key.font] = candidateFont
      if #available(macOS 12.0, *) {
        if useLangIdentifier {
          attributes?[NSAttributedString.Key.languageIdentifier] = locale as AnyObject
        }
      }
      setAttributes(attributes)
      update()
    }
  }

  public func specifyLayout(_ layout: NSUserInterfaceLayoutOrientation = .horizontal) {
    currentLayout = layout
    switch currentLayout {
      case .horizontal:
        if #available(macOS 10.14, *) {
          setPanelType(kIMKScrollingGridCandidatePanel)
        } else {
          // macOS 10.13 High Sierra 的矩陣選字窗不支援選字鍵，所以只能弄成橫版單行。
          setPanelType(kIMKSingleRowSteppingCandidatePanel)
        }
      case .vertical:
        setPanelType(kIMKSingleColumnScrollingCandidatePanel)
      @unknown default:
        setPanelType(kIMKSingleRowSteppingCandidatePanel)
    }
  }

  public func updateDisplay() {}

  public required init(_ layout: NSUserInterfaceLayoutOrientation = .horizontal) {
    super.init(server: theServer, panelType: kIMKScrollingGridCandidatePanel)
    specifyLayout(layout)
    // 設為 true 表示先交給 ctlIME 處理
    setAttributes([IMKCandidatesSendServerKeyEventFirst: true])
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
    selectedCandidateIndex = 0
    update()
  }

  /// 幹話：這裡很多函式內容亂寫也都無所謂了，因為都被 IMKCandidates 代管執行。
  /// 對於所有 IMK 選字窗的選字判斷動作，不是在 keyHandler 中，而是在 `ctlIME_Core` 中。

  // 該函式會影響 IMK 選字窗。
  @discardableResult public func showNextPage() -> Bool {
    do { currentLayout == .vertical ? moveRight(self) : moveDown(self) }
    return true
  }

  // 該函式會影響 IMK 選字窗。
  @discardableResult public func showPreviousPage() -> Bool {
    do { currentLayout == .vertical ? moveLeft(self) : moveUp(self) }
    return true
  }

  // 該函式會影響 IMK 選字窗。
  @discardableResult public func highlightNextCandidate() -> Bool {
    do { currentLayout == .vertical ? moveDown(self) : moveRight(self) }
    return true
  }

  // 該函式會影響 IMK 選字窗。
  @discardableResult public func highlightPreviousCandidate() -> Bool {
    do { currentLayout == .vertical ? moveUp(self) : moveLeft(self) }
    return true
  }

  // 該函式會影響 IMK 選字窗。
  public func showNextLine() -> Bool {
    do { currentLayout == .vertical ? moveRight(self) : moveDown(self) }
    return true
  }

  // 該函式會影響 IMK 選字窗。
  public func showPreviousLine() -> Bool {
    do { currentLayout == .vertical ? moveLeft(self) : moveUp(self) }
    return true
  }

  // IMK 選字窗目前無法實作該函式。威注音 IMK 選字窗目前也不需要使用該函式。
  public func candidateIndexAtKeyLabelIndex(_: Int) -> Int { 0 }

  public var selectedCandidateIndex: Int {
    get { selectedCandidate() }
    set { selectCandidate(withIdentifier: newValue) }
  }

  public func set(windowTopLeftPoint: NSPoint, bottomOutOfScreenAdjustmentHeight height: Double) {
    DispatchQueue.main.async {
      self.doSet(windowTopLeftPoint: windowTopLeftPoint, bottomOutOfScreenAdjustmentHeight: height)
    }
  }

  func doSet(windowTopLeftPoint: NSPoint, bottomOutOfScreenAdjustmentHeight heightDelta: Double) {
    guard var screenFrame = NSScreen.main?.visibleFrame else { return }
    var adjustedPoint = windowTopLeftPoint
    let windowSize = candidateFrame().size
    var delta = heightDelta
    for frame in NSScreen.screens.map(\.visibleFrame).filter({ $0.contains(windowTopLeftPoint) }) {
      screenFrame = frame
      break
    }

    if delta > screenFrame.size.height / 2.0 { delta = 0.0 }

    if adjustedPoint.y < screenFrame.minY + windowSize.height {
      adjustedPoint.y = windowTopLeftPoint.y + windowSize.height + delta
    }
    adjustedPoint.y = min(adjustedPoint.y, screenFrame.maxY - 1.0)
    adjustedPoint.x = min(max(adjustedPoint.x, screenFrame.minX), screenFrame.maxX - windowSize.width - 1.0)

    setCandidateFrameTopLeft(adjustedPoint)
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

// MARK: - Translating NumPad KeyCodes to Default IMK Candidate Selection KeyCodes.

extension CtlCandidateIMK {
  public static func replaceNumPadKeyCodes(target event: NSEvent) -> NSEvent? {
    let mapNumPadKeyCodeTranslation: [UInt16: UInt16] = [
      83: 18, 84: 19, 85: 20, 86: 21, 87: 23, 88: 22, 89: 26, 91: 28, 92: 25,
    ]
    return event.reinitiate(keyCode: mapNumPadKeyCodeTranslation[event.keyCode] ?? event.keyCode)
  }
}
