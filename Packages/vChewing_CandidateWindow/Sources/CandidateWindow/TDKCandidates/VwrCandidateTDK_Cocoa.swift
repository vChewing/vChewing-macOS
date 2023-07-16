// (c) 2022 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

#if USING_STACK_VIEW_IN_TDK_COCOA

  import AppKit
  import Shared

  /// 田所選字窗的 Cocoa 版本，繪製效率不受 SwiftUI 的限制。
  public class VwrCandidateTDKCocoa: NSStackView {
    public weak var controller: CtlCandidateTDK?
    public var thePool: CandidatePool
    private var lineDimension: CGSize = .zero
    private var candidateAreaDimension: CGSize = .zero

    // MARK: - Constructors.

    public init(controller: CtlCandidateTDK? = nil, thePool pool: CandidatePool) {
      self.controller = controller
      thePool = pool
      super.init(frame: .init(origin: .zero, size: .init(width: 114_514, height: 114_514)))
      refresh()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }
  }

  // MARK: - Interface Renderer.

  public extension VwrCandidateTDKCocoa {
    func refresh() {
      defer {
        vCLog(Self.strForConstraintStatistics.description)
        Self.strForConstraintStatistics = .init()
      }
      // 用來登記全部的行容器，方便在收尾階段統一設定 constraints。
      var arrStackViewsOfLines = [NSStackView]()
      // 清理兩個計數器。
      lineDimension = .zero
      candidateAreaDimension = .zero
      // 容器自身美化。
      edgeInsets = .init(top: 5, left: 5, bottom: 5, right: 5)
      wantsLayer = true
      layer?.backgroundColor = candidateListBackground.cgColor
      layer?.cornerRadius = 10
      // 現在開始準備容器內容。
      let isVerticalListing: Bool = thePool.layout == .vertical
      let candidateContainer = NSStackView()
      // 這是行陳列方向，不是候選字詞陳列方向。
      candidateContainer.orientation = isVerticalListing ? .horizontal : .vertical
      candidateContainer.alignment = isVerticalListing ? .top : .leading
      candidateContainer.spacing = 0
      candidateContainer.setHuggingPriority(.fittingSizeCompression, for: .horizontal)
      candidateContainer.setHuggingPriority(.fittingSizeCompression, for: .vertical)
      for lineID in thePool.lineRangeForCurrentPage {
        var theLine = thePool.candidateLines[lineID]
        let vwrCurrentLine = generateLineContainer(&theLine)
        candidateContainer.addView(vwrCurrentLine, in: isVerticalListing ? .top : .leading)
        arrStackViewsOfLines.append(vwrCurrentLine)
      }
      if thePool.maxLinesPerPage - thePool.lineRangeForCurrentPage.count > 0 {
        thePool.lineRangeForFinalPageBlanked.enumerated().forEach { _ in
          var theLine = [CandidateCellData]()
          let copied = CandidatePool.blankCell.cleanCopy
          for _ in 0 ..< thePool.maxLineCapacity {
            theLine.append(copied)
          }
          let vwrCurrentLine = generateLineContainer(&theLine)
          candidateContainer.addView(vwrCurrentLine, in: isVerticalListing ? .top : .leading)
          arrStackViewsOfLines.append(vwrCurrentLine)
        }
      }

      // 處理行寬或列高。
      switch thePool.layout {
      case .vertical:
        var accumulatedWidth: CGFloat = 0
        var lines = [[CandidateCellData]]()
        thePool.lineRangeForCurrentPage.forEach { lines.append(thePool.candidateLines[$0]) }
        arrStackViewsOfLines.enumerated().forEach { viewLineID, vwrCurrentLine in
          var columnWidth: CGFloat = 0
          if (0 ..< lines.count).contains(viewLineID), !lines.isEmpty {
            let line = Array(lines[viewLineID])
            columnWidth = line.map(\.visualDimension.width).max() ?? lineDimension.width
          } else {
            columnWidth = CandidatePool.blankCell.visualDimension.width
          }
          accumulatedWidth += columnWidth
          Self.makeSimpleConstraint(item: vwrCurrentLine, attribute: .width, relation: .equal, value: columnWidth)
          Self.makeSimpleConstraint(item: vwrCurrentLine, attribute: .height, relation: .equal, value: lineDimension.height)
          Self.addStatistics(vwrCurrentLine, memo: "vwrCurrentLine")
        }
        candidateAreaDimension.width = accumulatedWidth
        candidateAreaDimension.height = lineDimension.height
      case .horizontal:
        arrStackViewsOfLines.forEach { vwrCurrentLine in
          Self.makeSimpleConstraint(item: vwrCurrentLine, attribute: .width, relation: .equal, value: lineDimension.width)
          Self.makeSimpleConstraint(item: vwrCurrentLine, attribute: .height, relation: .equal, value: lineDimension.height)
          Self.addStatistics(vwrCurrentLine, memo: "vwrCurrentLine")
        }
        candidateAreaDimension.width = lineDimension.width
        candidateAreaDimension.height = lineDimension.height * Double(thePool.maxLinesPerPage)
      }

      Self.makeSimpleConstraint(item: candidateContainer, attribute: .width, relation: .equal, value: candidateAreaDimension.width)
      Self.makeSimpleConstraint(item: candidateContainer, attribute: .height, relation: .equal, value: candidateAreaDimension.height)
      Self.addStatistics(candidateContainer, memo: "candidateContainer")

      let vwrPeripherals = Self.makeLabel(thePool.attributedDescriptionBottomPanes)
      Self.makeSimpleConstraint(
        item: vwrPeripherals, attribute: .height, relation: .greaterThanOrEqual,
        value: vwrPeripherals.fittingSize.height
      )
      Self.makeSimpleConstraint(
        item: vwrPeripherals, attribute: .width, relation: .greaterThanOrEqual,
        value: vwrPeripherals.fittingSize.width
      )

      // 組裝。
      let finalContainer = NSStackView()
      let finalContainerOrientation: NSUserInterfaceLayoutOrientation = {
        if thePool.maxLinesPerPage == 1, thePool.layout == .horizontal { return .horizontal }
        return .vertical
      }()

      if finalContainerOrientation == .horizontal {
        let vwrPeripheralMinWidth = vwrPeripherals.fittingSize.width + 3
        Self.makeSimpleConstraint(item: vwrPeripherals, attribute: .width, relation: .greaterThanOrEqual, value: vwrPeripheralMinWidth)
        finalContainer.spacing = 5
      } else {
        finalContainer.spacing = 2
        Self.makeSimpleConstraint(item: vwrPeripherals, attribute: .width, relation: .greaterThanOrEqual, value: vwrPeripherals.fittingSize.width)
      }
      Self.addStatistics(vwrPeripherals, memo: "vwrPeripherals")

      finalContainer.orientation = finalContainerOrientation
      finalContainer.alignment = finalContainerOrientation == .vertical ? .leading : .centerY
      finalContainer.addView(candidateContainer, in: .leading)
      finalContainer.addView(vwrPeripherals, in: .leading)
      Self.makeSimpleConstraint(
        item: finalContainer, attribute: .width,
        relation: .equal, value: finalContainer.fittingSize.width
      )
      Self.makeSimpleConstraint(
        item: finalContainer, attribute: .height,
        relation: .equal, value: finalContainer.fittingSize.height
      )
      Self.addStatistics(finalContainer, memo: "finalContainer")

      // 更換容器內容為上文生成的新內容。
      subviews.forEach { removeView($0) }
      addView(finalContainer, in: .top)
    }
  }

  // MARK: - Interface Components.

  private extension VwrCandidateTDKCocoa {
    private var candidateListBackground: NSColor {
      let delta = NSApplication.isDarkMode ? 0.05 : 0.99
      return .init(white: delta, alpha: 1)
    }

    private func drawCellCocoa(_ theCell: CandidateCellData? = nil) -> NSView {
      let theCell = theCell ?? CandidatePool.blankCell.cleanCopy
      let cellLabel = VwrCandidateCell(cell: theCell)
      cellLabel.target = self
      Self.makeSimpleConstraint(item: cellLabel, attribute: .width, relation: .equal, value: cellLabel.fittingSize.width)
      Self.makeSimpleConstraint(item: cellLabel, attribute: .height, relation: .equal, value: cellLabel.fittingSize.height)
      Self.addStatistics(cellLabel, memo: "cellLabel")
      let wrappedCell = NSStackView()
      let padding: CGFloat = 3
      wrappedCell.edgeInsets = .init(top: padding, left: padding, bottom: padding, right: padding)
      wrappedCell.addView(cellLabel, in: .leading)
      if theCell.isHighlighted {
        wrappedCell.wantsLayer = true
        wrappedCell.layer?.backgroundColor = theCell.themeColorCocoa.cgColor
        wrappedCell.layer?.cornerRadius = padding * 2
      }
      let cellWidth = max(thePool.cellWidth(theCell).min ?? wrappedCell.fittingSize.width, wrappedCell.fittingSize.width)
      let cellHeight = wrappedCell.fittingSize.height
      wrappedCell.setHuggingPriority(.fittingSizeCompression, for: .horizontal)
      wrappedCell.setHuggingPriority(.fittingSizeCompression, for: .vertical)
      Self.makeSimpleConstraint(item: wrappedCell, attribute: .height, relation: .equal, value: cellHeight)
      switch thePool.layout {
      case .horizontal where thePool.maxLinesPerPage > 1:
        Self.makeSimpleConstraint(item: wrappedCell, attribute: .width, relation: .equal, value: cellWidth)
      default:
        Self.makeSimpleConstraint(item: wrappedCell, attribute: .width, relation: .greaterThanOrEqual, value: cellWidth)
      }
      Self.addStatistics(wrappedCell, memo: "wrappedCell")
      theCell.visualDimension = .init(width: cellWidth, height: cellHeight)
      return wrappedCell
    }

    private func lineBackground(isCurrentLine: Bool, isMatrix: Bool) -> NSColor {
      if !isCurrentLine { return .clear }
      let absBg: NSColor = NSApplication.isDarkMode ? .black : .white
      switch thePool.layout {
      case .horizontal where isMatrix:
        return NSApplication.isDarkMode ? .controlTextColor.withAlphaComponent(0.05) : .white
      case .vertical where isMatrix:
        return absBg.withAlphaComponent(0.9)
      default:
        return .clear
      }
    }

    private func generateLineContainer(_ theLine: inout [CandidateCellData]) -> NSStackView {
      let isVerticalListing: Bool = thePool.layout == .vertical
      let isMatrix = thePool.maxLinesPerPage > 1
      let vwrCurrentLine = NSStackView()
      vwrCurrentLine.spacing = 0
      vwrCurrentLine.orientation = isVerticalListing ? .vertical : .horizontal
      var cellHeight = 0.0
      var lineSize: CGSize = .zero
      let isCurrentLine = theLine.hasHighlightedCell
      theLine.forEach { theCell in
        vwrCurrentLine.addView(drawCellCocoa(theCell), in: isVerticalListing ? .top : .leading)
        switch thePool.layout {
        case .horizontal:
          lineSize.width += theCell.visualDimension.width
          lineSize.height = max(lineSize.height, theCell.visualDimension.height)
        case .vertical:
          lineSize.width = max(lineSize.width, theCell.visualDimension.width)
          lineSize.height += theCell.visualDimension.height
        }
        cellHeight = max(theCell.visualDimension.height, cellHeight)
      }
      let lineBg = lineBackground(isCurrentLine: isCurrentLine, isMatrix: isMatrix)
      vwrCurrentLine.wantsLayer = isCurrentLine && isMatrix
      if vwrCurrentLine.wantsLayer {
        vwrCurrentLine.layer?.backgroundColor = lineBg.cgColor
        vwrCurrentLine.layer?.cornerRadius = 6
      }
      vwrCurrentLine.alphaValue = isCurrentLine ? 1 : 0.85
      lineDimension.width = max(lineSize.width, lineDimension.width)
      switch thePool.layout {
      case .horizontal: lineDimension.height = max(lineSize.height, lineDimension.height)
      case .vertical: lineDimension.height = cellHeight * Double(thePool.maxLineCapacity)
      }
      return vwrCurrentLine
    }

    private static func makeLabel(_ attrStr: NSAttributedString) -> NSTextField {
      let textField = NSTextField()
      textField.isSelectable = false
      textField.isEditable = false
      textField.isBordered = false
      textField.backgroundColor = .clear
      textField.allowsEditingTextAttributes = false
      textField.preferredMaxLayoutWidth = textField.frame.width
      textField.attributedStringValue = attrStr
      textField.sizeToFit()
      return textField
    }
  }

  // MARK: - Constraint Utilities

  private extension VwrCandidateTDKCocoa {
    static var strForConstraintStatistics = NSMutableString(string: "TDKCandidates Dimensions (Debug):\n")

    static func addStatistics(_ target: NSView, memo: String = "") {
      if Self.strForConstraintStatistics.length == 0 {
        Self.strForConstraintStatistics.append("TDKCandidates Dimensions (Debug):\n")
      }
      Self.strForConstraintStatistics.append("\(target.fittingSize) \(memo)\n")
    }

    static func makeSimpleConstraint(item: NSView, attribute: NSLayoutConstraint.Attribute, relation: NSLayoutConstraint.Relation, value: CGFloat) {
      item.translatesAutoresizingMaskIntoConstraints = false
      let widthConstraint = NSLayoutConstraint(
        item: item, attribute: attribute, relatedBy: relation, toItem: nil,
        attribute: NSLayoutConstraint.Attribute.notAnAttribute, multiplier: 1, constant: value
      )
      item.addConstraint(widthConstraint)
    }
  }

  // MARK: - Candidate Cell View

  private extension VwrCandidateTDKCocoa {
    class VwrCandidateCell: NSTextField {
      public var cellData: CandidateCellData
      public init(cell: CandidateCellData) {
        cellData = cell
        super.init(frame: .init(origin: .zero, size: .init(width: 114_514, height: 114_514)))
        isSelectable = false
        isEditable = false
        isBordered = false
        backgroundColor = .clear
        allowsEditingTextAttributes = false
        preferredMaxLayoutWidth = frame.width
        attributedStringValue = cellData.attributedString()
        sizeToFit()
      }

      @available(*, unavailable)
      required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
      }

      deinit {
        // TODO: This doesn't work at all. (#TDKError_NSMenuDeconstruction)
        theMenu?.cancelTrackingWithoutAnimation()
      }

      // MARK: Mouse Actions.

      override func mouseUp(with _: NSEvent) {
        guard let target = target as? VwrCandidateTDKCocoa else { return }
        target.didSelectCandidateAt(cellData.index)
      }

      override func rightMouseUp(with event: NSEvent) {
        guard let target = target as? VwrCandidateTDKCocoa else { return }
        let index = cellData.index
        let candidateText = cellData.displayedText
        let isEnabled: Bool = target.controller?.delegate?.isCandidateContextMenuEnabled ?? false
        guard isEnabled, !candidateText.isEmpty, index >= 0 else { return }
        prepareMenu()
        theMenu?.popUp(positioning: nil, at: event.locationInWindow, in: target)
      }

      // MARK: Menu.

      var theMenu: NSMenu?

      private func prepareMenu() {
        guard let thePool = (target as? VwrCandidateTDKCocoa)?.thePool else { return }
        let newMenu = NSMenu()
        let boostMenuItem = NSMenuItem(
          title: "↑ \(cellData.displayedText)",
          action: #selector(menuActionOfBoosting(_:)),
          keyEquivalent: ""
        )
        boostMenuItem.target = self
        newMenu.addItem(boostMenuItem)

        let nerfMenuItem = NSMenuItem(
          title: "↓ \(cellData.displayedText)",
          action: #selector(menuActionOfNerfing(_:)),
          keyEquivalent: ""
        )
        nerfMenuItem.target = self
        newMenu.addItem(nerfMenuItem)

        if thePool.isFilterable(target: cellData.index) {
          let filterMenuItem = NSMenuItem(
            title: "✖︎ \(cellData.displayedText)",
            action: #selector(menuActionOfFiltering(_:)),
            keyEquivalent: ""
          )
          filterMenuItem.target = self
          newMenu.addItem(filterMenuItem)
        }

        theMenu = newMenu
        CtlCandidateTDK.currentMenu = newMenu
      }

      @objc func menuActionOfBoosting(_: Any? = nil) {
        guard let target = target as? VwrCandidateTDKCocoa else { return }
        target.didRightClickCandidateAt(cellData.index, action: .toBoost)
      }

      @objc func menuActionOfNerfing(_: Any? = nil) {
        guard let target = target as? VwrCandidateTDKCocoa else { return }
        target.didRightClickCandidateAt(cellData.index, action: .toNerf)
      }

      @objc func menuActionOfFiltering(_: Any? = nil) {
        guard let target = target as? VwrCandidateTDKCocoa else { return }
        target.didRightClickCandidateAt(cellData.index, action: .toFilter)
      }
    }
  }

  // MARK: - Delegate Methods

  private extension VwrCandidateTDKCocoa {
    func didSelectCandidateAt(_ pos: Int) {
      controller?.delegate?.candidatePairSelectionConfirmed(at: pos)
    }

    func didRightClickCandidateAt(_ pos: Int, action: CandidateContextMenuAction) {
      controller?.delegate?.candidatePairRightClicked(at: pos, action: action)
    }
  }

  // MARK: - Debug Module Using Swift UI.

  import SwiftUI

  @available(macOS 10.15, *)
  public struct VwrCandidateTDKCocoaForSwiftUI: NSViewRepresentable {
    public weak var controller: CtlCandidateTDK?
    public var thePool: CandidatePool

    public func makeNSView(context _: Context) -> VwrCandidateTDKCocoa {
      let nsView = VwrCandidateTDKCocoa(thePool: thePool)
      nsView.controller = controller
      return nsView
    }

    public func updateNSView(_ nsView: VwrCandidateTDKCocoa, context _: Context) {
      nsView.thePool = thePool
      nsView.refresh()
    }
  }

#endif
