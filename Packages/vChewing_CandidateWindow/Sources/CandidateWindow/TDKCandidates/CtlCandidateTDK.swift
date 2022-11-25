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
  public var maxLinesPerPage: Int = 0

  private static var thePoolHorizontal: CandidatePool = .init(candidates: [], rowCapacity: 6)
  private static var thePoolVertical: CandidatePool = .init(candidates: [], columnCapacity: 6)
  private static var currentView: NSView = .init()

  @available(macOS 12, *)
  private var theViewHorizontal: some View {
    VwrCandidateHorizontal(
      controller: self, thePool: Self.thePoolHorizontal,
      tooltip: tooltip, reverseLookupResult: reverseLookupResult
    ).edgesIgnoringSafeArea(.top)
  }

  @available(macOS 12, *)
  private var theViewVertical: some View {
    VwrCandidateVertical(
      controller: self, thePool: Self.thePoolVertical,
      tooltip: tooltip, reverseLookupResult: reverseLookupResult
    ).edgesIgnoringSafeArea(.top)
  }

  private var theViewHorizontalBackports: some View {
    VwrCandidateHorizontalBackports(
      controller: self, thePool: Self.thePoolHorizontal,
      tooltip: tooltip, reverseLookupResult: reverseLookupResult
    ).edgesIgnoringSafeArea(.top)
  }

  private var theViewVerticalBackports: some View {
    VwrCandidateVerticalBackports(
      controller: self, thePool: Self.thePoolVertical,
      tooltip: tooltip, reverseLookupResult: reverseLookupResult
    ).edgesIgnoringSafeArea(.top)
  }

  private var thePool: CandidatePool {
    get {
      switch currentLayout {
        case .horizontal: return Self.thePoolHorizontal
        case .vertical: return Self.thePoolVertical
        @unknown default: return .init(candidates: [], rowCapacity: 0)
      }
    }
    set {
      switch currentLayout {
        case .horizontal: Self.thePoolHorizontal = newValue
        case .vertical: Self.thePoolVertical = newValue
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
        Self.thePoolHorizontal = .init(
          candidates: delegate.candidatePairs(conv: true).map(\.1), rowCapacity: 6,
          rows: maxLinesPerPage, selectionKeys: delegate.selectionKeys, locale: locale
        )
        Self.thePoolHorizontal.highlight(at: 0)
      case .vertical:
        Self.thePoolVertical = .init(
          candidates: delegate.candidatePairs(conv: true).map(\.1), columnCapacity: 6,
          columns: maxLinesPerPage, selectionKeys: delegate.selectionKeys, locale: locale
        )
        Self.thePoolVertical.highlight(at: 0)
      @unknown default:
        return
    }
    updateDisplay()
  }

  override open func updateDisplay() {
    guard let window = window else { return }
    reverseLookupResult = delegate?.reverseLookup(for: currentSelectedCandidateText) ?? []
    switch currentLayout {
      case .horizontal:
        DispatchQueue.main.async { [self] in
          if #available(macOS 12, *) {
            Self.currentView = NSHostingView(rootView: theViewHorizontal)
          } else {
            Self.currentView = NSHostingView(rootView: theViewHorizontalBackports)
          }
          let newSize = Self.currentView.fittingSize
          window.contentView = Self.currentView
          window.setContentSize(newSize)
        }
      case .vertical:
        DispatchQueue.main.async { [self] in
          if #available(macOS 12, *) {
            Self.currentView = NSHostingView(rootView: theViewVertical)
          } else {
            Self.currentView = NSHostingView(rootView: theViewVerticalBackports)
          }
          let newSize = Self.currentView.fittingSize
          window.contentView = Self.currentView
          window.setContentSize(newSize)
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
    if !(0..<arrCurrentLine.count).contains(id) { return -114_514 }
    let actualID = max(0, min(id, arrCurrentLine.count - 1))
    return arrCurrentLine[actualID].index
  }

  override public var highlightedIndex: Int {
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

  private var currentSelectedCandidateText: String {
    if thePool.candidateDataAll.count > highlightedIndex {
      return thePool.candidateDataAll[highlightedIndex].displayedText
    }
    return ""
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
