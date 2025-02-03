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

extension SettingsPanesCocoa {
  public class Behavior: NSViewController {
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
              UserDef.kSpecifyShiftBackSpaceKeyBehavior.render(fixWidth: innerContentWidth)
              UserDef.kSpecifyShiftTabKeyBehavior.render(fixWidth: innerContentWidth)
              UserDef.kSpecifyShiftSpaceKeyBehavior.render(fixWidth: innerContentWidth)
              UserDef.kSpecifyCmdOptCtrlEnterBehavior.render(fixWidth: innerContentWidth)
            }?.boxed()
            NSStackView.buildSection(width: innerContentWidth) {
              UserDef.kBeepSoundPreference.render(fixWidth: contentWidth)
            }?.boxed()
            NSView()
          }
          NSTabView.TabPage(title: "Ｂ") {
            NSStackView.buildSection(width: innerContentWidth) {
              UserDef.kUpperCaseLetterKeyBehavior.render(fixWidth: innerContentWidth)
              UserDef.kNumPadCharInputBehavior.render(fixWidth: innerContentWidth)
            }?.boxed()
            NSStackView.buildSection(width: innerContentWidth) {
              UserDef.kSpecifyIntonationKeyBehavior.render(fixWidth: innerContentWidth)
              UserDef.kAcceptLeadingIntonations.render(fixWidth: innerContentWidth)
            }?.boxed()
            NSView()
          }
          NSTabView.TabPage(title: "Ｃ") {
            NSStackView.buildSection(width: innerContentWidth) {
              UserDef.kChooseCandidateUsingSpace.render(fixWidth: innerContentWidth)
              UserDef.kEscToCleanInputBuffer.render(fixWidth: innerContentWidth)
              UserDef.kAlsoConfirmAssociatedCandidatesByEnter.render(fixWidth: innerContentWidth)
              UserDef.kUseSpaceToCommitHighlightedSCPCCandidate.render(fixWidth: innerContentWidth)
            }?.boxed()
            if #available(macOS 10.14, *) {
              NSStackView.buildSection(width: innerContentWidth) {
                if #available(macOS 12, *) {
                  UserDef.kShowNotificationsWhenTogglingCapsLock.render(fixWidth: innerContentWidth)
                }
                UserDef.kAlwaysShowTooltipTextsHorizontally.render(fixWidth: innerContentWidth)
              }?.boxed()
            }
            if Date.isTodayTheDate(from: 0401) {
              NSStackView.buildSection(width: innerContentWidth) {
                UserDef.kShouldNotFartInLieuOfBeep
                  .render(fixWidth: innerContentWidth) { renderable in
                    renderable.currentControl?.target = self
                    renderable.currentControl?.action = #selector(self.onFartControlChange(_:))
                  }
              }?.boxed()
            }
            NSView()
          }
          NSTabView.TabPage(title: "Ｄ") {
            NSStackView.buildSection(width: innerContentWidth) {
              UserDef.kBypassNonAppleCapsLockHandling.render(fixWidth: innerContentWidth)
              UserDef.kShareAlphanumericalModeStatusAcrossClients
                .render(fixWidth: innerContentWidth)
              if #available(macOS 10.15, *) {
                NSStackView.build(.vertical) {
                  UserDef.kTogglingAlphanumericalModeWithLShift
                    .render(fixWidth: innerContentWidth) { renderable in
                      renderable.currentControl?.target = self
                      renderable.currentControl?.action = #selector(self.syncShiftKeyUpChecker(_:))
                    }
                  UserDef.kTogglingAlphanumericalModeWithRShift
                    .render(fixWidth: innerContentWidth) { renderable in
                      renderable.currentControl?.target = self
                      renderable.currentControl?.action = #selector(self.syncShiftKeyUpChecker(_:))
                    }
                  var strOSReq = " "
                  strOSReq += String(
                    format: "This feature requires macOS %@ and above.".localized,
                    arguments: ["10.15"]
                  )
                  strOSReq += "\n"
                  strOSReq += "i18n:settings.shiftKeyASCIITogle.description".localized
                  strOSReq.makeNSLabel(descriptive: true, fixWidth: innerContentWidth)
                }
              }
              UserDef.kShiftEisuToggleOffTogetherWithCapsLock.render(fixWidth: innerContentWidth)
            }?.boxed()
            NSView()
          }
        }?.makeSimpleConstraint(.width, relation: .equal, value: tabContainerWidth)
        NSView().makeSimpleConstraint(.height, relation: .equal, value: NSFont.systemFontSize)
      }
    }

    @IBAction
    func syncShiftKeyUpChecker(_: NSControl) {
      print("Syncing ShiftKeyUpChecker configurations.")
      InputSession.theShiftKeyDetector.toggleWithLShift = PrefMgr.shared
        .togglingAlphanumericalModeWithLShift
      InputSession.theShiftKeyDetector.toggleWithRShift = PrefMgr.shared
        .togglingAlphanumericalModeWithRShift
    }

    @IBAction
    func onFartControlChange(_: NSControl) {
      let content = String(
        format: NSLocalizedString(
          "You are about to uncheck this fart suppressor. You are responsible for all consequences lead by letting people nearby hear the fart sound come from your computer. We strongly advise against unchecking this in any public circumstance that prohibits NSFW netas.",
          comment: ""
        )
      )
      let alert = NSAlert(error: NSLocalizedString("Warning", comment: ""))
      alert.informativeText = content
      alert.addButton(withTitle: NSLocalizedString("Uncheck", comment: ""))
      if #available(macOS 11, *) {
        alert.buttons.forEach { button in
          button.hasDestructiveAction = true
        }
      }
      alert.addButton(withTitle: NSLocalizedString("Leave it checked", comment: ""))
      let window = CtlSettingsCocoa.shared?.window
      if !PrefMgr.shared.shouldNotFartInLieuOfBeep {
        PrefMgr.shared.shouldNotFartInLieuOfBeep = true
        alert.beginSheetModal(at: window) { result in
          switch result {
          case .alertFirstButtonReturn:
            PrefMgr.shared.shouldNotFartInLieuOfBeep = false
          case .alertSecondButtonReturn:
            PrefMgr.shared.shouldNotFartInLieuOfBeep = true
          default: break
          }
          IMEApp.buzz()
        }
        return
      }
      IMEApp.buzz()
    }
  }
}

@available(macOS 14.0, *)
#Preview(traits: .fixedLayout(width: 600, height: 768)) {
  SettingsPanesCocoa.Behavior()
}
