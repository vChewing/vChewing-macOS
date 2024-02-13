// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import AppKit
import Foundation
import Shared

public extension SettingsPanesCocoa {
  class Candidates: NSViewController {
    let windowWidth: CGFloat = 577
    let contentWidth: CGFloat = 512 - 37
    let tabContainerWidth: CGFloat = 512 + 20

    override public func loadView() {
      view = body ?? .init()
      (view as? NSStackView)?.alignment = .centerX
      view.makeSimpleConstraint(.width, relation: .equal, value: windowWidth)
    }

    var body: NSView? {
      NSStackView.build(.vertical) {
        NSView().makeSimpleConstraint(.height, relation: .equal, value: 4)
        NSTabView.build {
          NSTabView.TabPage(title: "Ａ") {
            NSStackView.buildSection(width: contentWidth) {
              UserDef.kUseHorizontalCandidateList.render(fixWidth: contentWidth)
              UserDef.kCandidateListTextSize.render(fixWidth: contentWidth) { renderable in
                renderable.currentControl?.target = self
                renderable.currentControl?.action = #selector(self.candidateFontSizeDidSet(_:))
              }
              UserDef.kCandidateWindowShowOnlyOneLine.render(fixWidth: contentWidth)
              UserDef.kAlwaysExpandCandidateWindow.render(fixWidth: contentWidth)
              UserDef.kRespectClientAccentColor.render(fixWidth: contentWidth)
            }?.boxed()
            NSView()
          }
          NSTabView.TabPage(title: "Ｂ") {
            NSStackView.buildSection(width: contentWidth) {
              UserDef.kCandidateKeys.render(fixWidth: contentWidth) { renderable in
                renderable.currentControl?.target = self
                renderable.currentControl?.action = #selector(self.candidateKeysDidSet(_:))
                renderable.currentControl?.alignment = .right
              }
            }?.boxed()
            NSStackView.buildSection(width: contentWidth) {
              UserDef.kUseRearCursorMode.render(fixWidth: contentWidth)
              UserDef.kMoveCursorAfterSelectingCandidate.render(fixWidth: contentWidth)
              UserDef.kUseDynamicCandidateWindowOrigin.render(fixWidth: contentWidth)
              UserDef.kDodgeInvalidEdgeCandidateCursorPosition.render(fixWidth: contentWidth)
              UserDef.kUseJKtoMoveCompositorCursorInCandidateState
                .render(fixWidth: contentWidth) { renderable in
                  renderable.currentControl?.target = self
                  renderable.currentControl?.action = #selector(self.useJKToMoveBufferCursorDidSet(_:))
                }
            }?.boxed()
            NSView()
          }
          NSTabView.TabPage(title: "Ｃ") {
            NSStackView.buildSection(width: contentWidth) {
              UserDef.kShowReverseLookupInCandidateUI.render(fixWidth: contentWidth)
              UserDef.kUseFixedCandidateOrderOnSelection.render(fixWidth: contentWidth)
              UserDef.kConsolidateContextOnCandidateSelection.render(fixWidth: contentWidth)
            }?.boxed()
            NSStackView.buildSection(width: contentWidth) {
              UserDef.kEnableMouseScrollingForTDKCandidatesCocoa.render(fixWidth: contentWidth)
              NSStackView.build(.horizontal) {
                "Where's IMK Candidate Window?".makeNSLabel(fixWidth: contentWidth)
                NSView()
                NSButton(verbatim: "...", target: self, action: #selector(whereIsIMKCandidatesWindow(_:)))
              }
            }?.boxed()
            NSView()
          }
        }?.makeSimpleConstraint(.width, relation: .equal, value: tabContainerWidth)
        NSView().makeSimpleConstraint(.height, relation: .equal, value: NSFont.systemFontSize)
      }
    }

    @IBAction func whereIsIMKCandidatesWindow(_: Any) {
      let window = NSApp.keyWindow
      let title = "The End of Support for IMK Candidate Window"
      let explanation = "1) Only macOS has IMKCandidates. Since it relies on a dedicated ObjC Bridging Header to expose necessary internal APIs to work, it hinders vChewing from completely modularized for multi-platform support.\n\n2) IMKCandidates is buggy. It is not likely to be completely fixed by Apple, and its devs are not allowed to talk about it to non-Apple individuals. That's why we have had enough with IMKCandidates. It is likely the reason why Apple had never used IMKCandidates in their official InputMethodKit sample projects (as of August 2023)."
      window.callAlert(title: title.localized, text: explanation.localized)
    }

    @IBAction func useJKToMoveBufferCursorDidSet(_: NSControl) {
      // 利用該變數的 didSet 屬性自糾。
      PrefMgr.shared.candidateKeys = PrefMgr.shared.candidateKeys
    }

    @IBAction func candidateKeysDidSet(_ sender: NSComboBox) {
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
      if let window = NSApp.keyWindow {
        alert.beginSheetModal(for: window) { _ in
          sender.stringValue = CandidateKey.defaultKeys
        }
      } else {
        switch alert.runModal() {
        default: sender.stringValue = CandidateKey.defaultKeys
        }
      }
    }

    @IBAction func candidateFontSizeDidSet(_: NSControl) {
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
