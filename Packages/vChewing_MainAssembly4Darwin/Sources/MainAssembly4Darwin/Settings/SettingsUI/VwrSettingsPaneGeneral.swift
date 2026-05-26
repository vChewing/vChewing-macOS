// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import SwiftUI

// MARK: - VwrSettingsPaneGeneral

@available(macOS 14, *)
public struct VwrSettingsPaneGeneral: View {
  // MARK: Lifecycle

  public init() {
    _appleLanguageTag = .init(
      get: {
        let loadedValue = (
          UserDefaults.standard
            .array(forKey: UserDef.kAppleLanguages.rawValue) as? [String] ?? ["auto"]
        ).joined()
        let plistValueNotExist = (
          UserDefaults.standard
            .object(forKey: UserDef.kAppleLanguages.rawValue) == nil
        )
        let targetToCheck = (plistValueNotExist || loadedValue.isEmpty) ? "auto" : loadedValue
        return Shared.arrSupportedLocales
          .contains(targetToCheck) ? (plistValueNotExist ? "auto" : loadedValue) : "auto"
      }, set: { newValue in
        var newValue = newValue
        if newValue.isEmpty || newValue == "auto" {
          UserDefaults.standard.removeObject(forKey: UserDef.kAppleLanguages.rawValue)
        }
        if newValue == "auto" { newValue = "" }
        guard PrefMgr.shared.appleLanguages.joined() != newValue else { return }
        if !newValue.isEmpty { PrefMgr.shared.appleLanguages = [newValue] }
        vCLog(forced: true, "vChewing App self-terminated due to UI language change.")
        NSApp.terminate(nil)
      }
    )
  }

  // MARK: Public

  // MARK: - Main View

  public var body: some View {
    Form {
      VStack(alignment: .leading) {
        Text(
          "\u{2022} " + "i18n:InfoMessage.MouseWheelScrollWithCheatSheet".i18n
            + "\n\u{2022} " + "i18n:InfoMessage.DeleteKeyNote".i18n
        )
        .settingsDescription()
        UserDef.kAppleLanguages.bind($appleLanguageTag).render()
      }

      // MARK: (header: Text("Typing Settings:"))

      Section {
        UserDef.kReadingNarrationCoverage.renderUI {
          SpeechSputnik.shared.refreshStatus()
        }
        UserDef.kAutoCorrectReadingCombination.renderUI()
        UserDef.kShowHanyuPinyinInCompositionBuffer.renderUI()
        UserDef.kKeepReadingUponCompositionError.renderUI()
        UserDef.kClassicHaninKeyboardSymbolModeShortcutEnabled.renderUI()
        UserDef.kUseSCPCTypingMode.renderUI()
        if Date.isTodayTheDate(from: 0_401) {
          UserDef.kShouldNotFartInLieuOfBeep.renderUI {
            onFartControlChange()
          }
        }
      }

      // MARK: (header: Text("Misc Settings:"))

      Section {
        HStack {
          UserDef.kCheckUpdateAutomatically.renderUI()
          Divider()
          UserDef.kIsDebugModeEnabled.renderUI()
        }
      }

      // MARK: (header: Text("Quick Setup:"))

      Section {
        HStack {
          Button("i18n:Settings.ApplySCPCPreset.ButtonTitle".i18n) {
            activeAlert = .confirmApplyingSCPCBatchSettings
          }
          Spacer()
        }
      }
    }.formStyled()
      .frame(
        minWidth: CtlSettingsUI.formWidth,
        maxHeight: CtlSettingsUI.contentMaxHeight
      )
      .alert(
        activeAlertTitle,
        isPresented: isShowingAlert
      ) {
        activeAlertButtons
      } message: {
        activeAlertMessage
      }
  }

  // MARK: Internal

  @Binding
  var appleLanguageTag: String

  // MARK: Private

  private enum ActiveAlert {
    case fartWarning
    case confirmApplyingSCPCBatchSettings
    case succeededInApplyingSCPCBatchSettings
  }

  @State
  private var activeAlert: ActiveAlert?

  private var isShowingAlert: Binding<Bool> {
    .init(
      get: { activeAlert != nil },
      set: { if !$0 { activeAlert = nil } }
    )
  }

  private var activeAlertTitle: String {
    switch activeAlert {
    case .fartWarning: return "i18n:Common.Warning".i18n
    case .confirmApplyingSCPCBatchSettings: return "i18n:Settings.ApplySCPCPreset.Confirm.AlertTitle".i18n
    case .succeededInApplyingSCPCBatchSettings: return "i18n:Settings.ApplySCPCPreset.Succeeded.AlertTitle".i18n
    case .none: return ""
    }
  }

  private var activeAlertMessage: Text {
    switch activeAlert {
    case .fartWarning:
      return Text("i18n:UserDef.kShouldNotFartInLieuOfBeep.description".i18n)
    case .confirmApplyingSCPCBatchSettings:
      return Text("i18n:Settings.ApplySCPCPreset.Confirm.AlertMessage".i18n)
    case .succeededInApplyingSCPCBatchSettings:
      return Text("i18n:Settings.ApplySCPCPreset.Succeeded.AlertMessage".i18n)
    case .none:
      return Text(verbatim: "")
    }
  }

  @ViewBuilder
  private var activeAlertButtons: some View {
    switch activeAlert {
    case .fartWarning:
      Button("i18n:Common.Uncheck".i18n, role: .destructive) {
        PrefMgr.shared.shouldNotFartInLieuOfBeep = false
        IMEApp.buzz()
      }
      Button("i18n:Common.LeaveItChecked".i18n, role: .cancel) {
        PrefMgr.shared.shouldNotFartInLieuOfBeep = true
        IMEApp.buzz()
      }
    case .confirmApplyingSCPCBatchSettings:
      Button("i18n:Common.Yes".i18n) {
        applySCPCPreset()
      }
      Button("i18n:Common.No".i18n, role: .cancel) {}
    case .succeededInApplyingSCPCBatchSettings:
      Button("i18n:Common.OK".i18n) {}
    case .none:
      EmptyView()
    }
  }

  private func applySCPCPreset() {
    PrefMgr.shared.useSpaceToCommitHighlightedCandidate4SCPC = false
    if !PrefMgr.shared.useSCPCTypingMode {
      Notifier.notify(
        message: "i18n:UserDef.kUsingHotKeySCPC.shortTitle".i18n + "\n"
          + (
            PrefMgr.shared.useSCPCTypingMode.toggled()
              ? "i18n:NotificationSwitch.On".i18n
              : "i18n:NotificationSwitch.Off".i18n
          )
      )
    }
    // 錯開兩條通知，防止兩條通知重疊到一起。
    asyncOnMain {
      if !PrefMgr.shared.associatedPhrasesEnabled {
        Notifier.notify(
          message: "i18n:UserDef.kUsingHotKeyAssociates.shortTitle".i18n + "\n"
            + (
              PrefMgr.shared.associatedPhrasesEnabled.toggled()
                ? "i18n:NotificationSwitch.On".i18n
                : "i18n:NotificationSwitch.Off".i18n
            )
        )
      }
    }
    activeAlert = .succeededInApplyingSCPCBatchSettings
  }

  private func onFartControlChange() {
    if !PrefMgr.shared.shouldNotFartInLieuOfBeep {
      PrefMgr.shared.shouldNotFartInLieuOfBeep = true
      activeAlert = .fartWarning
      return
    }
    IMEApp.buzz()
  }
}

// MARK: - VwrSettingsPaneGeneral_Previews

@available(macOS 14, *)
struct VwrSettingsPaneGeneral_Previews: PreviewProvider {
  static var previews: some View {
    VwrSettingsPaneGeneral()
  }
}
