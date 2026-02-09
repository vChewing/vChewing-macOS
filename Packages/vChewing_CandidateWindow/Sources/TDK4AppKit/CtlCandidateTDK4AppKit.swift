// (c) 2022 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import AppKit
import Shared_DarwinImpl
import SwiftExtension

extension TDK4AppKit {
  // MARK: - CtlCandidateTDK4AppKit

  public final class CtlCandidateTDK4AppKit: NSWindowController, CtlCandidateProtocol, NSWindowDelegate {
    // MARK: Lifecycle

    // MARK: - Constructors

    public required init(_ layout: UILayoutOrientation = .horizontal) {
      let contentRect = CGRect(x: 128.0, y: 128.0, width: 0.0, height: 0.0)
      let styleMask: NSWindow.StyleMask = [.nonactivatingPanel]
      let panel = NSPanel(
        contentRect: contentRect, styleMask: styleMask, backing: .buffered, defer: false
      )
      panel.level = NSWindow.Level(Int(max(CGShieldingWindowLevel(), kCGPopUpMenuWindowLevel)) + 2)
      panel.hasShadow = true
      panel.backgroundColor = NSColor.clear
      self.candidateView = Self.currentView

      super.init(window: .init())
      candidateView.controller = self
      self.window = panel
      window?.delegate = self
      self.currentLayout = layout
      // 設置背景視覺效果視圖
      if !Self.shouldDisableVisualEffectView {
        if window?.contentView == nil {
          window?.contentView = NSView()
        }
        if let visualEffectView, let contentView = window?.contentView {
          contentView.addSubview(visualEffectView)
          visualEffectView.pinEdges(to: contentView)
        }
      }

      self.observation = Broadcaster.shared
        .observe(\.eventForClosingAllPanels, options: [.new]) { [weak self] _, _ in
          self?.respondToEventsForClosingPanels()
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }

    deinit {
      mainSync {
        currentMenu = nil
        window = nil
        observation?.invalidate()
      }
    }

    // MARK: Public

    override public var window: NSWindow? {
      willSet {
        window?.orderOut(nil)
      }
    }

    public var currentLayout: UILayoutOrientation = .horizontal

    public var delegate: CtlCandidateDelegate? {
      didSet {
        guard let delegate = delegate else { return }
        if delegate.isCandidateState { reloadData() }
      }
    }

    public var visible = false {
      didSet {
        NSObject.cancelPreviousPerformRequests(withTarget: self)
        if let delegate, oldValue != visible {
          delegate.candidatePairHighlightChanged(at: visible ? 0 : nil)
        }
        asyncOnMain { [weak self] in
          guard let this = self else { return }
          _ = this.visible ? this.window?.orderFront(this) : this.window?.orderOut(this)
        }
      }
    }

    // Already implemented in CandidatePool.
    public var highlightedIndex: Int {
      get { Self.thePool.highlightedIndex }
      set {
        Self.thePool.highlight(at: newValue)
        updateDisplay()
      }
    }

    public var currentMenu: NSMenu? {
      willSet {
        currentMenu?.cancelTracking()
      }
    }

    override public func scrollWheel(with event: NSEvent) {
      guard useMouseScrolling else { return }
      handleMouseScroll(deltaX: event.deltaX, deltaY: event.deltaY)
    }

    public func reloadData() {
      guard let delegate = delegate else { return }

      let candidateLayout: UILayoutOrientation =
        (delegate.isVerticalCandidateWindow ? .vertical : .horizontal)
      currentLayout = candidateLayout
      maxLinesPerPage = delegate.isCandidateWindowSingleLine ? 1 : 4

      Self.thePool.reinit(
        candidates: delegate.candidatePairs(conv: true),
        lines: maxLinesPerPage,
        isExpanded: delegate.shouldAutoExpandCandidates,
        selectionKeys: delegate.selectionKeys,
        layout: currentLayout,
        locale: delegate.localeForFontFallbacks
      )
      Self.thePool.tooltip = tooltip
      Self.thePool.reverseLookupResult = reverseLookupResult
      Self.thePool.highlight(at: 0)
      updateDisplay()
    }

    // Already implemented in CandidatePool.
    @discardableResult
    public func showNextPage() -> Bool {
      defer { updateDisplay() }
      return Self.thePool.flipPage(isBackward: false)
    }

    // Already implemented in CandidatePool.
    @discardableResult
    public func showPreviousPage() -> Bool {
      defer { updateDisplay() }
      return Self.thePool.flipPage(isBackward: true)
    }

    // Already implemented in CandidatePool.
    @discardableResult
    public func showPreviousLine() -> Bool {
      defer { updateDisplay() }
      return Self.thePool.consecutivelyFlipLines(isBackward: true, count: 1)
    }

    // Already implemented in CandidatePool.
    @discardableResult
    public func showNextLine() -> Bool {
      defer { updateDisplay() }
      return Self.thePool.consecutivelyFlipLines(isBackward: false, count: 1)
    }

    // Already implemented in CandidatePool.
    @discardableResult
    public func highlightNextCandidate() -> Bool {
      defer { updateDisplay() }
      return Self.thePool.highlightNeighborCandidate(isBackward: false)
    }

    // Already implemented in CandidatePool.
    @discardableResult
    public func highlightPreviousCandidate() -> Bool {
      defer { updateDisplay() }
      return Self.thePool.highlightNeighborCandidate(isBackward: true)
    }

    // Already implemented in CandidatePool.
    public func candidateIndexAtKeyLabelIndex(_ id: Int) -> Int? {
      Self.thePool.calculateCandidateIndex(subIndex: id)
    }

    // MARK: Internal

    typealias CandidatePool4AppKit = TDK4AppKit.CandidatePool4AppKit

    var tooltip: String = ""

    var useMouseScrolling: Bool = true

    var reverseLookupResult: [String] = []
    var maxLinesPerPage: Int = 1

    var windowTopLeftPoint: CGPoint {
      get {
        guard let frameRect = window?.frame else { return CGPoint.zero }
        return CGPoint(x: frameRect.minX, y: frameRect.maxY)
      }
      set {
        asyncOnMain { [weak self] in
          guard let this = self else { return }
          this.set(windowTopLeftPoint: newValue, bottomOutOfScreenAdjustmentHeight: 0, useGCD: true)
        }
      }
    }

    func updateDisplay() {
      if let window = window {
        asyncOnMain { [weak self] in
          guard let this = self else { return }
          this.updateNSWindowModern(window)
        }
      }
      useMouseScrolling = prefs.enableMouseScrollingForTDKCandidatesCocoa
      // 先擦除之前的反查结果。
      reverseLookupResult = []
      // 再更新新的反查结果。
      if let currentCandidate = Self.thePool.currentCandidate {
        let displayedText = currentCandidate.displayedText
        var lookupResult: [String?] = delegate?.reverseLookup(for: displayedText) ?? []
        if displayedText.count == 1, delegate?.showCodePointForCurrentCandidate ?? false {
          if lookupResult.isEmpty {
            lookupResult
              .append(currentCandidate.charDescriptions(shortened: !Self.thePool.isMatrix).first)
          } else {
            lookupResult.insert(
              currentCandidate.charDescriptions(shortened: true).first,
              at: lookupResult.startIndex
            )
          }
          reverseLookupResult = lookupResult.compactMap { $0 }
        } else {
          reverseLookupResult = lookupResult.compactMap { $0 }
          // 如果不提供 UNICODE 碼位資料顯示的話，則在非多行多列模式下僅顯示一筆反查資料。
          if !Self.thePool.isMatrix {
            reverseLookupResult = [reverseLookupResult.first].compactMap { $0 }
          }
        }
      }
      Self.thePool.reverseLookupResult = reverseLookupResult
      Self.thePool.tooltip = delegate?.candidateToolTip(shortened: !Self.thePool.isMatrix) ?? ""
      delegate?.candidatePairHighlightChanged(at: highlightedIndex)
    }

    // MARK: Private

    private static let shouldDisableVisualEffectView: Bool = {
      if #available(macOS 10.13, *) {
        return false
      }
      return true
    }()

    private static let thePool: CandidatePool4AppKit = .init(candidates: [])
    private static let currentView: VwrCandidateTDK4AppKit = .init(thePool: thePool)

    private let prefs = PrefMgr()

    @objc
    private var observation: NSKeyValueObservation?
    // 創建背景視覺效果視圖
    private let visualEffectView: NSView? = {
      if #available(macOS 27.0, *), NSApplication.uxLevel == .liquidGlass {
        #if compiler(>=6.2) && canImport(AppKit, _version: 26.0)
          let resultView = NSGlassEffectView()
          return resultView
        #endif
      }
      if #available(macOS 10.10, *), NSApplication.uxLevel != .none {
        let resultView = NSVisualEffectView()
        return resultView
      }
      return nil
    }()

    private let candidateView: VwrCandidateTDK4AppKit

    private var candidateViewLegacy4Debug: NSView {
      let textField = NSTextField()
      textField.isSelectable = false
      textField.isEditable = false
      textField.isBordered = false
      textField.backgroundColor = .clear
      textField.allowsEditingTextAttributes = false
      textField.preferredMaxLayoutWidth = textField.frame.width
      textField.attributedStringValue = Self.thePool.attributedDescription
      textField.sizeToFit()
      textField.backgroundColor = .clear
      return textField
    }

    private func updateEffectView() {
      if #available(macOS 27.0, *), NSApplication.uxLevel == .liquidGlass {
        #if compiler(>=6.2) && canImport(AppKit, _version: 26.0)
          guard let resultView = visualEffectView as? NSGlassEffectView else { return }
          resultView.cornerRadius = Self.thePool.windowRadius
          resultView.style = .clear
          let bgTintColor: NSColor = !NSApplication.isDarkMode ? .white : .black
          resultView.wantsLayer = true
          resultView.layer?.cornerRadius = Self.thePool.windowRadius
          resultView.layer?.masksToBounds = true
          resultView.layer?.backgroundColor = bgTintColor.withAlphaComponent(0.1).cgColor
        #endif
      }
      if #available(macOS 10.10, *), NSApplication.uxLevel != .none {
        guard let resultView = visualEffectView as? NSVisualEffectView else { return }
        resultView.material = .titlebar
        resultView.blendingMode = .behindWindow
        resultView.state = .active
        // 設置圓角以保持原有的視覺特性
        resultView.wantsLayer = true
        resultView.layer?.cornerRadius = Self.thePool.windowRadius
        resultView.layer?.masksToBounds = true
      }
    }

    private func updateNSWindowModern(_ window: NSWindow) {
      // 同步 Metrics
      Self.thePool.updateMetrics()

      // fittingSize 跟随新的 metrics
      candidateView.invalidateIntrinsicContentSize()
      candidateView.setNeedsDisplay(candidateView.bounds)

      guard !Self.shouldDisableVisualEffectView else {
        window.isOpaque = false
        window.backgroundColor = .clear
        window.contentView = candidateView
        window.setContentSize(candidateView.fittingSize)
        delegate?.resetCandidateWindowOrigin()
        return
      }

      // 更新背景視覺效果視圖
      updateEffectView()

      let viewSize = candidateView.fittingSize
      guard let containerView = window.contentView else { return }
      containerView.setFrameSize(viewSize)
      // 為容器視圖也設置圓角，確保整體一致性
      containerView.wantsLayer = true
      containerView.layer?.cornerRadius = Self.thePool.windowRadius
      containerView.layer?.masksToBounds = true

      // 添加候選窗口內容視圖
      if containerView.subviews.allSatisfy({ !($0 is VwrCandidateTDK4AppKit) }) {
        containerView.addSubview(candidateView)
        candidateView.pinEdges(to: containerView)
      }

      window.isOpaque = false
      window.backgroundColor = .clear
      window.contentView = containerView
      window.setContentSize(viewSize)
      delegate?.resetCandidateWindowOrigin()
    }

    private func handleMouseScroll(deltaX: CGFloat, deltaY: CGFloat) {
      switch (deltaX, deltaY, Self.thePool.layout) {
      case (0, 1..., .vertical), (1..., 0, .horizontal): highlightNextCandidate()
      case (..<0, 0, .horizontal), (0, ..<0, .vertical): highlightPreviousCandidate()
      case (0, 1..., .horizontal), (1..., 0, .vertical): showNextLine()
      case (0, ..<0, .horizontal), (..<0, 0, .vertical): showPreviousLine()
      case (_, _, _): break
      }
    }

    nonisolated private func respondToEventsForClosingPanels() {
      mainSync {
        self.visible = false
        Self.thePool.cleanData()
      }
    }
  }
} // extension TDK4AppKit
