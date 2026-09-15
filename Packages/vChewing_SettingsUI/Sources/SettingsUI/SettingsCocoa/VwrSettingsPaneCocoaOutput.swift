// (c) 2022 and onwards The vChewing Project (MulanPSL-2.0 License).
// ====================
// This code is released under the SPDX-License-Identifier: `MulanPSL-2.0`.

import AppKit

// MARK: - SettingsPanesCocoa.Output

extension SettingsPanesCocoa {
  public final class Output: NSViewController {
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
          UserDef.kKanjiConversionPreferences.renderCocoa(
            fixWidth: contentWidth,
            prefUITab: .tabOutput
          )
          UserDef.kInlineDumpPinyinInLieuOfZhuyin.renderCocoa(
            fixWidth: contentWidth,
            prefUITab: .tabOutput
          )
          UserDef.kTrimUnfinishedReadingsOnCommit.renderCocoa(
            fixWidth: contentWidth,
            prefUITab: .tabOutput
          )
          UserDef.kRomanNumeralOutputFormat.renderCocoa(
            fixWidth: contentWidth,
            prefUITab: .tabOutput
          )
        }?.boxed()
        NSStackView.build(.horizontal, insets: .new(all: 0, left: 16, right: 16)) {
          "i18n:Settings.SectionExperimental"
            .makeNSLabel(fixWidth: contentWidth)
          NSView()
        }
        NSStackView.buildSection(width: contentWidth) {
          UserDef.kHardenVerticalPunctuations.renderCocoa(
            fixWidth: contentWidth,
            prefUITab: .tabOutput
          )
        }?.boxed()
        NSView().makeSimpleConstraint(.height, relation: .equal, value: NSFont.systemFontSize)
      }
    }
  }
}

// `#Preview` 是 SwiftUI 的巨集，展開需要 6.2 以上的巨集外掛（`@available` 擋不住展開）；
// 5.10 側編不到它，故整段圈進 compiler condition。
#if compiler(>=6.2)
  @available(macOS 14.0, *)
  #Preview(traits: .fixedLayout(width: 600, height: 768)) {
    SettingsPanesCocoa.Output()
  }
#endif
