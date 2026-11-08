// (c) 2022 and onwards The vChewing Project (MulanPSL-2.0 License).
// ====================
// This code is released under the SPDX-License-Identifier: `MulanPSL-2.0`.

import Foundation

// MARK: - Implements Conforming to Phrase Editor Delegate Protocol

extension LXMgr: PhraseEditorDelegate {
  public var currentInputMode: Shared.InputMode { IMEApp.currentInputMode }

  public var isCassetteModeEnabledInLM: Bool {
    get {
      IMEApp.currentInputMode.lexicon.config.isCassetteEnabled
    }
    set {
      Shared.InputMode.allCases.forEach {
        $0.lexicon.setOptions { config in
          config.isCassetteEnabled = newValue
        }
      }
    }
  }

  public func openPhraseFile(
    mode: Shared.InputMode,
    type: LXAssembly.ReplaceableUserDataType,
    using app: FileOpenMethod
  ) {
    Self.openPhraseFile(fromURL: Self.userDictDataURL(mode: mode, type: type), using: app)
  }

  public func consolidate(text strProcessed: inout String, pragma shouldCheckPragma: Bool) {
    LXAssembly.LXConsolidator.consolidate(text: &strProcessed, pragma: shouldCheckPragma)
  }

  public func retrieveData(
    mode: Shared.InputMode,
    type: LXAssembly.ReplaceableUserDataType
  )
    -> String {
    Self.retrieveData(mode: mode, type: type)
  }

  public static func retrieveData(
    mode: Shared.InputMode,
    type: LXAssembly.ReplaceableUserDataType
  )
    -> String {
    vCLog("Retrieving data. Mode: \(mode.localizedDescription), type: \(type.localizedDescription)")
    let theURL = Self.userDictDataURL(mode: mode, type: type)
    do {
      return try .init(contentsOf: theURL, encoding: .utf8)
    } catch {
      vCLog("Error reading: \(theURL.absoluteString)")
      return ""
    }
  }

  public func saveData(
    mode: Shared.InputMode,
    type: LXAssembly.ReplaceableUserDataType,
    data: String
  )
    -> String {
    Self.saveData(mode: mode, type: type, data: data)
  }

  @discardableResult
  public static func saveData(
    mode: Shared.InputMode, type: LXAssembly.ReplaceableUserDataType, data: String
  )
    -> String {
    LXAssembly.withFileHandleQueueSync {
      let theURL = Self.userDictDataURL(mode: mode, type: type)
      do {
        try data.write(to: theURL, atomically: true, encoding: .utf8)
        Self.loadUserPhrasesData(type: type)
      } catch {
        vCLog("Failed to save current database to: \(theURL.absoluteString)")
      }
    }
    return data
  }

  public func tagOverrides(in strProcessed: inout String, mode: Shared.InputMode) {
    performSyncTaskBypassingCassetteMode {
      strProcessed = Self.applyOverrideTags(to: strProcessed) { value, keyArray in
        Self.checkIfPhrasePairExists(
          userPhrase: value, mode: mode, keyArray: keyArray,
          factoryDictionaryOnly: true,
          cassetteModeAlreadyBypassed: true
        )
      }
    }
  }

  /// 逐列補上 `#𝙾𝚟𝚎𝚛𝚛𝚒𝚍𝚎` 標記——「整理」路徑之純函式部分，配對查詢以閉包注入。
  ///
  /// 三條規矩：① 帶 `#NGRAM` 之列**原樣放行**（不判配對、不追加標記）——該標記之語義是
  /// 「此（值，讀音）原廠已有」，與 n-gram 列無關；② **兩格以下之列原樣保留**——整理只該
  /// 正規化格式、不該刪內容（舊制會把這類列連同其斷行一併丟棄）；③ 其餘照舊。
  static func applyOverrideTags(
    to text: String,
    isFactoryPairExisting: (_ value: String, _ keyArray: [String]) -> Bool
  )
    -> String {
    var outputStack: ContiguousArray<String> = .init()
    for currentLine in text.split(separator: "\n") {
      let arr = currentLine.split(separator: " ")
      guard arr.count >= 2, !isNGramRow(currentLine) else {
        outputStack.append(currentLine.description)
        outputStack.append("\n")
        continue
      }
      let exists = isFactoryPairExisting(
        arr[0].description,
        arr[1].split(separator: "-").map(\.description)
      )
      outputStack.append(currentLine.description)
      let replace = !currentLine.contains(" #𝙾𝚟𝚎𝚛𝚛𝚒𝚍𝚎") && exists
      if replace { outputStack.append(" #𝙾𝚟𝚎𝚛𝚛𝚒𝚍𝚎") }
      outputStack.append("\n")
    }
    return outputStack.joined()
  }

  /// 該列是否為 n-gram 列：任一 `#` 標籤格以 ASCII `NGRAM`（不分大小寫）起首即算。
  static func isNGramRow(_ line: Substring) -> Bool {
    for cell in line.split(separator: " ") where cell.hasPrefix("#") {
      let body = cell.dropFirst()
      guard body.count >= 5 else { continue }
      if body.prefix(5).lowercased() == "ngram" { return true }
    }
    return false
  }

  public func performAsyncTaskBypassingCassetteMode<T>(
    _ task: @escaping (@escaping () -> ()) throws -> T
  ) rethrows
    -> T {
    if !PrefMgr.shared.cassetteEnabled {
      return try task {}
    }
    Shared.InputMode.allCases.forEach {
      $0.lexicon.setOptions { config in
        config.isCassetteEnabled = false
      }
    }
    func trailingOp() {
      let cassetteEnabled = PrefMgr.shared.cassetteEnabled
      Shared.InputMode.allCases.forEach {
        $0.lexicon.setOptions { config in
          config.isCassetteEnabled = cassetteEnabled
        }
      }
    }
    return try task(trailingOp)
  }

  public func performSyncTaskBypassingCassetteMode<T>(
    _ task: () throws -> T
  ) rethrows
    -> T {
    if !PrefMgr.shared.cassetteEnabled {
      return try task()
    }
    Shared.InputMode.allCases.forEach {
      $0.lexicon.setOptions { config in
        config.isCassetteEnabled = false
      }
    }
    defer {
      let cassetteEnabled = PrefMgr.shared.cassetteEnabled
      Shared.InputMode.allCases.forEach {
        $0.lexicon.setOptions { config in
          config.isCassetteEnabled = cassetteEnabled
        }
      }
    }
    return try task()
  }
}
