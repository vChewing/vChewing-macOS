// (c) 2011 and onwards The OpenVanilla Project (MIT License).
// All possible vChewing-specific modifications are of:
// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

// 將之前 Zonble 重寫的 Voltaire 選字窗隔的橫向版本與縱向版本合併到同一個型別實體內。

import CandidateWindow
import Cocoa
import Shared

private class vwrCandidateUniversal: NSView {
  var highlightedIndex: Int = 0 {
    didSet { highlightedIndex = min(max(highlightedIndex, 0), dispCandidatesWithLabels.count - 1) }
  }

  var action: Selector?
  weak var target: AnyObject?
  weak var controller: AnyObject?
  var isVerticalLayout = false
  var fractionFontSize: Double = 12.0

  private var keyLabels: [String] = []
  private var displayedCandidates: [String] = []
  private var dispCandidatesWithLabels: [String] = []
  private var keyLabelHeight: Double = 0
  private var keyLabelWidth: Double = 0
  private var candidateTextHeight: Double = 0
  private var cellPadding: Double = 0
  private var keyLabelAttrDict: [NSAttributedString.Key: AnyObject] = [:]
  private var candidateAttrDict: [NSAttributedString.Key: AnyObject] = [:]
  private var candidateWithLabelAttrDict: [NSAttributedString.Key: AnyObject] = [:]
  private var windowWidth: Double = 0  // 縱排專用
  private var elementWidths: [Double] = []
  private var elementHeights: [Double] = []  // 縱排專用
  private var trackingHighlightedIndex: Int = .max {
    didSet { trackingHighlightedIndex = max(trackingHighlightedIndex, 0) }
  }

  override var isFlipped: Bool {
    true
  }

  var sizeForView: NSSize {
    var result = NSSize.zero

    if !elementWidths.isEmpty {
      switch isVerticalLayout {
        case true:
          result.width = windowWidth
          result.height = elementHeights.reduce(0, +)
        case false:
          result.width = elementWidths.reduce(0, +) + Double(elementWidths.count)
          result.height = candidateTextHeight + cellPadding
      }
    }
    return result
  }

  func set(keyLabels labels: [String], displayedCandidates candidates: [String]) {
    guard let delegate = (controller as? CtlCandidateUniversal)?.delegate else { return }
    let candidates = candidates.map { theCandidate -> String in
      let theConverted = delegate.kanjiConversionIfRequired(theCandidate)
      return (theCandidate == theConverted) ? theCandidate : "\(theConverted)(\(theCandidate))"
    }

    let count = min(labels.count, candidates.count)
    keyLabels = Array(labels[0..<count])
    displayedCandidates = Array(candidates[0..<count])
    dispCandidatesWithLabels = zip(keyLabels, displayedCandidates).map { $0 + $1 }

    var newWidths = [Double]()
    var calculatedWindowWidth = Double()
    var newHeights = [Double]()
    let baseSize = NSSize(width: 10240.0, height: 10240.0)
    for index in 0..<count {
      let rctCandidate = (dispCandidatesWithLabels[index] as NSString).boundingRect(
        with: baseSize, options: .usesLineFragmentOrigin,
        attributes: candidateWithLabelAttrDict
      )
      var cellWidth = rctCandidate.size.width + cellPadding
      let cellHeight = rctCandidate.size.height + cellPadding
      switch isVerticalLayout {
        case true:
          if calculatedWindowWidth < rctCandidate.size.width {
            calculatedWindowWidth = rctCandidate.size.width + cellPadding * 2
          }
        case false:
          if cellWidth < cellHeight * 1.4 {
            cellWidth = cellHeight * 1.4
          }
      }
      newWidths.append(round(cellWidth))
      newHeights.append(round(cellHeight))  // 縱排專用
    }
    elementWidths = newWidths
    elementHeights = newHeights
    // 縱排專用，防止窗體右側邊框粗細不一
    windowWidth = round(calculatedWindowWidth + cellPadding)
  }

  @objc(setKeyLabelFont:candidateFont:)
  func set(keyLabelFont labelFont: NSFont, candidateFont: NSFont) {
    let paraStyle = NSMutableParagraphStyle()
    paraStyle.setParagraphStyle(NSParagraphStyle.default)
    paraStyle.alignment = isVerticalLayout ? .left : .center

    candidateWithLabelAttrDict = [
      .font: candidateFont,
      .paragraphStyle: paraStyle,
      .foregroundColor: NSColor.labelColor,
    ]  // We still need this dummy section to make sure that…
    // …the space occupations of the candidates are correct.

    keyLabelAttrDict = [
      .font: labelFont,
      .paragraphStyle: paraStyle,
      .verticalGlyphForm: true as AnyObject,
      .foregroundColor: NSColor.secondaryLabelColor,
    ]  // Candidate phrase text color
    candidateAttrDict = [
      .font: candidateFont,
      .paragraphStyle: paraStyle,
      .foregroundColor: NSColor.labelColor,
    ]  // Candidate index text color
    let labelFontSize = labelFont.pointSize
    let candidateFontSize = candidateFont.pointSize
    let biggestSize = max(labelFontSize, candidateFontSize)
    fractionFontSize = round(biggestSize * 0.75)
    keyLabelWidth = ceil(labelFontSize)
    keyLabelHeight = ceil(labelFontSize * 2)
    candidateTextHeight = ceil(candidateFontSize * 1.20)
    cellPadding = ceil(biggestSize / 4.0) * 2
  }

  override func draw(_: NSRect) {
    guard let controller = controller as? CtlCandidateUniversal else { return }
    let bounds = bounds
    NSColor.controlBackgroundColor.setFill()  // Candidate list panel base background
    NSBezierPath.fill(bounds)

    switch isVerticalLayout {
      case true:
        var accuHeight: Double = 0
        for (index, elementHeight) in elementHeights.enumerated() {
          let currentHeight = elementHeight
          let rctCandidateArea = NSRect(
            x: 3.0, y: accuHeight + 3.0, width: windowWidth - 6.0,
            height: candidateTextHeight + cellPadding - 6.0
          )
          let rctLabel = NSRect(
            x: cellPadding / 2 + 2, y: accuHeight + cellPadding / 2, width: keyLabelWidth,
            height: keyLabelHeight * 2.0
          )
          let rctCandidatePhrase = NSRect(
            x: cellPadding / 2 + 2 + keyLabelWidth, y: accuHeight + cellPadding / 2 - 1,
            width: windowWidth - keyLabelWidth, height: candidateTextHeight
          )

          var activeCandidateIndexAttr = keyLabelAttrDict
          var activeCandidateAttr = candidateAttrDict
          if index == highlightedIndex {
            controller.highlightedColor().setFill()
            // Highlightened index text color
            activeCandidateIndexAttr[.foregroundColor] = NSColor.selectedMenuItemTextColor
              .withAlphaComponent(0.84)
            // Highlightened phrase text color
            activeCandidateAttr[.foregroundColor] = NSColor.selectedMenuItemTextColor
            let path: NSBezierPath = .init(roundedRect: rctCandidateArea, xRadius: 6, yRadius: 6)
            path.fill()
          }
          if #available(macOS 12, *) {
            if controller.useLangIdentifier {
              activeCandidateAttr[.languageIdentifier] = controller.locale as AnyObject
            }
          }
          (keyLabels[index] as NSString).draw(
            in: rctLabel, withAttributes: activeCandidateIndexAttr
          )
          (displayedCandidates[index] as NSString).draw(
            in: rctCandidatePhrase, withAttributes: activeCandidateAttr
          )
          accuHeight += currentHeight
        }
      case false:
        var accuWidth: Double = 0
        for (index, elementWidth) in elementWidths.enumerated() {
          let currentWidth = elementWidth
          let rctCandidateArea = NSRect(
            x: accuWidth + 3.0, y: 3.0, width: currentWidth + 1.0 - 6.0,
            height: candidateTextHeight + cellPadding - 6.0
          )
          let rctLabel = NSRect(
            x: accuWidth + cellPadding / 2 - 1, y: cellPadding / 2, width: keyLabelWidth,
            height: keyLabelHeight * 2.0
          )
          let rctCandidatePhrase = NSRect(
            x: accuWidth + keyLabelWidth - 1, y: cellPadding / 2 - 1,
            width: currentWidth - keyLabelWidth,
            height: candidateTextHeight
          )

          var activeCandidateIndexAttr = keyLabelAttrDict
          var activeCandidateAttr = candidateAttrDict
          if index == highlightedIndex {
            controller.highlightedColor().setFill()
            // Highlightened index text color
            activeCandidateIndexAttr[.foregroundColor] = NSColor.selectedMenuItemTextColor
              .withAlphaComponent(0.84)
            // Highlightened phrase text color
            activeCandidateAttr[.foregroundColor] = NSColor.selectedMenuItemTextColor
            let path: NSBezierPath = .init(roundedRect: rctCandidateArea, xRadius: 6, yRadius: 6)
            path.fill()
          }
          if #available(macOS 12, *) {
            if controller.useLangIdentifier {
              activeCandidateAttr[.languageIdentifier] = controller.locale as AnyObject
            }
          }
          (keyLabels[index] as NSString).draw(
            in: rctLabel, withAttributes: activeCandidateIndexAttr
          )
          (displayedCandidates[index] as NSString).draw(
            in: rctCandidatePhrase, withAttributes: activeCandidateAttr
          )
          accuWidth += currentWidth + 1.0
        }
    }
  }

  private func findHitIndex(event: NSEvent) -> Int {
    let location = convert(event.locationInWindow, to: nil)
    if !bounds.contains(location) {
      return NSNotFound
    }
    switch isVerticalLayout {
      case true:
        var accuHeight = 0.0
        for (index, elementHeight) in elementHeights.enumerated() {
          let currentHeight = elementHeight

          if location.y >= accuHeight, location.y <= accuHeight + currentHeight {
            return index
          }
          accuHeight += currentHeight
        }
      case false:
        var accuWidth = 0.0
        for (index, elementWidth) in elementWidths.enumerated() {
          let currentWidth = elementWidth

          if location.x >= accuWidth, location.x <= accuWidth + currentWidth {
            return index
          }
          accuWidth += currentWidth + 1.0
        }
    }
    return NSNotFound
  }

  override func mouseUp(with event: NSEvent) {
    trackingHighlightedIndex = highlightedIndex
    let newIndex = findHitIndex(event: event)
    guard newIndex != NSNotFound else {
      return
    }
    highlightedIndex = newIndex
    setNeedsDisplay(bounds)
  }

  override func mouseDown(with event: NSEvent) {
    let newIndex = findHitIndex(event: event)
    guard newIndex != NSNotFound else {
      return
    }
    var triggerAction = false
    if newIndex == highlightedIndex {
      triggerAction = true
    } else {
      highlightedIndex = trackingHighlightedIndex
    }

    trackingHighlightedIndex = 0
    setNeedsDisplay(bounds)
    if triggerAction {
      if let target = target as? NSObject, let action = action {
        target.perform(action, with: self)
      }
    }
  }
}

public class CtlCandidateUniversal: CtlCandidate {
  private var candidateView: vwrCandidateUniversal
  private var prevPageButton: NSButton
  private var nextPageButton: NSButton
  private var pageCounterLabel: NSTextField
  private var currentPageIndex: Int = 0
  override public var currentLayout: NSUserInterfaceLayoutOrientation {
    get { candidateView.isVerticalLayout ? .vertical : .horizontal }
    set {
      switch newValue {
        case .vertical: candidateView.isVerticalLayout = true
        case .horizontal: candidateView.isVerticalLayout = false
        @unknown default: candidateView.isVerticalLayout = false
      }
    }
  }

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
    candidateView = vwrCandidateUniversal(frame: contentRect)

    candidateView.wantsLayer = true
    // candidateView.layer?.borderColor = NSColor.selectedMenuItemTextColor.withAlphaComponent(0.20).cgColor
    // candidateView.layer?.borderWidth = 1.0
    if #available(macOS 10.13, *) {
      candidateView.layer?.cornerRadius = 9.0
    }

    panel.contentView?.addSubview(candidateView)

    // MARK: Add Buttons

    contentRect.size = NSSize(width: 20.0, height: 10.0)  // Reduce the button width
    let buttonAttribute: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 9.0)]

    nextPageButton = .init(frame: contentRect)
    nextPageButton.wantsLayer = true
    nextPageButton.layer?.masksToBounds = true
    nextPageButton.layer?.borderColor = NSColor.clear.cgColor
    nextPageButton.layer?.borderWidth = 0.0
    nextPageButton.setButtonType(.momentaryLight)
    nextPageButton.bezelStyle = .disclosure
    nextPageButton.userInterfaceLayoutDirection = .leftToRight
    nextPageButton.attributedTitle = NSMutableAttributedString(
      string: " ", attributes: buttonAttribute
    )  // Next Page Arrow
    prevPageButton = .init(frame: contentRect)
    prevPageButton.wantsLayer = true
    prevPageButton.layer?.masksToBounds = true
    prevPageButton.layer?.borderColor = NSColor.clear.cgColor
    prevPageButton.layer?.borderWidth = 0.0
    prevPageButton.setButtonType(.momentaryLight)
    prevPageButton.bezelStyle = .disclosure
    prevPageButton.userInterfaceLayoutDirection = .rightToLeft
    prevPageButton.attributedTitle = NSMutableAttributedString(
      string: " ", attributes: buttonAttribute
    )  // Previous Page Arrow
    panel.contentView?.addSubview(nextPageButton)
    panel.contentView?.addSubview(prevPageButton)

    // MARK: Add Page Counter

    contentRect = NSRect(x: 128.0, y: 128.0, width: 48.0, height: 20.0)
    pageCounterLabel = .init(frame: contentRect)
    pageCounterLabel.isEditable = false
    pageCounterLabel.isSelectable = false
    pageCounterLabel.isBezeled = false
    pageCounterLabel.attributedStringValue = NSMutableAttributedString(
      string: " ", attributes: buttonAttribute
    )
    panel.contentView?.addSubview(pageCounterLabel)

    // MARK: Post-Init()

    super.init(layout)
    window = panel
    currentLayout = layout
    candidateView.controller = self

    candidateView.target = self
    candidateView.action = #selector(candidateViewMouseDidClick(_:))

    nextPageButton.target = self
    nextPageButton.action = #selector(pageButtonAction(_:))

    prevPageButton.target = self
    prevPageButton.action = #selector(pageButtonAction(_:))
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override public func reloadData() {
    candidateView.highlightedIndex = 0
    currentPageIndex = 0
    layoutCandidateView()
  }

  @discardableResult override public func showNextPage() -> Bool {
    guard let delegate = delegate else { return false }
    if pageCount == 1 { return highlightNextCandidate() }
    if currentPageIndex + 1 >= pageCount { delegate.buzz() }
    currentPageIndex = (currentPageIndex + 1 >= pageCount) ? 0 : currentPageIndex + 1
    if currentPageIndex == pageCount - 1 {
      candidateView.highlightedIndex = min(lastPageContentCount - 1, candidateView.highlightedIndex)
    }
    // candidateView.highlightedIndex = 0
    layoutCandidateView()
    return true
  }

  @discardableResult override public func showPreviousPage() -> Bool {
    guard let delegate = delegate else { return false }
    if pageCount == 1 { return highlightPreviousCandidate() }
    if currentPageIndex == 0 { delegate.buzz() }
    currentPageIndex = (currentPageIndex == 0) ? pageCount - 1 : currentPageIndex - 1
    if currentPageIndex == pageCount - 1 {
      candidateView.highlightedIndex = min(lastPageContentCount - 1, candidateView.highlightedIndex)
    }
    // candidateView.highlightedIndex = 0
    layoutCandidateView()
    return true
  }

  @discardableResult override public func highlightNextCandidate() -> Bool {
    guard let delegate = delegate else { return false }
    selectedCandidateIndex =
      (selectedCandidateIndex + 1 >= delegate.candidatePairs(conv: false).count)
      ? 0 : selectedCandidateIndex + 1
    return true
  }

  @discardableResult override public func highlightPreviousCandidate() -> Bool {
    guard let delegate = delegate else { return false }
    selectedCandidateIndex =
      (selectedCandidateIndex == 0)
      ? delegate.candidatePairs(conv: false).count - 1 : selectedCandidateIndex - 1
    return true
  }

  override public func candidateIndexAtKeyLabelIndex(_ index: Int) -> Int {
    guard let delegate = delegate else {
      return Int.max
    }

    let result = currentPageIndex * keyLabels.count + index
    return result < delegate.candidatePairs(conv: false).count ? result : Int.max
  }

  override public var selectedCandidateIndex: Int {
    get {
      currentPageIndex * keyLabels.count + candidateView.highlightedIndex
    }
    set {
      guard let delegate = delegate else {
        return
      }
      let keyLabelCount = keyLabels.count
      if newValue < delegate.candidatePairs(conv: false).count {
        currentPageIndex = newValue / keyLabelCount
        candidateView.highlightedIndex = newValue % keyLabelCount
        layoutCandidateView()
      }
    }
  }
}

extension CtlCandidateUniversal {
  private var pageCount: Int {
    guard let delegate = delegate else {
      return 0
    }
    let totalCount = delegate.candidatePairs(conv: false).count
    let keyLabelCount = keyLabels.count
    return totalCount / keyLabelCount + ((totalCount % keyLabelCount) != 0 ? 1 : 0)
  }

  private var lastPageContentCount: Int {
    guard let delegate = delegate else {
      return 0
    }
    let totalCount = delegate.candidatePairs(conv: false).count
    let keyLabelCount = keyLabels.count
    return totalCount % keyLabelCount
  }

  private func layoutCandidateView() {
    guard let delegate = delegate, let window = window else { return }

    candidateView.set(keyLabelFont: keyLabelFont, candidateFont: candidateFont)
    var candidates = [(String, String)]()
    let count = delegate.candidatePairs(conv: false).count
    let keyLabelCount = keyLabels.count

    let begin = currentPageIndex * keyLabelCount
    for index in begin..<min(begin + keyLabelCount, count) {
      let candidate = delegate.candidatePairAt(index)
      candidates.append(candidate)
    }
    candidateView.set(
      keyLabels: keyLabels.map(\.displayedText), displayedCandidates: candidates.map(\.1)
    )
    var newSize = candidateView.sizeForView
    var frameRect = candidateView.frame
    frameRect.size = newSize
    candidateView.frame = frameRect
    let counterHeight: Double = newSize.height - 24.0

    if pageCount > 1, showPageButtons {
      var buttonRect = nextPageButton.frame
      let spacing = 0.0

      if currentLayout == .horizontal { buttonRect.size.height = floor(newSize.height / 2) }
      let buttonOriginY: Double = {
        if currentLayout == .vertical {
          return counterHeight
        }
        return (newSize.height - (buttonRect.size.height * 2.0 + spacing)) / 2.0
      }()
      buttonRect.origin = NSPoint(x: newSize.width, y: buttonOriginY)
      nextPageButton.frame = buttonRect
      buttonRect.origin = NSPoint(
        x: newSize.width, y: buttonOriginY + buttonRect.size.height + spacing
      )
      prevPageButton.frame = buttonRect
      newSize.width += 20
      nextPageButton.isHidden = false
      prevPageButton.isHidden = false
    } else {
      nextPageButton.isHidden = true
      prevPageButton.isHidden = true
    }

    if pageCount >= 2 {
      let attrString = NSMutableAttributedString(
        string: "\(currentPageIndex + 1)/\(pageCount)",
        attributes: [
          .font: NSFont.systemFont(ofSize: candidateView.fractionFontSize)
        ]
      )
      pageCounterLabel.attributedStringValue = attrString
      var rect = attrString.boundingRect(
        with: NSSize(width: 1600.0, height: 1600.0),
        options: .usesLineFragmentOrigin
      )

      rect.size.height += 3
      rect.size.width += 4
      let rectOriginY: Double =
        (currentLayout == .horizontal)
        ? (newSize.height - rect.height) / 2
        : counterHeight
      let rectOriginX: Double =
        showPageButtons
        ? newSize.width
        : newSize.width + 4
      rect.origin = NSPoint(x: rectOriginX, y: rectOriginY)
      pageCounterLabel.frame = rect
      newSize.width += rect.width + 4
      pageCounterLabel.isHidden = false
    } else {
      pageCounterLabel.isHidden = true
    }

    frameRect = window.frame

    let topLeftPoint = NSPoint(x: frameRect.origin.x, y: frameRect.origin.y + frameRect.size.height)
    frameRect.size = newSize
    frameRect.origin = NSPoint(x: topLeftPoint.x, y: topLeftPoint.y - frameRect.size.height)
    window.setFrame(frameRect, display: false)
    candidateView.setNeedsDisplay(candidateView.bounds)
  }

  @objc private func pageButtonAction(_ sender: Any) {
    guard let sender = sender as? NSButton else {
      return
    }
    if sender == nextPageButton {
      _ = showNextPage()
    } else if sender == prevPageButton {
      _ = showPreviousPage()
    }
  }

  @objc private func candidateViewMouseDidClick(_: Any) {
    delegate?.candidatePairSelected(at: selectedCandidateIndex)
  }
}
