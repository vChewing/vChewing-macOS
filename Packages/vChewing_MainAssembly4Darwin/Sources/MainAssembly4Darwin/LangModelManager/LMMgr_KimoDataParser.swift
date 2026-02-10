// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import AppKit
import UniformTypeIdentifiers

#if hasFeature(RetroactiveAttribute)
  extension KimoDataReader.KDRException: @retroactive LocalizedError {}
#else
  extension KimoDataReader.KDRException: LocalizedError {}
#endif

extension KimoDataReader.KDRException {
  public var errorDescription: String? {
    description
  }

  // MARK: Private

  public var description: String {
    switch self {
    case let .sqliteDatabaseReadingError(subError):
      return "\n\n\(i18nKeyHeader.i18n)\n\n\(subError.localizedDescription)"
    case let .manjusriTextReadingError(subError):
      return "\n\n\(i18nKeyHeader.i18n)\n\n\(subError.localizedDescription)"
    case let .notFileURL(url):
      return "\n\n\(i18nKeyHeader.i18n)\n\nFile Path: \(url.standardizedFileURL.path)"
    case let .fileNotExist(url):
      return "\n\n\(i18nKeyHeader.i18n)\n\nFile Path: \(url.standardizedFileURL.path)"
    case let .fileNameInsane(url):
      return "\n\n\(i18nKeyHeader.i18n)\n\nFile Path: \(url.standardizedFileURL.path)"
    case let .wrongFileExtension(url):
      return "\n\n\(i18nKeyHeader.i18n)\n\nFile Path: \(url.standardizedFileURL.path)"
    }
  }
}

extension LMMgr {
  public enum KimoDataImportError: Error, LocalizedError {
    case dataExtractionFailureMsg(String)
    case dataExtractionFailure(Error)
    case lexiconWritingFailure

    // MARK: Public

    public var errorDescription: String? {
      switch self {
      case let .dataExtractionFailureMsg(msg):
        return "i18n:KimoDataImportError.dataExtractionFailure.errMsg".i18n
          + "\n\nMessage: \(msg)"
      case let .dataExtractionFailure(error):
        return "i18n:KimoDataImportError.dataExtractionFailure.errMsg".i18n
          + "\n\n\(error.localizedDescription)"
      case .lexiconWritingFailure:
        return "i18n:KimoDataImportError.lexiconWritingFailure.errMsg".i18n
      }
    }
  }

  /// 匯入自奇摩輸入法使用者自訂詞資料庫匯出的 TXT 檔案、或原始 SQLite 檔案 `SmartMandarinUserData.db`。
  /// - Parameter rawString: 原始檔案內容。
  /// - Returns: 成功匯入的資料數量。
  @discardableResult
  public static func importYahooKeyKeyUserDictionary(
    url: URL? = nil
  ) throws
    -> (totalFound: Int, importedCount: Int) {
    // 判斷 URL 來源：使用者透過 File Open Panel 選擇的 URL 是 security-scoped 的
    let isUserProvidedURL = url != nil
    let url = url ?? FileManager.realHomeDir
      .appendingPathComponent("Library")
      .appendingPathComponent("Application Support")
      .appendingPathComponent("Yahoo! KeyKey")
      .appendingPathComponent("SmartMandarinUserData.db")
    var allPhrasesCHT = [UserPhraseInsertable]()
    var allPhrasesCHS = [UserPhraseInsertable]()
    var entriesDiscovered = 0
    do {
      // 只有使用者透過 File Open Panel 提供的 URL 才需要 security-scoped 存取。
      // 手動構造的預設路徑使用 Entitlement 權限直接存取。
      let securityScopedAccessStarted = isUserProvidedURL && url.startAccessingSecurityScopedResource()
      defer {
        if securityScopedAccessStarted {
          url.stopAccessingSecurityScopedResource()
        }
      }
      // 檢查檔案是否存在
      guard FileManager.default.fileExists(atPath: url.path) else {
        throw KimoDataImportError.dataExtractionFailureMsg(
          "File not found at: \(url.path)"
        )
      }
      // 檢查檔案是否可讀
      guard FileManager.default.isReadableFile(atPath: url.path) else {
        throw KimoDataImportError.dataExtractionFailureMsg(
          "File not readable (Sandbox access denied?): \(url.path)"
        )
      }
      try shared.performSyncTaskBypassingCassetteMode {
        try KimoDataReader.shared.prepareData(url: url) { keyArray, value in
          entriesDiscovered += 1
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
      }
    } catch let error as KimoDataImportError {
      // 如果已經是 KimoDataImportError，直接重新拋出，避免二次包裝
      throw error
    } catch {
      throw KimoDataImportError.dataExtractionFailure(error)
    }
    guard !allPhrasesCHT.isEmpty else { return (entriesDiscovered, 0) }

    guard Self
      .batchImportUserPhrasePairs(allPhrasesCHT: allPhrasesCHT, allPhrasesCHS: allPhrasesCHS)
    else {
      throw KimoDataImportError.lexiconWritingFailure
    }

    let result = allPhrasesCHT.count
    if result > 0 {
      Broadcaster.shared.postEventForReloadingPhraseEditor()
    }
    return (entriesDiscovered, result)
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
