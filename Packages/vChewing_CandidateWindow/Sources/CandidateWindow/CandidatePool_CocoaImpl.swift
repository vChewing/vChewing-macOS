// (c) 2022 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Cocoa

// MARK: - Using One Single NSAttributedString.

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
    let attrCandidate: [NSAttributedString.Key: AnyObject] = [
      .font: blankCell.phraseFont(size: blankCell.size),
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
            .foregroundColor, value: NSColor.gray,
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
    let paragraphStyle = sharedParagraphStyle
    let attrCandidate: [NSAttributedString.Key: AnyObject] = [
      .font: blankCell.phraseFont(size: blankCell.size),
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
    if !reverseLookupResult.isEmpty { result.append(attributedDescriptionReverseLookp) }
    result.addAttribute(.paragraphStyle, value: paragraphStyle, range: .init(location: 0, length: result.string.utf16.count))
    return result
  }

  private var attributedDescriptionPositionCounter: NSAttributedString {
    let positionCounterColorBG = NSApplication.isDarkMode
      ? NSColor(white: 0.215, alpha: 0.7)
      : NSColor(white: 0.9, alpha: 0.7)
    let positionCounterColorText = NSColor.controlTextColor
    let positionCounterTextSize = max(ceil(CandidateCellData.unifiedSize * 0.7), 11)
    let attrPositionCounter: [NSAttributedString.Key: AnyObject] = [
      .font: blankCell.phraseFontEmphasized(size: positionCounterTextSize),
      .backgroundColor: positionCounterColorBG,
      .foregroundColor: positionCounterColorText,
    ]
    let positionCounter = NSAttributedString(
      string: " \(currentPositionLabelText) ", attributes: attrPositionCounter
    )
    return positionCounter
  }

  private var attributedDescriptionTooltip: NSAttributedString {
    let positionCounterTextSize = max(ceil(CandidateCellData.unifiedSize * 0.7), 11)
    let attrTooltip: [NSAttributedString.Key: AnyObject] = [
      .font: blankCell.phraseFontEmphasized(size: positionCounterTextSize),
    ]
    let tooltipText = NSAttributedString(
      string: " \(tooltip) ", attributes: attrTooltip
    )
    return tooltipText
  }

  private var attributedDescriptionReverseLookp: NSAttributedString {
    let reverseLookupTextSize = max(ceil(CandidateCellData.unifiedSize * 0.6), 9)
    let attrReverseLookup: [NSAttributedString.Key: AnyObject] = [
      .font: blankCell.phraseFont(size: reverseLookupTextSize),
    ]
    let attrReverseLookupSpacer: [NSAttributedString.Key: AnyObject] = [
      .font: blankCell.phraseFont(size: reverseLookupTextSize),
    ]
    let result = NSMutableAttributedString(string: "", attributes: attrReverseLookupSpacer)
    for neta in reverseLookupResult {
      result.append(NSAttributedString(string: " ", attributes: attrReverseLookupSpacer))
      result.append(NSAttributedString(string: " \(neta) ", attributes: attrReverseLookup))
      if maxLinesPerPage == 1 { break }
    }
    return result
  }
}
