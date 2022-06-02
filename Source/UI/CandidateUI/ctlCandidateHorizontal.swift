// Copyright (c) 2011 and onwards The OpenVanilla Project (MIT License).
// All possible vChewing-specific modifications are of:
// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
/*
Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

1. The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

2. No trademark license is granted to use the trade names, trademarks, service
marks, or product names of Contributor, except as required to fulfill notice
requirements above.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

import Cocoa

private class HorizontalCandidateView: NSView {
  var highlightedIndex: Int = 0 { didSet { highlightedIndex = max(highlightedIndex, 0) } }
  var action: Selector?
  weak var target: AnyObject?

  private var keyLabels: [String] = []
  private var displayedCandidates: [String] = []
  private var dispCandidatesWithLabels: [String] = []
  private var keyLabelHeight: CGFloat = 0
  private var keyLabelWidth: CGFloat = 0
  private var candidateTextHeight: CGFloat = 0
  private var cellPadding: CGFloat = 0
  private var keyLabelAttrDict: [NSAttributedString.Key: AnyObject] = [:]
  private var candidateAttrDict: [NSAttributedString.Key: AnyObject] = [:]
  private var candidateWithLabelAttrDict: [NSAttributedString.Key: AnyObject] = [:]
  private var elementWidths: [CGFloat] = []
  private var trackingHighlightedIndex: Int = .max {
    didSet { trackingHighlightedIndex = max(trackingHighlightedIndex, 0) }
  }

  override var isFlipped: Bool {
    true
  }

  var sizeForView: NSSize {
    var result = NSSize.zero

    if !elementWidths.isEmpty {
      result.width = elementWidths.reduce(0, +) + CGFloat(elementWidths.count)
      result.height = candidateTextHeight + cellPadding
    }
    return result
  }

  @objc(setKeyLabels:displayedCandidates:)
  func set(keyLabels labels: [String], displayedCandidates candidates: [String]) {
    let count = min(labels.count, candidates.count)
    keyLabels = Array(labels[0..<count])
    displayedCandidates = Array(candidates[0..<count])
    dispCandidatesWithLabels = zip(keyLabels, displayedCandidates).map { $0 + $1 }

    var newWidths = [CGFloat]()
    let baseSize = NSSize(width: 10240.0, height: 10240.0)
    for index in 0..<count {
      let rctCandidate = (dispCandidatesWithLabels[index] as NSString).boundingRect(
        with: baseSize, options: .usesLineFragmentOrigin,
        attributes: candidateWithLabelAttrDict
      )
      var cellWidth = rctCandidate.size.width + cellPadding
      let cellHeight = rctCandidate.size.height + cellPadding
      if cellWidth < cellHeight * 1.35 {
        cellWidth = cellHeight * 1.35
      }
      newWidths.append(round(cellWidth))
    }
    elementWidths = newWidths
  }

  @objc(setKeyLabelFont:candidateFont:)
  func set(keyLabelFont labelFont: NSFont, candidateFont: NSFont) {
    let paraStyle = NSMutableParagraphStyle()
    paraStyle.setParagraphStyle(NSParagraphStyle.default)
    paraStyle.alignment = .center

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
    keyLabelWidth = ceil(labelFontSize)
    keyLabelHeight = ceil(labelFontSize * 2)
    candidateTextHeight = ceil(candidateFontSize * 1.20)
    cellPadding = ceil(biggestSize / 4.0) * 2
  }

  override func draw(_: NSRect) {
    let bounds = bounds
    NSColor.controlBackgroundColor.setFill()  // Candidate list panel base background
    NSBezierPath.fill(bounds)

    NSColor.systemGray.withAlphaComponent(0.75).setStroke()

    NSBezierPath.strokeLine(
      from: NSPoint(x: bounds.size.width, y: 0.0),
      to: NSPoint(x: bounds.size.width, y: bounds.size.height)
    )

    var accuWidth: CGFloat = 0
    for (index, elementWidth) in elementWidths.enumerated() {
      let currentWidth = elementWidth
      let rctCandidateArea = NSRect(
        x: accuWidth, y: 0.0, width: currentWidth + 1.0,
        height: candidateTextHeight + cellPadding
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
        let colorBlendAmount: CGFloat = IME.isDarkMode() ? 0.25 : 0
        // The background color of the highlightened candidate
        switch ctlInputMethod.currentKeyHandler.inputMode {
          case InputMode.imeModeCHS:
            NSColor.systemRed.blended(
              withFraction: colorBlendAmount,
              of: NSColor.controlBackgroundColor
            )!
            .setFill()
          case InputMode.imeModeCHT:
            NSColor.systemBlue.blended(
              withFraction: colorBlendAmount,
              of: NSColor.controlBackgroundColor
            )!
            .setFill()
          default:
            NSColor.alternateSelectedControlColor.setFill()
        }
        // Highlightened index text color
        activeCandidateIndexAttr[.foregroundColor] = NSColor.selectedMenuItemTextColor
          .withAlphaComponent(0.84)
        // Highlightened phrase text color
        activeCandidateAttr[.foregroundColor] = NSColor.selectedMenuItemTextColor
      } else {
        NSColor.controlBackgroundColor.setFill()
      }
      switch ctlInputMethod.currentKeyHandler.inputMode {
        case InputMode.imeModeCHS:
          if #available(macOS 12.0, *) {
            activeCandidateAttr[.languageIdentifier] = "zh-Hans" as AnyObject
          }
        case InputMode.imeModeCHT:
          if #available(macOS 12.0, *) {
            activeCandidateAttr[.languageIdentifier] = "zh-Hant" as AnyObject
          }
        default:
          break
      }
      NSBezierPath.fill(rctCandidateArea)
      (keyLabels[index] as NSString).draw(
        in: rctLabel, withAttributes: activeCandidateIndexAttr
      )
      (displayedCandidates[index] as NSString).draw(
        in: rctCandidatePhrase, withAttributes: activeCandidateAttr
      )
      accuWidth += currentWidth + 1.0
    }
  }

  private func findHitIndex(event: NSEvent) -> Int {
    let location = convert(event.locationInWindow, to: nil)
    if !bounds.contains(location) {
      return NSNotFound
    }
    var accuWidth: CGFloat = 0.0
    for (index, elementWidth) in elementWidths.enumerated() {
      let currentWidth = elementWidth

      if location.x >= accuWidth, location.x <= accuWidth + currentWidth {
        return index
      }
      accuWidth += currentWidth + 1.0
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

public class ctlCandidateHorizontal: ctlCandidate {
  private var candidateView: HorizontalCandidateView
  private var prevPageButton: NSButton
  private var nextPageButton: NSButton
  private var currentPageIndex: Int = 0

  public init() {
    var contentRect = NSRect(x: 128.0, y: 128.0, width: 0.0, height: 0.0)
    let styleMask: NSWindow.StyleMask = [.nonactivatingPanel]
    let panel = NSPanel(
      contentRect: contentRect, styleMask: styleMask, backing: .buffered, defer: false
    )
    panel.level = NSWindow.Level(Int(kCGPopUpMenuWindowLevel) + 1)
    panel.hasShadow = true
    panel.isOpaque = false
    panel.backgroundColor = NSColor.clear

    contentRect.origin = NSPoint.zero
    candidateView = HorizontalCandidateView(frame: contentRect)

    candidateView.wantsLayer = true
    candidateView.layer?.borderColor =
      NSColor.selectedMenuItemTextColor.withAlphaComponent(0.10).cgColor
    candidateView.layer?.borderWidth = 1.0
    if #available(macOS 10.13, *) {
      candidateView.layer?.cornerRadius = 6.0
    }

    panel.contentView?.addSubview(candidateView)

    contentRect.size = NSSize(width: 20.0, height: 10.0)  // Reduce the button width
    let buttonAttribute: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 9.0)]

    nextPageButton = NSButton(frame: contentRect)
    NSColor.controlBackgroundColor.setFill()
    NSBezierPath.fill(nextPageButton.bounds)
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
    prevPageButton = NSButton(frame: contentRect)
    NSColor.controlBackgroundColor.setFill()
    NSBezierPath.fill(prevPageButton.bounds)
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

    super.init(window: panel)

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

  override public func showNextPage() -> Bool {
    guard delegate != nil else { return false }
    if pageCount == 1 { return highlightNextCandidate() }
    if currentPageIndex + 1 >= pageCount { clsSFX.beep() }
    currentPageIndex = (currentPageIndex + 1 >= pageCount) ? 0 : currentPageIndex + 1
    candidateView.highlightedIndex = 0
    layoutCandidateView()
    return true
  }

  override public func showPreviousPage() -> Bool {
    guard delegate != nil else { return false }
    if pageCount == 1 { return highlightPreviousCandidate() }
    if currentPageIndex == 0 { clsSFX.beep() }
    currentPageIndex = (currentPageIndex == 0) ? pageCount - 1 : currentPageIndex - 1
    candidateView.highlightedIndex = 0
    layoutCandidateView()
    return true
  }

  override public func highlightNextCandidate() -> Bool {
    guard let delegate = delegate else { return false }
    selectedCandidateIndex =
      (selectedCandidateIndex + 1 >= delegate.candidateCountForController(self))
      ? 0 : selectedCandidateIndex + 1
    return true
  }

  override public func highlightPreviousCandidate() -> Bool {
    guard let delegate = delegate else { return false }
    selectedCandidateIndex =
      (selectedCandidateIndex == 0)
      ? delegate.candidateCountForController(self) - 1 : selectedCandidateIndex - 1
    return true
  }

  override public func candidateIndexAtKeyLabelIndex(_ index: Int) -> Int {
    guard let delegate = delegate else {
      return Int.max
    }

    let result = currentPageIndex * keyLabels.count + index
    return result < delegate.candidateCountForController(self) ? result : Int.max
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
      if newValue < delegate.candidateCountForController(self) {
        currentPageIndex = newValue / keyLabelCount
        candidateView.highlightedIndex = newValue % keyLabelCount
        layoutCandidateView()
      }
    }
  }
}

extension ctlCandidateHorizontal {
  private var pageCount: Int {
    guard let delegate = delegate else {
      return 0
    }
    let totalCount = delegate.candidateCountForController(self)
    let keyLabelCount = keyLabels.count
    return totalCount / keyLabelCount + ((totalCount % keyLabelCount) != 0 ? 1 : 0)
  }

  private func layoutCandidateView() {
    guard let delegate = delegate else {
      return
    }

    candidateView.set(keyLabelFont: keyLabelFont, candidateFont: candidateFont)
    var candidates = [String]()
    let count = delegate.candidateCountForController(self)
    let keyLabelCount = keyLabels.count

    let begin = currentPageIndex * keyLabelCount
    for index in begin..<min(begin + keyLabelCount, count) {
      let candidate = delegate.ctlCandidate(self, candidateAtIndex: index)
      candidates.append(candidate)
    }
    candidateView.set(
      keyLabels: keyLabels.map(\.displayedText), displayedCandidates: candidates
    )
    var newSize = candidateView.sizeForView
    var frameRect = candidateView.frame
    frameRect.size = newSize
    candidateView.frame = frameRect

    if pageCount > 1, mgrPrefs.showPageButtonsInCandidateWindow {
      var buttonRect = nextPageButton.frame
      let spacing: CGFloat = 0.0

      buttonRect.size.height = floor(newSize.height / 2)

      let buttonOriginY = (newSize.height - (buttonRect.size.height * 2.0 + spacing)) / 2.0
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

    frameRect = window?.frame ?? NSRect.zero

    let topLeftPoint = NSPoint(x: frameRect.origin.x, y: frameRect.origin.y + frameRect.size.height)
    frameRect.size = newSize
    frameRect.origin = NSPoint(x: topLeftPoint.x, y: topLeftPoint.y - frameRect.size.height)
    window?.setFrame(frameRect, display: false)
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
    delegate?.ctlCandidate(self, didSelectCandidateAtIndex: selectedCandidateIndex)
  }
}
