// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import AppKit

extension SettingsPanesCocoa {
  public final class Behavior: NSViewController {
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
              UserDef.kSpecifyShiftBackSpaceKeyBehavior.renderCocoa(
                fixWidth: innerContentWidth,
                prefUITab: .tabBehavior
              )
              UserDef.kSpecifyShiftTabKeyBehavior.renderCocoa(
                fixWidth: innerContentWidth,
                prefUITab: .tabBehavior
              )
              UserDef.kSpecifyCmdOptCtrlEnterBehavior.renderCocoa(
                fixWidth: innerContentWidth,
                prefUITab: .tabBehavior
              )
            }?.boxed()
            NSStackView.buildSection(width: innerContentWidth) {
              UserDef.kSpecifyShiftSpaceKeyBehavior4CandidateWindow.renderCocoa(
                fixWidth: innerContentWidth,
                prefUITab: .tabBehavior
              )
              UserDef.kUseSpaceToCommitHighlightedCandidate4SCPC.renderCocoa(
                fixWidth: innerContentWidth,
                prefUITab: .tabBehavior
              )
            }?.boxed()
            NSStackView.buildSection(width: innerContentWidth) {
              UserDef.kBeepSoundPreference.renderCocoa(
                fixWidth: contentWidth,
                prefUITab: .tabBehavior
              )
            }?.boxed()
            NSView()
          }
          NSTabView.TabPage(title: "Ｂ") {
            NSStackView.buildSection(width: innerContentWidth) {
              UserDef.kUpperCaseLetterKeyBehavior.renderCocoa(
                fixWidth: innerContentWidth,
                prefUITab: .tabBehavior
              )
              UserDef.kNumPadCharInputBehavior.renderCocoa(
                fixWidth: innerContentWidth,
                prefUITab: .tabBehavior
              )
            }?.boxed()
            NSStackView.buildSection(width: innerContentWidth) {
              UserDef.kSpecifyIntonationKeyBehavior.renderCocoa(
                fixWidth: innerContentWidth,
                prefUITab: .tabBehavior
              )
              UserDef.kAcceptLeadingIntonations.renderCocoa(
                fixWidth: innerContentWidth,
                prefUITab: .tabBehavior
              )
            }?.boxed()
            NSStackView.buildSection(width: innerContentWidth) {
              UserDef.kReflectBPMFVSInCompositionBuffer.renderCocoa(
                fixWidth: innerContentWidth,
                prefUITab: .tabBehavior
              )
            }
            NSView()
          }
          NSTabView.TabPage(title: "Ｃ") {
            NSStackView.buildSection(width: innerContentWidth) {
              UserDef.kMixedAlphanumericalEnabled.renderCocoa(
                fixWidth: innerContentWidth,
                prefUITab: .tabBehavior
              )
            }?.boxed()
            NSStackView.buildSection(width: innerContentWidth) {
              UserDef.kSpaceKeyBehaviorAgainstICB.renderCocoa(
                fixWidth: innerContentWidth,
                prefUITab: .tabBehavior
              )
              UserDef.kPreferredRevolverForceLevel.renderCocoa(
                fixWidth: innerContentWidth,
                prefUITab: .tabBehavior
              )
              UserDef.kEscToCleanInputBuffer.renderCocoa(
                fixWidth: innerContentWidth,
                prefUITab: .tabBehavior
              )
              UserDef.kAlsoConfirmAssociatedCandidatesByEnter.renderCocoa(
                fixWidth: innerContentWidth,
                prefUITab: .tabBehavior
              )
            }?.boxed()
            if Date.isTodayTheDate(from: 0_401) {
              NSStackView.buildSection(width: innerContentWidth) {
                UserDef.kShouldNotFartInLieuOfBeep
                  .renderCocoa(
                    fixWidth: innerContentWidth,
                    prefUITab: .tabBehavior
                  ) { renderable in
                    renderable.currentControl?.target = self
                    renderable.currentControl?.action = #selector(self.onFartControlChange(_:))
                  }
              }?.boxed()
            }
            NSView()
          }
          NSTabView.TabPage(title: "Ｄ") {
            NSStackView.buildSection(width: innerContentWidth) {
              UserDef.kBypassNonAppleCapsLockHandling.renderCocoa(
                fixWidth: innerContentWidth,
                prefUITab: .tabBehavior
              )
              UserDef.kShareAlphanumericalModeStatusAcrossClients
                .renderCocoa(
                  fixWidth: innerContentWidth,
                  prefUITab: .tabBehavior
                )
              if #available(macOS 10.15, *) {
                NSStackView.build(.vertical) {
                  UserDef.kTogglingAlphanumericalModeWithLShift
                    .renderCocoa(
                      fixWidth: innerContentWidth,
                      prefUITab: .tabBehavior
                    ) { renderable in
                      renderable.currentControl?.target = self
                      renderable.currentControl?.action = #selector(self.syncShiftKeyUpChecker(_:))
                    }
                  UserDef.kTogglingAlphanumericalModeWithRShift
                    .renderCocoa(
                      fixWidth: innerContentWidth,
                      prefUITab: .tabBehavior
                    ) { renderable in
                      renderable.currentControl?.target = self
                      renderable.currentControl?.action = #selector(self.syncShiftKeyUpChecker(_:))
                    }
                  var strOSReq = " "
                  strOSReq += String(
                    format: "i18n:InfoMessage.FeatureRequiresMacOS:%@".i18n,
                    arguments: ["10.15"]
                  )
                  strOSReq += "\n"
                  strOSReq += "i18n:settings.shiftKeyASCIITogle.description".i18n
                  strOSReq.makeNSLabel(descriptive: true, fixWidth: innerContentWidth)
                }
              }
              UserDef.kShiftEisuToggleOffTogetherWithCapsLock.renderCocoa(
                fixWidth: innerContentWidth,
                prefUITab: .tabBehavior
              )
            }?.boxed()
            NSView()
          }
          NSTabView.TabPage(title: "Ｅ") {
            NSStackView.buildSection(width: innerContentWidth) {
              if #available(macOS 10.14, *) {
                UserDef.kSpecifiedNotifyUIColorScheme.renderCocoa(
                  fixWidth: innerContentWidth,
                  prefUITab: .tabBehavior
                )
              }
              if #available(macOS 12, *) {
                UserDef.kShowNotificationsWhenTogglingCapsLock.renderCocoa(
                  fixWidth: innerContentWidth,
                  prefUITab: .tabBehavior
                )
              }
              if #available(macOS 10.15, *) {
                UserDef.kShowNotificationsWhenTogglingShift.renderCocoa(
                  fixWidth: innerContentWidth,
                  prefUITab: .tabBehavior
                )
              }
              UserDef.kShowNotificationsWhenTogglingEisu.renderCocoa(
                fixWidth: innerContentWidth,
                prefUITab: .tabBehavior
              )
              if #available(macOS 10.13, *) {
                UserDef.kAlwaysShowTooltipTextsHorizontally.renderCocoa(
                  fixWidth: innerContentWidth,
                  prefUITab: .tabBehavior
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
    func syncShiftKeyUpChecker(_: NSControl) {
      print("Syncing ShiftKeyUpChecker configurations.")
      SessionUI.shared.resyncShiftKeyUpCheckerSettings()
    }

    @IBAction
    func onFartControlChange(_: NSControl) {
      let content = "i18n:UserDef.kShouldNotFartInLieuOfBeep.description".i18n
      let alert = NSAlert(error: "i18n:Common.Warning".i18n)
      alert.informativeText = content
      alert.addButton(withTitle: "i18n:Common.Uncheck".i18n)
      if #available(macOS 11, *) {
        alert.buttons.forEach { button in
          button.hasDestructiveAction = true
        }
      }
      alert.addButton(withTitle: "i18n:Common.LeaveItChecked".i18n)
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
