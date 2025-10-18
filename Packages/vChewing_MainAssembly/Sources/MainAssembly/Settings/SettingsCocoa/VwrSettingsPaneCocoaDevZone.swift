// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import AppKit

extension SettingsPanesCocoa {
  public class DevZone: NSViewController {
    // MARK: Public

    override public func loadView() {
      view = body ?? .init()
      (view as? NSStackView)?.alignment = .centerX
      view.makeSimpleConstraint(.width, relation: .equal, value: windowWidth)
    }

    // MARK: Internal

    var windowWidth: CGFloat { SettingsPanesCocoa.windowWidth }
    var contentWidth: CGFloat { SettingsPanesCocoa.contentWidth }
    var innerContentWidth: CGFloat { SettingsPanesCocoa.innerContentWidth }
    var tabContainerWidth: CGFloat { SettingsPanesCocoa.tabContainerWidth }
    var contentHalfWidth: CGFloat { SettingsPanesCocoa.contentHalfWidth }

    var body: NSView? {
      NSStackView.build(.vertical, insets: .new(all: 14)) {
        NSStackView.build(.horizontal, insets: .new(all: 0, left: 16, right: 16)) {
          "Warning: This page is for testing future features. \nFeatures listed here may not work as expected."
            .makeNSLabel(fixWidth: contentWidth)
          NSView()
        }
        NSStackView.buildSection(width: contentWidth) {
          UserDef.kSecurityHardenedCompositionBuffer.render(fixWidth: contentWidth)
          UserDef.kAlwaysUsePCBWithElectronBasedClients.render(fixWidth: contentWidth)
          UserDef.kDisableSegmentedThickUnderlineInMarkingModeForManagedClients
            .render(fixWidth: contentWidth)
          UserDef.kCheckAbusersOfSecureEventInputAPI.render(fixWidth: contentWidth)
        }?.boxed()
        NSStackView.build(.horizontal, insets: .new(all: 0, left: 16, right: 16)) {
          "Some previous options are moved to other tabs."
            .makeNSLabel(descriptive: true, fixWidth: contentWidth)
          NSView()
        }
        NSView().makeSimpleConstraint(.height, relation: .equal, value: NSFont.systemFontSize)
      }
    }

    @IBAction
    func sanityCheck(_: NSControl) {}
  }
}

@available(macOS 14.0, *)
#Preview(traits: .fixedLayout(width: 600, height: 768)) {
  SettingsPanesCocoa.DevZone()
}
