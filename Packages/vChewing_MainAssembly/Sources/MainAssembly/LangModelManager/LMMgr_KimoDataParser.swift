// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation
import LineReader
import Shared

public extension LMMgr {
  /// 匯入自奇摩輸入法使用者自訂詞資料庫匯出的 TXT 檔案。
  /// - Parameter rawString: 原始 TXT 檔案內容。
  /// - Returns: 成功匯入的資料數量。
  @discardableResult static func importYahooKeyKeyUserDictionary(text rawString: inout String) -> Int {
    var allPhrasesCHT = [UserPhrase]()
    rawString.enumerateLines { currentLine, _ in
      let cells = currentLine.split(separator: "\t")
      guard cells.count >= 3, cells.first != "#", cells.first != "MJSR" else { return }
      let value = cells[0].description
      let keyArray = cells[1].split(separator: ",").map(\.description)
      let phraseCHT = UserPhrase(keyArray: keyArray, value: value, inputMode: .imeModeCHT, isConverted: false)
      guard phraseCHT.isValid, !phraseCHT.isDuplicated else { return }
      guard !(phraseCHT.value.count == 1 && phraseCHT.keyArray.count == 1) else { return }
      allPhrasesCHT.append(phraseCHT)
    }
    guard !allPhrasesCHT.isEmpty else { return 0 }
    let allPhrasesCHS = allPhrasesCHT.compactMap { chtPhrase in
      let chsPhrase = chtPhrase.crossConverted
      return chsPhrase.isValid && !chsPhrase.isDuplicated ? chsPhrase : nil
    }.deduplicated
    let outputStrCHS = allPhrasesCHS.map(\.description).joined(separator: "\n")
    let outputStrCHT = allPhrasesCHT.map(\.description).joined(separator: "\n")
    var outputDataCHS = "\(outputStrCHS)\n".data(using: .utf8) ?? .init([])
    var outputDataCHT = "\(outputStrCHT)\n".data(using: .utf8) ?? .init([])
    let urlCHS = LMMgr.userDictDataURL(mode: .imeModeCHS, type: .thePhrases)
    let urlCHT = LMMgr.userDictDataURL(mode: .imeModeCHT, type: .thePhrases)

    let fileHandlerCHS = try? FileHandle(forUpdating: urlCHS)
    let fileHandlerCHT = try? FileHandle(forUpdating: urlCHT)
    guard let fileHandlerCHS = fileHandlerCHS, let fileHandlerCHT = fileHandlerCHT else { return 0 }
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

    let result = allPhrasesCHT.count
    if result > 0 {
      Broadcaster.shared.eventForReloadingPhraseEditor = .init()
    }
    return result
  }
}

private func fileSize(for theURL: URL) -> UInt64? {
  (try? FileManager.default.attributesOfItem(atPath: theURL.path))?[FileAttributeKey.size] as? UInt64
}
