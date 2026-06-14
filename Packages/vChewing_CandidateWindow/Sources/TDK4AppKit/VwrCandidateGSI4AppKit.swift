// (c) 2022 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import AppKit
import Shared_DarwinImpl

// MARK: - GSI4AppKit

public enum GSI4AppKit {}

// MARK: GSI4AppKit.VwrCandidateGSI4AppKit

extension GSI4AppKit {
  // MARK: - VwrCandidateGSI4AppKit

  /// 我修院選字窗的 AppKit 視圖。
  /// 所有內容（候選字 + 底部欄位 + scroller）皆在同一 view 內繪製，
  /// 以手動座標偏移取代 NSAffineTransform 捲動。

  final class VwrCandidateGSI4AppKit: NSView {
    // MARK: Lifecycle

    init(controller: CtlCandidateGSI4AppKit? = nil, thePool pool: CandidatePool4AppKit) {
      self.controller = controller
      self.thePool = pool
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

    weak var controller: CtlCandidateGSI4AppKit?
    var thePool: CandidatePool4AppKit

    /// 是否處於 scroll mode（展開且行數超過 maxLinesPerPage）。
    var rendersInScrollMode = false

    var action: Selector?
    weak var target: AnyObject?
    weak var theMenu: NSMenu?
    var clickedCell: CandidateCellData4AppKit = CandidatePool4AppKit.shitCell

    // MARK: Private

    // MARK: - Scroller State

    private var isHoveringScroller = false
    private var isDraggingScroller = false
    private var scrollerDragStartOffset: CGFloat = 0
    private var scrollerDragStartPoint: CGPoint = .zero
    private var scrollerTrackingArea: NSTrackingArea?
    private var isDraggingWindow = false

    // MARK: - Scroller Constants

    private let scrollerThickness: CGFloat = 10
    private let scrollerPadding: CGFloat = 0
    private let scrollerMinThumbLength: CGFloat = 25
    private let scrollerCornerRadius: CGFloat = 5

    // MARK: - Cached Paths (invalidate when geometry changes)

    private var cachedBackgroundPath: NSBezierPath?
    private var lastBackgroundFittingSize: CGSize = .zero
    private var lastBackgroundWindowRadius: CGFloat = 0

    private var cachedClipPath: NSBezierPath?
    private var lastClipPageSize: CGSize = .zero

    private var cachedScrollerTrackPath: NSBezierPath?
    private var lastTrackCandidateSize: CGSize = .zero

    /// Cached highlight line background color (avoids per-frame NSColor alloc).
    private lazy var cachedHighlightedLineBgColor: NSColor =
      CandidateCellData4AppKit.plainTextColor.withAlphaComponent(0.05)

    private let prefs = PrefMgr.sharedSansDidSetOps
  }
} // extension GSI4AppKit

// MARK: - Layout & Rendering.

extension GSI4AppKit.VwrCandidateGSI4AppKit {
  override var isFlipped: Bool { true }

  /// Total fitting size.  In scroll mode this is pageCandidateSize + bottom fields;
  /// in normal mode it delegates to pool.metrics (same as TDK).
  override var fittingSize: CGSize {
    guard rendersInScrollMode else { return thePool.metrics.fittingSize }
    let page = thePool.pageCandidateSize
    let bottom = bottomFieldsSize
    let hasScroller = thePool.maxScrollOffset > 0
    let extraWidth = (hasScroller && isVerticalScroller) ? scrollerThickness + scrollerPadding : 0
    let extraHeight = (hasScroller && !isVerticalScroller) ? scrollerThickness : 0
    let pad = thePool.originDelta
    return CGSize(
      width: pad + max(page.width + extraWidth, bottom.width) + pad,
      height: pad + page.height + extraHeight + bottom.height
    )
  }

  static var candidateListBackground: NSColor {
    let brightBackground = NSColor(red: 0.99, green: 0.99, blue: 0.99, alpha: 1.00)
    let darkBackground = NSColor(red: 0.13, green: 0.13, blue: 0.14, alpha: 1.00)
    return NSApplication.isDarkMode ? darkBackground : brightBackground
  }

  override func draw(_: CGRect) {
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

    // Fill background for whole view.
    let bgRect = CGRect(origin: .zero, size: fittingSize)
    if #available(macOS 10.13, *) {
      Self.candidateListBackground
        .withAlphaComponent(NSApplication.uxLevel == .none ? 1 : 0.5)
        .setFill()
    } else {
      Self.candidateListBackground.setFill()
    }
    if cachedBackgroundPath == nil
      || lastBackgroundFittingSize != bgRect.size
      || lastBackgroundWindowRadius != thePool.windowRadius {
      cachedBackgroundPath = NSBezierPath(
        roundedRect: bgRect, xRadius: thePool.windowRadius, yRadius: thePool.windowRadius
      )
      lastBackgroundFittingSize = bgRect.size
      lastBackgroundWindowRadius = thePool.windowRadius
    }
    cachedBackgroundPath?.fill()

    if rendersInScrollMode {
      drawScrollMode(themeColor: themeColor)
    } else {
      drawNormalMode(themeColor: themeColor)
    }
  }

  // MARK: - Scroll Mode Drawing

  private func drawScrollMode(themeColor: NSColor?) {
    guard let ctx = NSGraphicsContext.current else { return }
    let pageHeight = thePool.pageCandidateSize.height
    let pageSize = thePool.pageCandidateSize
    let clipOrigin = CGPoint(x: thePool.originDelta, y: thePool.originDelta)

    // Compute draw offsets once (replaces NSAffineTransform).
    let drawOffsetX: CGFloat
    let drawOffsetY: CGFloat
    if thePool.isHorizontal {
      drawOffsetX = thePool.originDelta
      drawOffsetY = thePool.originDelta - thePool.scrollOffset
    } else {
      drawOffsetX = thePool.originDelta - thePool.scrollOffset
      drawOffsetY = thePool.originDelta
    }

    ctx.saveGraphicsState()

    // Cached clip path.
    if cachedClipPath == nil || lastClipPageSize != pageSize {
      cachedClipPath = NSBezierPath(rect: CGRect(origin: clipOrigin, size: pageSize))
      lastClipPageSize = pageSize
    }
    cachedClipPath?.setClip()

    // --- Highlighted line: backgrounds ---
    let highlightedLine: [CandidateCellData4AppKit]? = thePool.candidateLines
      .first(where: { $0.contains(where: { $0.isHighlighted }) })

    if let line = highlightedLine,
       let (highlightedLineRect, highlightedCellRect, highlightedCell) = computeHighlightRects(forLine: line) {
      var highlightedLineRect = highlightedLineRect
      if thePool.isHorizontal {
        highlightedLineRect.size.width = max(highlightedLineRect.size.width, pageSize.width)
      } else {
        highlightedLineRect.size.height = max(highlightedLineRect.size.height, pageSize.height)
      }
      let adjustedLineRect = highlightedLineRect.offsetBy(dx: drawOffsetX, dy: drawOffsetY)
      let adjustedCellRect = highlightedCellRect.offsetBy(dx: drawOffsetX, dy: drawOffsetY)

      lineBackground(isCurrentLine: true, isMatrix: thePool.isMatrix).setFill()
      NSBezierPath(
        roundedRect: adjustedLineRect,
        xRadius: thePool.cellRadius,
        yRadius: thePool.cellRadius
      ).fill()

      (themeColor ?? highlightedCell.themeColorCocoa).setFill()
      NSBezierPath(
        roundedRect: adjustedCellRect,
        xRadius: thePool.cellRadius,
        yRadius: thePool.cellRadius
      ).fill()
    }

    // Draw candidate cells with visibility culling (skip lines outside clip rect).
    let padding = thePool.padding
    if thePool.isHorizontal {
      let clipMinY = clipOrigin.y
      let clipMaxY = clipOrigin.y + pageSize.height
      for line in thePool.candidateLines {
        guard let firstCell = line.first else { continue }
        let lineTop = firstCell.visualOrigin.y + drawOffsetY
        let lineHeight = line.map(\.visualDimension.height).max() ?? 0
        guard lineTop + lineHeight > clipMinY, lineTop < clipMaxY else { continue }
        for cell in line {
          cell.attributedStringHeader.draw(
            at: CGPoint(
              x: cell.visualOrigin.x + 2 * padding + drawOffsetX,
              y: cell.visualOrigin.y + cell.headerDrawYOffset + drawOffsetY
            )
          )
          cell.attributedStringPhrase(isMatrix: false).draw(
            at: CGPoint(
              x: cell.visualOrigin.x + 2 * padding + cell.phraseDrawXOffset + drawOffsetX,
              y: cell.visualOrigin.y + padding + drawOffsetY
            )
          )
        }
      }
    } else {
      let clipMinX = clipOrigin.x
      let clipMaxX = clipOrigin.x + pageSize.width
      for line in thePool.candidateLines {
        guard let firstCell = line.first else { continue }
        let lineLeft = firstCell.visualOrigin.x + drawOffsetX
        let lineWidth = line.map(\.visualDimension.width).max() ?? 0
        guard lineLeft + lineWidth > clipMinX, lineLeft < clipMaxX else { continue }
        for cell in line {
          cell.attributedStringHeader.draw(
            at: CGPoint(
              x: cell.visualOrigin.x + 2 * padding + drawOffsetX,
              y: cell.visualOrigin.y + cell.headerDrawYOffset + drawOffsetY
            )
          )
          cell.attributedStringPhrase(isMatrix: false).draw(
            at: CGPoint(
              x: cell.visualOrigin.x + 2 * padding + cell.phraseDrawXOffset + drawOffsetX,
              y: cell.visualOrigin.y + padding + drawOffsetY
            )
          )
        }
      }
    }
    ctx.restoreGraphicsState()

    // Draw scroller (only spans the candidate area, not bottom fields).
    if thePool.maxScrollOffset > 0 {
      drawScroller(candidateAreaSize: pageSize)
    }

    let scrollerGap: CGFloat = (thePool.maxScrollOffset > 0 && !isVerticalScroller) ? scrollerThickness : 0
    drawBottomFields(topY: thePool.originDelta + pageHeight + scrollerGap)
  }

  // MARK: - Normal Mode Drawing (same as TDK)

  private func drawNormalMode(themeColor: NSColor?) {
    let sizesCalculated = thePool.metrics

    lineBackground(isCurrentLine: true, isMatrix: thePool.isMatrix).setFill()
    NSBezierPath(
      roundedRect: sizesCalculated.highlightedLine,
      xRadius: thePool.cellRadius,
      yRadius: thePool.cellRadius
    ).fill()

    var cellHighlightedDrawn = false
    let allCells = thePool.candidateLines[thePool.lineRangeForCurrentPage].flatMap { $0 }
    let padding = thePool.padding
    allCells.forEach { currentCell in
      if currentCell.isHighlighted, !cellHighlightedDrawn {
        (themeColor ?? currentCell.themeColorCocoa).setFill()
        NSBezierPath(
          roundedRect: sizesCalculated.highlightedCandidate,
          xRadius: thePool.cellRadius,
          yRadius: thePool.cellRadius
        ).fill()
        cellHighlightedDrawn = true
      }
      currentCell.attributedStringHeader.draw(
        at: .init(
          x: currentCell.visualOrigin.x + 2 * padding,
          y: currentCell.visualOrigin.y + currentCell.headerDrawYOffset
        )
      )
      currentCell.attributedStringPhrase(isMatrix: false).draw(
        at: .init(
          x: currentCell.visualOrigin.x + 2 * padding + currentCell.phraseDrawXOffset,
          y: currentCell.visualOrigin.y + padding
        )
      )
    }

    let strPeripherals = thePool.attributedDescriptionBottomPanes
    strPeripherals.draw(at: sizesCalculated.peripherals.origin)
    let strReadingDisambig = thePool.attributedDescriptionReadingDisambiguation
    if !strReadingDisambig.string.isEmpty {
      strReadingDisambig.draw(at: sizesCalculated.readingDisambiguation.origin)
    }
  }

  // MARK: - Bottom Fields (drawn in same view, below candidate area)

  /// Size needed for the bottom fields (peripherals + reading disambiguation).
  private var bottomFieldsSize: CGSize {
    let strPeripherals = thePool.attributedDescriptionBottomPanes
    let strReading = thePool.attributedDescriptionReadingDisambiguation
    var dimPeriph = strPeripherals.getBoundingDimension(forceFallback: true)
    dimPeriph.width = ceil(dimPeriph.width)
    dimPeriph.height = ceil(dimPeriph.height)
    if strReading.string.isEmpty {
      return CGSize(
        width: dimPeriph.width,
        height: dimPeriph.height + thePool.originDelta
      )
    }
    var dimReading = strReading.getBoundingDimension(forceFallback: true)
    dimReading.width = ceil(dimReading.width)
    dimReading.height = ceil(dimReading.height)
    return CGSize(
      width: max(dimPeriph.width, dimReading.width),
      height: dimPeriph.height + dimReading.height + thePool.originDelta
    )
  }

  private func drawBottomFields(topY: CGFloat) {
    let strPeripherals = thePool.attributedDescriptionBottomPanes
    let strReading = thePool.attributedDescriptionReadingDisambiguation
    let dimPeriph = strPeripherals.getBoundingDimension(forceFallback: true)
    let y0 = topY
    strPeripherals.draw(at: CGPoint(x: thePool.originDelta, y: y0))
    if !strReading.string.isEmpty {
      strReading.draw(at: CGPoint(x: thePool.originDelta, y: y0 + ceil(dimPeriph.height)))
    }
  }

  // MARK: - Scroller Drawing

  private func drawScroller(candidateAreaSize: CGSize) {
    let track = scrollerTrackRect(candidateAreaSize: candidateAreaSize)
    let thumb = scrollerThumbRect(candidateAreaSize: candidateAreaSize)

    // Only recreate the cached track path when the candidate area size changes.
    if cachedScrollerTrackPath == nil || lastTrackCandidateSize != candidateAreaSize {
      cachedScrollerTrackPath = NSBezierPath(
        roundedRect: track, xRadius: scrollerCornerRadius, yRadius: scrollerCornerRadius
      )
      lastTrackCandidateSize = candidateAreaSize
    }

    let trackColor: NSColor
    let thumbColor: NSColor
    if #available(macOS 10.10, *) {
      trackColor = .quaternaryLabelColor
      thumbColor = isHoveringScroller ? .secondaryLabelColor : .tertiaryLabelColor
    } else {
      trackColor = .lightGray
      thumbColor = isHoveringScroller ? .gray : .darkGray
    }
    trackColor.setFill()
    cachedScrollerTrackPath?.fill()

    thumbColor.setFill()
    NSBezierPath(roundedRect: thumb, xRadius: scrollerCornerRadius, yRadius: scrollerCornerRadius).fill()
  }

  // MARK: - Scroller Geometry

  private var isVerticalScroller: Bool { thePool.isHorizontal }

  private func scrollerTrackRect(candidateAreaSize: CGSize) -> CGRect {
    if isVerticalScroller {
      let x = thePool.originDelta + candidateAreaSize.width + scrollerPadding
      let topPadding = thePool.windowRadius
      return CGRect(
        x: x,
        y: topPadding,
        width: scrollerThickness,
        height: candidateAreaSize.height - (topPadding - thePool.originDelta)
      )
    } else {
      let y = thePool.originDelta + candidateAreaSize.height
      return CGRect(x: thePool.originDelta, y: y, width: candidateAreaSize.width, height: scrollerThickness)
    }
  }

  private func scrollerThumbRect(candidateAreaSize: CGSize) -> CGRect {
    let track = scrollerTrackRect(candidateAreaSize: candidateAreaSize)
    let ratio = thePool.scrollerThumbRatio
    if isVerticalScroller {
      let thumbLen = max(scrollerMinThumbLength, track.height * ratio)
      let thumbY = track.minY + (track.height - thumbLen) * thePool.scrollerThumbPosition
      return CGRect(x: track.minX, y: thumbY, width: track.width, height: thumbLen)
    } else {
      let thumbLen = max(scrollerMinThumbLength, track.width * ratio)
      let thumbX = track.minX + (track.width - thumbLen) * thePool.scrollerThumbPosition
      return CGRect(x: thumbX, y: track.minY, width: thumbLen, height: track.height)
    }
  }

  // MARK: - Highlight Rect Computation (for scroll mode)

  private func computeHighlightRects(forLine line: [CandidateCellData4AppKit])
    -> (lineRect: CGRect, cellRect: CGRect, cell: CandidateCellData4AppKit)? {
    guard let highlightedCell = line.first(where: { $0.isHighlighted }),
          let firstCell = line.first,
          let lastCell = line.last else { return nil }

    let cellRect = CGRect(
      origin: highlightedCell.visualOrigin,
      size: highlightedCell.visualDimension
    )

    let lineMinX = firstCell.visualOrigin.x
    let lineMinY = firstCell.visualOrigin.y
    let lineWidth: CGFloat
    let lineHeight: CGFloat

    switch thePool.layout {
    case .horizontal:
      lineWidth = (lastCell.visualOrigin.x + lastCell.visualDimension.width) - lineMinX
      lineHeight = line.map(\.visualDimension.height).max() ?? cellRect.height
    case .vertical:
      lineHeight = (lastCell.visualOrigin.y + lastCell.visualDimension.height) - lineMinY
      lineWidth = line.map(\.visualDimension.width).max() ?? cellRect.width
    }

    let lineRect = CGRect(x: lineMinX, y: lineMinY, width: lineWidth, height: lineHeight)
    return (lineRect, cellRect, highlightedCell)
  }

  // MARK: - Shared Helpers

  private func lineBackground(isCurrentLine: Bool, isMatrix: Bool) -> NSColor {
    guard isCurrentLine, isMatrix else { return .clear }
    return cachedHighlightedLineBgColor
  }
}

// MARK: - Mouse Interaction Handlers.

extension GSI4AppKit.VwrCandidateGSI4AppKit {
  private func findCell(from mouseEvent: NSEvent) -> Int? {
    var clickPoint = convert(mouseEvent.locationInWindow, to: self)
    clickPoint.y = bounds.height - clickPoint.y
    guard bounds.contains(clickPoint) else { return nil }
    if rendersInScrollMode {
      if thePool.isHorizontal {
        clickPoint.y += thePool.scrollOffset
      } else {
        clickPoint.x += thePool.scrollOffset
      }
    }
    let flattenedCells: [CandidateCellData4AppKit]
    if rendersInScrollMode {
      flattenedCells = thePool.candidateLines.flatMap { $0 }
    } else {
      flattenedCells = thePool.candidateLines[thePool.lineRangeForCurrentPage].flatMap { $0 }
    }
    let filteredData = flattenedCells.filter { theCell in
      CGRect(origin: theCell.visualOrigin, size: theCell.visualDimension).contains(clickPoint)
    }
    let visibleData = filteredData.filter { theCell in
      if rendersInScrollMode {
        let viewX: CGFloat
        let viewY: CGFloat
        if thePool.isHorizontal {
          viewX = thePool.originDelta + theCell.visualOrigin.x
          viewY = thePool.originDelta + theCell.visualOrigin.y - thePool.scrollOffset
        } else {
          viewX = thePool.originDelta + theCell.visualOrigin.x - thePool.scrollOffset
          viewY = thePool.originDelta + theCell.visualOrigin.y
        }
        let viewport = CGRect(
          origin: CGPoint(x: thePool.originDelta, y: thePool.originDelta),
          size: thePool.pageCandidateSize
        )
        let cellRect = CGRect(origin: CGPoint(x: viewX, y: viewY), size: theCell.visualDimension)
        return viewport.intersects(cellRect)
      }
      return true
    }
    guard let firstValidCell = visibleData.first else { return nil }
    return firstValidCell.index
  }

  private func isPointInScrollerTrack(_ point: CGPoint) -> Bool {
    guard rendersInScrollMode, thePool.maxScrollOffset > 0 else { return false }
    return scrollerTrackRect(candidateAreaSize: thePool.pageCandidateSize).contains(point)
  }

  private func isPointInScrollerThumb(_ point: CGPoint) -> Bool {
    guard rendersInScrollMode, thePool.maxScrollOffset > 0 else { return false }
    return scrollerThumbRect(candidateAreaSize: thePool.pageCandidateSize).insetBy(dx: -3, dy: -3).contains(point)
  }

  private func scrollerRatio(for point: CGPoint) -> CGFloat {
    let track = scrollerTrackRect(candidateAreaSize: thePool.pageCandidateSize)
    let thumb = scrollerThumbRect(candidateAreaSize: thePool.pageCandidateSize)
    if isVerticalScroller {
      let movable = track.height - thumb.height
      guard movable > 0 else { return 0 }
      return (point.y - track.minY - thumb.height / 2) / movable
    } else {
      let movable = track.width - thumb.width
      guard movable > 0 else { return 0 }
      return (point.x - track.minX - thumb.width / 2) / movable
    }
  }

  override func mouseDown(with event: NSEvent) {
    var clickPoint = convert(event.locationInWindow, to: self)
    clickPoint.y = bounds.height - clickPoint.y

    if isPointInScrollerThumb(clickPoint) {
      isDraggingScroller = true
      scrollerDragStartOffset = thePool.scrollOffset
      scrollerDragStartPoint = clickPoint
      return
    }

    if isPointInScrollerTrack(clickPoint) {
      let ratio = scrollerRatio(for: clickPoint)
      thePool.scrollOffset = max(0, min(thePool.maxScrollOffset, ratio * thePool.maxScrollOffset))
      setNeedsDisplay(bounds)
      return
    }

    guard let cellIndex = findCell(from: event) else {
      isDraggingWindow = true
      window?.performDrag(with: event)
      return
    }
    guard cellIndex != thePool.highlightedIndex else { return }
    thePool.highlight(at: cellIndex)
    if rendersInScrollMode {
      thePool.computeCandidateOnlySize()
      thePool.scrollToMakeLineVisible(thePool.currentLineNumber)
    } else {
      thePool.updateMetrics()
    }
    setNeedsDisplay(bounds)
  }

  override func mouseDragged(with event: NSEvent) {
    guard !isDraggingWindow else { return }
    if isDraggingScroller {
      var clickPoint = convert(event.locationInWindow, to: self)
      clickPoint.y = bounds.height - clickPoint.y
      let startRatio = scrollerRatio(for: scrollerDragStartPoint)
      let currentRatio = scrollerRatio(for: clickPoint)
      let delta = currentRatio - startRatio
      thePool.scrollOffset = max(
        0,
        min(
          thePool.maxScrollOffset,
          scrollerDragStartOffset + delta * thePool.maxScrollOffset
        )
      )
      setNeedsDisplay(bounds)
      return
    }
    mouseDown(with: event)
  }

  override func mouseUp(with event: NSEvent) {
    guard !isDraggingWindow else {
      isDraggingWindow = false
      return
    }
    if isDraggingScroller {
      isDraggingScroller = false
      thePool.snapScrollOffset()
      setNeedsDisplay(bounds)
      return
    }
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
    let isEnabledInSession = delegate.isCandidateContextMenuEnabled
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
        delegate.callError("44E0B7CF")
      }
      conditions.append(!shouldDisableMenu)
    }
    let allConditionsMet = conditions.reduce(true) { $0 && $1 }
    guard allConditionsMet else { return }
    prepareMenu()
    var clickPoint = convert(event.locationInWindow, to: self)
    clickPoint.y = bounds.height - clickPoint.y
    theMenu?.popUp(positioning: nil, at: clickPoint, in: self)
  }

  override func updateTrackingAreas() {
    super.updateTrackingAreas()
    if let existing = scrollerTrackingArea {
      removeTrackingArea(existing)
    }
    let options: NSTrackingArea.Options = [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow]
    scrollerTrackingArea = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
    if let area = scrollerTrackingArea {
      addTrackingArea(area)
    }
  }

  override func mouseMoved(with event: NSEvent) {
    var point = convert(event.locationInWindow, to: self)
    point.y = bounds.height - point.y
    let wasHovering = isHoveringScroller
    isHoveringScroller = isPointInScrollerTrack(point)
    if wasHovering != isHoveringScroller {
      setNeedsDisplay(bounds)
    }
  }

  override func mouseExited(with _: NSEvent) {
    guard isHoveringScroller else { return }
    isHoveringScroller = false
    setNeedsDisplay(bounds)
  }
}

// MARK: - Scroll Wheel.

extension GSI4AppKit.VwrCandidateGSI4AppKit {
  override func scrollWheel(with event: NSEvent) {
    guard rendersInScrollMode else {
      controller?.scrollWheel(with: event)
      return
    }
    // Option (without Shift): always flip lines, using dominant scroll axis.
    if event.modifierFlags.contains(.option), !event.modifierFlags.contains(.shift),
       let dir = CandidatePool4AppKit.dominantScrollLineDirection(event) {
      switch dir {
      case .next: controller?.showNextLine()
      case .previous: controller?.showPreviousLine()
      }
      return
    }
    // Scroll axis: direct content scrolling (replaces flip-line).
    // Highlight axis: delegate to controller (same as non-expanded).
    if thePool.isHorizontal {
      thePool.scrollByPixels(-event.deltaY)
      if event.deltaX > 1 { controller?.highlightNextCandidate() }
      else if event.deltaX < -1 { controller?.highlightPreviousCandidate() }
    } else {
      thePool.scrollByPixels(-event.deltaX)
      if event.deltaY > 1 { controller?.highlightNextCandidate() }
      else if event.deltaY < -1 { controller?.highlightPreviousCandidate() }
    }
    if event.phase == .ended || event.momentumPhase == .ended {
      thePool.snapScrollOffset()
    }
    setNeedsDisplay(bounds)
  }
}

// MARK: - Context Menu.

extension GSI4AppKit.VwrCandidateGSI4AppKit {
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

// MARK: - Delegate Methods.

extension GSI4AppKit.VwrCandidateGSI4AppKit {
  fileprivate func didSelectCandidateAt(_ pos: Int) {
    controller?.delegate?.candidatePairSelectionConfirmed(at: pos)
  }

  fileprivate func didTriggerCandidatePairContextMenuActionAt(
    _ pos: Int, action: CandidateContextMenuAction
  ) {
    controller?.delegate?.candidatePairContextMenuActionTriggered(at: pos, action: action)
  }
}

// MARK: - Debug Module Using Swift UI.

import SwiftUI

// MARK: - GSI4AppKit.VwrCandidateGSI4SwiftUI

extension GSI4AppKit {
  @available(macOS 10.15, *)
  struct VwrCandidateGSI4SwiftUI: NSViewRepresentable {
    weak var controller: CtlCandidateGSI4AppKit?
    var thePool: TDK4AppKit.CandidatePool4AppKit

    func makeNSView(context _: Context) -> VwrCandidateGSI4AppKit {
      let nsView = VwrCandidateGSI4AppKit(thePool: thePool)
      nsView.controller = controller
      return nsView
    }

    func updateNSView(_ nsView: VwrCandidateGSI4AppKit, context _: Context) {
      nsView.thePool = thePool
    }
  }
} // extension TDK4AppKit
