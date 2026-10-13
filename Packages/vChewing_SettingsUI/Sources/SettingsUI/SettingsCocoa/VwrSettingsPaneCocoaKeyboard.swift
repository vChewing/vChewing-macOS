// (c) 2022 and onwards The vChewing Project (MulanPSL-2.0 License).
// ====================
// This code is released under the SPDX-License-Identifier: `MulanPSL-2.0`.

import AppKit

// MARK: - SettingsPanesCocoa.Keyboard

extension SettingsPanesCocoa {
  public final class Keyboard: NSViewController {
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
          NSStackView.build(.horizontal) {
            "i18n:Settings.SectionQuickSetup".i18n.makeNSLabel(fixWidth: contentWidth)
            NSView()
            NSButton(
              verbatim: "↻ㄅ" + " " + "i18n:KeyboardLayout.DachenTraditional".i18n,
              target: self,
              action: #selector(quickSetupButtonDachen(_:))
            )
            NSButton(
              verbatim: "↻ㄅ" + " " + "i18n:KeyboardLayout.EtenTraditionalShort".i18n,
              target: self,
              action: #selector(quickSetupButtonEtenTraditional(_:))
            )
            NSButton(
              verbatim: "↻Ａ", target: self,
              action: #selector(quickSetupButtonHanyuPinyin(_:))
            )
          }
          UserDef.kKeyboardParser4Zhuyin.renderCocoa(
            fixWidth: contentWidth,
            prefUITab: .tabKeyboard
          )
          UserDef.kKeyboardParser4Pinyin.renderCocoa(
            fixWidth: contentWidth,
            prefUITab: .tabKeyboard
          )
          UserDef.kKeyboardParser4Dualpin.renderCocoa(
            fixWidth: contentWidth,
            prefUITab: .tabKeyboard
          )
          UserDef.kDualpinEnabledForPinyinTyping.renderCocoa(
            fixWidth: contentWidth,
            prefUITab: .tabKeyboard
          )
          UserDef.kBasicKeyboardLayout.renderCocoa(
            fixWidth: contentWidth,
            prefUITab: .tabKeyboard
          )
          UserDef.kAlphanumericalKeyboardLayout.renderCocoa(
            fixWidth: contentWidth,
            prefUITab: .tabKeyboard
          )
        }?.boxed()
        NSStackView.build(.horizontal, insets: .new(all: 4, left: 16, right: 16)) {
          "i18n:Settings.SectionKeyboardShortcuts".i18n.makeNSLabel(fixWidth: contentWidth)
          NSView()
        }
        NSStackView.buildSection(.horizontal, width: contentWidth) {
          NSStackView.build(.vertical) {
            UserDef.kUsingHotKeySCPC.renderCocoa(
              fixWidth: contentHalfWidth,
              prefUITab: .tabKeyboard
            )
            UserDef.kUsingHotKeyAssociates.renderCocoa(
              fixWidth: contentHalfWidth,
              prefUITab: .tabKeyboard
            )
            UserDef.kUsingHotKeyCNS.renderCocoa(
              fixWidth: contentHalfWidth,
              prefUITab: .tabKeyboard
            )
            UserDef.kUsingHotKeyKanjiConversionMode.renderCocoa(
              fixWidth: contentHalfWidth,
              prefUITab: .tabKeyboard
            )
            UserDef.kUsingHotKeyRevLookup.renderCocoa(
              fixWidth: contentHalfWidth,
              prefUITab: .tabKeyboard
            )
          }
          NSStackView.build(.vertical) {
            UserDef.kUsingHotKeyPinyinZhuyinTypingSwitch.renderCocoa(
              fixWidth: contentHalfWidth,
              prefUITab: .tabKeyboard
            )
            UserDef.kUsingHotKeyHalfWidthPunctuation.renderCocoa(
              fixWidth: contentHalfWidth,
              prefUITab: .tabKeyboard
            )
            UserDef.kUsingHotKeyCurrencyNumerals.renderCocoa(
              fixWidth: contentHalfWidth,
              prefUITab: .tabKeyboard
            )
            UserDef.kUsingHotKeyCassette.renderCocoa(
              fixWidth: contentHalfWidth,
              prefUITab: .tabKeyboard
            )
            UserDef.kUsingHotKeyInputMode.renderCocoa(
              fixWidth: contentHalfWidth,
              prefUITab: .tabKeyboard
            )
          }
        }?.boxed()
        NSStackView.build(.horizontal, insets: .new(all: 4, left: 16, right: 16)) {
          "i18n:Settings.SectionDualpinScheme".i18n.makeNSLabel(fixWidth: contentWidth)
          NSView()
        }
        NSStackView.buildSection(width: contentWidth) {
          NSStackView.build(.vertical) {
            "i18n:Settings.DualpinScheme.Description".i18n.makeNSLabel(fixWidth: contentWidth)
            NSStackView.build(.horizontal) {
              dualpinSchemaImportButton
              NSView()
            }
            dualpinSchemaStatusLabel
          }
        }?.boxed()
        // 比照 SwiftUI 版：編輯器自成一個 Section（標題由窗格給），不再寄生於雙拼方案區之底端。
        NSStackView.build(.horizontal, insets: .new(all: 4, left: 16, right: 16)) {
          DualpinEditorText.sectionTitle.makeNSLabel(localized: false, fixWidth: contentWidth)
          NSView()
        }
        NSStackView.buildSection(width: contentWidth) {
          DualpinSchemaEditorCocoa(width: contentWidth) { [weak self] in
            self?.refreshDualpinSchemaStatus()
          }
        }?.boxed()
        NSView().makeSimpleConstraint(.height, relation: .equal, value: NSFont.systemFontSize)
      }
    }

    @IBAction
    func quickSetupButtonDachen(_: NSControl) {
      PrefMgr.shared.keyboardParser = 0
      PrefMgr.shared.basicKeyboardLayout = "com.apple.keylayout.ZhuyinBopomofo"
    }

    @IBAction
    func quickSetupButtonEtenTraditional(_: NSControl) {
      PrefMgr.shared.keyboardParser = 1
      PrefMgr.shared.basicKeyboardLayout = "com.apple.keylayout.ZhuyinEten"
    }

    @IBAction
    func quickSetupButtonHanyuPinyin(_: NSControl) {
      PrefMgr.shared.keyboardParser = 100
      PrefMgr.shared.basicKeyboardLayout = "com.apple.keylayout.ABC"
    }

    /// 匯入雙拼（Dualpin）自訂方案。比照 DevZone 的 JSON 匯入慣例：同一顆按鈕既可按下開面板
    /// （僅 macOS 10.13 以上），也可直接把 `.json` 檔拽進來（10.12 與更早版本唯一的匯入途徑）。
    @IBAction
    func importDualpinSchema(_: NSControl) {
      // macOS 10.12 與更早版本（ComDlg32 不可用）：於輸入法自身呼叫 NSOpenPanel 會令自身與客體應用
      // 陷入無限停止響應（只能斷電或經 SSH 強殺執行緒），故一律不開面板、改請使用者拽檔進來。
      guard #available(macOS 10.13, *) else {
        SettingsPanesCocoa.warnAboutComDlg32Inavailability()
        return
      }
      let dlgOpenFile = NSOpenPanel()
      dlgOpenFile.title = "i18n:Settings.DualpinScheme.Import".i18n + ":"
      dlgOpenFile.showsResizeIndicator = true
      dlgOpenFile.showsHiddenFiles = true
      dlgOpenFile.canChooseFiles = true
      dlgOpenFile.allowsMultipleSelection = false
      dlgOpenFile.canChooseDirectories = false
      let allowedExtensions = ["json"]
      if #unavailable(macOS 11) {
        dlgOpenFile.allowedFileTypes = allowedExtensions
      } else {
        dlgOpenFile.allowedContentTypes = allowedExtensions.compactMap {
          .init(filenameExtension: $0)
        }
      }

      let window = CtlSettingsCocoa.shared?.window
      dlgOpenFile.beginSheetModal(at: window) { [weak self] result in
        guard result == NSApplication.ModalResponse.OK, let url = dlgOpenFile.url else { return }
        self?.handleDualpinSchemaImport(from: url)
      }
    }

    // MARK: Private

    /// 匯入鈕。`NSFileDragRetrieverButton` 比照 DevZone 之 JSON 匯入鈕：按下走 `importDualpinSchema`，
    /// 拽入 `.json` 檔則直接交給 `handleDualpinSchemaImport(from:)`，且自帶 Aqua（`.rounded`）bezel 風格。
    private lazy var dualpinSchemaImportButton: NSFileDragRetrieverButton = {
      let result = NSFileDragRetrieverButton()
      result.title = "i18n:Settings.DualpinScheme.Import".i18n
      result.target = self
      result.allowedTypes = ["json"]
      result.action = #selector(importDualpinSchema(_:))
      result.postDragHandler = { [weak self] url in
        self?.handleDualpinSchemaImport(from: url)
      }
      return result
    }()

    /// 匯入區之狀態列。就地更新，故需保留其參照。
    private lazy var dualpinSchemaStatusLabel: NSLabelView = {
      let result = dualpinSchemaStatusText.makeNSLabel(fixWidth: contentWidth)
      // `secondaryLabelColor` 自 macOS 10.10 起才有；10.9 退回 `.gray`。
      if #available(macOS 10.10, *) {
        result.textColor = .secondaryLabelColor
      } else {
        result.textColor = .gray
      }
      return result
    }()

    private var dualpinSchemaImportOutcome: DualpinImportOutcome?

    private var dualpinSchemaStatusText: String {
      DualpinSchemaStore.statusText(
        after: dualpinSchemaImportOutcome,
        schemaJSON: PrefMgr.shared.dualpinSchemaJSON
      )
    }

    private func handleDualpinSchemaImport(from url: URL) {
      let outcome = SettingsUIHost.shared.importDualpinSchema(url)
      dualpinSchemaImportOutcome = outcome
      dualpinSchemaStatusLabel.attributedStringValue = NSAttributedString(
        string: dualpinSchemaStatusText
      )
      if case .failure = outcome { IMEApp.buzz() }
    }

    /// 供方案編輯器於儲存後重繪本區之狀態文案。
    private func refreshDualpinSchemaStatus() {
      dualpinSchemaImportOutcome = nil
      dualpinSchemaStatusLabel.attributedStringValue = NSAttributedString(
        string: dualpinSchemaStatusText
      )
    }
  }
}

// `#Preview` 是 SwiftUI 的巨集，展開需要 6.2 以上的巨集外掛（`@available` 擋不住展開）；
// 5.10 側編不到它，故整段圈進 compiler condition。
#if compiler(>=6.2)
  @available(macOS 14.0, *)
  #Preview(traits: .fixedLayout(width: 600, height: 768)) {
    SettingsPanesCocoa.Keyboard()
  }
#endif
