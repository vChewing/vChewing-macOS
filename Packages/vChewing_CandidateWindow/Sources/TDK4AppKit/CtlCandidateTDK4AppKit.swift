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

    public var delegate: CtlCandidateDelegate? {
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
        let animate = prefs.enableCandidateWindowAnimation
        asyncOnMain { [weak self] in
          guard let this = self else { return }
          this.set(
            windowTopLeftPoint: newValue,
            bottomOutOfScreenAdjustmentHeight: 0,
            useGCD: true,
            animated: animate
          )
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

    private let prefs = PrefMgr.sharedSansDidSetOps

    @objc
    private var observation: NSKeyValueObservation?
    // 創建背景視覺效果視圖
    private let visualEffectView: NSView? = {
      if #available(macOS 26, *), NSApplication.uxLevel == .liquidGlass {
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

    /// visible 狀態剛發生實質變化時設為 true，在下一次 updateNSWindowModern 執行完畢後歸零。
    private var suppressAnimationOnce = false

    private var enableAnimation: Bool {
      guard prefs.enableCandidateWindowAnimation else { return false }
      // visible 剛發生切換（含視窗從不可見變為可見）時，跳過動畫以避免「從遠處飛入」的效果。
      if suppressAnimationOnce { return false }
      // 視窗尚未實際出現在螢幕上時也不做動畫。
      guard window?.isVisible == true else { return false }
      return true
    }

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

    /// 針對給定的視窗目標尺寸，計算螢幕邊緣修正後的 top-left 坐標。
    private func adjustedTopLeft(
      rawTopLeft: CGPoint, heightDelta: Double, windowSize: CGSize
    )
      -> CGPoint {
      var adjustedPoint = rawTopLeft
      var delta = heightDelta
      var screenFrame = NSScreen.main?.visibleFrame ?? .zero
      for frame in NSScreen.screens.map(\.visibleFrame)
        .filter({ $0.contains(rawTopLeft) }) {
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

    private func updateEffectView() {
      if #available(macOS 26, *), NSApplication.uxLevel == .liquidGlass {
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

      let animateThisRound = enableAnimation
      // 無論是否啟用動畫，都在本次更新後清除抑制旗標。
      defer { suppressAnimationOnce = false }

      guard !Self.shouldDisableVisualEffectView else {
        window.isOpaque = false
        window.backgroundColor = .clear
        window.contentView = candidateView
        applyTargetFrame(to: window, contentSize: candidateView.fittingSize, animated: animateThisRound)
        return
      }

      // 更新背景視覺效果視圖
      updateEffectView()

      let viewSize = candidateView.fittingSize
      guard let containerView = window.contentView else { return }

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

      applyTargetFrame(to: window, contentSize: viewSize, animated: animateThisRound)
    }

    /// 依據給定的內容尺寸，向 delegate 查詢游標位置、計算螢幕邊緣修正後的目標 frame，
    /// 再將結果直接套用至視窗。
    ///
    /// NSWindow 在 `setFrame` 時會自動帶動 `contentView` resize（autoresizingMask 預設行為），
    /// 其下以 `pinEdges` 綁定的 subview（`candidateView`、`visualEffectView` 等）
    /// 亦會透過 Auto Layout 跟著同步縮放，無需手動介入 containerView。
    ///
    /// - Parameters:
    ///   - window: 目標 `NSWindow`。
    ///   - contentSize: 視窗內容的目標尺寸（通常為 `candidateView.fittingSize`）。
    ///   - animated: 是否使用 `NSAnimationContext` 動畫（duration 0.12s）。
    private func applyTargetFrame(
      to window: NSWindow,
      contentSize: CGSize,
      animated: Bool
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
