// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import AppKit

extension SettingsPanesCocoa {
  public class Output: NSViewController {
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
        NSStackView.buildSection(width: contentWidth) {
          UserDef.kChineseConversionEnabled.render(fixWidth: contentWidth) { renderable in
            renderable.currentControl?.target = self
            renderable.currentControl?.action = #selector(self.sanityCheckKangXi(_:))
          }
          UserDef.kShiftJISShinjitaiOutputEnabled.render(fixWidth: contentWidth) { renderable in
            renderable.currentControl?.target = self
            renderable.currentControl?.action = #selector(self.sanityCheckJIS(_:))
          }
          UserDef.kInlineDumpPinyinInLieuOfZhuyin.render(fixWidth: contentWidth)
          UserDef.kTrimUnfinishedReadingsOnCommit.render(fixWidth: contentWidth)
        }?.boxed()
        NSStackView.buildSection(width: contentWidth) {
          UserDef.kHardenVerticalPunctuations.render(fixWidth: contentWidth)
        }?.boxed()
        NSView().makeSimpleConstraint(.height, relation: .equal, value: NSFont.systemFontSize)
      }
    }

    @IBAction
    func sanityCheckKangXi(_: NSControl) {
      if PrefMgr.shared.chineseConversionEnabled, PrefMgr.shared.shiftJISShinjitaiOutputEnabled {
        PrefMgr.shared.shiftJISShinjitaiOutputEnabled = false
      }
    }

    @IBAction
    func sanityCheckJIS(_: NSControl) {
      if PrefMgr.shared.chineseConversionEnabled, PrefMgr.shared.shiftJISShinjitaiOutputEnabled {
        PrefMgr.shared.chineseConversionEnabled = false
      }
    }
  }
}

@available(macOS 14.0, *)
#Preview(traits: .fixedLayout(width: 600, height: 768)) {
  SettingsPanesCocoa.Output()
}
