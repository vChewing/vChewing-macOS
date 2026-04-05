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

  // MARK: - SimilarPhoneticUI

  /// 近音表浮動視窗。顯示二維近音表格，藍底高亮當前選中列。
  public final class SimilarPhoneticUI: NSObject, SimilarPhoneticUIProtocol {

    // MARK: - Layout constants

    private let font = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
    private let columnWidth: CGFloat = 22
    private let phoneticColumnWidth: CGFloat = 64
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

    private lazy var contentView: SimilarPhoneticContentView = {
      let v = SimilarPhoneticContentView()
      v.font = self.font
      v.columnWidth = self.columnWidth
      v.phoneticColumnWidth = self.phoneticColumnWidth
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

    // MARK: - SimilarPhoneticUIProtocol

    public func show(state: some IMEStateProtocol, at lineHeightRect: CGRect) {
      guard state.type == .ofSimilarPhonetic else { return }
      contentView.rows = state.data.similarPhoneticRows
      contentView.selectedRow = state.data.selectedSimilarPhoneticRow
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
      guard state.type == .ofSimilarPhonetic else { return }
      contentView.rows = state.data.similarPhoneticRows
      contentView.selectedRow = state.data.selectedSimilarPhoneticRow
      contentView.needsDisplay = true
      // resize if row count changed (shouldn't happen in normal navigation, but safe)
      let size = contentView.intrinsicContentSize
      var frame = panel.frame
      frame.size = size
      panel.setFrame(frame, display: true)
    }

    public func hide() {
      panel.orderOut(nil)
    }
  }

  // MARK: - SimilarPhoneticContentView

  /// 近音表的內容繪製視圖。
  private final class SimilarPhoneticContentView: NSView {

    var rows: [SimilarPhoneticRow] = []
    var selectedRow: Int = 0
    var font: NSFont = .monospacedSystemFont(ofSize: 14, weight: .regular)
    var columnWidth: CGFloat = 22
    var phoneticColumnWidth: CGFloat = 64
    var rowHeight: CGFloat = 22
    var headerHeight: CGFloat = 22
    var windowPadding: CGFloat = 6
    var maxColumns: Int = 8

    // MARK: - Size

    private var totalWidth: CGFloat {
      windowPadding * 2 + phoneticColumnWidth + columnWidth * CGFloat(maxColumns) + columnWidth
      // +columnWidth for the `>` indicator slot
    }

    private var totalHeight: CGFloat {
      windowPadding * 2 + headerHeight + rowHeight * CGFloat(rows.count)
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

      // Header: "近音表" label on left
      let headerLabelX = pad
      let headerLabelY = bounds.height - pad - headerHeight
      drawText("近音表", at: CGPoint(x: headerLabelX, y: headerLabelY), attrs: textAttrs, in: ctx)

      // Header: 1–8 column numbers aligned with candidate columns
      for col in 1 ... maxColumns {
        let x = pad + phoneticColumnWidth + columnWidth * CGFloat(col - 1)
        let y = bounds.height - pad - headerHeight
        drawText("\(col)", at: CGPoint(x: x, y: y), attrs: headerNumberAttrs, in: ctx)
      }

      // Data rows
      for (rowIdx, row) in rows.enumerated() {
        let y = bounds.height - pad - headerHeight - rowHeight * CGFloat(rowIdx + 1)
        let rowRect = CGRect(x: 0, y: y, width: bounds.width, height: rowHeight)

        if rowIdx == selectedRow {
          ctx.setFillColor(selectedRowColor.cgColor)
          ctx.fill(rowRect)
        }

        // Phonetic label
        drawText(row.phonetic, at: CGPoint(x: pad, y: y), attrs: textAttrs, in: ctx)

        // Candidates on current page
        let pageCandidates = row.candidatesOnCurrentPage
        for (colIdx, char) in pageCandidates.enumerated() {
          let x = pad + phoneticColumnWidth + columnWidth * CGFloat(colIdx)
          drawText(char, at: CGPoint(x: x, y: y), attrs: textAttrs, in: ctx)
        }

        // `<` indicator（有上一頁時顯示，置於注音欄右側）
        if row.currentPage > 0 {
          let x = pad + phoneticColumnWidth - columnWidth
          drawText("<", at: CGPoint(x: x, y: y), attrs: dimTextAttrs, in: ctx)
        }

        // `>` indicator（有下一頁時顯示，置於最後一欄右側）
        if row.hasNextPage {
          let x = pad + phoneticColumnWidth + columnWidth * CGFloat(maxColumns)
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
