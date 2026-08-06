// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import AppKit
import QuartzCore
import Shared_DarwinImpl
import SwiftExtension

/// 卡片自身陰影的基準不透明度（隨卡片淡化等比縮放）。
private let kNotifierCardShadowOpacity: Float = 0.25

// 卡片內文排版常數（NotifierCard 內部使用）。
private let kNotifierHorizontalPadding: CGFloat = 12
private let kNotifierExtraRightSpacing: CGFloat = 64
private let kNotifierIconSize: CGFloat = 64
private let kNotifierGapBetweenLabelAndIcon: CGFloat = 6

// MARK: - Notifier

/// 單一視窗通知 UI：所有通知內容一律顯示在同一個透明的 NSWindow 內。
///
/// 視窗本體全透明、不繪製任何背景與陰影——每張卡片（`NotifierCard`）自帶材質背景 layer
/// 與陰影，並於視窗內側留白處繪製（避免陰影被視窗邊緣裁切）。所有「幾何與序列」的計算
/// 皆委託給 `NotifierViewModel`（singleton）；本類別僅負責把計算結果渲染到畫面上——
/// 綁定視圖實例（卡片池重用）、套用框架 / 透明度 / 滑入起點、排程淡出與新鮮期計時器。
public final class Notifier: NSWindowController {
  // MARK: Lifecycle

  private init() {
    let styleMask: NSWindow.StyleMask = [.borderless]
    let theWindow = NSWindow(
      contentRect: .zero, styleMask: styleMask, backing: .buffered, defer: false
    )
    // 視窗本體全透明：背景與陰影皆由各卡片自行繪製。
    theWindow.isOpaque = false
    theWindow.backgroundColor = .clear
    theWindow.hasShadow = false
    theWindow.contentView = NSView()
    theWindow.ignoresMouseEvents = true
    theWindow.level = NSWindow.Level(Int(max(CGShieldingWindowLevel(), kCGPopUpMenuWindowLevel)))
    theWindow.title = ""
    if #available(macOS 10.10, *) {
      theWindow.titlebarAppearsTransparent = true
      theWindow.titleVisibility = .hidden
    }
    theWindow.showsToolbarButton = false
    theWindow.standardWindowButton(NSWindow.ButtonType.zoomButton)?.isHidden = true
    theWindow.standardWindowButton(NSWindow.ButtonType.miniaturizeButton)?.isHidden = true
    theWindow.standardWindowButton(NSWindow.ButtonType.closeButton)?.isHidden = true
    theWindow.isReleasedWhenClosed = false
    theWindow.isMovable = false
    // 常駐視窗於可見期間加入所有桌面空間——沿用舊版「每則通知各建視窗、於作用中空間顯示」
    // 的送達語義，避免視窗仍停留在前一空間時錯過後續通知。
    theWindow.collectionBehavior = [.canJoinAllSpaces, .stationary]
    // 強制 Notifier 視窗使用 Dark Mode（僅在 macOS 10.14+ 生效）。
    if #available(macOS 10.14, *) {
      theWindow.appearance = Self.currentNSAppearance
    }
    super.init(window: theWindow)
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // MARK: Public

  public static func notify(message: String) {
    mainSync { Self.shared.enqueue(message) }
  }

  // MARK: Fileprivate

  fileprivate static var currentNSAppearance: NSAppearance? {
    if #available(macOS 10.14, *) {
      // minus-zero: Bright, 0: nil, rest: Dark.
      switch prefs.specifiedNotifyUIColorScheme {
      case ..<0: return NSAppearance(named: .aqua)
      case 0: return nil
      default: return NSAppearance(named: .darkAqua)
      }
    }
    return nil
  }

  // MARK: Private

  private static let shared = Notifier()
  private static let prefs = PrefMgr.sharedSansDidSetOps

  private let viewModel = NotifierViewModel.shared

  /// 邏輯記錄 id → 視圖實例 的綁定。
  private var viewsByID: [Int: NotifierCard] = [:]

  /// 閒置視圖池（與綁定視圖合計不超過 `maxCardCount` 個實例，重複利用記憶體位址）。
  private var freeViews: [NotifierCard] = []

  // MARK: Private Methods

  private func enqueue(_ message: String) {
    guard let theWindow = window, NSScreen.main?.visibleFrame != nil else { return }
    let intrinsicWidth = NotifierCard.measureIntrinsicWidth(for: message)
    guard let event = viewModel.enqueue(message: message, intrinsicWidth: intrinsicWidth) else {
      return
    }
    applyAppearance()

    // 視圖綁定：被逐出者的視圖重用給新卡；否則自池中取用或新建。
    let card: NotifierCard
    if let evictedID = event.evictedID, let evicted = viewsByID.removeValue(forKey: evictedID) {
      card = evicted
      card.removeFromSuperview()
      // 重用前先隱藏，避免「由底部跳至頂部」的視覺錯位；於頂端再淡入。
      card.applyDisplayAlpha(0, animated: false)
    } else if let pooled = freeViews.popLast() {
      card = pooled
      card.applyDisplayAlpha(0, animated: false)
    } else {
      card = NotifierCard()
      card.applyDisplayAlpha(0, animated: false)
    }
    card.reset(message: message, intrinsicWidth: intrinsicWidth)
    viewsByID[event.newID] = card
    theWindow.contentView?.addSubview(card)

    // 新鮮期標記（去重窗口）。
    asyncOnMain(after: viewModel.dedupWindow) {
      self.viewModel.markNotNew(event.newID)
    }
    // 每則通知皆以相同的固定時長（displayLifetime）停留在螢幕上，之後觸發淡出；
    // 不因被推下（基礎透明度改變）而重置——三卡的淡出時機因此互不相同。
    asyncOnMain(after: viewModel.displayLifetime) { [weak self] in
      guard let self = self else { return }
      if self.viewModel.fadeOut(event.newID) {
        self.startFadeOut(event.newID)
      }
    }

    applyLayout(animated: true)
    viewModel.consumeSlideIn(for: event.newID)
  }

  /// 將指定卡片以動畫徹底淡出（透明度至 0）並於淡出完成後移除、歸還池中。
  private func startFadeOut(_ id: Int) {
    guard let card = viewsByID[id] else { return }
    NSAnimationContext.runAnimationGroup { context in
      context.duration = self.viewModel.fadeOutDuration
      card.applyDisplayAlpha(0, animated: true)
    } completionHandler: {
      // 淡出完成回呼不保證於主執行緒執行，統一以 mainSync 回主執行緒再處理。
      mainSync { [weak self] in
        guard let self = self else { return }
        // 淡出期間若已被逐出重用（記錄不存在）則不再處理。
        guard self.viewModel.completeRemoval(id) else { return }
        let removed = self.viewsByID.removeValue(forKey: id)
        removed?.removeFromSuperview()
        if let removed = removed {
          self.freeViews.append(removed)
        }
        self.applyLayout(animated: true)
      }
    }
  }

  private func applyLayout(animated: Bool) {
    guard let theWindow = window, let screenRect = NSScreen.main?.visibleFrame else { return }
    let layout = viewModel.layout(in: screenRect)
    if layout.placements.isEmpty {
      // 所有通知卡片均已移除時，收起視窗。
      theWindow.orderOut(nil)
      return
    }
    // 視窗尺寸直接就位（其本身不參與動畫）。
    let windowWidthChanged = theWindow.frame.width != layout.windowFrame.width
    theWindow.setFrame(layout.windowFrame, display: false)
    if !theWindow.isVisible {
      // 首次顯示（或清空後再現）：就位於滑入起點（左側偏移處）後帶出視窗，
      // 再於視窗顯示後以動畫飄入最終位置——即使動畫被顯示延遲，起始位置亦正確；
      // 動畫以「起點 → 終點」顯式 from/to（模型先就位於終點，結束後無跳變）。
      for p in layout.placements {
        viewsByID[p.id]?.applyDisplayAlpha(p.alpha, animated: false)
      }
      let finalFrame = layout.placements.first?.frame
      if let first = layout.placements.first, let start = first.slideInStart,
         let view = viewsByID[first.id] {
        view.frame = start
      }
      theWindow.orderFront(self)
      asyncOnMain { [weak self] in
        guard let self = self, let finalFrame = finalFrame, let first = layout.placements.first,
              let start = first.slideInStart, let view = self.viewsByID[first.id]
        else { return }
        // 延遲執行期間若已有更新的通知入列（本卡已被推下），其幾何由較新的 applyLayout 負責，
        // 不再以過期的「頂端就位＋滑入」覆寫（否則本卡會跳回頂端與新卡重疊）。
        guard self.viewModel.records.first?.id == first.id else { return }
        view.frame = finalFrame
        let slideAnimation = CABasicAnimation(keyPath: "position.x")
        slideAnimation.fromValue = start.origin.x
        slideAnimation.toValue = finalFrame.origin.x
        slideAnimation.duration = self.viewModel.slideInDuration
        view.layer?.add(slideAnimation, forKey: "slideInX")
      }
    } else if animated {
      // 最新卡片：先就位於最終位置（Y 永不參與動畫），再僅以 layer position.x 動畫
      // 自左側滑入——不依賴 animator 的起始值捕捉，杜絕重用卡片由舊位置「下往上」的錯位。
      // 註：NSView backing layer 的 anchorPoint 為 (0,0)、position 即 frame 原點，
      // 故以「目前 position.x − 滑入偏移 → 目前 position.x」動畫即為純水平左→右。
      var slidingID: Int?
      if let first = layout.placements.first, first.slideInStart != nil,
         let view = viewsByID[first.id] {
        slidingID = first.id
        view.frame = first.frame
        if let currentX = view.layer?.position.x {
          let slideAnimation = CABasicAnimation(keyPath: "position.x")
          slideAnimation.fromValue = currentX - viewModel.slideInOffset
          slideAnimation.toValue = currentX
          slideAnimation.duration = viewModel.slideInDuration
          view.layer?.add(slideAnimation, forKey: "slideInX")
        }
      }
      NSAnimationContext.runAnimationGroup { context in
        context.duration = viewModel.relayoutDuration
        for p in layout.placements {
          guard let view = viewsByID[p.id] else { continue }
          // 滑入中的卡片 frame 已就位，不再以 animator 覆寫（避免 Y 被動畫）。
          if p.id != slidingID {
            if windowWidthChanged {
              // 視窗寬度隨最寬卡片變動時，卡片 X 的變化與視窗位移在螢幕上恰好抵消——
              // X 直接就位（避免 animator 沿視窗座標插值造成水平抖動），僅以動畫推移 Y。
              view.frame.origin.x = p.frame.origin.x
            }
            view.animator().frame = p.frame
          }
          view.applyDisplayAlpha(p.alpha, animated: true)
        }
      }
    } else {
      for p in layout.placements {
        viewsByID[p.id]?.frame = p.frame
        viewsByID[p.id]?.applyDisplayAlpha(p.alpha, animated: false)
      }
    }
    // 以各卡自身寬度重新排版內容（fixedSize 語義）。
    for p in layout.placements {
      viewsByID[p.id]?.layoutContent(width: p.frame.width)
    }
  }

  private func applyAppearance() {
    if #available(macOS 10.14, *) {
      let appearance = Self.currentNSAppearance
      window?.appearance = appearance
      viewsByID.values.forEach { $0.applyAppearance(appearance) }
    }
  }
}

// MARK: - NotifierCard

/// 單張通知卡片：自帶材質背景 layer 與陰影、承載訊息文字與 App 圖示，
/// 是單一視窗內的堆疊單位。純渲染元件——位置、透明度、滑入起點皆由
/// `NotifierViewModel` 計算、由 `Notifier` 套用；本類別不持有任何堆疊狀態。
private final class NotifierCard: NSView {
  // MARK: Lifecycle

  /// 僅建立視覺子視圖（背景 / 文字 / 圖示）；內容於每次 `reset(message:intrinsicWidth:)` 時填寫。
  init() {
    // 背景 layer：10.10+ 使用視覺材質、其餘以純色填充。
    let backgroundView: NSView
    if #available(macOS 10.10, *) {
      let visual = NSVisualEffectView()
      visual.blendingMode = .behindWindow
      visual.state = .active
      if #available(macOS 10.14, *) {
        visual.material = .underWindowBackground
      }
      backgroundView = visual
    } else {
      let plain = NSView()
      plain.wantsLayer = true
      plain.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
      backgroundView = plain
    }
    self.backgroundView = backgroundView

    let lblMessage = NSTextField()
    lblMessage.drawsBackground = false
    lblMessage.font = .boldSystemFont(ofSize: NSFont.systemFontSize(for: .regular))
    lblMessage.isBezeled = false
    lblMessage.isEditable = false
    lblMessage.isSelectable = false
    lblMessage.textColor = .controlTextColor
    self.lblMessage = lblMessage

    var iconView: NSImageView?
    if let appIcon = NSApplication.shared.applicationIconImage {
      let theIcon = NSImageView()
      theIcon.image = appIcon
      theIcon.imageScaling = .scaleAxesIndependently
      theIcon.alphaValue = 0.5
      theIcon.wantsLayer = true
      iconView = theIcon
    }
    self.iconView = iconView

    super.init(frame: NSRect(x: 0, y: 0, width: 0, height: NotifierViewModel.shared.cardHeight))
    // 卡片自身繪製陰影（需視窗內側留白才不會被邊緣裁切）。
    // macOS < 10.13 的透明視窗不渲染 CALayer shadow——改以 1px 灰邊替代
    // （陰影 / 灰邊皆隨卡片 alpha 等比淡化，見 applyDisplayAlpha）。
    wantsLayer = true
    if #available(macOS 10.13, *) {
      layer?.shadowColor = NSColor.black.cgColor
      layer?.shadowOpacity = kNotifierCardShadowOpacity
      layer?.shadowRadius = 10
      layer?.shadowOffset = CGSize(width: 0, height: -2)
    } else {
      layer?.borderWidth = 1
      layer?.borderColor = NSColor.gray.withAlphaComponent(1.0).cgColor
    }
    layer?.masksToBounds = false
    addSubview(backgroundView)
    addSubview(lblMessage)
    if let iconView = iconView {
      addSubview(iconView)
    }
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // MARK: Internal

  /// 目前承載的訊息內容（供主題切換時重建文字）。
  private(set) var message: String = ""

  // MARK: Private Methods

  /// 系統明暗主題切換時（macOS 10.14+ 由 AppKit 呼叫）：重新套用材質外觀、
  /// 重建訊息字串，使動態顏色（`controlTextColor` / `secondaryLabelColor`）
  /// 於下一次繪製時依目前外觀解析——每張卡片各自獨立回應主題變更。
  @available(macOS 10.14, *)
  override func viewDidChangeEffectiveAppearance() {
    super.viewDidChangeEffectiveAppearance()
    (backgroundView as? NSVisualEffectView)?.appearance = Notifier.currentNSAppearance
    lblMessage.attributedStringValue = Self.makeAttributedString(for: message)
    lblMessage.needsDisplay = true
  }

  /// 靜態測量：以暫用文字欄位計算某則訊息所需的卡片自然寬度（供 viewModel 計算堆疊寬度）。
  static func measureIntrinsicWidth(for message: String) -> CGFloat {
    let lbl = NSTextField()
    lbl.attributedStringValue = makeAttributedString(for: message)
    lbl.drawsBackground = false
    lbl.font = .boldSystemFont(ofSize: NSFont.systemFontSize(for: .regular))
    lbl.isBezeled = false
    lbl.isEditable = false
    lbl.isSelectable = false
    lbl.sizeToFit()
    return lbl.frame.size.width + kNotifierHorizontalPadding * 2 + kNotifierExtraRightSpacing
  }

  /// 重置卡片內容以供重用：重建訊息字串、重新測量、依給定寬度排版。
  func reset(message: String, intrinsicWidth: CGFloat) {
    self.message = message
    // 回復未換行的測量基準後，重新測量自然尺寸。
    if let cell = lblMessage.cell as? NSTextFieldCell {
      cell.wraps = false
      cell.truncatesLastVisibleLine = false
    }
    lblMessage.attributedStringValue = Self.makeAttributedString(for: message)
    lblMessage.sizeToFit()
    labelNaturalSize = lblMessage.frame.size
    layoutContent(width: intrinsicWidth)
  }

  /// 依偏好設定套用外觀（僅 macOS 10.14+ 生效）。
  func applyAppearance(_ appearance: NSAppearance?) {
    if #available(macOS 10.14, *) {
      (backgroundView as? NSVisualEffectView)?.appearance = appearance
    }
  }

  /// 套用顯示透明度：文字、圖示、背景與陰影一律等比淡化（避免只淡內容、
  /// 材質與陰影仍全強度的視覺錯位）。
  func applyDisplayAlpha(_ alpha: CGFloat, animated: Bool) {
    let iconAlpha = alpha * 0.5 // 圖示自帶 0.5 基準透明度。
    if animated {
      lblMessage.animator().alphaValue = alpha
      iconView?.animator().alphaValue = iconAlpha
      backgroundView.animator().alphaValue = alpha
    } else {
      lblMessage.alphaValue = alpha
      iconView?.alphaValue = iconAlpha
      backgroundView.alphaValue = alpha
    }
    if #available(macOS 10.13, *) {
      // 陰影透明度隨 alpha 等比縮放（於 NSAnimationContext 內以隱式動畫淡化）。
      layer?.shadowOpacity = kNotifierCardShadowOpacity * Float(alpha)
    } else {
      // macOS < 10.13：灰邊透明度隨 alpha 等比縮放。
      layer?.borderColor = NSColor.gray.withAlphaComponent(alpha).cgColor
    }
  }

  /// 依給定的卡片寬度重新定位背景、文字與圖示。
  func layoutContent(width: CGFloat) {
    let cardHeight = NotifierViewModel.shared.cardHeight
    backgroundView.frame = NSRect(x: 0, y: 0, width: width, height: cardHeight)
    let maxLabelWidth = width - kNotifierIconSize - kNotifierGapBetweenLabelAndIcon
      - kNotifierHorizontalPadding
    var labelFrame = lblMessage.frame
    if labelNaturalSize.width > maxLabelWidth {
      labelFrame.size.width = maxLabelWidth
      lblMessage.frame = labelFrame
      if let cell = lblMessage.cell as? NSTextFieldCell {
        cell.wraps = true
        cell.truncatesLastVisibleLine = false
        cell.lineBreakMode = .byWordWrapping
      }
      lblMessage.sizeToFit()
      labelFrame = lblMessage.frame
    } else {
      labelFrame.size = labelNaturalSize
      lblMessage.frame = labelFrame
    }
    labelFrame.origin.x = kNotifierHorizontalPadding
    labelFrame.origin.y = (cardHeight - labelFrame.height) / 1.9
    lblMessage.frame = labelFrame
    if let iconView = iconView {
      iconView.frame = NSRect(
        x: width - kNotifierIconSize, y: (cardHeight - kNotifierIconSize) / 2.0,
        width: kNotifierIconSize, height: kNotifierIconSize
      )
    }
  }

  // MARK: Private

  private var labelNaturalSize: NSSize = .zero
  private let backgroundView: NSView
  private let lblMessage: NSTextField
  private let iconView: NSImageView?

  // MARK: Private Methods

  private static func makeAttributedString(for message: String) -> NSAttributedString {
    let messageArray = message.components(separatedBy: "\n")

    let paraStyle = NSMutableParagraphStyle()
    paraStyle.setParagraphStyle(NSParagraphStyle.default)
    paraStyle.alignment = .left
    let attrTitle: [NSAttributedString.Key: Any] = [
      .kern: 0,
      .foregroundColor: NSColor.controlTextColor,
      .font: NSFont.boldSystemFont(ofSize: 17),
      .paragraphStyle: paraStyle,
    ]
    let attrString = NSMutableAttributedString(string: messageArray[0], attributes: attrTitle)
    let foregroundColor: NSColor = {
      if #available(macOS 10.10, *) {
        return NSColor.secondaryLabelColor
      }
      return NSColor.controlTextColor
    }()
    let attrAlt: [NSAttributedString.Key: Any] = [
      .kern: 0,
      .foregroundColor: foregroundColor,
      .font: NSFont.systemFont(ofSize: 15),
      .paragraphStyle: paraStyle,
    ]
    let additionalString = messageArray.count > 1 ? "\n\(messageArray[1])" : ""
    let attrStringAlt = NSMutableAttributedString(string: additionalString, attributes: attrAlt)
    attrString.insert(attrStringAlt, at: attrString.length)
    return attrString
  }
}
