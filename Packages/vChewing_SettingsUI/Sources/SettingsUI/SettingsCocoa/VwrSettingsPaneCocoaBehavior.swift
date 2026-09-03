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
      NSStackView.build(.vertical, insets: .new(all: 14)) {
        NSStackView.buildSection(width: contentWidth) {
          if #available(macOS 10.14, *) {
            UserDef.kSpecifiedNotifyUIColorScheme.renderCocoa(
              fixWidth: contentWidth,
              prefUITab: .tabBehavior
            )
          }
          if #available(macOS 12, *) {
            UserDef.kShowNotificationsWhenTogglingCapsLock.renderCocoa(
              fixWidth: contentWidth,
              prefUITab: .tabBehavior
            )
          }
          UserDef.kShowNotificationsWhenTogglingEisu.renderCocoa(
            fixWidth: contentWidth,
            prefUITab: .tabBehavior
          )
          if #available(macOS 10.15, *) {
            UserDef.kShowNotificationsWhenTogglingShift.renderCocoa(
              fixWidth: contentWidth,
              prefUITab: .tabBehavior
            )
          }
          if #available(macOS 10.13, *) {
            UserDef.kAlwaysShowTooltipTextsHorizontally.renderCocoa(
              fixWidth: contentWidth,
              prefUITab: .tabBehavior
            )
          }
          UserDef.kBeepSoundPreference.renderCocoa(
            fixWidth: contentWidth,
            prefUITab: .tabBehavior
          )
        }?.boxed()
        NSStackView.buildSection(width: contentWidth) {
          UserDef.kMixedAlphanumericalEnabled.renderCocoa(
            fixWidth: contentWidth,
            prefUITab: .tabBehavior
          )
        }?.boxed()
        NSStackView.buildSection(width: contentWidth) {
          UserDef.kSpaceKeyBehaviorAgainstICB.renderCocoa(
            fixWidth: contentWidth,
            prefUITab: .tabBehavior
          )
          UserDef.kPreferredRevolverForceLevel.renderCocoa(
            fixWidth: contentWidth,
            prefUITab: .tabBehavior
          )
          UserDef.kEscToCleanInputBuffer.renderCocoa(
            fixWidth: contentWidth,
            prefUITab: .tabBehavior
          )
          UserDef.kAlsoConfirmAssociatedCandidatesByEnter.renderCocoa(
            fixWidth: contentWidth,
            prefUITab: .tabBehavior
          )
          UserDef.kSpecifyShiftBackSpaceKeyBehavior.renderCocoa(
            fixWidth: contentWidth,
            prefUITab: .tabBehavior
          )
          UserDef.kSpecifyShiftTabKeyBehavior.renderCocoa(
            fixWidth: contentWidth,
            prefUITab: .tabBehavior
          )
        }?.boxed()
        NSStackView.buildSection(width: contentWidth) {
          UserDef.kSpecifyShiftSpaceKeyBehavior4CandidateWindow.renderCocoa(
            fixWidth: contentWidth,
            prefUITab: .tabBehavior
          )
          UserDef.kUseSpaceToCommitHighlightedCandidate4SCPC.renderCocoa(
            fixWidth: contentWidth,
            prefUITab: .tabBehavior
          )
        }?.boxed()
        NSStackView.buildSection(width: contentWidth) {
          UserDef.kSpecifyCmdOptCtrlEnterBehavior.renderCocoa(
            fixWidth: contentWidth,
            prefUITab: .tabBehavior
          )
          UserDef.kReflectBPMFVSInCompositionBuffer.renderCocoa(
            fixWidth: contentWidth,
            prefUITab: .tabBehavior
          )
        }?.boxed()
        NSStackView.buildSection(width: contentWidth) {
          UserDef.kUpperCaseLetterKeyBehavior.renderCocoa(
            fixWidth: contentWidth,
            prefUITab: .tabBehavior
          )
          UserDef.kNumPadCharInputBehavior.renderCocoa(
            fixWidth: contentWidth,
            prefUITab: .tabBehavior
          )
        }?.boxed()
        NSStackView.buildSection(width: contentWidth) {
          UserDef.kSpecifyIntonationKeyBehavior.renderCocoa(
            fixWidth: contentWidth,
            prefUITab: .tabBehavior
          )
          UserDef.kAcceptLeadingIntonations.renderCocoa(
            fixWidth: contentWidth,
            prefUITab: .tabBehavior
          )
        }?.boxed()
        NSStackView.buildSection(width: contentWidth) {
          UserDef.kBypassNonAppleCapsLockHandling.renderCocoa(
            fixWidth: contentWidth,
            prefUITab: .tabBehavior
          )
          UserDef.kShareAlphanumericalModeStatusAcrossClients
            .renderCocoa(
              fixWidth: contentWidth,
              prefUITab: .tabBehavior
            )
          if #available(macOS 10.15, *) {
            NSStackView.build(.vertical) {
              UserDef.kTogglingAlphanumericalModeWithLShift
                .renderCocoa(
                  fixWidth: contentWidth,
                  prefUITab: .tabBehavior
                ) { renderable in
                  renderable.currentControl?.target = self
                  renderable.currentControl?.action = #selector(self.syncShiftKeyUpChecker(_:))
                }
              UserDef.kTogglingAlphanumericalModeWithRShift
                .renderCocoa(
                  fixWidth: contentWidth,
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
              strOSReq.makeNSLabel(descriptive: true, fixWidth: contentWidth)
            }
          }
          UserDef.kShiftEisuToggleOffTogetherWithCapsLock.renderCocoa(
            fixWidth: contentWidth,
            prefUITab: .tabBehavior
          )
        }?.boxed()
        NSStackView.buildSection(width: contentWidth) {
          UserDef.kFuriousTypingEnabled.renderCocoa(
            fixWidth: contentWidth,
            prefUITab: .tabBehavior
          )
        }?.boxed()
        NSView().makeSimpleConstraint(.height, relation: .equal, value: NSFont.systemFontSize)
      }
    }

    @IBAction
    func syncShiftKeyUpChecker(_: NSControl) {
      print("Syncing ShiftKeyUpChecker configurations.")
      SettingsUIHost.shared.resyncShiftKeyUpCheckerSettings()
    }
  }
}

@available(macOS 14.0, *)
#Preview(traits: .fixedLayout(width: 600, height: 768)) {
  SettingsPanesCocoa.Behavior()
}
