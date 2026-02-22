// (c) 2025 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation
import KeyKeyUserDBKit

public final class KimoDataReader {
  public nonisolated static let shared: KimoDataReader = .init()

  public func prepareData(
    url: URL,
    handler: @escaping (_ keyArray: [String], _ value: String) -> ()
  ) throws {
    guard url.isFileURL else { throw OIDRException.notFileURL(url) }
    guard FileManager.default.fileExists(atPath: url.path) else {
      throw OIDRException.fileNotExist(url)
    }
    let filename = url.lastPathComponent
    let fileNameCells = filename.split(separator: ".")
    guard fileNameCells.count >= 2, fileNameCells.allSatisfy({ !$0.isEmpty }) else {
      throw OIDRException.fileNameInsane(url)
    }
    let extensionName = fileNameCells[Swift.max(0, fileNameCells.indices.upperBound - 1)]
    var isSQLite = false

    func handleSubTaskWithError(subTask: () throws -> ()) throws {
      do {
        try subTask()
      } catch let error as OIDRException {
        // 如果已經是 OIDRException，直接重新拋出，避免二次包裝
        throw error
      } catch {
        switch isSQLite {
        case true: throw OIDRException.sqliteCERODDatabaseReadingError(error)
        case false: throw OIDRException.manjusriTextReadingError(error)
        }
      }
    }

    try handleSubTaskWithError {
      let userDB: any KeyKeyUserDBKit.UserPhraseDataSource
      switch extensionName.lowercased() {
      case "db":
        isSQLite = true
        if KeyKeyUserDBKit.SEEDecryptor.isEncryptedDatabase(at: url) {
          // 使用記憶體資料庫（無需寫入臨時檔案，避免 Sandbox 問題）
          userDB = try KeyKeyUserDBKit.UserDatabase.openEncrypted(at: url)
        } else {
          // 未加密的資料庫直接開啟
          userDB = try KeyKeyUserDBKit.UserDatabase(path: url.path)
        }
      case "txt":
        isSQLite = false
        userDB = try KeyKeyUserDBKit.UserPhraseTextFileObj(path: url.path)
      default:
        throw OIDRException.wrongFileExtension(url)
      }
      for gram in try userDB.fetchAllGrams() {
        guard gram.isUnigram, !gram.isCandidateOverride else { continue }
        handler(gram.keyArray, gram.current)
      }
    }
  }
}
