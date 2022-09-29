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
  public var thePoolHorizontal: CandidatePool = .init(candidates: [], rowCapacity: 6)
  public var theViewHorizontal: VwrCandidateHorizontal {
    .init(controller: self, thePool: thePoolHorizontal, hint: hint)
  }

  public var thePoolVertical: CandidatePool = .init(candidates: [], columnCapacity: 6)
  public var theViewVertical: VwrCandidateVertical { .init(controller: self, thePool: thePoolVertical, hint: hint) }
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
    switch currentLayout {
      case .horizontal:
        thePoolHorizontal = .init(
          candidates: delegate.candidatePairs(conv: true).map(\.1), rowCapacity: 6,
          selectionKeys: delegate.selectionKeys, locale: locale
        )
        thePoolHorizontal.highlightHorizontal(at: 0)
      case .vertical:
        thePoolVertical = .init(
          candidates: delegate.candidatePairs(conv: true).map(\.1), columnCapacity: 6,
          selectionKeys: delegate.selectionKeys, locale: locale
        )
        thePoolVertical.highlightVertical(at: 0)
      @unknown default:
        return
    }
    updateDisplay()
  }

  override open func updateDisplay() {
    switch currentLayout {
      case .horizontal:
        DispatchQueue.main.async { [self] in
          let newView = NSHostingView(rootView: theViewHorizontal)
          let newSize = newView.fittingSize
          window?.contentView = newView
          window?.setContentSize(newSize)
        }
      case .vertical:
        DispatchQueue.main.async { [self] in
          let newView = NSHostingView(rootView: theViewVertical)
          let newSize = newView.fittingSize
          window?.contentView = newView
          window?.setContentSize(newSize)
        }
      @unknown default:
        return
    }
  }

  @discardableResult override public func showNextPage() -> Bool {
    switch currentLayout {
      case .horizontal:
        for _ in 0..<thePoolHorizontal.maximumRowsPerPage {
          thePoolHorizontal.selectNewNeighborRow(direction: .down)
        }
      case .vertical:
        for _ in 0..<thePoolVertical.maximumColumnsPerPage {
          thePoolVertical.selectNewNeighborColumn(direction: .right)
        }
      @unknown default:
        return false
    }
    updateDisplay()
    return true
  }

  @discardableResult override public func showPreviousPage() -> Bool {
    switch currentLayout {
      case .horizontal:
        for _ in 0..<thePoolHorizontal.maximumRowsPerPage {
          thePoolHorizontal.selectNewNeighborRow(direction: .up)
        }
      case .vertical:
        for _ in 0..<thePoolVertical.maximumColumnsPerPage {
          thePoolVertical.selectNewNeighborColumn(direction: .left)
        }
      @unknown default:
        return false
    }
    updateDisplay()
    return true
  }

  @discardableResult override public func showNextLine() -> Bool {
    switch currentLayout {
      case .horizontal:
        thePoolHorizontal.selectNewNeighborRow(direction: .down)
      case .vertical:
        thePoolVertical.selectNewNeighborColumn(direction: .right)
      @unknown default:
        return false
    }
    updateDisplay()
    return true
  }

  @discardableResult override public func showPreviousLine() -> Bool {
    switch currentLayout {
      case .horizontal:
        thePoolHorizontal.selectNewNeighborRow(direction: .up)
      case .vertical:
        thePoolVertical.selectNewNeighborColumn(direction: .left)
      @unknown default:
        return false
    }
    updateDisplay()
    return true
  }

  @discardableResult override public func highlightNextCandidate() -> Bool {
    switch currentLayout {
      case .horizontal:
        thePoolHorizontal.highlightHorizontal(at: thePoolHorizontal.highlightedIndex + 1)
      case .vertical:
        thePoolVertical.highlightVertical(at: thePoolVertical.highlightedIndex + 1)
      @unknown default:
        return false
    }
    updateDisplay()
    return true
  }

  @discardableResult override public func highlightPreviousCandidate() -> Bool {
    switch currentLayout {
      case .horizontal:
        thePoolHorizontal.highlightHorizontal(at: thePoolHorizontal.highlightedIndex - 1)
      case .vertical:
        thePoolVertical.highlightVertical(at: thePoolVertical.highlightedIndex - 1)
      @unknown default:
        return false
    }
    updateDisplay()
    return true
  }

  override public func candidateIndexAtKeyLabelIndex(_ id: Int) -> Int {
    switch currentLayout {
      case .horizontal:
        let currentRow = thePoolHorizontal.candidateRows[thePoolHorizontal.currentRowNumber]
        let actualID = max(0, min(id, currentRow.count - 1))
        return thePoolHorizontal.candidateRows[thePoolHorizontal.currentRowNumber][actualID].index
      case .vertical:
        let currentColumn = thePoolVertical.candidateColumns[thePoolVertical.currentColumnNumber]
        let actualID = max(0, min(id, currentColumn.count - 1))
        return thePoolVertical.candidateColumns[thePoolVertical.currentColumnNumber][actualID].index
      @unknown default:
        return 0
    }
  }

  override public var selectedCandidateIndex: Int {
    get {
      switch currentLayout {
        case .horizontal: return thePoolHorizontal.highlightedIndex
        case .vertical: return thePoolVertical.highlightedIndex
        @unknown default: return 0
      }
    }
    set {
      switch currentLayout {
        case .horizontal: thePoolHorizontal.highlightHorizontal(at: newValue)
        case .vertical: thePoolVertical.highlightVertical(at: newValue)
        @unknown default: return
      }
      updateDisplay()
    }
  }
}
