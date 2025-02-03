// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import InputMethodKit
import SwiftExtension

// MARK: Guarded Method for Validating Candidate Keys.

extension PrefMgr {
  public func validate(candidateKeys: String) -> String? {
    var excluded = ""
    if useJKtoMoveCompositorCursorInCandidateState { excluded.append("jk") }
    if useHLtoMoveCompositorCursorInCandidateState { excluded.append("hl") }
    if useShiftQuestionToCallServiceMenu { excluded.append("?") }
    excluded.append(IMEApp.isKeyboardJIS ? "_" : "`~")
    return CandidateKey.validate(keys: candidateKeys, excluding: excluded)
  }
}

// MARK: Auto parameter fix procedures, executed everytime on InputSession.activateServer().

extension PrefMgr {
  public func fixOddPreferences() {
    if #unavailable(macOS 12) {
      showNotificationsWhenTogglingCapsLock = false
    }
    if appleLanguages.isEmpty {
      UserDefaults.current.removeObject(forKey: UserDef.kAppleLanguages.rawValue)
    }
    // 自動糾正選字鍵 (利用其 didSet 特性)
    candidateKeys = candidateKeys
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
    // 注拼槽注音排列選項糾錯。
    if KeyboardParser(rawValue: keyboardParser) == nil {
      keyboardParser = 0
    }
    // 基礎鍵盤排列選項糾錯。
    let matchedResults = TISInputSource.match(identifiers: [
      basicKeyboardLayout,
      alphanumericalKeyboardLayout,
    ])
    if !matchedResults.contains(where: { $0.identifier == basicKeyboardLayout }) {
      basicKeyboardLayout = Self.kDefaultBasicKeyboardLayout
    }
    if !matchedResults.contains(where: { $0.identifier == alphanumericalKeyboardLayout }) {
      alphanumericalKeyboardLayout = Self.kDefaultAlphanumericalKeyboardLayout
    }
    // 其它多元選項參數自動糾錯。
    if ![0, 1, 2].contains(specifyIntonationKeyBehavior) {
      specifyIntonationKeyBehavior = 0
    }
    if ![0, 1, 2].contains(specifyShiftBackSpaceKeyBehavior) {
      specifyShiftBackSpaceKeyBehavior = 0
    }
    if ![0, 1, 2, 3, 4].contains(upperCaseLetterKeyBehavior) {
      upperCaseLetterKeyBehavior = 0
    }
    if ![0, 1, 2].contains(readingNarrationCoverage) {
      readingNarrationCoverage = 0
    }
    if ![0, 1, 2, 3].contains(specifyCmdOptCtrlEnterBehavior) {
      specifyCmdOptCtrlEnterBehavior = 0
    }
    if ![0, 1, 2].contains(beepSoundPreference) {
      beepSoundPreference = 2
    }
  }
}

// MARK: Print share-safe UserDefaults into a bunch of "defaults write" commands.

extension PrefMgr {
  @discardableResult
  public func dumpShellScriptBackup() -> String? {
    let mirror = Mirror(reflecting: self)
    guard let bundleIdentifier = Bundle.main.bundleIdentifier else { return nil }
    let strDoubleDashLine = String(String(repeating: "=", count: 70))
    let consoleOutput = NSMutableString(string: "#!/bin/sh\n\n")
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
      var strTypeParam = String(describing: theUserDef.dataType)
      // 忽略會被 Sandbox 擋到的選項、以及其他一些雜項。
      let blackList: [UserDef] = [
        .kUserDataFolderSpecified, .kCassettePath, .kAppleLanguages, .kFailureFlagForUOMObservation,
        .kMostRecentInputMode,
      ]
      guard !blackList.contains(theUserDef) else { continue }
      var strValue = rawCells[3].dropLast(1).replacingOccurrences(of: "\n", with: "")
      typeCheck: switch theUserDef.dataType {
      case .double: strTypeParam = strTypeParam.replacingOccurrences(of: "double", with: "float")
      case .dictionary:
        if let valParsed = value as? AppProperty<[String: Bool]> {
          strTypeParam = strTypeParam.replacingOccurrences(of: "ionary", with: "")
          let stack = NSMutableString()
          valParsed.wrappedValue.forEach { currentPair in
            stack.append("\(currentPair.key) \(currentPair.value) ")
          }
          strValue = stack.replacingOccurrences(of: "\n", with: "\\n")
        } else {
          continue
        }
      case .array:
        if let valParsed = value as? AppProperty<[String]> {
          strValue = valParsed.wrappedValue.joined(separator: " ")
        } else {
          continue
        }
      case .other: continue // 忽略對終端機單行輸入不友好的選項。
      default: break typeCheck
      }
      if let metaData = theUserDef.metaData {
        let strDashLine = String(String(repeating: "-", count: 70))
        let texts: [String] = [
          strDashLine, metaData.shortTitle,
          strDashLine, metaData.prompt,
          metaData.popupPrompt, metaData.description, metaData.toolTip,
        ].compactMap { $0 }.map(\.localized)
        texts.forEach { currentLines in
          currentLines.split(separator: "\n").forEach { currentLine in
            consoleOutput.append("# \(currentLine)\n")
          }
        }
        metaData.options?.sorted(by: { $0.key < $1.key }).forEach { pair in
          consoleOutput.append("# - \(pair.key): \(pair.value.localized)\n")
        }
      } else {
        consoleOutput.append("# No comments supplied by the engineer.\n")
      }
      consoleOutput
        .append(
          "\ndefaults write \(bundleIdentifier) \(strKeyName) -\(strTypeParam) \(strValue)\n\n"
        )
    }
    return consoleOutput.description
  }
}
