// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import AppKit

extension SettingsPanesCocoa {
  public final class Candidates: NSViewController {
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
      NSStackView.build(.vertical) {
        NSView().makeSimpleConstraint(.height, relation: .equal, value: 4)
        NSTabView.build {
          NSTabView.TabPage(title: "Ａ") {
            NSStackView.buildSection(width: innerContentWidth) {
              UserDef.kUseHorizontalCandidateList.render(fixWidth: innerContentWidth)
              UserDef.kCandidateListTextSize.render(fixWidth: innerContentWidth) { renderable in
                renderable.currentControl?.target = self
                renderable.currentControl?.action = #selector(self.candidateFontSizeDidSet(_:))
              }
              UserDef.kCandidateWindowShowOnlyOneLine.render(fixWidth: innerContentWidth)
              UserDef.kAlwaysExpandCandidateWindow.render(fixWidth: innerContentWidth)
              UserDef.kMinCellWidthForHorizontalMatrix.render(fixWidth: innerContentWidth)
            }?.boxed()
            NSView()
          }
          NSTabView.TabPage(title: "Ｂ") {
            NSStackView.buildSection(width: innerContentWidth) {
              UserDef.kCandidateKeys.render(fixWidth: innerContentWidth) { renderable in
                renderable.currentControl?.target = self
                renderable.currentControl?.action = #selector(self.candidateKeysDidSet(_:))
                renderable.currentControl?.alignment = .right
              }
              UserDef.kUseRearCursorMode.render(fixWidth: innerContentWidth)
              UserDef.kCursorPlacementAfterSelectingCandidate.render(fixWidth: innerContentWidth)
            }?.boxed()
            NSStackView.buildSection(width: innerContentWidth) {
              UserDef.kShowCodePointInCandidateUI.render(fixWidth: innerContentWidth)
              UserDef.kShowReverseLookupInCandidateUI.render(fixWidth: innerContentWidth)
              UserDef.kUseFixedCandidateOrderOnSelection.render(fixWidth: innerContentWidth)
            }?.boxed()
            NSView()
          }
          NSTabView.TabPage(title: "Ｃ") {
            NSStackView.buildSection(width: innerContentWidth) {
              UserDef.kUseDynamicCandidateWindowOrigin.render(fixWidth: innerContentWidth)
              UserDef.kDodgeInvalidEdgeCandidateCursorPosition.render(fixWidth: innerContentWidth)
              UserDef.kUseShiftQuestionToCallServiceMenu
                .render(fixWidth: innerContentWidth) { renderable in
                  renderable.currentControl?.target = self
                  renderable.currentControl?
                    .action = #selector(self.performCandidateKeysSanityCheck(_:))
                }
              UserDef.kUseJKtoMoveCompositorCursorInCandidateState
                .render(fixWidth: innerContentWidth) { renderable in
                  renderable.currentControl?.target = self
                  renderable.currentControl?
                    .action = #selector(self.performCandidateKeysSanityCheck(_:))
                }
              UserDef.kUseHLtoMoveCompositorCursorInCandidateState
                .render(fixWidth: innerContentWidth) { renderable in
                  renderable.currentControl?.target = self
                  renderable.currentControl?
                    .action = #selector(self.performCandidateKeysSanityCheck(_:))
                }
            }?.boxed()
            NSStackView.buildSection(width: innerContentWidth) {
              UserDef.kCandidateNarrationToggleType.render(fixWidth: innerContentWidth)
            }?.boxed()
            NSView()
          }
          NSTabView.TabPage(title: "Ｄ") {
            NSStackView.buildSection(width: innerContentWidth) {
              UserDef.kConsolidateContextOnCandidateSelection.render(fixWidth: innerContentWidth)
            }?.boxed()
            NSStackView.buildSection(width: innerContentWidth) {
              UserDef.kEnableMouseScrollingForTDKCandidatesCocoa.render(fixWidth: innerContentWidth)
              UserDef.kRespectClientAccentColor.render(fixWidth: innerContentWidth)
            }?.boxed()
            NSStackView.buildSection(width: innerContentWidth) {
              NSStackView.build(.horizontal) {
                "Where's IMK Candidate Window?".makeNSLabel(fixWidth: innerContentWidth)
                NSView()
                NSButton(
                  verbatim: "...",
                  target: self,
                  action: #selector(whereIsIMKCandidatesWindow(_:))
                )
              }
            }?.boxed()
            NSView()
          }
        }?.makeSimpleConstraint(.width, relation: .equal, value: tabContainerWidth)
        NSView().makeSimpleConstraint(.height, relation: .equal, value: NSFont.systemFontSize)
      }
    }

    @IBAction
    func whereIsIMKCandidatesWindow(_: Any) {
      let window = CtlSettingsCocoa.shared?.window
      let title = "The End of Support for IMK Candidate Window"
      let explanation =
        "1) Only macOS has IMKCandidates. Since it relies on a dedicated ObjC Bridging Header to expose necessary internal APIs to work, it hinders vChewing from completely modularized for multi-platform support.\n\n2) IMKCandidates is buggy. It is not likely to be completely fixed by Apple, and its devs are not allowed to talk about it to non-Apple individuals. That's why we have had enough with IMKCandidates. It is likely the reason why Apple had never used IMKCandidates in their official InputMethodKit sample projects (as of August 2023)."
      window.callAlert(title: title.localized, text: explanation.localized)
    }

    @IBAction
    func performCandidateKeysSanityCheck(_: NSControl) {
      // 利用該變數的 didSet 屬性自糾。
      PrefMgr.shared.candidateKeys = PrefMgr.shared.candidateKeys
    }

    @IBAction
    func candidateKeysDidSet(_ sender: NSComboBox) {
      let keys = sender.stringValue.trimmingCharacters(
        in: .whitespacesAndNewlines
      ).lowercased().deduplicated
      // Start Error Handling.
      guard let errorResult = PrefMgr.shared.validate(candidateKeys: keys) else {
        PrefMgr.shared.candidateKeys = keys
        return
      }
      let alert = NSAlert(error: NSLocalizedString("Invalid Selection Keys.", comment: ""))
      alert.informativeText = errorResult
      IMEApp.buzz()
      if let window = CtlSettingsCocoa.shared?.window {
        alert.beginSheetModal(for: window) { _ in
          sender.stringValue = CandidateKey.defaultKeys
        }
      } else {
        switch alert.runModal() {
        default: sender.stringValue = CandidateKey.defaultKeys
        }
      }
    }

    @IBAction
    func candidateFontSizeDidSet(_: NSControl) {
      print("Candidate Font Size Changed to \(PrefMgr.shared.candidateListTextSize)")
      guard !(12 ... 196).contains(PrefMgr.shared.candidateListTextSize) else { return }
      PrefMgr.shared.candidateListTextSize = max(12, min(PrefMgr.shared.candidateListTextSize, 196))
    }
  }
}

@available(macOS 14.0, *)
#Preview(traits: .fixedLayout(width: 600, height: 768)) {
  SettingsPanesCocoa.Candidates()
}
