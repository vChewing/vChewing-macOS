// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import AppKit
import Shared_DarwinImpl
import SwiftExtension

open class CtlCandidate: NSWindowController, CtlCandidateProtocol {
  // MARK: Lifecycle

  public required init(_: UILayoutOrientation = .horizontal) {
    super.init(window: .init())
    self.visible = false
  }

  // MARK: - 不需要在這裡仔細實作的內容。

  @available(*, unavailable)
  public required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // MARK: Open

  open var tooltip: String = ""
  open var currentLayout: UILayoutOrientation = .horizontal
  open var locale: String = ""
  open var useLangIdentifier: Bool = false
  open var reverseLookupResult: [String] = []

  open var highlightedIndex: Int = .max
  open var candidateFont: NSFont = .systemFont(
    ofSize: min(196, max(12, Double(UserDefaults.current.integer(forKey: "CandidateListTextSize"))))
  )

  open var delegate: CtlCandidateDelegateCore? {
    didSet {
      guard let delegate = delegate else { return }
      if delegate.isCandidateState { reloadData() }
    }
  }

  open var windowTopLeftPoint: CGPoint {
    get {
      guard let frameRect = window?.frame else { return CGPoint.zero }
      return CGPoint(x: frameRect.minX, y: frameRect.maxY)
    }
    set {
      asyncOnMain { [weak self] in
        guard let self = self else { return }
        self.set(windowTopLeftPoint: newValue, bottomOutOfScreenAdjustmentHeight: 0, useGCD: true)
      }
    }
  }

  open var visible = false {
    didSet {
      NSObject.cancelPreviousPerformRequests(withTarget: self)
      asyncOnMain { [weak self] in
        guard let self = self else { return }
        _ = self.visible ? self.window?.orderFront(self) : self.window?.orderOut(self)
      }
    }
  }

  open func highlightedColor() -> NSColor {
    var result = NSColor.clear
    if #available(macOS 10.14, *) {
      result = .controlAccentColor
    } else {
      result = .alternateSelectedControlTextColor
    }
    let colorBlendAmount = 0.3
    // 設定當前高亮候選字的背景顏色。
    switch locale {
    case "zh-Hans":
      result = NSColor.red
    case "zh-Hant":
      result = NSColor.blue
    case "ja":
      result = NSColor.brown
    default: break
    }
    let blendingAgainstTarget: NSColor = NSApplication.isDarkMode ? NSColor.black : NSColor.white
    return result.blended(withFraction: colorBlendAmount, of: blendingAgainstTarget)!
  }

  @discardableResult
  open func showNextLine() -> Bool {
    false
  }

  @discardableResult
  open func showPreviousLine() -> Bool {
    false
  }

  @discardableResult
  open func highlightNextCandidate() -> Bool {
    false
  }

  @discardableResult
  open func highlightPreviousCandidate() -> Bool {
    false
  }

  @discardableResult
  open func showNextPage() -> Bool {
    false
  }

  @discardableResult
  open func showPreviousPage() -> Bool {
    false
  }

  open func candidateIndexAtKeyLabelIndex(_: Int) -> Int? {
    Int.max
  }

  open func reloadData() {}

  open func updateDisplay() {}
}
