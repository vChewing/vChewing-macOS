// (c) 2022 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Cocoa

extension CandidatePool {
  public var attributedDescription: NSAttributedString {
    switch layout {
    case .horizontal: return attributedDescriptionHorizontal
    case .vertical: return attributedDescriptionVertical
    }
  }

  /// 將當前資料池以橫版的形式列印成 NSAttributedString。
  private var attributedDescriptionHorizontal: NSAttributedString {
    let paragraphStyle = CandidateCellData.sharedParagraphStyle as! NSMutableParagraphStyle
    paragraphStyle.lineSpacing = ceil(blankCell.size * 0.3)
    paragraphStyle.lineBreakStrategy = .pushOut
    let attrCandidate: [NSAttributedString.Key: AnyObject] = [
      .font: NSFont.monospacedDigitSystemFont(ofSize: blankCell.size, weight: .regular),
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
            noSpacePadding: false, withHighlight: true, isMatrix: maxLinesPerPage > 1
          )
        )
        if lineID != currentLineNumber {
          cellString.addAttribute(
            .foregroundColor, value: NSColor.controlTextColor,
            range: .init(location: 0, length: cellString.string.utf16.count)
          )
        }
        result.append(cellString)
        if cellID < arrLine.count - 1 {
          result.append(spacer)
        }
      }
      if lineID < lineRangeForCurrentPage.upperBound - 1 || maxLinesPerPage > 1 {
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
    let paragraphStyle = CandidateCellData.sharedParagraphStyle as! NSMutableParagraphStyle
    paragraphStyle.lineSpacing = ceil(blankCell.size * 0.3)
    paragraphStyle.lineBreakStrategy = .pushOut
    let attrCandidate: [NSAttributedString.Key: AnyObject] = [
      .font: NSFont.monospacedDigitSystemFont(ofSize: blankCell.size, weight: .regular),
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
            noSpacePadding: false, withHighlight: true, isMatrix: maxLinesPerPage > 1
          )
        )
        if lineID != currentLineNumber {
          cellString.addAttribute(
            .foregroundColor, value: NSColor.gray,
            range: .init(location: 0, length: cellString.string.utf16.count)
          )
        }
        result.append(cellString)
        if maxLinesPerPage > 1, currentCell.displayedText.count > 1 {
          if currentCell.isHighlighted {
            spacer.addAttribute(
              .backgroundColor,
              value: currentCell.highlightedNSColor,
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

  private var attributedDescriptionBottomPanes: NSAttributedString {
    let paragraphStyle = CandidateCellData.sharedParagraphStyle as! NSMutableParagraphStyle
    paragraphStyle.lineSpacing = ceil(blankCell.size * 0.3)
    paragraphStyle.lineBreakStrategy = .pushOut
    let attrCandidate: [NSAttributedString.Key: AnyObject] = [
      .font: NSFont.monospacedDigitSystemFont(ofSize: blankCell.size, weight: .regular),
      .paragraphStyle: paragraphStyle,
    ]
    let result = NSMutableAttributedString(string: "", attributes: attrCandidate)
    let positionCounterColorBG = NSApplication.isDarkMode
      ? NSColor(white: 0.215, alpha: 0.7)
      : NSColor(white: 0.9, alpha: 0.7)
    let positionCounterColorText = NSColor.controlTextColor
    let positionCounterTextSize = max(ceil(CandidateCellData.unifiedSize * 0.7), 11)
    let attrPositionCounter: [NSAttributedString.Key: AnyObject] = [
      .font: NSFont.monospacedDigitSystemFont(ofSize: positionCounterTextSize, weight: .bold),
      .paragraphStyle: paragraphStyle,
      .backgroundColor: positionCounterColorBG,
      .foregroundColor: positionCounterColorText,
    ]
    let positionCounter = NSAttributedString(
      string: " \(currentPositionLabelText) ", attributes: attrPositionCounter
    )
    result.append(positionCounter)

    if !tooltip.isEmpty {
      let attrTooltip: [NSAttributedString.Key: AnyObject] = [
        .font: NSFont.monospacedDigitSystemFont(ofSize: positionCounterTextSize, weight: .regular),
        .paragraphStyle: paragraphStyle,
      ]
      let tooltipText = NSAttributedString(
        string: " \(tooltip) ", attributes: attrTooltip
      )
      result.append(tooltipText)
    }

    if !reverseLookupResult.isEmpty {
      let reverseLookupTextSize = max(ceil(CandidateCellData.unifiedSize * 0.6), 9)
      let reverseLookupColorBG = NSApplication.isDarkMode
        ? NSColor(white: 0.1, alpha: 1)
        : NSColor(white: 0.9, alpha: 1)
      let attrReverseLookup: [NSAttributedString.Key: AnyObject] = [
        .font: NSFont.monospacedDigitSystemFont(ofSize: reverseLookupTextSize, weight: .regular),
        .paragraphStyle: paragraphStyle,
        .backgroundColor: reverseLookupColorBG,
      ]
      let attrReverseLookupSpacer: [NSAttributedString.Key: AnyObject] = [
        .font: NSFont.monospacedDigitSystemFont(ofSize: reverseLookupTextSize, weight: .regular),
        .paragraphStyle: paragraphStyle,
      ]
      for neta in reverseLookupResult {
        result.append(NSAttributedString(string: " ", attributes: attrReverseLookupSpacer))
        result.append(NSAttributedString(string: " \(neta) ", attributes: attrReverseLookup))
        if maxLinesPerPage == 1 { break }
      }
    }
    result.addAttribute(.paragraphStyle, value: paragraphStyle, range: .init(location: 0, length: result.string.utf16.count))
    return result
  }
}
