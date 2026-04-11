// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import AppKit

extension SettingsPanesCocoa.About {
  public static let copyrightLabel = Bundle.main
    .localizedInfoDictionary?["NSHumanReadableCopyright"] as? String ?? "BAD_COPYRIGHT_LABEL"
  public static let eulaContent = Bundle.main
    .localizedInfoDictionary?["CFEULAContent"] as? String ?? "BAD_EULA_CONTENT"
  public static let eulaContentUpstream = Bundle.main
    .infoDictionary?["CFUpstreamEULAContent"] as? String ?? "BAD_EULA_UPSTREAM"
}

// MARK: - SettingsPanesCocoa.About

extension SettingsPanesCocoa {
  public final class About: NSViewController {
    // MARK: Public

    override public func loadView() {
      view = body ?? .init()
      (view as? NSStackView)?.alignment = .centerX
      view.makeSimpleConstraint(.width, relation: .equal, value: windowWidth)
    }

    // MARK: Internal

    let imgWidth: CGFloat = 63

    var windowWidth: CGFloat { SettingsPanesCocoa.windowWidth }
    var contentWidth: CGFloat { SettingsPanesCocoa.contentWidth }

    var appNameAndVersionString: NSAttributedString {
      let strResult = NSMutableAttributedString(string: "i18n:aboutWindow.APP_NAME".i18n)
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
      let strVersion = NSMutableAttributedString(string: "\n\(versionString)")
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
      NSStackView.build(.vertical, insets: .new(all: 14)) {
        NSStackView.buildSection(width: contentWidth) {
          NSStackView.build(.horizontal) {
            bannerImage
            NSStackView.build(.vertical) {
              appNameAndVersionString.makeNSLabel(fixWidth: contentWidth - imgWidth)
              makeFormattedLabel(
                verbatim: "i18n:aboutWindow.DONATION_MESSAGE".i18n
                  + "\n"
                  + Self.copyrightLabel,
                size: 11,
                isBold: false, fixWidth: contentWidth - imgWidth
              )
              makeFormattedLabel(
                verbatim: "i18n:aboutWindow.DEV_CREW".i18n,
                size: 11,
                isBold: false, fixWidth: contentWidth - imgWidth
              )
              makeFormattedLabel(
                verbatim: "i18n:aboutWindow.LICENSE_TITLE".i18n,
                size: 11,
                isBold: false, fixWidth: contentWidth - imgWidth
              )
              eulaBox
            }
          }
          NSStackView.build(.horizontal) {
            NSStackView.build(.vertical) {
              "i18n:aboutWindow.DISCLAIMER_TEXT".makeNSLabel(
                descriptive: true, fixWidth: contentWidth - 140
              )
              NSView()
            }
            var verticalButtonStackSpacing: CGFloat? = 4
            if #unavailable(macOS 10.10) {
              verticalButtonStackSpacing = nil
            }
            NSStackView.build(.vertical, spacing: verticalButtonStackSpacing, width: 114) {
              NSButton(
                "i18n:aboutWindow.WEBSITE_BUTTON",
                target: self, action: #selector(btnWebSiteAction(_:))
              )
              NSButton(
                "i18n:aboutWindow.BUGREPORT_BUTTON",
                target: self, action: #selector(btnBugReportAction(_:))
              )
              NSView()
            }
          }
        }?.boxed()
      }
    }

    var versionString: String {
      "v\(IMEApp.appMainVersionLabel.joined(separator: " Build ")) - \(IMEApp.appSignedDateLabel)"
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
        .width, relation: .equal, value: contentWidth - imgWidth
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
  }
}

@available(macOS 14.0, *)
#Preview(traits: .fixedLayout(width: 600, height: 768)) {
  SettingsPanesCocoa.About()
}
