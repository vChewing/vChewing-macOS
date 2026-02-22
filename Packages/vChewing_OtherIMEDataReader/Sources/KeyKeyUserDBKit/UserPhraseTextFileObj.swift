// (c) 2025 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import CommonCrypto
import CSQLite3Lib
import Foundation

// MARK: - KeyKeyUserDBKit.UserPhraseTextFileObj

extension KeyKeyUserDBKit {
  /// MJSR 匯出檔案解析器
  ///
  /// 此類別可解析 Yahoo! 奇摩輸入法 (KeyKey) 匯出的使用者詞庫文字檔案。
  ///
  /// ## 檔案格式
  /// - Header: "MJSR version 1.0.0"
  /// - 使用者單字詞: 每行一筆 (word\treading\tprobability\tbackoff)
  /// - 註解行: 以 # 開頭
  /// - `<database>` block: 加密的 SQLite 資料庫 (user_bigram_cache + user_candidate_override_cache)
  ///
  /// ## 加密方式
  /// - SQLite SEE AES-128-CCM
  /// - 密鑰: "mjsrexportmjsrex" (重複填充到 16 bytes)
  public final class UserPhraseTextFileObj: UserPhraseDataSource {
    // MARK: Lifecycle

    /// 從檔案路徑初始化
    /// - Parameter path: MJSR 匯出檔案路徑
    /// - Throws: 檔案讀取或解析錯誤
    public convenience init(path: String) throws {
      let content = try String(contentsOfFile: path, encoding: .utf8)
      try self.init(content: content)
    }

    /// 從 URL 初始化
    /// - Parameter url: MJSR 匯出檔案 URL
    /// - Throws: 檔案讀取或解析錯誤
    public convenience init(url: URL) throws {
      let content = try String(contentsOf: url, encoding: .utf8)
      try self.init(content: content)
    }

    /// 從文字內容初始化
    /// - Parameter content: MJSR 匯出檔案的文字內容
    /// - Throws: 解析錯誤
    public init(content: String) throws {
      let lines = content.components(separatedBy: .newlines)

      // 檢查 header
      guard let firstLine = lines.first, firstLine.hasPrefix("MJSR version") else {
        throw TextFileError.invalidFormat(message: "Missing MJSR header")
      }
      self.version = firstLine

      // 解析 unigrams（逐行解析到 # 或 < 開頭為止）
      var unigrams: [KeyKeyGram] = []
      for line in lines.dropFirst() {
        if line.hasPrefix("#") || line.hasPrefix("<") {
          break
        }
        if line.isEmpty { continue }

        let parts = line.split(separator: "\t", omittingEmptySubsequences: false)
        guard parts.count >= 4 else { continue }

        let word = String(parts[0])
        let reading = String(parts[1])
        let probability = Double(parts[2]) ?? 0
        // backoff 目前不使用

        // reading 格式是逗號分隔的注音字串，如 "ㄔㄨㄣ,ㄒㄧ"
        let keyArray = reading.split(separator: ",").map(String.init)
        unigrams.append(KeyKeyGram(keyArray: keyArray, current: word, probability: probability))
      }
      self.unigrams = unigrams

      // 解析 database block
      let databaseBlockResult = try Self.parseDatabaseBlock(from: content)
      self.bigrams = databaseBlockResult.bigrams
      self.candidateOverrides = databaseBlockResult.candidateOverrides
    }

    // MARK: Public

    // MARK: - Constants

    /// 候選字覆蓋記錄的預設權重
    public static let candidateOverrideProbability: Double = 114.514

    /// Export 密鑰（"mjsrexport" 重複填充到 16 bytes）
    public static let exportKey: [UInt8] = Array("mjsrexportmjsrex".utf8)

    /// MJSR 版本字串
    public let version: String

    /// 使用者單元圖
    public let unigrams: [KeyKeyGram]

    /// 使用者雙元圖（來自 database block）
    public let bigrams: [KeyKeyGram]

    /// 候選字覆蓋（來自 database block）
    public let candidateOverrides: [KeyKeyGram]

    // MARK: - UserPhraseDataSource

    public func fetchUnigrams() throws -> [KeyKeyGram] {
      unigrams
    }

    public func fetchBigrams(limit: Int? = nil) throws -> [KeyKeyGram] {
      if let limit {
        return Array(bigrams.prefix(limit))
      }
      return bigrams
    }

    public func fetchCandidateOverrides() throws -> [KeyKeyGram] {
      candidateOverrides
    }

    // MARK: - Sequence

    public func makeIterator() -> IndexingIterator<[KeyKeyGram]> {
      var allGrams: [KeyKeyGram] = []
      allGrams.append(contentsOf: unigrams)
      allGrams.append(contentsOf: bigrams)
      allGrams.append(contentsOf: candidateOverrides)
      return allGrams.makeIterator()
    }

    // MARK: Private

    // MARK: - Database Block Parsing

    private static func parseDatabaseBlock(
      from content: String
    ) throws
      -> (bigrams: [KeyKeyGram], candidateOverrides: [KeyKeyGram]) {
      // 找到 <database> block
      guard let startRange = content.range(of: "<database>"),
            let endRange = content.range(of: "</database>")
      else {
        // 沒有 database block，回傳空陣列
        return (bigrams: [], candidateOverrides: [])
      }

      let hexDataStart = content.index(startRange.upperBound, offsetBy: 0)
      let hexString = content[hexDataStart ..< endRange.lowerBound]
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .replacingOccurrences(of: "\n", with: "")
        .replacingOccurrences(of: "\r", with: "")

      if hexString.isEmpty {
        return (bigrams: [], candidateOverrides: [])
      }

      // 將 hex 字串轉換為 bytes
      guard let encryptedData = Data(hexString: hexString) else {
        throw TextFileError.invalidDatabaseBlock(message: "Invalid hex data")
      }

      // 解密資料庫
      let decryptedData = try decryptDatabaseBlock(encryptedData: encryptedData)

      // 使用記憶體資料庫讀取 SQLite 資料（無需臨時檔案）
      return try readGramsFromDecryptedDatabase(data: decryptedData)
    }

    private static func decryptDatabaseBlock(encryptedData: Data) throws -> Data {
      let pageSize = SEEDecryptor.pageSize

      guard encryptedData.count % pageSize == 0 else {
        throw TextFileError.invalidDatabaseBlock(
          message: "Invalid size: \(encryptedData.count) is not a multiple of \(pageSize)"
        )
      }

      let numPages = encryptedData.count / pageSize
      var decrypted = Data()

      for pageIdx in 0 ..< numPages {
        let pageStart = pageIdx * pageSize
        let pageData = encryptedData[pageStart ..< pageStart + pageSize]

        let decryptedPage = try decryptPage(
          pageData: pageData,
          pageNumber: pageIdx,
          key: exportKey
        )
        decrypted.append(decryptedPage)
      }

      // 清除 SQLite header 中的 reserved bytes 設定 (offset 20)
      if decrypted.count > 20 {
        decrypted[20] = 0
      }

      return decrypted
    }

    private static func decryptPage(
      pageData: Data,
      pageNumber: Int,
      key: [UInt8]
    ) throws
      -> Data {
      let pageSize = SEEDecryptor.pageSize
      let reservedBytes = SEEDecryptor.reservedBytes
      let dataAreaSize = SEEDecryptor.dataAreaSize

      guard pageData.count == pageSize else {
        throw TextFileError.invalidDatabaseBlock(message: "Invalid page size")
      }

      let pageBytes = Array(pageData)
      let nonce = Array(pageBytes[(pageSize - 16)...])

      // 建立 AES cipher
      var decrypted = [UInt8](repeating: 0, count: dataAreaSize)
      let baseCounter = UInt32(
        littleEndian: nonce[4 ..< 8].withUnsafeBytes { $0.load(as: UInt32.self) }
      )

      for blockIdx in 0 ..< (dataAreaSize / 16) {
        let counter = baseCounter &+ UInt32(blockIdx)
        var counterBytes = nonce
        withUnsafeBytes(of: counter.littleEndian) { counterPtr in
          for i in 0 ..< 4 {
            counterBytes[4 + i] = counterPtr[i]
          }
        }

        // AES-ECB 加密 counter block 產生 keystream
        var keystream = [UInt8](repeating: 0, count: 16)

        var numBytesEncrypted = 0
        let status = counterBytes.withUnsafeBytes { counterPtr in
          keystream.withUnsafeMutableBytes { keystreamPtr in
            CCCrypt(
              CCOperation(kCCEncrypt),
              CCAlgorithm(kCCAlgorithmAES),
              CCOptions(kCCOptionECBMode),
              key, key.count,
              nil,
              counterPtr.baseAddress, 16,
              keystreamPtr.baseAddress, 16,
              &numBytesEncrypted
            )
          }
        }
        guard status == kCCSuccess else {
          throw TextFileError.decryptionFailed(message: "AES encryption failed")
        }

        // XOR 解密
        let blockStart = blockIdx * 16
        if pageNumber == 0 {
          // Page 1 特殊處理：bytes 16-23 是明文
          if blockIdx == 0 {
            // Block 0: 全部解密
            for i in 0 ..< 16 {
              decrypted[i] = pageBytes[i] ^ keystream[i]
            }
          } else if blockIdx == 1 {
            // Block 1: bytes 16-23 保持明文，bytes 24-31 解密
            for i in 0 ..< 8 {
              decrypted[16 + i] = pageBytes[16 + i]
            }
            for i in 8 ..< 16 {
              decrypted[16 + i] = pageBytes[16 + i] ^ keystream[i]
            }
          } else {
            // 其他 blocks: 全部解密
            for i in 0 ..< 16 {
              decrypted[blockStart + i] = pageBytes[blockStart + i] ^ keystream[i]
            }
          }
        } else {
          // 其他頁面：全部解密
          for i in 0 ..< 16 {
            decrypted[blockStart + i] = pageBytes[blockStart + i] ^ keystream[i]
          }
        }
      }

      // 填充 reserved bytes 為零
      var result = Data(decrypted)
      result.append(Data(repeating: 0, count: reservedBytes))
      return result
    }

    private static func readGramsFromDecryptedDatabase(
      data: Data
    ) throws
      -> (bigrams: [KeyKeyGram], candidateOverrides: [KeyKeyGram]) {
      // sbooth/CSQLite is built with SQLITE_OMIT_AUTOINIT,
      // so we need to call sqlite3_initialize() first.
      // However, the current project does not use that. Skipping that step.

      // 開啟記憶體資料庫
      var db: OpaquePointer?
      guard sqlite3_open(":memory:", &db) == SQLITE_OK else {
        let errorMsg = db.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "Unknown error"
        sqlite3_close(db)
        throw TextFileError.databaseReadFailed(message: errorMsg)
      }

      // 使用 sqlite3_deserialize 載入資料
      let dataSize = Int64(data.count)
      guard let buffer = sqlite3_malloc64(UInt64(dataSize)) else {
        sqlite3_close(db)
        throw TextFileError.databaseReadFailed(message: "Failed to allocate memory for database")
      }

      // 複製資料到緩衝區
      data.withUnsafeBytes { bytes in
        guard let baseAddress = bytes.baseAddress else { return }
        memcpy(buffer, baseAddress, data.count)
      }

      // 使用 sqlite3_deserialize 載入資料庫
      // SQLITE_DESERIALIZE_FREEONCLOSE: 當資料庫關閉時，SQLite 會自動釋放緩衝區
      // SQLITE_DESERIALIZE_RESIZEABLE: 允許資料庫調整大小
      let result = sqlite3_deserialize(
        db,
        "main",
        buffer.assumingMemoryBound(to: UInt8.self),
        dataSize,
        dataSize,
        UInt32(SQLITE_DESERIALIZE_FREEONCLOSE | SQLITE_DESERIALIZE_RESIZEABLE)
      )

      guard result == SQLITE_OK else {
        let errorMsg = db.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "Unknown error"
        sqlite3_close(db)
        throw TextFileError.databaseReadFailed(
          message: "Failed to deserialize database: \(errorMsg)"
        )
      }

      defer { sqlite3_close(db) }

      var bigrams: [KeyKeyGram] = []
      var candidateOverrides: [KeyKeyGram] = []

      // 讀取 user_bigram_cache
      var statement: OpaquePointer?
      let bigramSQL = "SELECT qstring, previous, current, probability FROM user_bigram_cache"
      if sqlite3_prepare_v2(db, bigramSQL, -1, &statement, nil) == SQLITE_OK {
        while sqlite3_step(statement) == SQLITE_ROW {
          let qstring = String(cString: sqlite3_column_text(statement, 0))
          let previous = String(cString: sqlite3_column_text(statement, 1))
          let current = String(cString: sqlite3_column_text(statement, 2))
          let probability = sqlite3_column_double(statement, 3)

          // bigram 的 qstring 格式是 "{前字注音2char} {當前字注音2char}"
          let keyArray = PhonaSet.decodeQueryStringAsKeyArray(qstring)
          bigrams.append(
            KeyKeyGram(keyArray: keyArray, current: current, previous: previous, probability: probability)
          )
        }
        sqlite3_finalize(statement)
      }

      // 讀取 user_candidate_override_cache
      statement = nil
      let overrideSQL = "SELECT qstring, current FROM user_candidate_override_cache"
      if sqlite3_prepare_v2(db, overrideSQL, -1, &statement, nil) == SQLITE_OK {
        while sqlite3_step(statement) == SQLITE_ROW {
          let qstring = String(cString: sqlite3_column_text(statement, 0))
          let current = String(cString: sqlite3_column_text(statement, 1))

          let keyArray = PhonaSet.decodeQueryStringAsKeyArray(qstring)
          candidateOverrides.append(
            KeyKeyGram(
              keyArray: keyArray,
              current: current,
              probability: candidateOverrideProbability,
              isCandidateOverride: true
            )
          )
        }
        sqlite3_finalize(statement)
      }

      return (bigrams: bigrams, candidateOverrides: candidateOverrides)
    }
  }
}

// MARK: - KeyKeyUserDBKit.UserPhraseTextFileObj.TextFileError

extension KeyKeyUserDBKit.UserPhraseTextFileObj {
  /// 文字檔案解析錯誤
  public enum TextFileError: Error, LocalizedError {
    case invalidFormat(message: String)
    case invalidDatabaseBlock(message: String)
    case decryptionFailed(message: String)
    case databaseReadFailed(message: String)

    // MARK: Public

    public var errorDescription: String? {
      switch self {
      case let .invalidFormat(message):
        "Invalid file format: \(message)"
      case let .invalidDatabaseBlock(message):
        "Invalid database block: \(message)"
      case let .decryptionFailed(message):
        "Decryption failed: \(message)"
      case let .databaseReadFailed(message):
        "Database read failed: \(message)"
      }
    }
  }
}

// MARK: - Data Extension for Hex String

extension Data {
  /// 從十六進位字串初始化 Data
  fileprivate init?(hexString: String) {
    let len = hexString.count / 2
    var data = Data(capacity: len)
    var index = hexString.startIndex

    for _ in 0 ..< len {
      let nextIndex = hexString.index(index, offsetBy: 2)
      guard let byte = UInt8(hexString[index ..< nextIndex], radix: 16) else {
        return nil
      }
      data.append(byte)
      index = nextIndex
    }

    self = data
  }
}
