// (c) 2022 and onwards The vChewing Project (MulanPSL-2.0 License).
// ====================
// This code is released under the SPDX-License-Identifier: `MulanPSL-2.0`.

import Foundation
import IMKSwift

// MARK: Auto parameter fix procedures, executed everytime on InputSession.activateServer().

extension PrefMgr {
  public func fixOddPreferences() {
    fixOddPreferencesCore()
    if #unavailable(macOS 12) {
      showNotificationsWhenTogglingCapsLock = false
    }

    if appleLanguages.isEmpty {
      UserDefaults.current.removeObject(forKey: UserDef.kAppleLanguages.rawValue)
    }
    // 客體黑名單資料類型升級。
    if let clients = UserDefaults.current.object(
      forKey: UserDef.kClientsIMKTextInputIncapable.rawValue
    ) as? [String] {
      UserDefaults.current.removeObject(forKey: UserDef.kClientsIMKTextInputIncapable.rawValue)
      clients.forEach { neta in
        guard !clientsIMKTextInputIncapable.keys.contains(neta) else { return }
        clientsIMKTextInputIncapable[neta] = true
      }
    }

    // 基礎鍵盤排列選項糾錯。
    let matchedResults = TISInputSource.match(identifiers: [
      basicKeyboardLayout,
      alphanumericalKeyboardLayout,
    ])
    if !matchedResults.contains(where: { $0.identifier == basicKeyboardLayout }) {
      basicKeyboardLayout = UserDef.kBasicKeyboardLayout.stringDefaultValue
    }
    if !matchedResults.contains(where: { $0.identifier == alphanumericalKeyboardLayout }) {
      alphanumericalKeyboardLayout = UserDef.kAlphanumericalKeyboardLayout.stringDefaultValue
    }
  }
}

// MARK: - Reconcile push-based side effects after an external prefs import.

extension PrefMgr {
  /// 於「外部來源直接寫入 `UserDefaults`」之後，把 `@AppProperty` setter 才會觸發的推式副作用補上。
  ///
  /// `UserDef` 之匯入繞過 `@AppProperty`，故帶 `didSet` 之偏好一概不會觸發；
  /// 而 IME 行程是長駐的，故此和解不能省。
  public func reconcileAfterExternalPrefsImport() {
    // ① 值域與正規化（其 `candidateKeys = candidateKeys` 之技巧已涵蓋選字鍵之 didSet）。
    fixOddPreferencesCore()
    // ② 逐一自我賦值，以觸發其餘帶 didSet 之偏好的推式同步。
    userPhrasesDatabaseBypassed = userPhrasesDatabaseBypassed
    candidateListTextSize = candidateListTextSize
    popupCompositionBufferTextSize = popupCompositionBufferTextSize
    readingNarrationCoverage = readingNarrationCoverage
    togglingAlphanumericalModeWithLShift = togglingAlphanumericalModeWithLShift
    togglingAlphanumericalModeWithRShift = togglingAlphanumericalModeWithRShift
    cns11643Enabled = cns11643Enabled
    symbolInputEnabled = symbolInputEnabled
    cassetteEnabled = cassetteEnabled
    suppressFactoryUnigramsOfKanaSyllables = suppressFactoryUnigramsOfKanaSyllables
    useSCPCTypingMode = useSCPCTypingMode
    phraseReplacementEnabled = phraseReplacementEnabled
    associatedPhrasesEnabled = associatedPhrasesEnabled
    // ③ 顯式同步：常駐行程雖有 cfprefsd 代理，顯式同步無害且便於測試。
    UserDefaults.current.synchronize()
    // ④ 另有一項推式狀態 `inputHandler.assembler.maxSegLength` 並非即時：
    //    其值於 `initInputHandler()` 時才重推，故須待下一次啟用輸入源時才會生效。
  }
}

// MARK: Print share-safe UserDefaults into a bunch of "defaults write" commands.

extension PrefMgr {
  @discardableResult
  public func dumpShellScriptBackup() -> String? {
    let mirror = Mirror(reflecting: self)
    // swift test 等非 app 環境下 Bundle.main 沒有 bundle identifier；
    // 以 process name 遞補，確保此工具在 CLI／測試環境也能產出內容。
    let bundleIdentifier = Bundle.main.bundleIdentifier ?? ProcessInfo.processInfo.processName
    let strDoubleDashLine = String(String(repeating: "=", count: 70))
    var consoleOutput = ContiguousArray<String>(["#!/bin/sh\n\n"])
    consoleOutput.append("# \(strDoubleDashLine)\n")
    consoleOutput.append("# vChewing Preferences Migration Script\n")
    consoleOutput.append("# - vChewing IME v\(IMEApp.appVersionLabel)\n")
    consoleOutput.append("# \(strDoubleDashLine)\n\n")
    for case let (_, value) in mirror.children {
      // 為了讓接下來的命令抓到客體管理器的內容既存資料：
      let rawCells = "\(value)".replacingOccurrences(of: "String, Bool", with: "String,Bool")
        .components(separatedBy: " ")
      guard rawCells.count >= 4 else { continue }
      let strKeyName = rawCells[1].dropLast(2).dropFirst(1).replacingOccurrences(
        of: "\n",
        with: "\\n"
      )
      guard let theUserDef = UserDef(rawValue: strKeyName) else { continue }
      let strTypeParam = theUserDef.dataType.defaultsCommandTypeName
      // 忽略會被 Sandbox 擋到的選項、以及其他一些雜項。
      let blackList: [UserDef] = [
        .kUserDataFolderSpecified, .kCassettePath, .kAppleLanguages, .kFailureFlagForPOMObservation,
        .kMostRecentInputMode, .kCandidateServiceMenuContents,
      ]
      guard !blackList.contains(theUserDef) else { continue }
      var strValue = rawCells[3].dropLast(1).replacingOccurrences(of: "\n", with: "")
      typeCheck: switch theUserDef.dataType {
      case .dictionary:
        if let valParsed = value as? AppProperty<[String: Bool]> {
          var stack = ContiguousArray<String>()
          valParsed.wrappedValue.forEach { currentPair in
            stack.append("\(currentPair.key) \(currentPair.value) ")
          }
          strValue = stack.joined().replacingOccurrences(of: "\n", with: "\\n")
        } else {
          continue
        }
      case .arrayOfStrings:
        if let valParsed = value as? AppProperty<[String]> {
          strValue = valParsed.wrappedValue.joined(separator: " ")
        } else {
          continue
        }
      default: break typeCheck
      }
      if let metaData = theUserDef.metaData {
        let strDashLine = String(String(repeating: "-", count: 70))
        let texts: [String] = [
          strDashLine, metaData.shortTitle,
          strDashLine, metaData.prompt,
          metaData.popupPrompt, metaData.description, metaData.toolTip,
        ].compactMap { $0 }.map(\.i18n)
        texts.forEach { currentLines in
          currentLines.split(separator: "\n").forEach { currentLine in
            consoleOutput.append("# \(currentLine)\n")
          }
        }
        metaData.options?.sorted(by: { $0.key < $1.key }).forEach { pair in
          consoleOutput.append("# - \(pair.key): \(pair.value.i18n)\n")
        }
      } else {
        consoleOutput.append("# No comments supplied by the engineer.\n")
      }
      consoleOutput
        .append(
          "\ndefaults write \(bundleIdentifier) \(strKeyName) -\(strTypeParam) \(strValue)\n\n"
        )
    }
    return consoleOutput.joined()
  }
}
