// (c) 2022 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import AppKit

extension NSColor {
  fileprivate static var dark: NSColor { NSColor(calibratedWhite: 0.12, alpha: 1) }
}

// MARK: - RoundedBadgeTextAttachmentCell

private final class RoundedBadgeTextAttachmentCell: NSTextAttachmentCell {
  // MARK: Lifecycle

  init(
    label: String,
    attributes: [NSAttributedString.Key: Any],
    backgroundColor: NSColor,
    padding: NSEdgeInsets
  ) {
    self.text = NSAttributedString(string: label, attributes: attributes)
    self.backgroundColor = backgroundColor
    self.padding = padding

    let constraint = CGSize(
      width: CGFloat.greatestFiniteMagnitude,
      height: CGFloat.greatestFiniteMagnitude
    )
    let textBounds = text.boundingRect(
      with: constraint,
      options: [.usesLineFragmentOrigin, .usesFontLeading]
    )
    var size = CGSize(
      width: ceil(textBounds.width) + padding.left + padding.right,
      height: ceil(textBounds.height) + padding.top + padding.bottom
    )
    if let font = attributes[.font] as? NSFont {
      let ascent = font.ascender
      let descent = -font.descender
      let lineHeight = ceil(ascent + descent)
      size.height = max(size.height, lineHeight + padding.top + padding.bottom)
    }
    self.cachedSize = size
    self.cornerRadius = size.height / 2
    super.init()
  }

  @available(*, unavailable)
  required init(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // MARK: Internal

  // MARK: NSTextAttachmentCell

  override func cellSize() -> CGSize { cachedSize }

  override func draw(withFrame cellFrame: CGRect, in controlView: NSView?, characterIndex: Int) {
    backgroundColor.setFill()
    NSBezierPath(roundedRect: cellFrame, xRadius: cornerRadius, yRadius: cornerRadius).fill()

    let textRect = CGRect(
      x: cellFrame.origin.x + padding.left,
      y: cellFrame.origin.y + padding.bottom,
      width: cellFrame.width - padding.left - padding.right,
      height: cellFrame.height - padding.top - padding.bottom
    )
    text.draw(in: textRect)
  }

  // MARK: Private

  private let text: NSAttributedString
  private let backgroundColor: NSColor
  private let cornerRadius: CGFloat
  private let padding: NSEdgeInsets
  private let cachedSize: CGSize
}

// MARK: - UI Metrics.

extension CandidatePool {
  public func updateMetrics() {
    // 開工
    let initialOrigin: CGPoint = .init(x: originDelta, y: originDelta)
    var totalAccuSize: CGSize = .zero
    // Origin is at the top-left corner.
    var currentOrigin: CGPoint = initialOrigin
    var highlightedCellRect: CGRect = .zero
    var highlightedLineRect: CGRect = .zero
    var currentPageLines = candidateLines[lineRangeForCurrentPage]
    var blankLines = maxLinesPerPage - currentPageLines.count
    var fillBlankCells = true
    switch (layout, isMatrix) {
    case (.horizontal, false):
      blankLines = 0
      fillBlankCells = false
    case (.vertical, false): blankLines = 0
    case (_, true): break
    }
    while blankLines > 0 {
      currentPageLines.append(.init(repeating: Self.shitCell, count: maxLineCapacity))
      blankLines -= 1
    }
    Self.shitCell.updateMetrics(pool: self, origin: currentOrigin)
    Self.shitCell.isHighlighted = false
    let minimumCellDimension = Self.shitCell.visualDimension
    currentPageLines.forEach { currentLine in
      let currentLineOrigin = currentOrigin
      var accumulatedLineSize: CGSize = .zero
      var currentLineRect: CGRect { .init(origin: currentLineOrigin, size: accumulatedLineSize) }
      let lineHasHighlightedCell = currentLine.hasHighlightedCell

      currentLine.forEach { currentCell in
        currentCell.updateMetrics(pool: self, origin: currentOrigin)
        var cellDimension = currentCell.visualDimension
        if layout == .vertical || currentCell.displayedText.count <= 2 {
          cellDimension.width = max(minimumCellDimension.width, cellDimension.width)
        }
        cellDimension.height = max(minimumCellDimension.height, cellDimension.height)

        switch self.layout {
        case .horizontal:
          accumulatedLineSize.width += cellDimension.width
          accumulatedLineSize.height = max(accumulatedLineSize.height, cellDimension.height)
        case .vertical:
          accumulatedLineSize.height += cellDimension.height
          accumulatedLineSize.width = max(accumulatedLineSize.width, cellDimension.width)
        }

        if lineHasHighlightedCell {
          switch self.layout {
          case .horizontal where currentCell.isHighlighted:
            highlightedCellRect.size.width = cellDimension.width
          case .vertical:
            highlightedCellRect.size.width = max(
              highlightedCellRect.size.width,
              cellDimension.width
            )
          default: break
          }
          if currentCell.isHighlighted {
            highlightedCellRect.origin = currentOrigin
            highlightedCellRect.size.height = cellDimension.height
          }
        }

        switch self.layout {
        case .horizontal: currentOrigin.x += cellDimension.width
        case .vertical: currentOrigin.y += cellDimension.height
        }
      }

      if lineHasHighlightedCell {
        highlightedLineRect.origin = currentLineRect.origin
        switch self.layout {
        case .horizontal:
          highlightedLineRect.size.height = currentLineRect.size.height
        case .vertical:
          highlightedLineRect.size.width = currentLineRect.size.width
        }
      }

      switch self.layout {
      case .horizontal:
        highlightedLineRect.size.width = max(currentLineRect.size.width, highlightedLineRect.width)
      case .vertical:
        highlightedLineRect.size.height = max(
          currentLineRect.size.height,
          highlightedLineRect.height
        )
        currentLine.forEach { theCell in
          theCell.visualDimension.width = accumulatedLineSize.width
        }
      }

      switch self.layout {
      case .horizontal:
        currentOrigin.x = originDelta
        currentOrigin.y += accumulatedLineSize.height
        totalAccuSize.width = max(totalAccuSize.width, accumulatedLineSize.width)
        totalAccuSize.height += accumulatedLineSize.height
      case .vertical:
        currentOrigin.y = originDelta
        currentOrigin.x += accumulatedLineSize.width
        totalAccuSize.height = max(totalAccuSize.height, accumulatedLineSize.height)
        totalAccuSize.width += accumulatedLineSize.width
      }
    }
    if fillBlankCells {
      switch layout {
      case .horizontal:
        totalAccuSize.width = max(
          totalAccuSize.width,
          CGFloat(maxLineCapacity) * minimumCellDimension.width
        )
        highlightedLineRect.size.width = totalAccuSize.width
      case .vertical:
        totalAccuSize.height = CGFloat(maxLineCapacity) * minimumCellDimension.height
      }
    }
    // 繪製附加內容
    let strPeripherals = attributedDescriptionBottomPanes
    var dimensionPeripherals = strPeripherals.getBoundingDimension(forceFallback: true)
    dimensionPeripherals.width = ceil(dimensionPeripherals.width)
    dimensionPeripherals.height = ceil(dimensionPeripherals.height)
    if finalContainerOrientation == .horizontal {
      totalAccuSize.width += 5
      dimensionPeripherals.width += 5
      let delta = max(
        CandidateCellData.unifiedTextHeight + padding * 2 - dimensionPeripherals.height,
        0
      )
      currentOrigin = .init(x: totalAccuSize.width + originDelta, y: ceil(delta / 2) + originDelta)
      totalAccuSize.width += dimensionPeripherals.width
    } else {
      totalAccuSize.height += 2
      currentOrigin = .init(x: padding + originDelta, y: totalAccuSize.height + originDelta)
      totalAccuSize.height += dimensionPeripherals.height
      totalAccuSize.width = max(totalAccuSize.width, dimensionPeripherals.width)
    }
    let rectPeripherals = CGRect(origin: currentOrigin, size: dimensionPeripherals)
    totalAccuSize.width += originDelta * 2
    totalAccuSize.height += originDelta * 2
    metrics = .init(
      fittingSize: totalAccuSize,
      highlightedLine: highlightedLineRect,
      highlightedCandidate: highlightedCellRect,
      peripherals: rectPeripherals
    )
  }

  private var finalContainerOrientation: NSUserInterfaceLayoutOrientation {
    if maxLinesPerPage == 1, layout == .horizontal { return .horizontal }
    return .vertical
  }
}

// MARK: - Using One Single NSAttributedString. (Some of them are for debug purposes.)

extension CandidatePool {
  // MARK: Candidate List with Peripherals.

  public var attributedDescription: NSAttributedString {
    switch layout {
    case .horizontal: return attributedDescriptionHorizontal
    case .vertical: return attributedDescriptionVertical
    }
  }

  private var sharedParagraphStyle: NSParagraphStyle { CandidateCellData.sharedParagraphStyle }

  private var attributedDescriptionHorizontal: NSAttributedString {
    let paragraphStyle = sharedParagraphStyle
    let attrCandidate: [NSAttributedString.Key: Any] = [
      .kern: 0,
      .font: Self.blankCell.phraseFont(size: Self.blankCell.size),
      .paragraphStyle: paragraphStyle,
    ]
    let result = NSMutableAttributedString(string: "", attributes: attrCandidate)
    let spacer = NSAttributedString(string: " ", attributes: attrCandidate)
    let lineFeed = NSAttributedString(string: "\n", attributes: attrCandidate)
    for lineID in lineRangeForCurrentPage {
      let arrLine = candidateLines[lineID]
      arrLine.enumerated().forEach { cellID, currentCell in
        let cellString = NSMutableAttributedString(
          attributedString: currentCell.attributedString(
            noSpacePadding: false,
            withHighlight: true,
            isMatrix: isMatrix
          )
        )
        if lineID != currentLineNumber {
          cellString.addAttribute(
            .foregroundColor,
            value: NSColor.gray,
            range: .init(location: 0, length: cellString.string.utf16.count)
          )
        }
        result.append(cellString)
        if cellID < arrLine.count - 1 {
          result.append(spacer)
        }
      }
      if lineID < lineRangeForCurrentPage.upperBound - 1 || isMatrix {
        result.append(lineFeed)
      } else {
        result.append(spacer)
      }
    }
    // 這裡已經換行過了。
    result.append(attributedDescriptionBottomPanes)
    return result
  }

  private var attributedDescriptionVertical: NSAttributedString {
    let paragraphStyle = sharedParagraphStyle
    let attrCandidate: [NSAttributedString.Key: Any] = [
      .kern: 0,
      .font: Self.blankCell.phraseFont(size: Self.blankCell.size),
      .paragraphStyle: paragraphStyle,
    ]
    let result = NSMutableAttributedString(string: "", attributes: attrCandidate)
    let spacer = NSMutableAttributedString(string: "　", attributes: attrCandidate)
    let lineFeed = NSAttributedString(string: "\n", attributes: attrCandidate)
    for (inlineIndex, _) in selectionKeys.enumerated() {
      for (lineID, lineData) in candidateLines.enumerated() {
        if !fallbackedLineRangeForCurrentPage.contains(lineID) { continue }
        if !(0 ..< lineData.count).contains(inlineIndex) { continue }
        let currentCell = lineData[inlineIndex]
        let cellString = NSMutableAttributedString(
          attributedString: currentCell.attributedString(
            noSpacePadding: false,
            withHighlight: true,
            isMatrix: isMatrix
          )
        )
        if lineID != currentLineNumber {
          cellString.addAttribute(
            .foregroundColor,
            value: NSColor.gray,
            range: .init(location: 0, length: cellString.string.utf16.count)
          )
        }
        result.append(cellString)
        if isMatrix, currentCell.displayedText.count > 1 {
          if currentCell.isHighlighted {
            spacer.addAttribute(
              .backgroundColor,
              value: currentCell.themeColorCocoa,
              range: .init(location: 0, length: spacer.string.utf16.count)
            )
          } else {
            spacer.removeAttribute(
              .backgroundColor,
              range: .init(location: 0, length: spacer.string.utf16.count)
            )
          }
          result.append(spacer)
        }
      }
      result.append(lineFeed)
    }
    // 這裡已經換行過了。
    result.append(attributedDescriptionBottomPanes)
    return result
  }

  // MARK: Peripherals

  public var attributedDescriptionBottomPanes: NSAttributedString {
    let paragraphStyle = sharedParagraphStyle
    let result = NSMutableAttributedString(string: "")
    result.append(attributedDescriptionPositionCounter)
    if !tooltip.isEmpty { result.append(attributedDescriptionTooltip) }
    if !reverseLookupResult.isEmpty { result.append(attributedDescriptionReverseLookup) }
    result.addAttribute(
      .paragraphStyle,
      value: paragraphStyle,
      range: .init(location: 0, length: result.string.utf16.count)
    )
    return result
  }

  private var attributedDescriptionPositionCounter: NSAttributedString {
    let attachment = NSTextAttachment()
    let badgeCell = makePositionCounterBadgeCell()
    attachment.attachmentCell = badgeCell
    return .init(attachment: attachment)
  }

  private var attributedDescriptionTooltip: NSAttributedString {
    let positionCounterTextSize = max(ceil(CandidateCellData.unifiedSize * 0.7), 11)
    let tooltipColorBG = Self.shitCell.clientThemeColor ?? Self.shitCell.themeColorCocoa
    let tooltipColorText = NSColor.white
    let attrTooltip: [NSAttributedString.Key: Any] = [
      .kern: 0,
      .font: Self.blankCell.phraseFontEmphasized(size: positionCounterTextSize),
      .foregroundColor: tooltipColorText,
    ]
    let fontSize = CGFloat(positionCounterTextSize)
    let verticalInset = max((fontSize * 0.12).rounded(.up), 1)
    let horizontalInset = max((fontSize * 0.12).rounded(.up), 1)
    let attachment = NSTextAttachment()
    let badgeCell = RoundedBadgeTextAttachmentCell(
      label: " \(tooltip) ",
      attributes: attrTooltip,
      backgroundColor: tooltipColorBG,
      padding: .init(
        top: verticalInset,
        left: horizontalInset,
        bottom: verticalInset,
        right: horizontalInset
      )
    )
    attachment.attachmentCell = badgeCell
    return .init(attachment: attachment)
  }

  private var attributedDescriptionReverseLookup: NSAttributedString {
    let reverseLookupTextSize = max(ceil(CandidateCellData.unifiedSize * 0.6), 9)
    let badgeFont = Self.blankCell.phraseFont(size: reverseLookupTextSize)
    let attrReverseLookup: [NSAttributedString.Key: Any] = [
      .kern: 0,
      .font: badgeFont,
      .foregroundColor: CandidateCellData.absoluteTextColor,
    ]
    var segments: [String] = []
    var addedCounter = 0
    for neta in reverseLookupResult {
      segments.append(" \(neta) ")
      addedCounter += 1
      if maxLinesPerPage == 1, addedCounter == 2 { break }
    }
    guard !segments.isEmpty else { return NSAttributedString(string: "") }
    let label = segments.joined()
    let fontSize = CGFloat(reverseLookupTextSize)
    let referenceHeight = positionCounterBadgeHeight()
    let contentHeight = badgeContentHeight(label: label, attributes: attrReverseLookup)
    let verticalInset = max((referenceHeight - contentHeight) / 2, 1)
    let horizontalInset = max((fontSize * 0.45).rounded(.up), 4)
    let attachment = NSTextAttachment()
    let badgeCell = RoundedBadgeTextAttachmentCell(
      label: label,
      attributes: attrReverseLookup,
      backgroundColor: .clear,
      padding: .init(
        top: verticalInset,
        left: horizontalInset,
        bottom: verticalInset,
        right: horizontalInset
      )
    )
    attachment.attachmentCell = badgeCell
    return .init(attachment: attachment)
  }
}

// MARK: - Badge Helpers

extension CandidatePool {
  fileprivate func makePositionCounterBadgeCell() -> RoundedBadgeTextAttachmentCell {
    let positionCounterColorBG =
      NSApplication.isDarkMode
        ? NSColor(white: 0.215, alpha: 0.7)
        : NSColor(white: 0.9, alpha: 0.7)
    let positionCounterColorText = CandidateCellData.plainTextColor
    let positionCounterTextSize = max(ceil(CandidateCellData.unifiedSize * 0.7), 11)
    let badgeFont = Self.blankCell.phraseFontEmphasized(size: positionCounterTextSize)
    let attrPositionCounter: [NSAttributedString.Key: Any] = [
      .kern: 0,
      .font: badgeFont,
      .foregroundColor: positionCounterColorText,
    ]
    let fontSize = CGFloat(positionCounterTextSize)
    let verticalInset = max((fontSize * 0.12).rounded(.up), 1)
    let horizontalInset = max((fontSize * 0.45).rounded(.up), 4)
    return RoundedBadgeTextAttachmentCell(
      label: "\(currentPositionLabelText)",
      attributes: attrPositionCounter,
      backgroundColor: positionCounterColorBG,
      padding: .init(
        top: verticalInset,
        left: horizontalInset,
        bottom: verticalInset,
        right: horizontalInset
      )
    )
  }

  fileprivate func positionCounterBadgeHeight() -> CGFloat {
    makePositionCounterBadgeCell()
      .cellSize().height
  }

  fileprivate func badgeContentHeight(
    label: String,
    attributes: [NSAttributedString.Key: Any]
  )
    -> CGFloat {
    let constraint = CGSize(
      width: CGFloat.greatestFiniteMagnitude,
      height: CGFloat.greatestFiniteMagnitude
    )
    let textBounds = NSAttributedString(string: label, attributes: attributes).boundingRect(
      with: constraint,
      options: [.usesLineFragmentOrigin, .usesFontLeading]
    )
    var contentHeight = ceil(textBounds.height)
    if let font = attributes[.font] as? NSFont {
      let ascent = font.ascender
      let descent = -font.descender
      let lineHeight = ceil(ascent + descent)
      contentHeight = max(contentHeight, lineHeight)
    }
    return contentHeight
  }
}
