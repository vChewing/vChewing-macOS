// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

#if canImport(Darwin)
  import AppKit
  import Shared

  // MARK: - SymbolTableUI

  /// 符號表浮動視窗。顯示二維符號表格，藍底高亮當前選中列。
  public final class SymbolTableUI: NSObject, SymbolTableGridUIProtocol {

    // MARK: - Layout constants

    private let font = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
    private let columnWidth: CGFloat = 22
    /// 分類名稱欄寬（符號表比近音表寬，需容納較長的分類名稱）。
    private let categoryColumnWidth: CGFloat = 72
    private let rowHeight: CGFloat = 22
    private let headerHeight: CGFloat = 22
    private let windowPadding: CGFloat = 6
    private let maxColumns = 8

    // MARK: - Window

    private lazy var panel: NSPanel = {
      let p = NSPanel(
        contentRect: .zero,
        styleMask: [.nonactivatingPanel, .borderless],
        backing: .buffered,
        defer: false
      )
      p.level = .floating
      p.backgroundColor = .clear
      p.isOpaque = false
      p.hasShadow = true
      return p
    }()

    private lazy var contentView: SymbolTableContentView = {
      let v = SymbolTableContentView()
      v.font = self.font
      v.columnWidth = self.columnWidth
      v.categoryColumnWidth = self.categoryColumnWidth
      v.rowHeight = self.rowHeight
      v.headerHeight = self.headerHeight
      v.windowPadding = self.windowPadding
      v.maxColumns = self.maxColumns
      return v
    }()

    public override init() {
      super.init()
      panel.contentView = contentView
    }

    // MARK: - SymbolTableGridUIProtocol

    public func show(state: some IMEStateProtocol, at lineHeightRect: CGRect) {
      guard state.type == .ofSymbolTableGrid else { return }
      contentView.categories = state.data.symbolTableCategories
      contentView.selectedRow = state.data.selectedSymbolTableRow
      contentView.needsDisplay = true

      let size = contentView.intrinsicContentSize
      let cursorBottom = lineHeightRect.origin.y
      let cursorTop = cursorBottom + lineHeightRect.height
      let screen = NSScreen.screens.first { $0.frame.contains(lineHeightRect.origin) } ?? NSScreen.main
      let visibleMinY = screen?.visibleFrame.minY ?? 0
      // 若放在游標下方會超出螢幕底部，則改放在游標上方。
      let originY: CGFloat
      if cursorBottom - size.height - 4 < visibleMinY {
        originY = cursorTop + 4
      } else {
        originY = cursorBottom - size.height - 4
      }
      panel.setFrame(NSRect(origin: NSPoint(x: lineHeightRect.origin.x, y: originY), size: size), display: true)
      panel.orderFront(nil)
    }

    public func update(state: some IMEStateProtocol) {
      guard state.type == .ofSymbolTableGrid else { return }
      contentView.categories = state.data.symbolTableCategories
      contentView.selectedRow = state.data.selectedSymbolTableRow
      contentView.needsDisplay = true
      let size = contentView.intrinsicContentSize
      var frame = panel.frame
      frame.size = size
      panel.setFrame(frame, display: true)
    }

    public func hide() {
      panel.orderOut(nil)
    }
  }

  // MARK: - SymbolTableContentView

  /// 符號表的內容繪製視圖。
  private final class SymbolTableContentView: NSView {

    var categories: [SymbolTableCategory] = []
    var selectedRow: Int = 0
    var font: NSFont = .monospacedSystemFont(ofSize: 14, weight: .regular)
    var columnWidth: CGFloat = 22
    var categoryColumnWidth: CGFloat = 72
    var rowHeight: CGFloat = 22
    var headerHeight: CGFloat = 22
    var windowPadding: CGFloat = 6
    var maxColumns: Int = 8

    // MARK: - Size

    private var totalWidth: CGFloat {
      windowPadding * 2 + categoryColumnWidth + columnWidth * CGFloat(maxColumns) + columnWidth
      // +columnWidth for the `>` indicator slot
    }

    private var totalHeight: CGFloat {
      windowPadding * 2 + headerHeight + rowHeight * CGFloat(categories.count)
    }

    override var intrinsicContentSize: NSSize {
      NSSize(width: totalWidth, height: totalHeight)
    }

    // MARK: - Colors & Attributes

    private let bgColor = NSColor(white: 0.12, alpha: 0.95)
    private let headerBgColor = NSColor(white: 0.18, alpha: 1)
    private let selectedRowColor = NSColor.systemBlue
    private let normalTextColor = NSColor.white
    private let dimTextColor = NSColor(white: 0.6, alpha: 1)
    private let headerNumberColor = NSColor(white: 0.7, alpha: 1)

    private var textAttrs: [NSAttributedString.Key: Any] {
      [.font: font, .foregroundColor: normalTextColor]
    }

    private var dimTextAttrs: [NSAttributedString.Key: Any] {
      [.font: font, .foregroundColor: dimTextColor]
    }

    private var headerNumberAttrs: [NSAttributedString.Key: Any] {
      [.font: font, .foregroundColor: headerNumberColor]
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
      super.draw(dirtyRect)
      guard let ctx = NSGraphicsContext.current?.cgContext else { return }

      // Background
      ctx.setFillColor(bgColor.cgColor)
      ctx.fill(bounds)

      let pad = windowPadding

      // Header row background
      let headerRect = CGRect(x: 0, y: bounds.height - pad - headerHeight, width: bounds.width, height: headerHeight)
      ctx.setFillColor(headerBgColor.cgColor)
      ctx.fill(headerRect)

      // Header: "符號表" label on left
      let headerLabelX = pad
      let headerLabelY = bounds.height - pad - headerHeight
      drawText("符號表", at: CGPoint(x: headerLabelX, y: headerLabelY), attrs: textAttrs, in: ctx)

      // Header: 1–8 column numbers aligned with symbol columns
      for col in 1 ... maxColumns {
        let x = pad + categoryColumnWidth + columnWidth * CGFloat(col - 1)
        let y = bounds.height - pad - headerHeight
        drawText("\(col)", at: CGPoint(x: x, y: y), attrs: headerNumberAttrs, in: ctx)
      }

      // Data rows
      for (rowIdx, cat) in categories.enumerated() {
        let y = bounds.height - pad - headerHeight - rowHeight * CGFloat(rowIdx + 1)
        let rowRect = CGRect(x: 0, y: y, width: bounds.width, height: rowHeight)

        if rowIdx == selectedRow {
          ctx.setFillColor(selectedRowColor.cgColor)
          ctx.fill(rowRect)
        }

        // Category name label
        drawText(cat.name, at: CGPoint(x: pad, y: y), attrs: textAttrs, in: ctx)

        // Symbols on current page
        let pageSymbols = cat.symbolsOnCurrentPage
        for (colIdx, sym) in pageSymbols.enumerated() {
          let x = pad + categoryColumnWidth + columnWidth * CGFloat(colIdx)
          drawText(sym, at: CGPoint(x: x, y: y), attrs: textAttrs, in: ctx)
        }

        // `<` indicator（有上一頁時顯示，置於分類欄右側）
        if cat.currentPage > 0 {
          let x = pad + categoryColumnWidth - columnWidth
          drawText("<", at: CGPoint(x: x, y: y), attrs: dimTextAttrs, in: ctx)
        }

        // `>` indicator（有下一頁時顯示，置於最後一欄右側）
        if cat.hasNextPage {
          let x = pad + categoryColumnWidth + columnWidth * CGFloat(maxColumns)
          drawText(">", at: CGPoint(x: x, y: y), attrs: dimTextAttrs, in: ctx)
        }
      }
    }

    private func drawText(
      _ text: String, at point: CGPoint,
      attrs: [NSAttributedString.Key: Any], in ctx: CGContext
    ) {
      let attrStr = NSAttributedString(string: text, attributes: attrs)
      let line = CTLineCreateWithAttributedString(attrStr)
      ctx.saveGState()
      ctx.translateBy(x: point.x, y: point.y + 4) // +4 for baseline offset
      ctx.textMatrix = .identity
      CTLineDraw(line, ctx)
      ctx.restoreGState()
    }
  }
#endif
