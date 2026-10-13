// (c) 2022 and onwards The vChewing Project (MulanPSL-2.0 License).
// ====================
// This code is released under the SPDX-License-Identifier: `MulanPSL-2.0`.

// 本檔為 SwiftUI 專屬，legacy 倉庫（＝本倉的「子集 ＋ Swift 5.10 Dialect」，砍掉了 SwiftUI）無對位模組可繼承；
// 依「SwiftUI 之任何內容不得裸露於 5.10 可編的路徑上」整段圈進 compiler condition，<6.2 分支不提供替代實作。
#if compiler(>=6.2)

  import SwiftUI

  // MARK: - VwrSettingsPaneKeyboard

  @available(macOS 14, *)
  public struct VwrSettingsPaneKeyboard: View {
    // MARK: Public

    // MARK: - Main View

    public var body: some View {
      Form {
        Section {
          HStack(alignment: .top) {
            Text("i18n:Settings.SectionQuickSetup".i18n)
            Spacer()
            Button {
              PrefMgr.shared.keyboardParser = 0
              basicKeyboardLayout = "com.apple.keylayout.ZhuyinBopomofo"
            } label: {
              Text("↻ㄅ" + " " + "i18n:KeyboardLayout.DachenTraditional".i18n)
            }
            Button {
              PrefMgr.shared.keyboardParser = 1
              basicKeyboardLayout = "com.apple.keylayout.ZhuyinEten"
            } label: {
              Text("↻ㄅ" + " " + "i18n:KeyboardLayout.EtenTraditionalShort".i18n)
            }
            Button {
              PrefMgr.shared.keyboardParser = 100
              basicKeyboardLayout = "com.apple.keylayout.ABC"
            } label: {
              Text("↻Ａ")
            }
          }
          UserDef.kKeyboardParser4Zhuyin.renderUI()
          UserDef.kKeyboardParser4Pinyin.renderUI()
          UserDef.kKeyboardParser4Dualpin.renderUI()
          UserDef.kDualpinEnabledForPinyinTyping.renderUI()
          UserDef.kBasicKeyboardLayout.renderUI()
          UserDef.kAlphanumericalKeyboardLayout.renderUI()
        }
        Section(header: Text("i18n:Settings.SectionKeyboardShortcuts".i18n)) {
          VwrSettingsPaneKeyboard_KeyboardShortcuts()
        }
        Section(header: Text("i18n:Settings.SectionDualpinScheme".i18n)) {
          VStack(alignment: .leading, spacing: NSFont.systemFontSize / 2) {
            Text("i18n:Settings.DualpinScheme.Description".i18n)
              .font(.callout)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
            HStack(alignment: .firstTextBaseline) {
              Button {
                isShowingDualpinSchemaImporter = true
              } label: {
                Text("i18n:Settings.DualpinScheme.Import".i18n)
              }
              Text(dualpinSchemaStatusText)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
              Spacer()
            }
          }
        }
        Section {
          VwrDualpinSchemaEditor()
        } header: {
          Text(DualpinEditorText.sectionTitle)
        }
      }.formStyled()
        .frame(
          minWidth: CtlSettingsUI.formWidth,
          maxHeight: CtlSettingsUI.contentMaxHeight
        )
        .fileImporter(
          isPresented: $isShowingDualpinSchemaImporter,
          allowedContentTypes: [.json],
          allowsMultipleSelection: false
        ) { result in
          switch result {
          case let .success(urls):
            guard let selectedURL = urls.first else { return }
            let outcome = SettingsUIHost.shared.importDualpinSchema(selectedURL)
            dualpinSchemaImportOutcome = outcome
            if case .failure = outcome { IMEApp.buzz() }
          case .failure:
            dualpinSchemaImportOutcome = .failure(.unreadable)
            IMEApp.buzz()
          }
        }
    }

    // MARK: Private

    // MARK: - AppStorage Variables

    @AppStorage(
      wrappedValue: UserDef.kBasicKeyboardLayout.stringDefaultValue,
      UserDef.kBasicKeyboardLayout.rawValue
    )
    private var basicKeyboardLayout: String

    /// 自訂雙拼（Dualpin）方案之 JSON 原文；令匯入區之狀態文案可觀察。
    @AppStorage(
      wrappedValue: UserDef.kDualpinSchemaJSON.stringDefaultValue,
      UserDef.kDualpinSchemaJSON.rawValue
    )
    private var dualpinSchemaJSON: String

    // MARK: - States

    @State
    private var isShowingDualpinSchemaImporter = false
    @State
    private var dualpinSchemaImportOutcome: DualpinImportOutcome?

    // MARK: - 雙拼方案匯入區之狀態文案

    /// 匯入區之狀態文案。
    ///
    /// 本次匯入之結果優先；否則由 `DualpinSchemaStore` 依偏好設定現值推斷。
    /// 傳入 `dualpinSchemaJSON` 是為了讓本視圖隨偏好鍵之變更重繪。
    private var dualpinSchemaStatusText: String {
      DualpinSchemaStore.statusText(
        after: dualpinSchemaImportOutcome,
        schemaJSON: dualpinSchemaJSON
      )
    }
  }

  // MARK: - VwrSettingsPaneKeyboard_KeyboardShortcuts

  @available(macOS 14, *)
  private struct VwrSettingsPaneKeyboard_KeyboardShortcuts: View {
    // MARK: - Main View

    var body: some View {
      HStack(alignment: .top, spacing: NSFont.systemFontSize) {
        VStack(alignment: .leading) {
          UserDef.kUsingHotKeySCPC.renderUI()
          UserDef.kUsingHotKeyAssociates.renderUI()
          UserDef.kUsingHotKeyCNS.renderUI()
          UserDef.kUsingHotKeyKanjiConversionMode.renderUI()
          UserDef.kUsingHotKeyRevLookup.renderUI()
        }
        Divider()
        VStack(alignment: .leading) {
          UserDef.kUsingHotKeyPinyinZhuyinTypingSwitch.renderUI()
          UserDef.kUsingHotKeyHalfWidthPunctuation.renderUI()
          UserDef.kUsingHotKeyCurrencyNumerals.renderUI()
          UserDef.kUsingHotKeyCassette.renderUI()
          UserDef.kUsingHotKeyInputMode.renderUI()
        }
      }
    }
  }

  // MARK: - VwrSettingsPaneKeyboard_Previews

  @available(macOS 14, *)
  struct VwrSettingsPaneKeyboard_Previews: PreviewProvider {
    static var previews: some View {
      VwrSettingsPaneKeyboard()
    }
  }

#endif
