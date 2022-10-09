// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Cocoa
import Shared

open class CtlCandidate: NSWindowController, CtlCandidateProtocol {
  open var tooltip: String = ""
  open var currentLayout: NSUserInterfaceLayoutOrientation = .horizontal
  open var locale: String = ""
  open var useLangIdentifier: Bool = false

  open func highlightedColor() -> NSColor {
    var result = NSColor.alternateSelectedControlColor
    var colorBlendAmount: Double = NSApplication.isDarkMode ? 0.3 : 0.0
    if #available(macOS 10.14, *), !NSApplication.isDarkMode, locale == "zh-Hant" {
      colorBlendAmount = 0.15
    }
    // 設定當前高亮候選字的背景顏色。
    switch locale {
      case "zh-Hans":
        result = NSColor.systemRed
      case "zh-Hant":
        result = NSColor.systemBlue
      case "ja":
        result = NSColor.systemBrown
      default: break
    }
    var blendingAgainstTarget: NSColor = NSApplication.isDarkMode ? NSColor.black : NSColor.white
    if #unavailable(macOS 10.14) {
      colorBlendAmount = 0.3
      blendingAgainstTarget = NSColor.white
    }
    return result.blended(withFraction: colorBlendAmount, of: blendingAgainstTarget)!
  }

  open weak var delegate: CtlCandidateDelegate? {
    didSet {
      reloadData()
    }
  }

  open var windowTopLeftPoint: NSPoint {
    get {
      guard let frameRect = window?.frame else { return NSPoint.zero }
      return NSPoint(x: frameRect.minX, y: frameRect.maxY)
    }
    set {
      DispatchQueue.main.async {
        self.set(windowTopLeftPoint: newValue, bottomOutOfScreenAdjustmentHeight: 0)
      }
    }
  }

  open var selectedCandidateIndex: Int = .max
  open var visible = false {
    didSet {
      NSObject.cancelPreviousPerformRequests(withTarget: self)
      DispatchQueue.main.async { [self] in
        _ = visible ? window?.orderFront(self) : window?.orderOut(self)
      }
    }
  }

  public required init(_: NSUserInterfaceLayoutOrientation = .horizontal) {
    super.init(window: .init())
    visible = false
  }

  /// 設定選字窗的顯示位置。
  ///
  /// 需注意：該函數會藉由設定選字窗左上角頂點的方式、使選字窗始終位於某個螢幕之內。
  ///
  /// - Parameters:
  ///   - windowTopLeftPoint: 給定的視窗顯示位置。
  ///   - heightDelta: 為了「防止選字窗抻出螢幕下方」而給定的預留高度。
  public func set(windowTopLeftPoint: NSPoint, bottomOutOfScreenAdjustmentHeight heightDelta: Double) {
    DispatchQueue.main.async { [self] in
      guard let window = window, var screenFrame = NSScreen.main?.visibleFrame else { return }
      let windowSize = window.frame.size

      var adjustedPoint = windowTopLeftPoint
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

      window.setFrameTopLeftPoint(adjustedPoint)
    }
  }

  // MARK: - 不需要在這裡仔細實作的內容。

  @available(*, unavailable)
  public required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  open var candidateFont = NSFont.systemFont(ofSize: 18)

  @discardableResult open func showNextLine() -> Bool {
    false
  }

  @discardableResult open func showPreviousLine() -> Bool {
    false
  }

  @discardableResult open func highlightNextCandidate() -> Bool {
    false
  }

  @discardableResult open func highlightPreviousCandidate() -> Bool {
    false
  }

  @discardableResult open func showNextPage() -> Bool {
    false
  }

  @discardableResult open func showPreviousPage() -> Bool {
    false
  }

  open func candidateIndexAtKeyLabelIndex(_: Int) -> Int {
    Int.max
  }

  open func reloadData() {}

  open func updateDisplay() {}
}
