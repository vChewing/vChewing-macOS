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
      NSStackView.build(.vertical, insets: .new(all: 14)) {
        NSStackView.buildSection(width: contentWidth) {
          UserDef.kUseRearCursorMode.renderCocoa(
            fixWidth: contentWidth,
            prefUITab: .tabCandidates
          )
          UserDef.kCursorPlacementAfterSelectingCandidate.renderCocoa(
            fixWidth: contentWidth,
            prefUITab: .tabCandidates
          )
          UserDef.kUseDynamicCandidateWindowOrigin.renderCocoa(
            fixWidth: contentWidth,
            prefUITab: .tabCandidates
          )
          UserDef.kDodgeInvalidEdgeCandidateCursorPosition.renderCocoa(
            fixWidth: contentWidth,
            prefUITab: .tabCandidates
          )
          UserDef.kCandidateStateJKHLBehavior
            .renderCocoa(
              fixWidth: contentWidth,
              prefUITab: .tabCandidates
            ) { renderable in
              renderable.currentControl?.target = self
              renderable.currentControl?
                .action = #selector(self.performCandidateKeysSanityCheck(_:))
            }
          UserDef.kUseShiftQuestionToCallServiceMenu
            .renderCocoa(
              fixWidth: contentWidth,
              prefUITab: .tabCandidates
            ) { renderable in
              renderable.currentControl?.target = self
              renderable.currentControl?
                .action = #selector(self.performCandidateKeysSanityCheck(_:))
            }
        }?.boxed()
        NSStackView.buildSection(width: contentWidth) {
          UserDef.kCandidateKeys.renderCocoa(
            fixWidth: contentWidth,
            prefUITab: .tabCandidates
          ) { renderable in
            renderable.currentControl?.target = self
            renderable.currentControl?.action = #selector(self.candidateKeysDidSet(_:))
            renderable.currentControl?.alignment = .right
          }
          UserDef.kUseHorizontalCandidateList.renderCocoa(
            fixWidth: contentWidth,
            prefUITab: .tabCandidates
          )
          UserDef.kCandidateListTextSize
            .renderCocoa(
              fixWidth: contentWidth,
              prefUITab: .tabCandidates
            ) { renderable in
              renderable.currentControl?.target = self
              renderable.currentControl?.action = #selector(self.candidateFontSizeDidSet(_:))
            }
          UserDef.kCandidateWindowShowOnlyOneLine.renderCocoa(
            fixWidth: contentWidth,
            prefUITab: .tabCandidates
          )
          UserDef.kEnforceSingleLineCandidateWindowLayout4SCPC.renderCocoa(
            fixWidth: contentWidth,
            prefUITab: .tabCandidates
          )
          UserDef.kEnableCandidateWindowAnimation.renderCocoa(
            fixWidth: contentWidth,
            prefUITab: .tabCandidates
          )
          UserDef.kAlwaysExpandCandidateWindow.renderCocoa(
            fixWidth: contentWidth,
            prefUITab: .tabCandidates
          )
          UserDef.kMinCellWidthForHorizontalMatrix.renderCocoa(
            fixWidth: contentWidth,
            prefUITab: .tabCandidates
          )
          UserDef.kRespectClientAccentColor.renderCocoa(
            fixWidth: contentWidth,
            prefUITab: .tabCandidates
          )
        }?.boxed()
        NSStackView.buildSection(width: contentWidth) {
          UserDef.kShowCodePointInCandidateUI.renderCocoa(
            fixWidth: contentWidth,
            prefUITab: .tabCandidates
          )
          UserDef.kShowReverseLookupInCandidateUI.renderCocoa(
            fixWidth: contentWidth,
            prefUITab: .tabCandidates
          )
          UserDef.kUseFixedCandidateOrderOnSelection.renderCocoa(
            fixWidth: contentWidth,
            prefUITab: .tabCandidates
          )
          UserDef.kConsolidateContextOnCandidateSelection.renderCocoa(
            fixWidth: contentWidth,
            prefUITab: .tabCandidates
          )
          UserDef.kCandidateNarrationToggleType.renderCocoa(
            fixWidth: contentWidth,
            prefUITab: .tabCandidates
          )
        }?.boxed()
        NSStackView.buildSection(width: contentWidth) {
          UserDef.kPopupCompositionBufferTextSize.renderCocoa(
            fixWidth: contentWidth,
            prefUITab: .tabCandidates
          )
        }?.boxed()
        NSStackView.buildSection(width: contentWidth) {
          NSStackView.build(.horizontal) {
            "i18n:Menu.WhereIsIMKCandidateWindow".makeNSLabel(fixWidth: contentWidth)
            NSView()
            NSButton(
              verbatim: "...",
              target: self,
              action: #selector(whereIsIMKCandidatesWindow(_:))
            )
          }
        }?.boxed()
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
