// (c) 2022 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import AppKit
import Shared_DarwinImpl

// MARK: - VwrCandidateTDKAppKit

/// 田所選字窗的 AppKit 简单版本，繪製效率不受 SwiftUI 的限制。
/// 該版本可以使用更少的系統資源來繪製選字窗。

public final class VwrCandidateTDKAppKit: NSView {
  // MARK: Lifecycle

  // MARK: - Constructors.

  public init(controller: CtlCandidateTDK? = nil, thePool pool: CandidatePool) {
    self.controller = controller
    self.thePool = pool
    thePool.updateMetrics()
    super.init(frame: .init(origin: .zero, size: .init(width: 114_514, height: 114_514)))
  }

  deinit {
    theMenu?.cancelTrackingWithoutAnimation()
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // MARK: Public

  public weak var controller: CtlCandidateTDK?
  public var thePool: CandidatePool

  // MARK: Internal

  var action: Selector?
  weak var target: AnyObject?
  var theMenu: NSMenu?
  var clickedCell: CandidateCellData = CandidatePool.shitCell

  // MARK: - Variables used for rendering the UI.

  var padding: CGFloat { thePool.padding }
  var originDelta: CGFloat { thePool.originDelta }
  var cellRadius: CGFloat { thePool.cellRadius }
  var windowRadius: CGFloat { thePool.windowRadius }
  var isMatrix: Bool { thePool.isMatrix }

  // MARK: Private

  private let prefs = PrefMgr()
  private var dimension: CGSize = .zero
}

// MARK: - Interface Renderer (with shared public variables).

extension VwrCandidateTDKAppKit {
  override public var isFlipped: Bool { true }

  override public var fittingSize: CGSize { thePool.metrics.fittingSize }

  public static var candidateListBackground: NSColor {
    let brightBackground = NSColor(red: 0.99, green: 0.99, blue: 0.99, alpha: 1.00)
    let darkBackground = NSColor(red: 0.13, green: 0.13, blue: 0.14, alpha: 1.00)
    return NSApplication.isDarkMode ? darkBackground : brightBackground
  }

  override public func draw(_: CGRect) {
    let sizesCalculated = thePool.metrics
    let alphaRatio = NSApplication.isDarkMode ? 0.75 : 1
    var themeColor: NSColor?
    if let delegate = controller?.delegate as? CtlCandidateDelegate,
       var hsba = delegate.clientAccentColor {
      hsba.alpha = alphaRatio
      themeColor = hsba.nsColor
      CandidatePool.shitCell.clientThemeColor = themeColor
    } else {
      CandidatePool.shitCell.clientThemeColor = prefs.respectClientAccentColor
        ? NSColor.accentColor.withAlphaComponent(alphaRatio)
        : nil
      themeColor = CandidatePool.shitCell.clientThemeColor
    }
    // 先塗底色
    if #available(macOS 10.13, *) {
      Self.candidateListBackground
        .withAlphaComponent(NSApplication.uxLevel == .none ? 1 : 0.5)
        .setFill()
    } else {
      Self.candidateListBackground.setFill()
    }
    let allRect = CGRect(origin: .zero, size: sizesCalculated.fittingSize)
    NSBezierPath(roundedRect: allRect, xRadius: windowRadius, yRadius: windowRadius).fill()
    // 繪製高亮行背景與高亮候選字詞背景
    lineBackground(isCurrentLine: true, isMatrix: isMatrix).setFill()
    NSBezierPath(
      roundedRect: sizesCalculated.highlightedLine,
      xRadius: cellRadius,
      yRadius: cellRadius
    ).fill()
    var cellHighlightedDrawn = false
    // 開始繪製候選字詞
    let allCells = thePool.candidateLines[thePool.lineRangeForCurrentPage].flatMap { $0 }
    allCells.forEach { currentCell in
      if currentCell.isHighlighted, !cellHighlightedDrawn {
        (themeColor ?? currentCell.themeColorCocoa).setFill()
        NSBezierPath(
          roundedRect: sizesCalculated.highlightedCandidate,
          xRadius: cellRadius,
          yRadius: cellRadius
        ).fill()
        cellHighlightedDrawn = true
      }
      currentCell.attributedStringHeader.draw(
        at:
        .init(
          x: currentCell.visualOrigin.x + 2 * padding,
          y: currentCell.visualOrigin.y + ceil(currentCell.visualDimension.height * 0.2)
        )
      )
      currentCell.attributedStringPhrase(isMatrix: false).draw(
        at: .init(
          x: currentCell.visualOrigin.x + 2 * padding + ceil(currentCell.size * 0.6),
          y: currentCell.visualOrigin.y + padding
        )
      )
    }
    // 繪製附加內容
    let strPeripherals = thePool.attributedDescriptionBottomPanes
    strPeripherals.draw(at: sizesCalculated.peripherals.origin)
  }
}

// MARK: - Mouse Interaction Handlers.

extension VwrCandidateTDKAppKit {
  private func findCell(from mouseEvent: NSEvent) -> Int? {
    var clickPoint = convert(mouseEvent.locationInWindow, to: self)
    clickPoint.y = bounds.height - clickPoint.y // 翻轉座標系
    guard bounds.contains(clickPoint) else { return nil }
    let flattenedCells = thePool.candidateLines[thePool.lineRangeForCurrentPage].flatMap { $0 }
    let filteredData: [CandidateCellData] = flattenedCells.filter { theCell in
      CGRect(origin: theCell.visualOrigin, size: theCell.visualDimension).contains(clickPoint)
    }
    guard let firstValidCell = filteredData.first else { return nil }
    return firstValidCell.index
  }

  override public func mouseDown(with event: NSEvent) {
    guard let cellIndex = findCell(from: event) else { return }
    guard cellIndex != thePool.highlightedIndex else { return }
    thePool.highlight(at: cellIndex)
    thePool.updateMetrics()
    setNeedsDisplay(bounds)
  }

  override public func mouseDragged(with event: NSEvent) {
    mouseDown(with: event)
  }

  override public func mouseUp(with event: NSEvent) {
    guard let cellIndex = findCell(from: event) else { return }
    didSelectCandidateAt(cellIndex)
  }

  override public func rightMouseUp(with event: NSEvent) {
    guard let cellIndex = findCell(from: event) else { return }
    guard let delegate = controller?.delegate else { return }
    clickedCell = thePool.candidateDataAll[cellIndex]
    let index = clickedCell.index
    let candidateText = clickedCell.displayedText
    let isEnabled: Bool = delegate.isCandidateContextMenuEnabled
    let isMacroToken = delegate.checkIsMacroTokenResult(index)
    guard isEnabled, !candidateText.isEmpty, !isMacroToken, index >= 0 else { return }
    prepareMenu()
    var clickPoint = convert(event.locationInWindow, to: self)
    clickPoint.y = bounds.height - clickPoint.y // 翻轉座標系
    theMenu?.popUp(positioning: nil, at: clickPoint, in: self)
  }
}

// MARK: - Context Menu.

extension VwrCandidateTDKAppKit {
  private func prepareMenu() {
    let newMenu = NSMenu()
    newMenu.appendItems(self) {
      NSMenu.Item(
        verbatim: "↑ \(clickedCell.displayedText)"
      )?.act(#selector(menuActionOfBoosting(_:)))
      NSMenu.Item(
        verbatim: "↓ \(clickedCell.displayedText)"
      )?.act(#selector(menuActionOfNerfing(_:)))
      NSMenu.Item(
        verbatim: "✖︎ \(clickedCell.displayedText)"
      )?.act(#selector(menuActionOfFiltering(_:)))
        .nulled(!thePool.isFilterable(target: clickedCell.index))
    }

    theMenu = newMenu
    CtlCandidateTDK.currentMenu = newMenu
  }

  @objc
  fileprivate func menuActionOfBoosting(_: Any? = nil) {
    didTriggerCandidatePairContextMenuActionAt(clickedCell.index, action: .toBoost)
  }

  @objc
  fileprivate func menuActionOfNerfing(_: Any? = nil) {
    didTriggerCandidatePairContextMenuActionAt(clickedCell.index, action: .toNerf)
  }

  @objc
  fileprivate func menuActionOfFiltering(_: Any? = nil) {
    didTriggerCandidatePairContextMenuActionAt(clickedCell.index, action: .toFilter)
  }
}

// MARK: - Delegate Methods

extension VwrCandidateTDKAppKit {
  fileprivate func didSelectCandidateAt(_ pos: Int) {
    controller?.delegate?.candidatePairSelectionConfirmed(at: pos)
  }

  fileprivate func didTriggerCandidatePairContextMenuActionAt(
    _ pos: Int, action: CandidateContextMenuAction
  ) {
    controller?.delegate?.candidatePairContextMenuActionTriggered(
      at: pos, action: action
    )
  }
}

// MARK: - Extracted Internal Methods for UI Rendering.

extension VwrCandidateTDKAppKit {
  private func lineBackground(isCurrentLine: Bool, isMatrix: Bool) -> NSColor {
    guard isCurrentLine, isMatrix else { return .clear }
    return CandidateCellData.plainTextColor.withAlphaComponent(0.05)
  }

  private var finalContainerOrientation: NSUserInterfaceLayoutOrientation {
    if thePool.maxLinesPerPage == 1, thePool.layout == .horizontal { return .horizontal }
    return .vertical
  }
}

// MARK: - Debug Module Using Swift UI.

import SwiftUI

// MARK: - VwrCandidateTDKAppKitForSwiftUI

@available(macOS 10.15, *)
public struct VwrCandidateTDKAppKitForSwiftUI: NSViewRepresentable {
  public weak var controller: CtlCandidateTDK?
  public var thePool: CandidatePool

  public func makeNSView(context _: Context) -> VwrCandidateTDKAppKit {
    let nsView = VwrCandidateTDKAppKit(thePool: thePool)
    nsView.controller = controller
    return nsView
  }

  public func updateNSView(_ nsView: VwrCandidateTDKAppKit, context _: Context) {
    nsView.thePool = thePool
  }
}
