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
  open var showPageButtons: Bool = false
  open var currentLayout: CandidateLayout = .horizontal
  open var locale: String = ""
  open var useLangIdentifier: Bool = false

  open func highlightedColor() -> NSColor {
    var result = NSColor.alternateSelectedControlColor
    var colorBlendAmount: Double = NSApplication.isDarkMode ? 0.3 : 0.0
    if #available(macOS 10.14, *), !NSApplication.isDarkMode, locale == "zh-Hant" {
      colorBlendAmount = 0.15
    }
    // The background color of the highlightened candidate
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

  public required init(_: CandidateLayout = .horizontal) {
    super.init(window: .init())
    visible = false
  }

  /// Sets the location of the candidate window.
  ///
  /// Please note that the method has side effects that modifies
  /// `windowTopLeftPoint` to make the candidate window to stay in at least
  /// in a screen.
  ///
  /// - Parameters:
  ///   - windowTopLeftPoint: The given location.
  ///   - height: The height that helps the window not to be out of the bottom
  ///     of a screen.
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

  // MARK: - Contents that are not needed to be implemented here.

  @available(*, unavailable)
  public required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  open var keyLabels: [CandidateKeyLabel] = ["1", "2", "3", "4", "5", "6", "7", "8", "9"]
    .map {
      CandidateKeyLabel(key: $0, displayedText: $0)
    }

  open var candidateFont = NSFont.systemFont(ofSize: 18)
  open var keyLabelFont = NSFont.monospacedDigitSystemFont(ofSize: 14, weight: .medium)

  open var tooltip: String = ""

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
}
