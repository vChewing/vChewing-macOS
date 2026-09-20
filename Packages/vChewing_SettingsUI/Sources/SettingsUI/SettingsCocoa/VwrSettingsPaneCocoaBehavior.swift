// (c) 2022 and onwards The vChewing Project (MulanPSL-2.0 License).
// ====================
// This code is released under the SPDX-License-Identifier: `MulanPSL-2.0`.

import AppKit

// MARK: - SettingsPanesCocoa.Behavior

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
          UserDef.kShowModeDescriptionOnActivatingServer.renderCocoa(
            fixWidth: contentWidth,
            prefUITab: .tabBehavior
          )
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
          UserDef.kEnableLatchedAlnumStateInMixedAlnumMode.renderCocoa(
            fixWidth: contentWidth,
            prefUITab: .tabBehavior
          )
          // 為何此處**不**作「母關則子禁用」（而 SwiftUI 側有作）：
          // AppKit 不像 SwiftUI 那樣有 Observation-based 的 enabling／disabling，
          // 要做就得另掛 UserDefaults 的變更觀察、再遞迴走訪子列之 NSView 樹設 isEnabled——
          // 為單一選項引入一套機制並不划算；且非法態（母關子開）在程式端已被合取吸收
          // （`isLatchedAlnumStateEnabled`＝兩開關之 AND），故其為純外觀問題。
          // 所需之前提已寫進該選項之 description（「需先啟用上方選項」），兩側面板皆適用。
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
          UserDef.kSpecifyShiftSpaceKeyBehavior4EmptyState.renderCocoa(
            fixWidth: contentWidth,
            prefUITab: .tabBehavior
          )
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
          UserDef.kSuppressTooltipForIntonationKeyOverrideEvents.renderCocoa(
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

// `#Preview` 是 SwiftUI 的巨集，展開需要 6.2 以上的巨集外掛（`@available` 擋不住展開）；
// 5.10 側編不到它，故整段圈進 compiler condition。
#if compiler(>=6.2)
  @available(macOS 14.0, *)
  #Preview(traits: .fixedLayout(width: 600, height: 768)) {
    SettingsPanesCocoa.Behavior()
  }
#endif
