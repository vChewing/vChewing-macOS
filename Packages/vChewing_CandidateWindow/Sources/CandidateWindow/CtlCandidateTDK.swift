// (c) 2022 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Cocoa
import CocoaExtension
import Shared
import SwiftUI

@available(macOS 12, *)
public class CtlCandidateTDK: CtlCandidate {
  public var thePool: CandidatePool = .init(candidates: [])
  public var theView: VwrCandidateTDK { .init(controller: self, thePool: thePool, hint: hint) }
  public required init(_ layout: NSUserInterfaceLayoutOrientation = .horizontal) {
    var contentRect = NSRect(x: 128.0, y: 128.0, width: 0.0, height: 0.0)
    let styleMask: NSWindow.StyleMask = [.nonactivatingPanel]
    let panel = NSPanel(
      contentRect: contentRect, styleMask: styleMask, backing: .buffered, defer: false
    )
    panel.level = NSWindow.Level(Int(kCGPopUpMenuWindowLevel) + 2)
    panel.hasShadow = true
    panel.isOpaque = false
    panel.backgroundColor = NSColor.clear

    contentRect.origin = NSPoint.zero

    super.init(layout)
    window = panel
    currentLayout = layout
    reloadData()
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override public func reloadData() {
    CandidateCellData.highlightBackground = highlightedColor()
    CandidateCellData.unifiedSize = candidateFont.pointSize
    guard let delegate = delegate else { return }
    thePool = .init(
      candidates: delegate.candidatePairs(conv: true).map(\.1),
      selectionKeys: delegate.selectionKeys, locale: locale
    )
    thePool.highlight(at: 0)
    updateDisplay()
  }

  override open func updateDisplay() {
    DispatchQueue.main.async { [self] in
      let newView = NSHostingView(rootView: theView.fixedSize())
      let newSize = newView.fittingSize
      var newFrame = NSRect.zero
      if let window = window { newFrame = window.frame }
      newFrame.size = newSize
      window?.setFrame(newFrame, display: false)
      window?.contentView = NSHostingView(rootView: theView.fixedSize())
      window?.setContentSize(newSize)
    }
  }

  @discardableResult override public func showNextPage() -> Bool {
    thePool.selectNewNeighborRow(direction: .down)
    updateDisplay()
    return true
  }

  @discardableResult override public func showPreviousPage() -> Bool {
    thePool.selectNewNeighborRow(direction: .up)
    updateDisplay()
    return true
  }

  @discardableResult override public func highlightNextCandidate() -> Bool {
    thePool.highlight(at: thePool.highlightedIndex + 1)
    updateDisplay()
    return true
  }

  @discardableResult override public func highlightPreviousCandidate() -> Bool {
    thePool.highlight(at: thePool.highlightedIndex - 1)
    updateDisplay()
    return true
  }

  override public func candidateIndexAtKeyLabelIndex(_ id: Int) -> Int {
    let currentRow = thePool.candidateRows[thePool.currentRowNumber]
    let actualID = max(0, min(id, currentRow.count - 1))
    return thePool.candidateRows[thePool.currentRowNumber][actualID].index
  }

  override public var selectedCandidateIndex: Int {
    get {
      thePool.highlightedIndex
    }
    set {
      thePool.highlight(at: newValue)
      updateDisplay()
    }
  }
}
