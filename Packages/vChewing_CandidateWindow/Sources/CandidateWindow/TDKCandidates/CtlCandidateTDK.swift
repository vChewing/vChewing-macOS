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

@available(macOS 10.15, *)
public class CtlCandidateTDK: CtlCandidate {
  public var thePoolHorizontal: CandidatePool = .init(candidates: [], rowCapacity: 6)
  public var thePoolVertical: CandidatePool = .init(candidates: [], columnCapacity: 6)

  @available(macOS 12, *)
  public var theViewHorizontal: VwrCandidateHorizontal {
    .init(controller: self, thePool: thePoolHorizontal, tooltip: tooltip)
  }

  @available(macOS 12, *)
  public var theViewVertical: VwrCandidateVertical {
    .init(controller: self, thePool: thePoolVertical, tooltip: tooltip)
  }

  public var theViewHorizontalBackports: VwrCandidateHorizontalBackports {
    .init(controller: self, thePool: thePoolHorizontal, tooltip: tooltip)
  }

  public var theViewVerticalBackports: VwrCandidateVerticalBackports {
    .init(controller: self, thePool: thePoolVertical, tooltip: tooltip)
  }

  public var thePool: CandidatePool {
    get {
      switch currentLayout {
        case .horizontal: return thePoolHorizontal
        case .vertical: return thePoolVertical
        @unknown default: return .init(candidates: [], rowCapacity: 0)
      }
    }
    set {
      switch currentLayout {
        case .horizontal: thePoolHorizontal = newValue
        case .vertical: thePoolVertical = newValue
        @unknown default: break
      }
    }
  }

  // MARK: - Constructors

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

  // MARK: - Public functions

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
        thePoolHorizontal.highlight(at: 0)
      case .vertical:
        thePoolVertical = .init(
          candidates: delegate.candidatePairs(conv: true).map(\.1), columnCapacity: 6,
          selectionKeys: delegate.selectionKeys, locale: locale
        )
        thePoolVertical.highlight(at: 0)
      @unknown default:
        return
    }
    updateDisplay()
  }

  override open func updateDisplay() {
    switch currentLayout {
      case .horizontal:
        DispatchQueue.main.async { [self] in
          if #available(macOS 12, *) {
            let newView = NSHostingView(rootView: theViewHorizontal)
            let newSize = newView.fittingSize
            window?.contentView = newView
            window?.setContentSize(newSize)
          } else {
            let newView = NSHostingView(rootView: theViewHorizontalBackports)
            let newSize = newView.fittingSize
            window?.contentView = newView
            window?.setContentSize(newSize)
          }
        }
      case .vertical:
        DispatchQueue.main.async { [self] in
          if #available(macOS 12, *) {
            let newView = NSHostingView(rootView: theViewVertical)
            let newSize = newView.fittingSize
            window?.contentView = newView
            window?.setContentSize(newSize)
          } else {
            let newView = NSHostingView(rootView: theViewVerticalBackports)
            let newSize = newView.fittingSize
            window?.contentView = newView
            window?.setContentSize(newSize)
          }
        }
      @unknown default:
        return
    }
  }

  @discardableResult override public func showNextPage() -> Bool {
    showNextLine(count: thePool.maxLinesPerPage)
  }

  @discardableResult override public func showNextLine() -> Bool {
    showNextLine(count: 1)
  }

  public func showNextLine(count: Int) -> Bool {
    if thePool.currentLineNumber == thePool.candidateLines.count - 1 {
      return highlightNextCandidate()
    }
    if count <= 0 { return false }
    for _ in 0..<min(thePool.maxLinesPerPage, count) {
      thePool.selectNewNeighborLine(isForward: true)
    }
    updateDisplay()
    return true
  }

  @discardableResult override public func showPreviousPage() -> Bool {
    showPreviousLine(count: thePool.maxLinesPerPage)
  }

  @discardableResult override public func showPreviousLine() -> Bool {
    showPreviousLine(count: 1)
  }

  public func showPreviousLine(count: Int) -> Bool {
    if thePool.currentLineNumber == 0 {
      return highlightPreviousCandidate()
    }
    if count <= 0 { return false }
    for _ in 0..<min(thePool.maxLinesPerPage, count) {
      thePool.selectNewNeighborLine(isForward: false)
    }
    updateDisplay()
    return true
  }

  @discardableResult override public func highlightNextCandidate() -> Bool {
    if thePool.highlightedIndex == thePool.candidateDataAll.count - 1 {
      thePool.highlight(at: 0)
      updateDisplay()
      return false
    }
    thePool.highlight(at: thePool.highlightedIndex + 1)
    updateDisplay()
    return true
  }

  @discardableResult override public func highlightPreviousCandidate() -> Bool {
    if thePool.highlightedIndex == 0 {
      thePool.highlight(at: thePool.candidateDataAll.count - 1)
      updateDisplay()
      return false
    }
    thePool.highlight(at: thePool.highlightedIndex - 1)
    updateDisplay()
    return true
  }

  override public func candidateIndexAtKeyLabelIndex(_ id: Int) -> Int {
    let arrCurrentLine = thePool.candidateLines[thePool.currentLineNumber]
    let actualID = max(0, min(id, arrCurrentLine.count - 1))
    return arrCurrentLine[actualID].index
  }

  override public var selectedCandidateIndex: Int {
    get { thePool.highlightedIndex }
    set {
      thePool.highlight(at: newValue)
      updateDisplay()
    }
  }
}

@available(macOS 10.15, *)
extension CtlCandidateTDK {
  private var isMontereyAvailable: Bool {
    if #unavailable(macOS 12) { return false }
    return true
  }
}

@available(macOS 10.15, *)
extension CtlCandidateTDK {
  public var highlightedColorUIBackports: some View {
    // 設定當前高亮候選字的背景顏色。
    let result: Color = {
      switch locale {
        case "zh-Hans": return Color.red
        case "zh-Hant": return Color.blue
        case "ja": return Color.pink
        default: return Color.accentColor
      }
    }()
    return result.opacity(0.85)
  }
}
