// (c) 2025 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation
import KeyKeyUserDBKit

public final class KimoDataReader {
  public enum KDRException: Error {
    case notFileURL(URL)
    case fileNotExist(URL)
    case fileNameInsane(URL)
    case wrongFileExtension(URL)
    case sqliteDatabaseReadingError(Error)
    case manjusriTextReadingError(Error)

    // MARK: Public

    public var i18nKeyHeader: String {
      switch self {
      case .notFileURL:
        "i18n:KimoDataReader.KDRException.notFileURL"
      case .fileNotExist:
        "i18n:KimoDataReader.KDRException.fileNotExist"
      case .fileNameInsane:
        "i18n:KimoDataReader.KDRException.fileNameInsane"
      case .wrongFileExtension:
        "i18n:KimoDataReader.KDRException.wrongFileExtension"
      case .sqliteDatabaseReadingError:
        "i18n:KimoDataReader.KDRException.sqliteDatabaseReadingError"
      case .manjusriTextReadingError:
        "i18n:KimoDataReader.KDRException.manjusriTextReadingError"
      }
    }
  }

  public static let shared: KimoDataReader = .init()

  public func prepareData(
    url: URL,
    handler: @escaping (_ keyArray: [String], _ value: String) -> ()
  ) throws {
    guard url.isFileURL else { throw KDRException.notFileURL(url) }
    guard FileManager.default.fileExists(atPath: url.path) else {
      throw KDRException.fileNotExist(url)
    }
    let filename = url.lastPathComponent
    let fileNameCells = filename.split(separator: ".")
    guard fileNameCells.count >= 2, fileNameCells.allSatisfy({ !$0.isEmpty }) else {
      throw KDRException.fileNameInsane(url)
    }
    let extensionName = fileNameCells[Swift.max(0, fileNameCells.indices.upperBound - 1)]
    var isSQLite = false

    func handleSubTaskWithError(subTask: () throws -> ()) throws {
      do {
        try subTask()
      } catch let error as KDRException {
        // 如果已經是 KDRException，直接重新拋出，避免二次包裝
        throw error
      } catch {
        switch isSQLite {
        case true: throw KDRException.sqliteDatabaseReadingError(error)
        case false: throw KDRException.manjusriTextReadingError(error)
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
        throw KDRException.wrongFileExtension(url)
      }
      for gram in userDB {
        guard gram.isUnigram, !gram.isCandidateOverride else { continue }
        handler(gram.keyArray, gram.current)
      }
    }
  }
}
