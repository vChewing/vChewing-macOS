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
    NavigationStack {
      Form {
        VStack(alignment: .leading) {
          Text(
            "\u{2022} "
              + "i18n:Instruction.useMouseWheelToScroll".localized + "\n\u{2022} "
              + "i18n:Help.deleteKeyNote".localized
          )
          .settingsDescription()
          UserDef.kAppleLanguages.bind($appleLanguageTag).render()
        }

        // MARK: (header: Text("Typing Settings:"))

        Section {
          UserDef.kReadingNarrationCoverage.bind(
            $readingNarrationCoverage.didChange {
              SpeechSputnik.shared.refreshStatus()
            }
          ).render()
          UserDef.kAutoCorrectReadingCombination.bind($autoCorrectReadingCombination).render()
          UserDef.kShowHanyuPinyinInCompositionBuffer.bind($showHanyuPinyinInCompositionBuffer)
            .render()
          UserDef.kKeepReadingUponCompositionError.bind($keepReadingUponCompositionError).render()
          UserDef.kClassicHaninKeyboardSymbolModeShortcutEnabled
            .bind($classicHaninKeyboardSymbolModeShortcutEnabled).render()
          UserDef.kUseSCPCTypingMode.bind($useSCPCTypingMode).render()
          if Date.isTodayTheDate(from: 0_401) {
            UserDef.kShouldNotFartInLieuOfBeep.bind(
              $shouldNotFartInLieuOfBeep.didChange { onFartControlChange() }
            ).render()
          }
        }

        // MARK: (header: Text("Misc Settings:"))

        Section {
          HStack {
            UserDef.kCheckUpdateAutomatically.bind($checkUpdateAutomatically).render()
            Divider()
            UserDef.kIsDebugModeEnabled.bind($isDebugModeEnabled).render()
          }
        }
      }.formStyled()
    }
    .frame(
      minWidth: CtlSettingsUI.formWidth,
      maxHeight: CtlSettingsUI.contentMaxHeight
    )
  }

  // MARK: Internal

  @Binding
  var appleLanguageTag: String

  // MARK: Private

  // MARK: - AppStorage Variables

  @AppStorage(wrappedValue: true, UserDef.kAutoCorrectReadingCombination.rawValue)
  private var autoCorrectReadingCombination: Bool

  @AppStorage(wrappedValue: 0, UserDef.kReadingNarrationCoverage.rawValue)
  private var readingNarrationCoverage: Int

  @AppStorage(wrappedValue: false, UserDef.kKeepReadingUponCompositionError.rawValue)
  private var keepReadingUponCompositionError: Bool

  @AppStorage(wrappedValue: false, UserDef.kShowHanyuPinyinInCompositionBuffer.rawValue)
  private var showHanyuPinyinInCompositionBuffer: Bool

  @AppStorage(wrappedValue: false, UserDef.kClassicHaninKeyboardSymbolModeShortcutEnabled.rawValue)
  private var classicHaninKeyboardSymbolModeShortcutEnabled: Bool

  @AppStorage(wrappedValue: false, UserDef.kUseSCPCTypingMode.rawValue)
  private var useSCPCTypingMode: Bool

  @AppStorage(wrappedValue: true, UserDef.kShouldNotFartInLieuOfBeep.rawValue)
  private var shouldNotFartInLieuOfBeep: Bool

  @AppStorage(wrappedValue: false, UserDef.kCheckUpdateAutomatically.rawValue)
  private var checkUpdateAutomatically: Bool

  @AppStorage(wrappedValue: false, UserDef.kIsDebugModeEnabled.rawValue)
  private var isDebugModeEnabled: Bool

  private func onFartControlChange() {
    let content = String(
      format: "i18n:Warning.fartSuppressorUncheck".localized
    )
    let alert = NSAlert(error: "i18n:Common.warning".localized)
    alert.informativeText = content
    alert.addButton(withTitle: "i18n:Common.uncheck".localized)
    alert.buttons.forEach { button in
      button.hasDestructiveAction = true
    }
    alert.addButton(withTitle: "i18n:Instruction.leaveItChecked".localized)
    if let window = CtlSettingsUI.shared?.window, !shouldNotFartInLieuOfBeep {
      shouldNotFartInLieuOfBeep = true
      alert.beginSheetModal(for: window) { result in
        switch result {
        case .alertFirstButtonReturn:
          shouldNotFartInLieuOfBeep = false
        case .alertSecondButtonReturn:
          shouldNotFartInLieuOfBeep = true
        default: break
        }
        IMEApp.buzz()
      }
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
