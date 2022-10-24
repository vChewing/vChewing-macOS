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
  open var reverseLookupResult: [String] = []

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

  open var delegate: CtlCandidateDelegate? {
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
        self.set(windowTopLeftPoint: newValue, bottomOutOfScreenAdjustmentHeight: 0, useGCD: true)
      }
    }
  }

  open var highlightedIndex: Int = .max
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

  // MARK: - 不需要在這裡仔細實作的內容。

  @available(*, unavailable)
  public required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  open var candidateFont = NSFont.systemFont(
    ofSize: min(196, max(12, Double(UserDefaults.standard.integer(forKey: "CandidateListTextSize"))))
  )

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
