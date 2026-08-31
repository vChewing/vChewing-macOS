// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import AppKit
import OSFrameworkImpl
import SwiftExtension

extension VwrAppInstaller4Cocoa {
  public static let copyrightLabel = Bundle.main
    .localizedInfoDictionary?["NSHumanReadableCopyright"] as? String ?? "BAD_COPYRIGHT_LABEL"
  public static let eulaContent = Bundle.main
    .localizedInfoDictionary?["CFEULAContent"] as? String ?? "BAD_EULA_CONTENT"
  public static let eulaContentUpstream = Bundle.main
    .infoDictionary?["CFUpstreamEULAContent"] as? String ?? "BAD_EULA_UPSTREAM"

  /// 主視窗的 content size，與 SwiftUI 版安裝程式的 Window Size（1000×630）一致。
  public static let meshWindowWidth: CGFloat = 1_000
  public static let meshWindowHeight: CGFloat = 630
}

// MARK: - VwrAppInstaller4Cocoa

public final class VwrAppInstaller4Cocoa: NSViewController, InstallerVMProtocol {
  // MARK: Lifecycle

  deinit {
    mainSync {
      stopTranslocationTimer()
    }
  }

  // MARK: Public

  override public func loadView() {
    let container = NSView()
    container.autoresizingMask = [.width, .height]

    // 背景 color mesh（與 SwiftUI 版安裝程式的 GradientViewWrapper 一致）。
    let meshView = MeshGradientView()
    container.addSubview(meshView)
    meshView.pinEdges(to: container)

    // 左上角的標題文字（與 SwiftUI 版相同：30pt 斜體粗體、白色、黑色陰影）。
    let titleLabel = Self.makeMeshTitleLabel()
    container.addSubview(titleLabel)
    titleLabel.translatesAutoresizingMaskIntoConstraints = false
    container.addConstraint(
      NSLayoutConstraint(
        item: titleLabel, attribute: .top, relatedBy: .equal,
        toItem: container, attribute: .top, multiplier: 1, constant: 16
      )
    )
    container.addConstraint(
      NSLayoutConstraint(
        item: titleLabel, attribute: .leading, relatedBy: .equal,
        toItem: container, attribute: .leading, multiplier: 1, constant: 16
      )
    )

    // 置中的安裝程式內容（圓角卡片＋陰影，外觀對應 SwiftUI 版的 GroupBox）。
    let content = body ?? .init()
    (content as? NSStackView)?.alignment = .centerX
    content.makeSimpleConstraint(.width, relation: .equal, value: windowWidth)
    let card = InstallerCardView()
    container.addSubview(card)
    card.translatesAutoresizingMaskIntoConstraints = false
    container.addConstraint(
      NSLayoutConstraint(
        item: card, attribute: .centerX, relatedBy: .equal,
        toItem: container, attribute: .centerX, multiplier: 1, constant: 0
      )
    )
    container.addConstraint(
      NSLayoutConstraint(
        item: card, attribute: .centerY, relatedBy: .equal,
        toItem: container, attribute: .centerY, multiplier: 1, constant: 0
      )
    )
    content.translatesAutoresizingMaskIntoConstraints = false
    card.addSubview(content)
    // 內容釘住「可見卡片」的四邊（frame 內縮 shadowMargin 後的可見圓角矩形）：
    // 上方補上 inner padding（對應 SwiftUI 版 GroupBox 的頂部留白），其餘三邊貼齊。
    // 注意 trailing／bottom 需用負號（向內縮），否則內容會往右下溢出卡片。
    [NSLayoutConstraint.Attribute.top, .leading, .trailing, .bottom].forEach { attribute in
      let constant: CGFloat
      switch attribute {
      case .top: constant = 20 + InstallerCardView.shadowMargin
      case .leading: constant = InstallerCardView.shadowMargin
      case .trailing: constant = -InstallerCardView.shadowMargin
      case .bottom: constant = -InstallerCardView.shadowMargin
      default: constant = 0
      }
      card.addConstraint(
        NSLayoutConstraint(
          item: content, attribute: attribute, relatedBy: .equal,
          toItem: card, attribute: attribute, multiplier: 1, constant: constant
        )
      )
    }

    view = container
    updateUpgradeableStatus()
    refreshUI()
  }

  // MARK: Internal

  let windowWidth: CGFloat = 533
  let contentWidth: CGFloat = 510
  let imgWidth: CGFloat = 63
  let taskQueue: DispatchQueue = .init(label: "vChewingInstaller.Queue.\(UUID().uuidString)")
  var translocationTimer: DispatchSourceTimer?

  var config: InstallerUIConfig = .init() {
    didSet {
      DispatchQueue.main.async { [weak self] in
        self?.refreshUI()
      }
    }
  }

  var appNameAndVersionString: NSAttributedString {
    // Use installer title and show version + build similar to SwiftUI
    let strResult = NSMutableAttributedString(string: "i18n:installer.APP_NAME".i18n)
    strResult.addAttribute(
      .font,
      value: {
        if #available(macOS 10.11, *) {
          return NSFont.systemFont(ofSize: 12, weight: .bold)
        }
        return NSFont.boldSystemFont(ofSize: 12)
      }(),
      range: .init(location: 0, length: strResult.length)
    )
    let strVersion = NSMutableAttributedString(string: " v\(versionString) Build \(installingVersion)")
    strVersion.addAttribute(
      .font,
      value: NSFont.systemFont(ofSize: 11),
      range: .init(location: 0, length: strVersion.length)
    )
    strResult.append(strVersion)
    strResult.addAttribute(
      .kern,
      value: 0,
      range: .init(location: 0, length: strResult.length)
    )
    return strResult
  }

  var body: NSView? {
    NSStackView.buildSection(width: contentWidth - 18) {
      NSStackView.build(.horizontal) {
        bannerImage
        NSStackView.build(.vertical) {
          appNameAndVersionString.makeNSLabel(fixWidth: contentWidth - imgWidth - 10)
          if let minimumOSSupportedDescriptionString {
            makeFormattedLabel(
              verbatim: minimumOSSupportedDescriptionString,
              size: 11,
              isBold: false, fixWidth: contentWidth - imgWidth - 10
            )
          }
          makeFormattedLabel(
            verbatim: "i18n:installer.DONATION_MESSAGE".i18n
              + "\n"
              + Self.copyrightLabel,
            size: 11,
            isBold: false, fixWidth: contentWidth - imgWidth - 10
          )
          makeFormattedLabel(
            verbatim: "i18n:installer.DEV_CREW".i18n,
            size: 11,
            isBold: false, fixWidth: contentWidth - imgWidth - 10
          )
          makeFormattedLabel(
            verbatim: "i18n:installer.LICENSE_TITLE".i18n,
            size: 11,
            isBold: false, fixWidth: contentWidth - imgWidth - 10
          )
          eulaBox
        }
      }
      NSStackView.build(.horizontal) {
        NSStackView.build(.vertical) {
          "i18n:installer.DISCLAIMER_TEXT".makeNSLabel(
            descriptive: true, fixWidth: contentWidth - 140
          )
          NSView()
        }
        var verticalButtonStackSpacing: CGFloat? = 4
        if #unavailable(macOS 10.10) {
          verticalButtonStackSpacing = nil
        }
        NSStackView.build(.vertical, spacing: verticalButtonStackSpacing, width: 114) {
          addKeyEquivalent(installButton)
          cancelButton
          websiteDonationButton
          NSView()
        }
      }
    }?.withInsets(
      {
        if #available(macOS 10.10, *) {
          return .new(all: 20, top: 0, bottom: 24)
        } else {
          return .new(all: 20, top: 10, bottom: 24)
        }
      }()
    )
  }

  var bannerImage: NSImageView {
    let maybeImg = NSImage(named: "AboutBanner")
    let imgIsNull = maybeImg == nil
    let img = maybeImg ?? .init(size: .init(width: 63, height: 310))
    let result = NSImageView()
    result.image = img
    result.makeSimpleConstraint(.width, relation: .equal, value: 63)
    result.makeSimpleConstraint(.height, relation: .equal, value: 310)
    if imgIsNull {
      result.wantsLayer = true
      result.layer?.backgroundColor = NSColor.black.cgColor
    }
    return result
  }

  var eulaBox: NSScrollView {
    let textView = NSTextView()
    let clipView = NSClipView()
    let scrollView = NSScrollView()
    textView.autoresizingMask = [.width, .height]
    textView.isEditable = false
    textView.isRichText = false
    textView.isSelectable = true
    textView.isVerticallyResizable = true
    textView.smartInsertDeleteEnabled = true
    textView.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
    textView.string = Self.eulaContent + "\n" + Self.eulaContentUpstream
    clipView.documentView = textView
    clipView.autoresizingMask = [.width, .height]
    clipView.drawsBackground = false
    scrollView.contentView = clipView
    scrollView.makeSimpleConstraint(
      .width, relation: .equal, value: contentWidth - imgWidth - 30
    )
    scrollView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    scrollView.hasVerticalScroller = true
    scrollView.hasHorizontalScroller = false
    scrollView.scrollerStyle = .legacy
    return scrollView
  }

  func makeFormattedLabel(
    verbatim: String,
    size: CGFloat = 12,
    isBold: Bool = false,
    fixWidth: CGFloat? = nil
  )
    -> NSLabelView {
    let attrStr = NSMutableAttributedString(string: verbatim)
    attrStr.addAttribute(
      .kern,
      value: 0,
      range: .init(location: 0, length: attrStr.length)
    )
    attrStr.addAttribute(
      .font,
      value: {
        guard isBold else { return NSFont.systemFont(ofSize: size) }
        if #available(macOS 10.11, *) {
          return NSFont.systemFont(ofSize: size, weight: .bold)
        }
        return NSFont.boldSystemFont(ofSize: size)
      }(),
      range: .init(location: 0, length: attrStr.length)
    )
    return attrStr.makeNSLabel(fixWidth: fixWidth)
  }

  @discardableResult
  func addKeyEquivalent(_ button: NSButton) -> NSButton {
    button.keyEquivalent = String(NSEvent.SpecialKey.carriageReturn.unicodeScalar)
    return button
  }

  // MARK: - Button Actions

  @objc
  func btnInstallAction(_: NSControl) {
    installationButtonClicked()
  }

  @objc
  func btnCancelAction(_: NSControl) {
    NSApp.terminateWithDelay()
  }

  @objc
  func btnWebSiteAction(_: NSControl) {
    if let url = URL(string: "https://vchewing.github.io/") {
      NSWorkspace.shared.open(url)
    }
  }

  @objc
  func btnBugReportAction(_: NSControl) {
    if let url = URL(string: "https://vchewing.github.io/BUGREPORT.html") {
      NSWorkspace.shared.open(url)
    }
  }

  // MARK: Private

  // MARK: - 標題文字（mesh 左上角）

  private static var meshTitleFont: NSFont {
    let baseFont = NSFont.systemFont(ofSize: 30)
    let descriptor = baseFont.fontDescriptor.withSymbolicTraits([.bold, .italic])
    return NSFont(descriptor: descriptor, size: 30) ?? baseFont
  }

  // MARK: UI Elements

  private lazy var installButton: NSButton = {
    NSButton(
      "i18n:installer.ACCEPT_INSTALLATION",
      target: self,
      action: #selector(btnInstallAction(_:))
    )
  }()

  private lazy var cancelButton: NSButton = {
    NSButton(
      "i18n:installer.CANCEL_INSTALLATION",
      target: self,
      action: #selector(btnCancelAction(_:))
    )
  }()

  private lazy var websiteDonationButton: NSButton = {
    let b = NSButton(
      "i18n:installer.HP_AND_DONATION",
      target: self, action: #selector(btnWebSiteAction(_:))
    )
    // 按鈕寬度有限：優先使用 Arial Narrow Bold，不可用時回退至系統預設字型。
    let size = b.font?.pointSize ?? NSFont.systemFontSize
    if let narrowBold = NSFont(name: "ArialNarrow-Bold", size: size) {
      b.font = narrowBold
    }
    return b
  }()

  private var pendingSheetWindow: NSWindow?
  private var pendingSheetTimeLabel: NSTextField?

  private var isPresentingAlert: Bool = false

  private static func makeMeshTitleLabel() -> NSTextField {
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black
    shadow.shadowBlurRadius = 0
    shadow.shadowOffset = .init(width: 5, height: -5)
    let label = NSTextField()
    label.attributedStringValue = NSAttributedString(
      string: "i18n:Installer.VChewingInputMethod".i18n,
      attributes: [
        .font: meshTitleFont,
        .foregroundColor: NSColor.white,
        .shadow: shadow,
      ]
    )
    label.isEditable = false
    label.isSelectable = false
    label.isBordered = false
    label.drawsBackground = false
    return label
  }

  // MARK: - UI Refresh & Alerts

  private func refreshUI() {
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }

      // Update install button title
      let installTitle = self.config.isUpgrading ? "i18n:installer.DO_APP_UPGRADE"
        .i18n : "i18n:installer.ACCEPT_INSTALLATION".i18n
      self.installButton.title = installTitle

      // Update enabled state
      self.installButton.isEnabled = self.config.isCancelButtonEnabled
      self.cancelButton.isEnabled = self.config.isAgreeButtonEnabled

      // Pending sheet
      if self.config.pendingSheetPresenting {
        self.showPendingSheet()
      } else {
        self.hidePendingSheet()
      }

      // Update sheet time label
      if let timeLabel = self.pendingSheetTimeLabel {
        timeLabel.stringValue = "i18n:installer.STOPPING_TIMEOUT_REMAINING".i18n + ": \(self.config.timeRemaining)s"
      }

      legacyAlert: if #available(macOS 13, *), AppInstallerDelegate.shared.isLegacyDistro {
        if !config.isLegacyPackageNoticeEverShown {
          config.isLegacyPackageNoticeEverShown = true
        } else {
          break legacyAlert
        }
        NSSound.beep()
        let alert = NSAlert()
        alert.messageText = "i18n:Installer.PleaseUseMainstreamReleases".i18n
        alert.informativeText =
          "i18n:Installer.LegacyInstallerNotice".i18n
        alert.addButton(withTitle: "i18n:Installer.DownloadMainstreamReleases".i18n)
        alert.addButton(withTitle: "i18n:Installer.ContinueInstallation".i18n)
        alert.addButton(withTitle: "i18n:Installer.QuitInstallation".i18n)
        alert.beginSheetModal(for: self.view.window ?? NSApp.mainWindow ?? NSWindow()) { result in
          switch result {
          case .alertFirstButtonReturn:
            if let url = URL(string: "https://vchewing.github.io/") {
              NSWorkspace.shared.open(url)
            }
            NSApp.terminate(self)
          case .alertSecondButtonReturn: return
          case .alertThirdButtonReturn: NSApp.terminate(self)
          default: NSApp.terminate(self)
          }
        }
        return
      }

      // Alerts：統一由 alertItem 驅動，避免多個 alert 互相覆蓋。
      // 若安裝過程中已直接設定 alertItem（安裝失敗 / 註冊失敗），則直接顯示；
      // 否則將 currentAlertContent 與 adminRenameFailureAlertPaths 轉換成 alertItem。
      if self.config.alertItem == nil,
         let postInstallAlertItem = self.config.currentAlertContent.makeAlertItemIfNeeded(
           paths: self.config.adminRenameFailureAlertPaths
         ) {
        // 將 currentAlertContent 消耗掉（歸零），避免每次 refreshUI 都對同一內容
        // 反覆重建 alertItem（在舊版 macOS 上會造成「安裝成功」提示循環彈出）。
        self.config.currentAlertContent = .nothing
        self.config.alertItem = postInstallAlertItem
      }

      if let alertItem = self.config.alertItem {
        self.showSimpleAlert(
          title: alertItem.title,
          message: alertItem.message,
          buttonTitle: alertItem.buttonTitle
        ) {
          self.config.alertItem = nil
          NSApp.terminateWithDelay()
        }
      }
    }
  }

  private func showSimpleAlert(title: String, message: String, buttonTitle: String, completion: @escaping () -> ()) {
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      // Prevent multiple simultaneous alerts
      guard !self.isPresentingAlert else { return }
      self.isPresentingAlert = true

      let alert = NSAlert()
      alert.messageText = title
      alert.informativeText = message
      alert.addButton(withTitle: buttonTitle)
      alert.beginSheetModal(for: self.view.window ?? NSApp.mainWindow ?? NSWindow()) { _ in
        // reset flag and invoke completion
        self.isPresentingAlert = false
        completion()
      }
    }
  }

  private func showPendingSheet() {
    guard pendingSheetWindow == nil, let parent = view.window else { return }

    let contentRect = NSRect(x: 0, y: 0, width: 407, height: 144)
    let panel = NSPanel(contentRect: contentRect, styleMask: [.titled], backing: .buffered, defer: false)
    panel.title = "i18n:installer.STOPPING_THE_OLD_VERSION".i18n

    let label = NSTextField()
    label.stringValue = "i18n:installer.STOPPING_THE_OLD_VERSION".i18n
    label.alignment = .center
    let timeLabel = NSTextField()
    timeLabel.stringValue = "i18n:installer.STOPPING_TIMEOUT_REMAINING"
      .i18n + ": \(config.timeRemaining)s"
    timeLabel.alignment = .center
    pendingSheetTimeLabel = timeLabel

    let stack = NSStackView(views: [label, timeLabel])
    stack.orientation = .vertical
    stack.alignment = .centerX
    stack.spacing = 6
    stack.edgeInsets = NSEdgeInsets(top: 20, left: 12, bottom: 20, right: 12)
    stack.frame = NSRect(x: 0, y: 0, width: contentRect.width, height: contentRect.height)
    panel.contentView?.addSubview(stack)

    parent.beginSheet(panel, completionHandler: nil)
    pendingSheetWindow = panel
  }

  private func hidePendingSheet() {
    guard let panel = pendingSheetWindow, let parent = view.window else { return }
    parent.endSheet(panel)
    pendingSheetWindow = nil
    pendingSheetTimeLabel = nil
  }
}

// MARK: - InstallerCardView

/// 置中的安裝程式內容卡片：以 CoreGraphics 直接繪製圓角底色與 thick round-rectangle
/// outline，外觀對應 SwiftUI 版的 GroupBox（`.background(underPageBackgroundColor)`＋
/// `.clipShape(RoundedRectangle(16))` 疊於其上）。
private final class InstallerCardView: NSView {
  // MARK: Internal

  /// 外框留白：frame 比可見圓角矩形多出的邊距，讓 outline 得以在 bounds 內繪製
  /// （`draw(_:)` 的輸出會被裁切到視圖 bounds，故外框必須留在界內）。
  static let shadowMargin: CGFloat = 16

  override func draw(_ dirtyRect: NSRect) {
    super.draw(dirtyRect)
    let visibleRect = bounds.insetBy(dx: Self.shadowMargin, dy: Self.shadowMargin)
    let path = NSBezierPath(roundedRect: visibleRect, xRadius: 16, yRadius: 16)
    // thick round-rectangle outline：以比可見卡片大一圈的圓角矩形繪出，邊緣以
    // NSShadow 模糊柔化（shadowColor＝系統 shadowColor@0.3、blur 3）。外框基色為
    // makeOutlineColor()（依底色 brightness 門檻：亮底→純白、暗底→純黑），再以
    // controlBackgroundColor 覆蓋為實心色——皆為 dynamic color、隨外觀自動變化。
    let outlinePath = NSBezierPath(
      roundedRect: visibleRect.insetBy(dx: -10, dy: -10), xRadius: 26, yRadius: 26
    )
    let outlineColor = Self.makeOutlineColor()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.shadowColor.withAlphaComponent(0.3)
    shadow.shadowBlurRadius = 3
    shadow.shadowOffset = .zero
    NSGraphicsContext.saveGraphicsState()
    shadow.set()
    outlineColor.setFill()
    outlinePath.fill()
    NSColor.controlBackgroundColor.setFill()
    outlinePath.fill()
    NSGraphicsContext.restoreGraphicsState()
    // 底色：underPageBackgroundColor（dynamic color，隨 bright／dark 自動變化）。
    NSColor.underPageBackgroundColor.setFill()
    path.fill()
  }

  // MARK: Private

  /// 依底色的 brightness 門檻產生外框基色：亮底→純白、暗底→純黑（brightness-only，
  /// hue／saturation 不變）；實際外框色再由 controlBackgroundColor 覆蓋。
  private static func makeOutlineColor() -> NSColor {
    let background = NSColor.windowBackgroundColor
    guard let rgb = background.usingColorSpace(.deviceRGB) else { return background }
    var hue: CGFloat = 0
    var saturation: CGFloat = 0
    var brightness: CGFloat = 0
    var alpha: CGFloat = 0
    rgb.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
    let adjustedBrightness = brightness > 0.5 ? 1.0 : 0.0
    return NSColor(hue: hue, saturation: saturation, brightness: adjustedBrightness, alpha: alpha)
  }
}

// MARK: - MeshGradientView

/// AppKit 版的「2×2 四角色」color mesh 背景。
/// 顏色與插值方式與 SwiftUI 版安裝程式的 `GradientViewWrapper`（Canvas fallback）
/// 完全一致：以線性色域做雙線性插值、再轉回 sRGB，以 64×64 個小方格繪製。
private final class MeshGradientView: NSView {
  override var isFlipped: Bool { true }

  override func draw(_ dirtyRect: NSRect) {
    super.draw(dirtyRect)
    let steps = 64
    let cellWidth = bounds.width / CGFloat(steps)
    let cellHeight = bounds.height / CGFloat(steps)
    // 四角顏色（sRGB 分量）：左上、右上、左下、右下。
    let c00 = (r: 0.93, g: 0.49, b: 0.21)
    let c10 = (r: 0.31, g: 0.73, b: 0.30)
    let c01 = (r: 0.38, g: 0.58, b: 0.81)
    let c11 = (r: 0.97, g: 0.84, b: 0.02)
    for y in 0 ..< steps {
      for x in 0 ..< steps {
        let u = (Double(x) + 0.5) / Double(steps)
        let v = (Double(y) + 0.5) / Double(steps)
        // 線性色域中的雙線性插值。
        let top = lerp(srgbToLinear(c00), srgbToLinear(c10), t: u)
        let bottom = lerp(srgbToLinear(c01), srgbToLinear(c11), t: u)
        let linear = lerp(top, bottom, t: v)
        let srgb = linearToSrgb(linear)
        NSColor(
          srgbRed: CGFloat(srgb.r), green: CGFloat(srgb.g), blue: CGFloat(srgb.b), alpha: 1
        ).setFill()
        NSRect(
          x: CGFloat(x) * cellWidth,
          y: CGFloat(y) * cellHeight,
          width: cellWidth + 0.5,
          height: cellHeight + 0.5
        ).fill()
      }
    }
  }
}

// MARK: - 色域換算輔助函式

private typealias RGB = (r: Double, g: Double, b: Double)

private func lerp(_ a: RGB, _ b: RGB, t: Double) -> RGB {
  (r: a.r + (b.r - a.r) * t, g: a.g + (b.g - a.g) * t, b: a.b + (b.b - a.b) * t)
}

private func srgbToLinear(_ c: RGB) -> RGB {
  (r: srgbChannelToLinear(c.r), g: srgbChannelToLinear(c.g), b: srgbChannelToLinear(c.b))
}

private func linearToSrgb(_ c: RGB) -> RGB {
  (r: linearChannelToSrgb(c.r), g: linearChannelToSrgb(c.g), b: linearChannelToSrgb(c.b))
}

private func srgbChannelToLinear(_ channel: Double) -> Double {
  if channel <= 0.04045 {
    return channel / 12.92
  } else {
    return pow((channel + 0.055) / 1.055, 2.4)
  }
}

private func linearChannelToSrgb(_ channel: Double) -> Double {
  if channel <= 0.0031308 {
    return channel * 12.92
  } else {
    return 1.055 * pow(channel, 1.0 / 2.4) - 0.055
  }
}

@available(macOS 14.0, *)
#Preview(traits: .fixedLayout(width: 1_000, height: 630)) {
  VwrAppInstaller4Cocoa()
}
