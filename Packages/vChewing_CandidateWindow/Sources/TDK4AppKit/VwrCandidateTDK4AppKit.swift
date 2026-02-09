// (c) 2022 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import AppKit
import Shared_DarwinImpl

// MARK: - TDK4AppKit.VwrCandidateTDK4AppKit

extension TDK4AppKit {
  // MARK: - VwrCandidateTDK4AppKit

  /// 田所選字窗的 AppKit 简单版本，繪製效率不受 SwiftUI 的限制。
  /// 該版本可以使用更少的系統資源來繪製選字窗。

  final class VwrCandidateTDK4AppKit: NSView {
    // MARK: Lifecycle

    // MARK: - Constructors.

    init(controller: CtlCandidateTDK4AppKit? = nil, thePool pool: CandidatePool4AppKit) {
      self.controller = controller
      self.thePool = pool
      thePool.updateMetrics()
      super.init(frame: .init(origin: .zero, size: .init(width: 114_514, height: 114_514)))
    }

    deinit {
      mainSync {
        theMenu?.cancelTrackingWithoutAnimation()
      }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }

    // MARK: Internal

    typealias CandidateCellData4AppKit = TDK4AppKit.CandidateCellData4AppKit
    typealias CandidatePool4AppKit = TDK4AppKit.CandidatePool4AppKit

    weak var controller: CtlCandidateTDK4AppKit?
    var thePool: CandidatePool4AppKit

    var action: Selector?
    weak var target: AnyObject?
    weak var theMenu: NSMenu?
    var clickedCell: CandidateCellData4AppKit = CandidatePool4AppKit.shitCell

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
} // extension TDK4AppKit

// MARK: - Interface Renderer (with shared variables).

extension TDK4AppKit.VwrCandidateTDK4AppKit {
  override var isFlipped: Bool { true }

  override var fittingSize: CGSize { thePool.metrics.fittingSize }

  static var candidateListBackground: NSColor {
    let brightBackground = NSColor(red: 0.99, green: 0.99, blue: 0.99, alpha: 1.00)
    let darkBackground = NSColor(red: 0.13, green: 0.13, blue: 0.14, alpha: 1.00)
    return NSApplication.isDarkMode ? darkBackground : brightBackground
  }

  override func draw(_: CGRect) {
    let sizesCalculated = thePool.metrics
    let alphaRatio = NSApplication.isDarkMode ? 0.75 : 1
    var themeColor: NSColor?
    if let delegate = controller?.delegate as? CtlCandidateDelegate,
       var hsba = delegate.clientAccentColor {
      hsba.alpha = alphaRatio
      themeColor = hsba.nsColor
      CandidatePool4AppKit.shitCell.clientThemeColor = themeColor
    } else {
      CandidatePool4AppKit.shitCell.clientThemeColor = prefs.respectClientAccentColor
        ? NSColor.accentColor.withAlphaComponent(alphaRatio)
        : nil
      themeColor = CandidatePool4AppKit.shitCell.clientThemeColor
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

extension TDK4AppKit.VwrCandidateTDK4AppKit {
  private func findCell(from mouseEvent: NSEvent) -> Int? {
    var clickPoint = convert(mouseEvent.locationInWindow, to: self)
    clickPoint.y = bounds.height - clickPoint.y // 翻轉座標系
    guard bounds.contains(clickPoint) else { return nil }
    let flattenedCells = thePool.candidateLines[thePool.lineRangeForCurrentPage].flatMap { $0 }
    let filteredData: [CandidateCellData4AppKit] = flattenedCells.filter { theCell in
      CGRect(origin: theCell.visualOrigin, size: theCell.visualDimension).contains(clickPoint)
    }
    guard let firstValidCell = filteredData.first else { return nil }
    return firstValidCell.index
  }

  override func mouseDown(with event: NSEvent) {
    guard let cellIndex = findCell(from: event) else { return }
    guard cellIndex != thePool.highlightedIndex else { return }
    thePool.highlight(at: cellIndex)
    thePool.updateMetrics()
    setNeedsDisplay(bounds)
  }

  override func mouseDragged(with event: NSEvent) {
    mouseDown(with: event)
  }

  override func mouseUp(with event: NSEvent) {
    guard let cellIndex = findCell(from: event) else { return }
    didSelectCandidateAt(cellIndex)
  }

  override func rightMouseUp(with event: NSEvent) {
    guard let cellIndex = findCell(from: event) else { return }
    guard let delegate = controller?.delegate else { return }
    clickedCell = thePool.candidateDataAll[cellIndex]
    let index = clickedCell.index
    guard let candidate = delegate.getCandidate(at: index) else { return }
    let candidateText = clickedCell.displayedText
    let isEnabledInSession: Bool = delegate.isCandidateContextMenuEnabled
    let isMacroToken = delegate.checkIsMacroTokenResult(index)
    var conditions: [Bool] = [
      isEnabledInSession,
      !candidateText.isEmpty,
      !isMacroToken,
      index >= 0,
    ]
    singleKanjiCheck: if !prefs.allowRescoringSingleKanjiCandidates {
      guard let firstKey = candidate.keyArray.first else { break singleKanjiCheck }
      let segLengthIsOne = candidate.keyArray.count == 1
      let isPunctuation = firstKey.hasPrefix("_")
      let shouldDisableMenu = !isPunctuation && segLengthIsOne
      if shouldDisableMenu {
        delegate.callError("44E0B7CF: 當前輸入法偏好設定不允許單個漢字被控頻或被刪除。")
      }
      conditions.append(!shouldDisableMenu)
    }
    let allConditionsMet = conditions.reduce(true) { $0 && $1 }
    guard allConditionsMet else { return }
    prepareMenu()
    var clickPoint = convert(event.locationInWindow, to: self)
    clickPoint.y = bounds.height - clickPoint.y // 翻轉座標系
    theMenu?.popUp(positioning: nil, at: clickPoint, in: self)
  }
}

// MARK: - Context Menu.

extension TDK4AppKit.VwrCandidateTDK4AppKit {
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
    controller?.currentMenu = newMenu
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

extension TDK4AppKit.VwrCandidateTDK4AppKit {
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

extension TDK4AppKit.VwrCandidateTDK4AppKit {
  private func lineBackground(isCurrentLine: Bool, isMatrix: Bool) -> NSColor {
    guard isCurrentLine, isMatrix else { return .clear }
    return CandidateCellData4AppKit.plainTextColor.withAlphaComponent(0.05)
  }

  private var finalContainerOrientation: NSUserInterfaceLayoutOrientation {
    if thePool.maxLinesPerPage == 1, thePool.layout == .horizontal { return .horizontal }
    return .vertical
  }
}

// MARK: - Debug Module Using Swift UI.

import SwiftUI

// MARK: - TDK4AppKit.VwrCandidateTDK4AppKitForSwiftUI

extension TDK4AppKit {
  @available(macOS 10.15, *)
  struct VwrCandidateTDK4AppKitForSwiftUI: NSViewRepresentable {
    weak var controller: CtlCandidateTDK4AppKit?
    var thePool: CandidatePool4AppKit

    func makeNSView(context _: Context) -> VwrCandidateTDK4AppKit {
      let nsView = VwrCandidateTDK4AppKit(thePool: thePool)
      nsView.controller = controller
      return nsView
    }

    func updateNSView(_ nsView: VwrCandidateTDK4AppKit, context _: Context) {
      nsView.thePool = thePool
    }
  }
} // extension TDK4AppKit
