// (c) 2022 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import AppKit
import Shared
import Shared_DarwinImpl
import SwiftExtension

// MARK: - GSI4AppKit.CtlCandidateGSI4AppKit

extension GSI4AppKit {
  // MARK: - CtlCandidateGSI4AppKit

  /// 我修院選字窗的 NSWindowController — 極簡 facade。
  /// 不使用 NSScrollView，所有內容（候選字 + 底部欄位 + scroller）由 view 自行繪製。

  public final class CtlCandidateGSI4AppKit: NSWindowController, CtlCandidateProtocol, NSWindowDelegate {
    // MARK: Lifecycle

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
          asyncOnMain {
            self?.respondToEventsForClosingPanels()
          }
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

    public weak var delegate: CtlCandidateDelegate? {
      didSet {
        guard let delegate = delegate else { return }
        if delegate.isCandidateState { reloadData() }
      }
    }

    public var visible = false {
      didSet {
        NSObject.cancelPreviousPerformRequests(withTarget: self)
        if oldValue != visible {
          suppressAnimationOnce = true
          delegate?.candidatePairHighlightChanged(at: visible ? 0 : nil)
        }
        asyncOnMain { [weak self] in
          guard let this = self else { return }
          _ = this.visible ? this.window?.orderFront(this) : this.window?.orderOut(this)
        }
      }
    }

    public var expanded: Bool { Self.thePool.isExpanded }

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
      guard !isInScrollMode else { return }
      // When expandable & unexpanded, mouse wheel only expands, doesn't flip lines.
      // Option (without Shift): always flip lines, using dominant scroll axis.
      if event.modifierFlags.contains(.option), !event.modifierFlags.contains(.shift),
         let dir = CandidatePool4AppKit.dominantScrollLineDirection(event) {
        if Self.thePool.isExpandable, !Self.thePool.isExpanded {
          Self.thePool.expandIfNeeded(isBackward: dir == .previous)
          updateDisplay()
          return
        }
        switch dir {
        case .next: showNextLine()
        case .previous: showPreviousLine()
        }
        return
      }
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

    // MARK: - Keyboard Navigation

    @discardableResult
    public func showNextPage() -> Bool {
      defer { updateDisplay() }
      if isInScrollMode {
        let result = Self.thePool.consecutivelyFlipLines(isBackward: false, count: Self.thePool.maxLinesPerPage)
        Self.thePool.computeCandidateOnlySize()
        Self.thePool.scrollToMakeLineVisible(Self.thePool.currentLineNumber)
        return result
      }
      return Self.thePool.flipPage(isBackward: false)
    }

    @discardableResult
    public func showPreviousPage() -> Bool {
      defer { updateDisplay() }
      if isInScrollMode {
        let result = Self.thePool.consecutivelyFlipLines(isBackward: true, count: Self.thePool.maxLinesPerPage)
        Self.thePool.computeCandidateOnlySize()
        Self.thePool.scrollToMakeLineVisible(Self.thePool.currentLineNumber)
        return result
      }
      return Self.thePool.flipPage(isBackward: true)
    }

    @discardableResult
    public func showPreviousLine() -> Bool {
      defer { updateDisplay() }
      if isInScrollMode {
        let result = Self.thePool.consecutivelyFlipLines(isBackward: true, count: 1)
        Self.thePool.computeCandidateOnlySize()
        Self.thePool.scrollToMakeLineVisible(Self.thePool.currentLineNumber)
        return result
      }
      return Self.thePool.consecutivelyFlipLines(isBackward: true, count: 1)
    }

    @discardableResult
    public func showNextLine() -> Bool {
      defer { updateDisplay() }
      if isInScrollMode {
        let result = Self.thePool.consecutivelyFlipLines(isBackward: false, count: 1)
        Self.thePool.computeCandidateOnlySize()
        Self.thePool.scrollToMakeLineVisible(Self.thePool.currentLineNumber)
        return result
      }
      return Self.thePool.consecutivelyFlipLines(isBackward: false, count: 1)
    }

    @discardableResult
    public func highlightNextCandidate() -> Bool {
      defer {
        if isInScrollMode {
          Self.thePool.computeCandidateOnlySize()
          Self.thePool.scrollToMakeLineVisible(Self.thePool.currentLineNumber)
        }
        updateDisplay()
      }
      return Self.thePool.highlightNeighborCandidate(isBackward: false)
    }

    @discardableResult
    public func highlightPreviousCandidate() -> Bool {
      defer {
        if isInScrollMode {
          Self.thePool.computeCandidateOnlySize()
          Self.thePool.scrollToMakeLineVisible(Self.thePool.currentLineNumber)
        }
        updateDisplay()
      }
      return Self.thePool.highlightNeighborCandidate(isBackward: true)
    }

    public func candidateIndexAtKeyLabelIndex(_ id: Int) -> Int? {
      Self.thePool.calculateCandidateIndex(subIndex: id)
    }

    // MARK: Internal

    typealias CandidatePool4AppKit = TDK4AppKit.CandidatePool4AppKit

    var tooltip: String = ""
    var reverseLookupResult: [String] = []
    var maxLinesPerPage: Int = 1

    var isInScrollMode: Bool {
      Self.thePool.isMatrix && Self.thePool.candidateLines.count > Self.thePool.maxLinesPerPage
    }

    var windowTopLeftPoint: CGPoint {
      get {
        guard let frameRect = window?.frame else { return CGPoint.zero }
        return CGPoint(x: frameRect.minX, y: frameRect.maxY)
      }
      set {
        asyncOnMain { [weak self] in
          guard let this = self, let window = this.window else { return }
          let windowSize = window.frame.size
          let adjustedPoint = this.adjustedTopLeft(
            rawTopLeft: newValue, heightDelta: 0, windowSize: windowSize
          )
          let targetFrame = NSRect(
            x: adjustedPoint.x, y: adjustedPoint.y - windowSize.height,
            width: windowSize.width, height: windowSize.height
          )
          let animate = this.prefs.enableCandidateWindowAnimation
          if animate {
            NSAnimationContext.runAnimationGroup { context in
              context.duration = 0.12
              window.animator().setFrame(targetFrame, display: true)
            }
          } else {
            window.setFrame(targetFrame, display: true)
          }
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
      reverseLookupResult = []
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
          if !Self.thePool.isMatrix {
            reverseLookupResult = [reverseLookupResult.first].compactMap { $0 }
          }
        }
      }
      Self.thePool.updateReadingDisambiguation()
      Self.thePool.reverseLookupResult = reverseLookupResult
      Self.thePool.tooltip = delegate?.candidateToolTip(shortened: !Self.thePool.isMatrix) ?? ""
      delegate?.candidatePairHighlightChanged(at: highlightedIndex)
    }

    // MARK: Private

    private static let shouldDisableVisualEffectView: Bool = {
      if #available(macOS 10.13, *) { return false }
      return true
    }()

    private static let thePool: CandidatePool4AppKit = .init(candidates: [])
    private static let currentView: VwrCandidateGSI4AppKit = .init(thePool: thePool)

    private let prefs = PrefMgr.sharedSansDidSetOps

    @objc
    private var observation: NSKeyValueObservation?

    private let visualEffectView: NSView? = {
      if NSApplication.uxLevel == .liquidGlass,
         let glassClass = NSClassFromString("NSGlassEffectView") as? NSView.Type {
        let resultView = glassClass.init()
        return resultView
      }
      if #available(macOS 10.10, *), NSApplication.uxLevel != .none {
        let resultView = NSVisualEffectView()
        return resultView
      }
      return nil
    }()

    private let candidateView: VwrCandidateGSI4AppKit

    private var suppressAnimationOnce = false

    // MARK: - Scroll Mode Configuration

    /// Tracks the previous scroll-mode state so we only reset on mode entry.
    private var wasInScrollMode = false

    private var enableAnimation: Bool {
      guard prefs.enableCandidateWindowAnimation else { return false }
      if suppressAnimationOnce { return false }
      guard window?.isVisible == true else { return false }
      return true
    }

    private func configureScrollMode() {
      candidateView.rendersInScrollMode = true
      Self.thePool.computeCandidateOnlySize()
      // Only reset scroll on first entry, not on every updateDisplay().
      if !wasInScrollMode {
        Self.thePool.resetScrollOffset()
      }
      wasInScrollMode = true
    }

    private func configureNormalMode() {
      candidateView.rendersInScrollMode = false
      Self.thePool.scrollOffset = 0
      Self.thePool.updateMetrics()
      wasInScrollMode = false
    }

    // MARK: - Window Update

    private func updateNSWindowModern(_ window: NSWindow) {
      if isInScrollMode {
        configureScrollMode()
      } else {
        configureNormalMode()
      }

      candidateView.invalidateIntrinsicContentSize()

      let animateThisRound = enableAnimation
      defer { suppressAnimationOnce = false }

      guard !Self.shouldDisableVisualEffectView else {
        window.isOpaque = false
        window.backgroundColor = .clear
        window.contentView = candidateView
        applyTargetFrame(to: window, contentSize: candidateView.fittingSize, animated: animateThisRound)
        return
      }

      updateEffectView()

      guard let containerView = window.contentView else { return }

      containerView.wantsLayer = true
      containerView.layer?.cornerRadius = Self.thePool.windowRadius
      containerView.layer?.masksToBounds = true

      if containerView.subviews.allSatisfy({ !($0 is VwrCandidateGSI4AppKit) }) {
        containerView.addSubview(candidateView)
      }
      // Remove old constraints referencing candidateView before re-pinning.
      containerView.removeConstraints(
        containerView.constraints.filter {
          $0.firstItem as? NSView === candidateView || $0.secondItem as? NSView === candidateView
        }
      )
      candidateView.pinEdges(to: containerView)

      window.isOpaque = false
      window.backgroundColor = .clear
      window.contentView = containerView

      applyTargetFrame(to: window, contentSize: candidateView.fittingSize, animated: animateThisRound)
      candidateView.setNeedsDisplay(candidateView.bounds)
    }

    // MARK: - Visual Effect View

    private func updateEffectView() {
      if NSApplication.uxLevel == .liquidGlass,
         NSClassFromString("NSGlassEffectView") != nil,
         let resultView = visualEffectView {
        resultView.setValue(Self.thePool.windowRadius, forKey: "cornerRadius")
        // macOS 27 的玻璃無需額外的底層 tint，因為文字顏色不再隨底部的內容而變化。
        // resultView.setValue(0, forKey: "style")  // .clear
        // let bgTintColor: NSColor = !NSApplication.isDarkMode ? .white : .black
        // resultView.wantsLayer = true
        // resultView.layer?.cornerRadius = Self.thePool.windowRadius
        // resultView.layer?.masksToBounds = true
        // resultView.layer?.backgroundColor = bgTintColor.withAlphaComponent(0.1).cgColor
        return
      }
      if #available(macOS 10.10, *), NSApplication.uxLevel != .none {
        guard let resultView = visualEffectView as? NSVisualEffectView else { return }
        resultView.material = .titlebar
        resultView.blendingMode = .behindWindow
        resultView.state = .active
        resultView.wantsLayer = true
        resultView.layer?.cornerRadius = Self.thePool.windowRadius
        resultView.layer?.masksToBounds = true
      }
    }

    // MARK: - Window Frame

    private func applyTargetFrame(
      to window: NSWindow, contentSize: CGSize, animated: Bool
    ) {
      let newFrameRect = window.frameRect(forContentRect: .init(origin: .zero, size: contentSize))
      let originInfo = delegate?.candidateWindowOriginInfo()
        ?? (topLeft: CGPoint(x: window.frame.minX, y: window.frame.maxY), heightDelta: 0)
      let adjustedPoint = adjustedTopLeft(
        rawTopLeft: originInfo.topLeft,
        heightDelta: originInfo.heightDelta,
        windowSize: newFrameRect.size
      )
      let targetFrame = NSRect(
        x: adjustedPoint.x, y: adjustedPoint.y - newFrameRect.height,
        width: newFrameRect.width, height: newFrameRect.height
      )
      if animated {
        NSAnimationContext.runAnimationGroup { context in
          context.duration = 0.12
          window.animator().setFrame(targetFrame, display: true)
        }
      } else {
        window.setFrame(targetFrame, display: true)
      }
    }

    private func adjustedTopLeft(
      rawTopLeft: CGPoint, heightDelta: Double, windowSize: CGSize
    )
      -> CGPoint {
      var adjustedPoint = rawTopLeft
      var delta = heightDelta
      var screenFrame = NSScreen.main?.visibleFrame ?? .zero
      for frame in NSScreen.screens.map(\.visibleFrame).filter({ $0.contains(rawTopLeft) }) {
        screenFrame = frame
        break
      }
      if delta > screenFrame.size.height / 2.0 { delta = 0.0 }
      if adjustedPoint.y < screenFrame.minY + windowSize.height {
        adjustedPoint.y = rawTopLeft.y + windowSize.height + delta
      }
      adjustedPoint.y = min(adjustedPoint.y, screenFrame.maxY - 1.0)
      adjustedPoint.x = min(
        max(adjustedPoint.x, screenFrame.minX),
        screenFrame.maxX - windowSize.width - 1.0
      )
      return adjustedPoint
    }

    private func handleMouseScroll(deltaX: CGFloat, deltaY: CGFloat) {
      switch (deltaX, deltaY, Self.thePool.layout) {
      case (0, 1..., .vertical), (1..., 0, .horizontal): highlightNextCandidate()
      case (..<0, 0, .horizontal), (0, ..<0, .vertical): highlightPreviousCandidate()
      case (0, 1..., .horizontal), (1..., 0, .vertical):
        // When expandable & unexpanded, just expand, no line flip.
        if Self.thePool.isExpandable, !Self.thePool.isExpanded {
          Self.thePool.expandIfNeeded(isBackward: false)
          updateDisplay()
          return
        }
        showNextLine()
      case (0, ..<0, .horizontal), (..<0, 0, .vertical):
        // When expandable & unexpanded, just expand, no line flip.
        if Self.thePool.isExpandable, !Self.thePool.isExpanded {
          Self.thePool.expandIfNeeded(isBackward: true)
          updateDisplay()
          return
        }
        showPreviousLine()
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
} // extension GSI4AppKit
