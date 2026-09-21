// (c) 2022 and onwards The vChewing Project (MulanPSL-2.0 License).
// ====================
// This code is released under the SPDX-License-Identifier: `MulanPSL-2.0`.

// 本檔為 SwiftUI 專屬，legacy 倉庫（＝本倉的「子集 ＋ Swift 5.10 Dialect」，砍掉了 SwiftUI）無對位模組可繼承；
// 依「SwiftUI 之任何內容不得裸露於 5.10 可編的路徑上」整段圈進 compiler condition，<6.2 分支不提供替代實作。
#if compiler(>=6.2)

  import SwiftUI

  // MARK: - VwrSettingsPaneBehavior

  @available(macOS 14, *)
  public struct VwrSettingsPaneBehavior: View {
    // MARK: - Main View

    public var body: some View {
      Form {
        Section {
          UserDef.kSpecifiedNotifyUIColorScheme.renderUI()
          UserDef.kShowNotificationsWhenTogglingCapsLock.renderUI()
          UserDef.kShowNotificationsWhenTogglingEisu.renderUI()
          UserDef.kShowNotificationsWhenTogglingShift.renderUI()
          UserDef.kAlwaysShowTooltipTextsHorizontally.renderUI()
            .disabled(Bundle.main.preferredLocalizations[0] == "en")
          UserDef.kShowModeDescriptionOnActivatingServer.renderUI()
          UserDef.kBeepSoundPreference.renderUI()
        }

        Section {
          UserDef.kMixedAlphanumericalEnabled.renderUI()
          // 該二子選項僅在中英混打模式啟用時才有作用；母選項關閉時，其在程式端已被合取吸收，
          // 故不另作 UI 層的「連動停用」（Cocoa 側亦同）。
          UserDef.kMixedAlnumJudgeReadingsBySequentialRawKeyOrder.renderUI()
          UserDef.kEnableLatchedAlnumStateInMixedAlnumMode.renderUI()
        }

        Section {
          UserDef.kSpaceKeyBehaviorAgainstICB.renderUI()
          UserDef.kPreferredRevolverForceLevel.renderUI()
          UserDef.kEscToCleanInputBuffer.renderUI()
          UserDef.kAlsoConfirmAssociatedCandidatesByEnter.renderUI()
          UserDef.kSpecifyShiftBackSpaceKeyBehavior.renderUI()
          UserDef.kSpecifyShiftTabKeyBehavior.renderUI()
            .pickerStyle(RadioGroupPickerStyle())
        }

        Section {
          UserDef.kSpecifyShiftSpaceKeyBehavior4EmptyState.renderUI()
          UserDef.kSpecifyShiftSpaceKeyBehavior4CandidateWindow.renderUI()
          UserDef.kUseSpaceToCommitHighlightedCandidate4SCPC.renderUI()
        }

        Section {
          UserDef.kSpecifyCmdOptCtrlEnterBehavior.renderUI()
          VStack(alignment: .leading) {
            UserDef.kReflectBPMFVSInCompositionBuffer.renderUI()
            if let urlBPMFVS = URL(string: "https://github.com/ButTaiwan/bpmfvs") {
              Link(destination: urlBPMFVS) {
                Text(verbatim: "→ BPMFVS @ GitHub")
                  .controlSize(.small)
                  .multilineTextAlignment(.leading)
                  .frame(maxWidth: .infinity, alignment: .leading)
                  .foregroundStyle(Color.accentColor)
              }
            }
          }
        }

        Section {
          UserDef.kUpperCaseLetterKeyBehavior.renderUI()
          UserDef.kNumPadCharInputBehavior.renderUI()
        }

        Section {
          UserDef.kSpecifyIntonationKeyBehavior.renderUI()
          UserDef.kSuppressTooltipForIntonationKeyOverrideEvents.renderUI()
          UserDef.kAcceptLeadingIntonations.renderUI()
        }

        Section {
          UserDef.kBypassNonAppleCapsLockHandling.renderUI()
          UserDef.kShareAlphanumericalModeStatusAcrossClients.renderUI()
          VStack(alignment: .leading) {
            UserDef.kTogglingAlphanumericalModeWithLShift.renderUI {
              SettingsUIHost.shared.resyncShiftKeyUpCheckerSettings()
            }
            UserDef.kTogglingAlphanumericalModeWithRShift.renderUI {
              SettingsUIHost.shared.resyncShiftKeyUpCheckerSettings()
            }
            Spacer()
            Group {
              Text(" ") +
                Text(String(format: "i18n:InfoMessage.FeatureRequiresMacOS:%@".i18n, "10.15"))
                + Text(CtlSettingsUI.sentenceSeparator)
                + Text("i18n:settings.shiftKeyASCIITogle.description".i18n)
            }.settingsDescription()
          }
          UserDef.kShiftEisuToggleOffTogetherWithCapsLock.renderUI()
        }

        Section {
          UserDef.kFuriousTypingEnabled.renderUI()
        }
      }.formStyled()
        .frame(
          minWidth: CtlSettingsUI.formWidth,
          maxHeight: CtlSettingsUI.contentMaxHeight
        )
    }
  }

  // MARK: - VwrSettingsPaneBehavior_Previews

  @available(macOS 14, *)
  struct VwrSettingsPaneBehavior_Previews: PreviewProvider {
    static var previews: some View {
      VwrSettingsPaneBehavior()
    }
  }

#endif
