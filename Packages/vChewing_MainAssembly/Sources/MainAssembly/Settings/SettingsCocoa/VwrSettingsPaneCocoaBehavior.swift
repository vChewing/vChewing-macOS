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
  class Behavior: NSViewController {
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
              UserDef.kSpecifyShiftBackSpaceKeyBehavior.render(fixWidth: contentWidth)
              UserDef.kSpecifyShiftTabKeyBehavior.render(fixWidth: contentWidth)
              UserDef.kSpecifyShiftSpaceKeyBehavior.render(fixWidth: contentWidth)
            }?.boxed()
            NSStackView.buildSection(width: contentWidth) {
              UserDef.kUpperCaseLetterKeyBehavior.render(fixWidth: contentWidth)
              UserDef.kNumPadCharInputBehavior.render(fixWidth: contentWidth)
            }?.boxed()
            NSStackView.buildSection(width: contentWidth) {
              UserDef.kSpecifyIntonationKeyBehavior.render(fixWidth: contentWidth)
              UserDef.kAcceptLeadingIntonations.render(fixWidth: contentWidth)
            }?.boxed()
            NSView()
          }
          NSTabView.TabPage(title: "Ｂ") {
            NSStackView.buildSection(width: contentWidth) {
              UserDef.kChooseCandidateUsingSpace.render(fixWidth: contentWidth)
              UserDef.kEscToCleanInputBuffer.render(fixWidth: contentWidth)
              UserDef.kAlsoConfirmAssociatedCandidatesByEnter.render(fixWidth: contentWidth)
              UserDef.kUseSpaceToCommitHighlightedSCPCCandidate.render(fixWidth: contentWidth)
            }?.boxed()
            NSStackView.buildSection(width: contentWidth) {
              if #available(macOS 12, *) {
                UserDef.kShowNotificationsWhenTogglingCapsLock.render(fixWidth: contentWidth)
              }
              UserDef.kAlwaysShowTooltipTextsHorizontally.render(fixWidth: contentWidth)
              if Date.isTodayTheDate(from: 0401) {
                UserDef.kShouldNotFartInLieuOfBeep.render { renderable in
                  renderable.currentControl?.target = self
                  renderable.currentControl?.action = #selector(self.onFartControlChange(_:))
                }
              }
            }?.boxed()
            NSView()
          }
          NSTabView.TabPage(title: "Ｃ") {
            NSStackView.buildSection(width: contentWidth) {
              UserDef.kBypassNonAppleCapsLockHandling.render(fixWidth: contentWidth)
              UserDef.kShareAlphanumericalModeStatusAcrossClients.render(fixWidth: contentWidth)
              if #available(macOS 10.15, *) {
                NSStackView.build(.vertical) {
                  UserDef.kTogglingAlphanumericalModeWithLShift.render { renderable in
                    renderable.currentControl?.target = self
                    renderable.currentControl?.action = #selector(self.syncShiftKeyUpChecker(_:))
                  }
                  UserDef.kTogglingAlphanumericalModeWithRShift.render { renderable in
                    renderable.currentControl?.target = self
                    renderable.currentControl?.action = #selector(self.syncShiftKeyUpChecker(_:))
                  }
                  var strOSReq = " "
                  strOSReq += String(
                    format: "This feature requires macOS %@ and above.".localized, arguments: ["10.15"]
                  )
                  strOSReq += "\n"
                  strOSReq += "i18n:settings.shiftKeyASCIITogle.description".localized
                  strOSReq.makeNSLabel(descriptive: true, fixWidth: contentWidth)
                }
              }
              UserDef.kShiftEisuToggleOffTogetherWithCapsLock.render(fixWidth: contentWidth)
            }?.boxed()
            NSView()
          }
        }?.makeSimpleConstraint(.width, relation: .equal, value: tabContainerWidth)
        NSView().makeSimpleConstraint(.height, relation: .equal, value: NSFont.systemFontSize)
      }
    }

    @IBAction func syncShiftKeyUpChecker(_: NSControl) {
      print("Syncing ShiftKeyUpChecker configurations.")
      SessionCtl.theShiftKeyDetector.toggleWithLShift = PrefMgr.shared.togglingAlphanumericalModeWithLShift
      SessionCtl.theShiftKeyDetector.toggleWithRShift = PrefMgr.shared.togglingAlphanumericalModeWithRShift
    }

    @IBAction func onFartControlChange(_: NSControl) {
      let content = String(
        format: NSLocalizedString(
          "You are about to uncheck this fart suppressor. You are responsible for all consequences lead by letting people nearby hear the fart sound come from your computer. We strongly advise against unchecking this in any public circumstance that prohibits NSFW netas.",
          comment: ""
        ))
      let alert = NSAlert(error: NSLocalizedString("Warning", comment: ""))
      alert.informativeText = content
      alert.addButton(withTitle: NSLocalizedString("Uncheck", comment: ""))
      if #available(macOS 11, *) {
        alert.buttons.forEach { button in
          button.hasDestructiveAction = true
        }
      }
      alert.addButton(withTitle: NSLocalizedString("Leave it checked", comment: ""))
      let window = NSApp.keyWindow
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
