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
              UserDef.kUseHorizontalCandidateList.renderCocoa(
                fixWidth: innerContentWidth,
                prefUITab: .tabCandidates
              )
              UserDef.kCandidateListTextSize
                .renderCocoa(
                  fixWidth: innerContentWidth,
                  prefUITab: .tabCandidates
                ) { renderable in
                  renderable.currentControl?.target = self
                  renderable.currentControl?.action = #selector(self.candidateFontSizeDidSet(_:))
                }
              UserDef.kCandidateWindowShowOnlyOneLine.renderCocoa(
                fixWidth: innerContentWidth,
                prefUITab: .tabCandidates
              )
              UserDef.kEnforceSingleLineCandidateWindowLayout4SCPC.renderCocoa(
                fixWidth: innerContentWidth,
                prefUITab: .tabCandidates
              )
              UserDef.kEnableCandidateWindowAnimation.renderCocoa(
                fixWidth: innerContentWidth,
                prefUITab: .tabCandidates
              )
              UserDef.kAlwaysExpandCandidateWindow.renderCocoa(
                fixWidth: innerContentWidth,
                prefUITab: .tabCandidates
              )
              UserDef.kMinCellWidthForHorizontalMatrix.renderCocoa(
                fixWidth: innerContentWidth,
                prefUITab: .tabCandidates
              )
            }?.boxed()
            NSView()
          }
          NSTabView.TabPage(title: "Ｂ") {
            NSStackView.buildSection(width: innerContentWidth) {
              UserDef.kCandidateKeys.renderCocoa(
                fixWidth: innerContentWidth,
                prefUITab: .tabCandidates
              ) { renderable in
                renderable.currentControl?.target = self
                renderable.currentControl?.action = #selector(self.candidateKeysDidSet(_:))
                renderable.currentControl?.alignment = .right
              }
              UserDef.kUseRearCursorMode.renderCocoa(
                fixWidth: innerContentWidth,
                prefUITab: .tabCandidates
              )
              UserDef.kCursorPlacementAfterSelectingCandidate.renderCocoa(
                fixWidth: innerContentWidth,
                prefUITab: .tabCandidates
              )
            }?.boxed()
            NSStackView.buildSection(width: innerContentWidth) {
              UserDef.kShowCodePointInCandidateUI.renderCocoa(
                fixWidth: innerContentWidth,
                prefUITab: .tabCandidates
              )
              UserDef.kShowReverseLookupInCandidateUI.renderCocoa(
                fixWidth: innerContentWidth,
                prefUITab: .tabCandidates
              )
              UserDef.kUseFixedCandidateOrderOnSelection.renderCocoa(
                fixWidth: innerContentWidth,
                prefUITab: .tabCandidates
              )
            }?.boxed()
            NSView()
          }
          NSTabView.TabPage(title: "Ｃ") {
            NSStackView.buildSection(width: innerContentWidth) {
              UserDef.kUseDynamicCandidateWindowOrigin.renderCocoa(
                fixWidth: innerContentWidth,
                prefUITab: .tabCandidates
              )
              UserDef.kDodgeInvalidEdgeCandidateCursorPosition.renderCocoa(
                fixWidth: innerContentWidth,
                prefUITab: .tabCandidates
              )
              UserDef.kCandidateStateJKHLBehavior
                .renderCocoa(
                  fixWidth: innerContentWidth,
                  prefUITab: .tabCandidates
                ) { renderable in
                  renderable.currentControl?.target = self
                  renderable.currentControl?
                    .action = #selector(self.performCandidateKeysSanityCheck(_:))
                }
              UserDef.kUseShiftQuestionToCallServiceMenu
                .renderCocoa(
                  fixWidth: innerContentWidth,
                  prefUITab: .tabCandidates
                ) { renderable in
                  renderable.currentControl?.target = self
                  renderable.currentControl?
                    .action = #selector(self.performCandidateKeysSanityCheck(_:))
                }
            }?.boxed()
            NSStackView.buildSection(width: innerContentWidth) {
              UserDef.kCandidateNarrationToggleType.renderCocoa(
                fixWidth: innerContentWidth,
                prefUITab: .tabCandidates
              )
            }?.boxed()
            NSView()
          }
          NSTabView.TabPage(title: "Ｄ") {
            NSStackView.buildSection(width: innerContentWidth) {
              UserDef.kConsolidateContextOnCandidateSelection.renderCocoa(
                fixWidth: innerContentWidth,
                prefUITab: .tabCandidates
              )
            }?.boxed()
            NSStackView.buildSection(width: innerContentWidth) {
              UserDef.kRespectClientAccentColor.renderCocoa(
                fixWidth: innerContentWidth,
                prefUITab: .tabCandidates
              )
            }?.boxed()
            NSStackView.buildSection(width: innerContentWidth) {
              NSStackView.build(.horizontal) {
                "i18n:Menu.WhereIsIMKCandidateWindow".makeNSLabel(fixWidth: innerContentWidth)
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
      let title = "i18n:Menu.EndOfIMKCandidateWindow".i18n
      let explanation = "i18n:InfoMessage.EndOfIMKCandidatesExplanation".i18n
      window.callAlert(title: title, text: explanation)
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
      let alert = NSAlert(error: "i18n:ErrorMessage.InvalidSelectionKeys".i18n)
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
