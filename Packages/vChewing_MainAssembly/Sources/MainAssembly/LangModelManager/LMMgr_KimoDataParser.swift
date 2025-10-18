// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import AppKit

extension LMMgr {
  public enum KimoDataImportError: Error, LocalizedError {
    case connectionFailure
    case fileHandlerFailure

    // MARK: Public

    public var errorDescription: String? {
      switch self {
      case .fileHandlerFailure: return "i18n:KimoDataImportError.fileHandlerFailure.errMsg"
        .localized
      case .connectionFailure: return "i18n:KimoDataImportError.connectionFailure.errMsg".localized
      }
    }
  }

  /// 藉由 XPC 通訊的方式匯入自奇摩輸入法使用者自訂詞資料庫檔案。
  /// - Parameter rawString: 原始 TXT 檔案內容。
  /// - Returns: 成功匯入的資料數量。
  @discardableResult
  public static func importYahooKeyKeyUserDictionaryByXPC() throws -> Int {
    let kimoBundleID = "com.yahoo.inputmethod.KeyKey"
    if #unavailable(macOS 11) {
      NSWorkspace.shared.launchApplication(
        withBundleIdentifier: kimoBundleID,
        additionalEventParamDescriptor: nil,
        launchIdentifier: nil
      )
    } else {
      guard let imeURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: kimoBundleID)
      else {
        throw KimoDataImportError.connectionFailure
      }
      NSWorkspace.shared.openApplication(at: imeURL, configuration: .init())
    }
    guard KimoCommunicator.shared.establishConnection()
    else { throw KimoDataImportError.connectionFailure }
    var allPhrasesCHT = [UserPhraseInsertable]()
    var allPhrasesCHS = [UserPhraseInsertable]()
    KimoCommunicator.shared.prepareData { key, value in
      let phraseCHT = UserPhraseInsertable(
        keyArray: key.components(separatedBy: ","),
        value: value,
        inputMode: .imeModeCHT,
        isConverted: false
      )
      guard phraseCHT.isValid, !phraseCHT.isDuplicated else { return }
      guard !(phraseCHT.value.count == 1 && phraseCHT.keyArray.count == 1) else { return }
      allPhrasesCHT.append(phraseCHT)
      let phraseCHS = phraseCHT.crossConverted
      guard phraseCHS.isValid, !phraseCHS.isDuplicated else { return }
      guard !(phraseCHS.value.count == 1 && phraseCHS.keyArray.count == 1) else { return }
      allPhrasesCHS.append(phraseCHS)
    }

    guard Self
      .batchImportUserPhrasePairs(allPhrasesCHT: allPhrasesCHT, allPhrasesCHS: allPhrasesCHS)
    else {
      throw KimoDataImportError.fileHandlerFailure
    }

    let result = allPhrasesCHT.count
    if result > 0 {
      Broadcaster.shared.eventForReloadingPhraseEditor = .init()
    }
    return result
  }

  /// 匯入自奇摩輸入法使用者自訂詞資料庫匯出的 TXT 檔案。
  /// - Parameter rawString: 原始 TXT 檔案內容。
  /// - Returns: 成功匯入的資料數量。
  @discardableResult
  public static func importYahooKeyKeyUserDictionary(
    text rawString: inout String
  ) throws
    -> Int {
    var allPhrasesCHT = [UserPhraseInsertable]()
    var allPhrasesCHS = [UserPhraseInsertable]()
    rawString.enumerateLines { currentLine, _ in
      let cells = currentLine.split(separator: "\t")
      guard cells.count >= 3, cells.first != "#", cells.first != "MJSR" else { return }
      let value = cells[0].description
      let keyArray = cells[1].split(separator: ",").map(\.description)
      let phraseCHT = UserPhraseInsertable(
        keyArray: keyArray,
        value: value,
        inputMode: .imeModeCHT,
        isConverted: false
      )
      guard phraseCHT.isValid, !phraseCHT.isDuplicated else { return }
      guard !(phraseCHT.value.count == 1 && phraseCHT.keyArray.count == 1) else { return }
      allPhrasesCHT.append(phraseCHT)
      let phraseCHS = phraseCHT.crossConverted
      guard phraseCHS.isValid, !phraseCHS.isDuplicated else { return }
      guard !(phraseCHS.value.count == 1 && phraseCHS.keyArray.count == 1) else { return }
      allPhrasesCHS.append(phraseCHS)
    }
    guard !allPhrasesCHT.isEmpty else { return 0 }

    guard Self
      .batchImportUserPhrasePairs(allPhrasesCHT: allPhrasesCHT, allPhrasesCHS: allPhrasesCHS)
    else {
      throw KimoDataImportError.fileHandlerFailure
    }

    let result = allPhrasesCHT.count
    if result > 0 {
      Broadcaster.shared.eventForReloadingPhraseEditor = .init()
    }
    return result
  }

  private static func batchImportUserPhrasePairs(
    allPhrasesCHT: [UserPhraseInsertable],
    allPhrasesCHS: [UserPhraseInsertable]
  )
    -> Bool {
    LMAssembly.withFileHandleQueueSync {
      let outputStrCHS = allPhrasesCHS.map(\.description).joined(separator: "\n")
      let outputStrCHT = allPhrasesCHT.map(\.description).joined(separator: "\n")
      var outputDataCHS = "\(outputStrCHS)\n".data(using: .utf8) ?? .init([])
      var outputDataCHT = "\(outputStrCHT)\n".data(using: .utf8) ?? .init([])
      let urlCHS = LMMgr.userDictDataURL(mode: .imeModeCHS, type: .thePhrases)
      let urlCHT = LMMgr.userDictDataURL(mode: .imeModeCHT, type: .thePhrases)

      let fileHandlerCHS = try? FileHandle(forUpdating: urlCHS)
      let fileHandlerCHT = try? FileHandle(forUpdating: urlCHT)
      guard let fileHandlerCHS = fileHandlerCHS,
            let fileHandlerCHT = fileHandlerCHT else { return false }
      defer {
        fileHandlerCHS.closeFile()
        fileHandlerCHT.closeFile()
      }

      if let sizeCHS = fileSize(for: urlCHS), sizeCHS > 0 {
        fileHandlerCHS.seek(toFileOffset: sizeCHS)
        if fileHandlerCHS.readDataToEndOfFile().first != 0x0A {
          outputDataCHS.insert(0x0A, at: 0)
        }
      }
      fileHandlerCHS.seekToEndOfFile()
      fileHandlerCHS.write(outputDataCHS)

      if let sizeCHT = fileSize(for: urlCHT), sizeCHT > 0 {
        fileHandlerCHT.seek(toFileOffset: sizeCHT)
        if fileHandlerCHT.readDataToEndOfFile().first != 0x0A {
          outputDataCHT.insert(0x0A, at: 0)
        }
      }
      fileHandlerCHT.seekToEndOfFile()
      fileHandlerCHT.write(outputDataCHT)
      return true
    }
  }
}

private func fileSize(for theURL: URL) -> UInt64? {
  (
    try? FileManager.default
      .attributesOfItem(atPath: theURL.path)
  )?[FileAttributeKey.size] as? UInt64
}
