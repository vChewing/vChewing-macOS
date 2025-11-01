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

extension UILayoutOrientation {
  fileprivate var layoutTDK: CandidatePool.LayoutOrientation {
    switch self {
    case .horizontal:
      return .horizontal
    case .vertical:
      return .vertical
    @unknown default:
      return .horizontal
    }
  }
}

// MARK: - CtlCandidateTDK

public class CtlCandidateTDK: CtlCandidate, NSWindowDelegate {
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

    super.init(layout)
    window = panel
    Self.currentWindow = panel
    window?.delegate = self
    currentLayout = layout

    self.observation = Broadcaster.shared
      .observe(\.eventForClosingAllPanels, options: [.new]) { _, _ in
        self.visible = false
      }
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // MARK: Public

  public static var currentMenu: NSMenu? {
    willSet {
      currentMenu?.cancelTracking()
    }
  }

  public static var currentWindow: NSWindow? {
    willSet {
      currentWindow?.orderOut(nil)
    }
  }

  // Already implemented in CandidatePool.
  override public var highlightedIndex: Int {
    get { Self.thePool.highlightedIndex }
    set {
      Self.thePool.highlight(at: newValue)
      updateDisplay()
    }
  }

  public var maxLinesPerPage: Int = 0
  public var useCocoa: Bool = false
  public var useMouseScrolling: Bool = true

  override public func updateDisplay() {
    guard let window = window else { return }
    asyncOnMain { [weak self] in
      guard let self = self else { return }
      self.updateNSWindowModern(window)
    }
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

  // MARK: - Public functions

  override public func reloadData() {
    CandidateCellData.unifiedSize = candidateFont.pointSize
    guard let delegate = delegate else { return }
    Self.thePool = .init(
      candidates: delegate.candidatePairs(conv: true), lines: maxLinesPerPage,
      isExpanded: delegate.shouldAutoExpandCandidates,
      selectionKeys: delegate.selectionKeys, layout: currentLayout.layoutTDK, locale: locale
    )
    Self.thePool.tooltip = tooltip
    Self.thePool.reverseLookupResult = reverseLookupResult
    Self.thePool.highlight(at: 0)
    updateDisplay()
  }

  override public func scrollWheel(with event: NSEvent) {
    guard useMouseScrolling else { return }
    handleMouseScroll(deltaX: event.deltaX, deltaY: event.deltaY)
  }

  // Already implemented in CandidatePool.
  @discardableResult
  override public func showNextPage() -> Bool {
    defer { updateDisplay() }
    return Self.thePool.flipPage(isBackward: false)
  }

  // Already implemented in CandidatePool.
  @discardableResult
  override public func showPreviousPage() -> Bool {
    defer { updateDisplay() }
    return Self.thePool.flipPage(isBackward: true)
  }

  // Already implemented in CandidatePool.
  @discardableResult
  override public func showPreviousLine() -> Bool {
    defer { updateDisplay() }
    return Self.thePool.consecutivelyFlipLines(isBackward: true, count: 1)
  }

  // Already implemented in CandidatePool.
  @discardableResult
  override public func showNextLine() -> Bool {
    defer { updateDisplay() }
    return Self.thePool.consecutivelyFlipLines(isBackward: false, count: 1)
  }

  // Already implemented in CandidatePool.
  @discardableResult
  override public func highlightNextCandidate() -> Bool {
    defer { updateDisplay() }
    return Self.thePool.highlightNeighborCandidate(isBackward: false)
  }

  // Already implemented in CandidatePool.
  @discardableResult
  override public func highlightPreviousCandidate() -> Bool {
    defer { updateDisplay() }
    return Self.thePool.highlightNeighborCandidate(isBackward: true)
  }

  // Already implemented in CandidatePool.
  override public func candidateIndexAtKeyLabelIndex(_ id: Int) -> Int? {
    Self.thePool.calculateCandidateIndex(subIndex: id)
  }

  // MARK: Internal

  @objc
  var observation: NSKeyValueObservation?

  func updateNSWindowModern(_ window: NSWindow) {
    guard #available(macOS 10.13, *) else {
      Self.currentView = theViewAppKit
      window.isOpaque = false
      window.backgroundColor = .clear
      window.contentView = Self.currentView
      window.setContentSize(Self.currentView.fittingSize)
      delegate?.resetCandidateWindowOrigin()
      return
    }

    // 獲取候選視圖並計算其尺寸
    let candidateView = theViewAppKit
    let viewSize = candidateView.fittingSize

    // 創建背景視覺效果視圖
    let visualEffectView: NSView? = {
      if #available(macOS 26.0, *), NSApplication.uxLevel == .liquidGlass {
        #if compiler(>=6.2) && canImport(AppKit, _version: 26.0)
          let resultView = AXIrresponsiveView4NSLiquidGlass()
          resultView.cornerRadius = Self.thePool.windowRadius
          resultView.style = .clear
          let bgTintColor: NSColor = !NSApplication.isDarkMode ? .white : .black
          resultView.wantsLayer = true
          resultView.layer?.cornerRadius = Self.thePool.windowRadius
          resultView.layer?.masksToBounds = true
          resultView.layer?.backgroundColor = bgTintColor.withAlphaComponent(0.1).cgColor
          return resultView
        #endif
      }
      if #available(macOS 10.10, *), NSApplication.uxLevel != .none {
        let resultView = AXIrresponsiveView4NSVisualFX()
        resultView.material = .titlebar
        resultView.blendingMode = .behindWindow
        resultView.state = .active
        // 設置圓角以保持原有的視覺特性
        resultView.wantsLayer = true
        resultView.layer?.cornerRadius = Self.thePool.windowRadius
        resultView.layer?.masksToBounds = true
        return resultView
      }
      return nil
    }()

    // 創建容器視圖作為 ZStack，設置固定尺寸
    let containerView = AXIrresponsiveView(frame: CGRect(origin: .zero, size: viewSize))
    // 為容器視圖也設置圓角，確保整體一致性
    containerView.wantsLayer = true
    containerView.layer?.cornerRadius = Self.thePool.windowRadius
    containerView.layer?.masksToBounds = true

    // 設置背景視覺效果視圖
    if let visualEffectView {
      containerView.addSubview(visualEffectView)
      visualEffectView.pinEdges(to: containerView)
    }

    // 添加候選窗口內容視圖
    containerView.addSubview(candidateView)
    candidateView.pinEdges(to: containerView)

    Self.currentView = containerView
    window.isOpaque = false
    window.backgroundColor = .clear
    window.contentView = Self.currentView
    window.setContentSize(viewSize)
    delegate?.resetCandidateWindowOrigin()
  }

  func handleMouseScroll(deltaX: CGFloat, deltaY: CGFloat) {
    switch (deltaX, deltaY, Self.thePool.layout) {
    case (0, 1..., .vertical), (1..., 0, .horizontal): highlightNextCandidate()
    case (..<0, 0, .horizontal), (0, ..<0, .vertical): highlightPreviousCandidate()
    case (0, 1..., .horizontal), (1..., 0, .vertical): showNextLine()
    case (0, ..<0, .horizontal), (..<0, 0, .vertical): showPreviousLine()
    case (_, _, _): break
    }
  }

  // MARK: Private

  private static var thePool: CandidatePool = .init(candidates: [])
  private static var currentView: NSView = AXIrresponsiveView()

  private var theViewAppKit: NSView {
    VwrCandidateTDKAppKit(controller: self, thePool: Self.thePool)
  }

  private var theViewLegacy: NSView {
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
}

// MARK: - AXIrresponsivePanel

public class AXIrresponsivePanel: NSPanel {
  // MARK: Lifecycle

  convenience init() {
    let contentRect = CGRect(x: 128.0, y: 128.0, width: 0.0, height: 0.0)
    let styleMask: NSWindow.StyleMask = [.nonactivatingPanel]
    self.init(
      contentRect: contentRect, styleMask: styleMask, backing: .buffered, defer: false
    )

    // 如仍想在 10.10+ 以呼叫方式加強語義（非必要，因為已覆寫）：
    if #available(macOS 10.10, *) {
      self.setAccessibilityElement(false)
      self.setAccessibilityRole(.unknown)
    }
  }

  // MARK: Public

  // macOS 10.10+：讓此 Panel 不是可存取元素
  @available(macOS 10.10, *)
  override public func isAccessibilityElement() -> Bool {
    false
  }

  // macOS 10.10+：角色回報為 unknown（避免成為具名可聚焦元素）
  @available(macOS 10.10, *)
  override public func accessibilityRole() -> NSAccessibility.Role? {
    .unknown
  }

  // macOS 10.9 與更早：舊式 API，直接忽略此元素
  @objc
  override public func accessibilityIsIgnored() -> Bool {
    true
  }
}

// MARK: - AXIrresponsiveView

public class AXIrresponsiveView: NSView {
  // MARK: Lifecycle

  override init(frame: NSRect) {
    super.init(frame: frame)

    // 如仍想在 10.10+ 以呼叫方式加強語義（非必要，因為已覆寫）：
    if #available(macOS 10.10, *) {
      self.setAccessibilityElement(false)
    }
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
  }

  // MARK: Public

  // macOS 10.10+：讓此 Panel 不是可存取元素
  @available(macOS 10.10, *)
  override public func isAccessibilityElement() -> Bool {
    false
  }

  // macOS 10.9 與更早：舊式 API，直接忽略此元素
  @objc
  override public func accessibilityIsIgnored() -> Bool {
    true
  }
}

// MARK: - AXIrresponsiveView4NSVisualFX

@available(macOS 10.10, *)
public class AXIrresponsiveView4NSVisualFX: NSVisualEffectView {
  // MARK: Lifecycle

  override init(frame: NSRect) {
    super.init(frame: frame)
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
  }

  // MARK: Public

  // macOS 10.10+：讓此 Panel 不是可存取元素
  override public func isAccessibilityElement() -> Bool {
    false
  }

  // macOS 10.9 與更早：舊式 API，直接忽略此元素
  @objc
  override public func accessibilityIsIgnored() -> Bool {
    true
  }
}

// MARK: - AXIrresponsiveView4NSLiquidGlass

#if compiler(>=6.2) && canImport(AppKit, _version: 26.0)
  @available(macOS 26, *)
  public class AXIrresponsiveView4NSLiquidGlass: NSGlassEffectView {
    // MARK: Lifecycle

    override init(frame: NSRect) {
      super.init(frame: frame)
    }

    required init?(coder: NSCoder) {
      super.init(coder: coder)
    }

    // MARK: Public

    // macOS 10.10+：讓此 Panel 不是可存取元素
    override public func isAccessibilityElement() -> Bool {
      false
    }

    // macOS 10.9 與更早：舊式 API，直接忽略此元素
    @objc
    override public func accessibilityIsIgnored() -> Bool {
      true
    }
  }
#endif
