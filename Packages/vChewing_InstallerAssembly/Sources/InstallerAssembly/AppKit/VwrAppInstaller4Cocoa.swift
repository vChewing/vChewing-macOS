// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import AppKit

extension VwrAppInstaller4Cocoa {
  public static let copyrightLabel = Bundle.main
    .localizedInfoDictionary?["NSHumanReadableCopyright"] as? String ?? "BAD_COPYRIGHT_LABEL"
  public static let eulaContent = Bundle.main
    .localizedInfoDictionary?["CFEULAContent"] as? String ?? "BAD_EULA_CONTENT"
  public static let eulaContentUpstream = Bundle.main
    .infoDictionary?["CFUpstreamEULAContent"] as? String ?? "BAD_EULA_UPSTREAM"
}

// MARK: - VwrAppInstaller4Cocoa

public final class VwrAppInstaller4Cocoa: NSViewController, InstallerVMProtocol {
  // MARK: Lifecycle

  deinit {
    stopTranslocationTimer()
  }

  // MARK: Public

  override public func loadView() {
    view = body ?? .init()
    (view as? NSStackView)?.alignment = .centerX
    view.makeSimpleConstraint(.width, relation: .equal, value: windowWidth)
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
    didSet { refreshUI() }
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
    -> NSTextField {
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

  // MARK: UI Elements

  private lazy var installButton: NSButton = {
    let b = NSButton(
      "i18n:installer.ACCEPT_INSTALLATION",
      target: self,
      action: #selector(btnInstallAction(_:))
    )
    return b
  }()

  private lazy var cancelButton: NSButton = {
    let b = NSButton(
      "i18n:installer.CANCEL_INSTALLATION",
      target: self,
      action: #selector(btnCancelAction(_:))
    )
    return b
  }()

  private var pendingSheetWindow: NSWindow?
  private var pendingSheetTimeLabel: NSTextField?

  private var isPresentingAlert: Bool = false

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

      if #available(macOS 13, *), AppInstallerDelegate.shared.isLegacyDistro {
        NSSound.beep()
        let alert = NSAlert()
        alert.messageText = "Please use mainstream releases for the current system version.".i18n
        alert.informativeText =
          "The current installer only installs version suitable for macOS 10.9 Mavericks, and it theoreotically works with macOS 10.10 Yosemite - macOS 12 Monterey. Meanwhile, the mainstream releases is made available for most recent macOS release."
            .i18n
        alert.addButton(withTitle: "Download Mainstream Releases".i18n)
        alert.addButton(withTitle: "Continue Installation".i18n)
        alert.addButton(withTitle: "Quit Installation".i18n)
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

      // Alerts
      if self.config.isShowingAlertForFailedInstallation {
        self.showSimpleAlert(
          title: self.alertTitle(for: .installationFailed),
          message: InstallerUIConfig.AlertType.installationFailed.message,
          buttonTitle: "Cancel"
        ) {
          self.config.isShowingAlertForFailedInstallation = false
          NSApp.terminateWithDelay()
        }
      }

      if self.config.isShowingAlertForMissingPostInstall {
        self.showSimpleAlert(
          title: self.alertTitle(for: .missingAfterRegistration),
          message: InstallerUIConfig.AlertType.missingAfterRegistration.message,
          buttonTitle: "Abort"
        ) {
          self.config.isShowingAlertForMissingPostInstall = false
          NSApp.terminateWithDelay()
        }
      }

      if self.config.isShowingPostInstallNotification {
        let type = self.config.currentAlertContent
        let btnTitle = (type == .postInstallWarning) ? "Continue" : "OK"
        self.showSimpleAlert(title: self.alertTitle(for: type), message: type.message, buttonTitle: btnTitle) {
          self.config.isShowingPostInstallNotification = false
          NSApp.terminateWithDelay()
        }
      }
    }
  }

  private func alertTitle(for type: InstallerUIConfig.AlertType) -> String {
    type.titleLocalized
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

@available(macOS 14.0, *)
#Preview(traits: .fixedLayout(width: 533, height: 550)) {
  VwrAppInstaller4Cocoa()
}
