// (c) 2025 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import CommonCrypto
import Foundation
import KeyKeyUserDBKit
import SQLite3
import Testing

// MARK: - KeyKeyUserDBKitTests

@MainActor
@Suite(.serialized)
struct KeyKeyUserDBKitTests {
  // MARK: Internal

  @Test("[KeyKeyUserDBKit] UserDatabase_InitWithData_ReadsAllTables")
  func userDatabaseFromDataReadsAllTables() throws {
    let fixture = try Self.makeFixtureDatabase()
    let db = try KeyKeyUserDBKit.UserDatabase(data: fixture)

    let expectedUnigrams: [KeyKeyUserDBKit.KeyKeyGram] = [
      .init(
        keyArray: KeyKeyUserDBKit.PhonaSet.decodeQueryStringAsKeyArray("0j"),
        current: "你",
        probability: 3.5
      ),
      .init(
        keyArray: KeyKeyUserDBKit.PhonaSet.decodeQueryStringAsKeyArray("0j3j"),
        current: "你好",
        probability: 2.0
      ),
    ]
    // UserDatabase 的 bigram 查詢不讀取 probability 欄位，權重恆為 0。
    let expectedBigrams: [KeyKeyUserDBKit.KeyKeyGram] = [
      .init(
        keyArray: KeyKeyUserDBKit.PhonaSet.decodeQueryStringAsKeyArray("~0j 3j"),
        current: "好",
        previous: "你"
      ),
    ]
    let expectedOverrides: [KeyKeyUserDBKit.KeyKeyGram] = [
      .init(
        keyArray: KeyKeyUserDBKit.PhonaSet.decodeQueryStringAsKeyArray("0j"),
        current: "妳",
        probability: KeyKeyUserDBKit.UserDatabase.candidateOverrideProbability,
        isCandidateOverride: true
      ),
    ]

    #expect(try db.fetchUnigrams() == expectedUnigrams)
    #expect(try db.fetchBigrams() == expectedBigrams)
    #expect(try db.fetchBigrams(limit: 1) == expectedBigrams)
    #expect(try db.fetchCandidateOverrides() == expectedOverrides)
    #expect(try db.fetchAllGrams() == expectedUnigrams + expectedBigrams + expectedOverrides)
    #expect(db.map { $0 } == expectedUnigrams + expectedBigrams + expectedOverrides)
  }

  @Test("[KeyKeyUserDBKit] UserDatabase_InitWithPath_ReadsAllTables")
  func userDatabaseFromPathReadsAllTables() throws {
    let fixture = try Self.makeFixtureDatabase()
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("KeyKeyUserDBKitTests-\(UUID().uuidString).db")
    try fixture.write(to: url)
    defer { try? FileManager.default.removeItem(at: url) }

    let db = try KeyKeyUserDBKit.UserDatabase(path: url.path)
    #expect(try db.fetchUnigrams().count == 2)
    #expect(try db.fetchBigrams().count == 1)
    #expect(try db.fetchCandidateOverrides().count == 1)
  }

  @Test("[KeyKeyUserDBKit] UserDatabase_InitWithInvalidData_ThrowsOpenFailed")
  func userDatabaseFromInvalidDataThrowsOpenFailed() throws {
    let garbage = Data("This is definitely not a SQLite database image.".utf8)
    do {
      _ = try KeyKeyUserDBKit.UserDatabase(data: garbage)
      Issue.record("應拋出 DatabaseError.openFailed，但初始化成功了。")
    } catch let KeyKeyUserDBKit.DatabaseError.openFailed(message) {
      #expect(!message.isEmpty)
    } catch {
      Issue.record("拋出了非預期的錯誤：\(error)")
    }
  }

  @available(macOS 10.15, *)
  @Test("[KeyKeyUserDBKit] UserDatabase_AsyncIteration_MatchesFetchAll")
  func userDatabaseAsyncIterationMatchesFetchAll() async throws {
    let fixture = try Self.makeFixtureDatabase()
    let db = try KeyKeyUserDBKit.UserDatabase(data: fixture)
    var collected: [KeyKeyUserDBKit.KeyKeyGram] = []
    for await gram in db.async {
      collected.append(gram)
    }
    let expectedAll = try db.fetchAllGrams()
    #expect(collected == expectedAll)
  }

  @Test("[KeyKeyUserDBKit] MJSRText_WithoutDatabaseBlock_ParsesUnigramsOnly")
  func mjsrTextWithoutDatabaseBlockParsesUnigramsOnly() throws {
    let content = """
    MJSR version 1.0.0
    春天\tㄔㄨㄣ,ㄊㄧㄢ\t5\t0
    # comment line

    """
    let parsed = try KeyKeyUserDBKit.UserPhraseTextFileObj(content: content)
    let expectedUnigrams: [KeyKeyUserDBKit.KeyKeyGram] = [
      .init(keyArray: ["ㄔㄨㄣ", "ㄊㄧㄢ"], current: "春天", probability: 5.0),
    ]
    #expect(parsed.unigrams == expectedUnigrams)
    #expect(parsed.bigrams.isEmpty)
    #expect(parsed.candidateOverrides.isEmpty)
    #expect(try parsed.fetchUnigrams() == expectedUnigrams)
  }

  @Test("[KeyKeyUserDBKit] MJSRText_WithEncryptedDatabaseBlock_ReadsAllTables")
  func mjsrTextWithEncryptedDatabaseBlockReadsAllTables() throws {
    let fixture = try Self.makeFixtureDatabase()
    let encrypted = try Self.mjsrEncrypt(databaseData: fixture)
    let hexString = encrypted.map { String(format: "%02x", $0) }.joined()
    let content = """
    MJSR version 1.0.0
    春天\tㄔㄨㄣ,ㄊㄧㄢ\t5\t0
    # database block follows
    <database>
    \(hexString)
    </database>
    """
    let parsed = try KeyKeyUserDBKit.UserPhraseTextFileObj(content: content)

    let expectedUnigrams: [KeyKeyUserDBKit.KeyKeyGram] = [
      .init(keyArray: ["ㄔㄨㄣ", "ㄊㄧㄢ"], current: "春天", probability: 5.0),
    ]
    // MJSR 路徑的 bigram 查詢會讀取 probability 欄位。
    let expectedBigrams: [KeyKeyUserDBKit.KeyKeyGram] = [
      .init(
        keyArray: KeyKeyUserDBKit.PhonaSet.decodeQueryStringAsKeyArray("~0j 3j"),
        current: "好",
        previous: "你",
        probability: 4.25
      ),
    ]
    let expectedOverrides: [KeyKeyUserDBKit.KeyKeyGram] = [
      .init(
        keyArray: KeyKeyUserDBKit.PhonaSet.decodeQueryStringAsKeyArray("0j"),
        current: "妳",
        probability: KeyKeyUserDBKit.UserPhraseTextFileObj.candidateOverrideProbability,
        isCandidateOverride: true
      ),
    ]
    #expect(parsed.unigrams == expectedUnigrams)
    #expect(parsed.bigrams == expectedBigrams)
    #expect(parsed.candidateOverrides == expectedOverrides)
  }

  // MARK: Private

  private struct FixtureError: Error {
    let message: String
  }

  /// 以系統 SQLite 建立具備 KeyKey 結構的測試資料庫，並回傳其檔案二進位映像。
  ///
  /// 頁面大小 1024、每頁保留 32 bytes，與 Yahoo KeyKey SEE 加密庫的幾何一致。
  private static func makeFixtureDatabase() throws -> Data {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("KeyKeyUserDBKitTests-\(UUID().uuidString).db")
    defer {
      try? FileManager.default.removeItem(at: url)
      try? FileManager.default.removeItem(atPath: url.path + "-journal")
    }

    let statements = [
      "PRAGMA page_size = 1024",
      "CREATE TABLE user_unigrams (qstring TEXT, current TEXT, probability REAL)",
      "CREATE TABLE user_bigram_cache (qstring TEXT, previous TEXT, current TEXT, probability REAL)",
      "CREATE TABLE user_candidate_override_cache (qstring TEXT, current TEXT)",
      "INSERT INTO user_unigrams VALUES ('0j', '你', 3.5)",
      "INSERT INTO user_unigrams VALUES ('0j3j', '你好', 2.0)",
      "INSERT INTO user_bigram_cache VALUES ('~0j 3j', '你', '好', 4.25)",
      "INSERT INTO user_candidate_override_cache VALUES ('0j', '妳')",
    ]

    var db: OpaquePointer?
    guard sqlite3_open(url.path, &db) == SQLITE_OK else {
      throw FixtureError(message: "無法建立測試資料庫。")
    }
    // SEE 加密格式每頁保留 32 bytes；此設定無對應 PRAGMA，須用 file control。
    var reserveBytes = 32
    _ = sqlite3_file_control(db, "main", SQLITE_FCNTL_RESERVE_BYTES, &reserveBytes)
    for sql in statements {
      guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else {
        let message = db.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "Unknown error"
        sqlite3_close(db)
        throw FixtureError(message: "建立測試資料庫失敗：\(message)")
      }
    }
    // 關閉連線以確保全部頁面落盤，再讀取檔案映像。
    sqlite3_close(db)

    return try Data(contentsOf: url)
  }

  /// MJSR `<database>` block 的 SEE AES-128-CCM 加密（與產品端解密互逆的測試側實作）。
  private static func mjsrEncrypt(databaseData: Data) throws -> [UInt8] {
    let pageSize = KeyKeyUserDBKit.SEEDecryptor.pageSize
    let dataAreaSize = KeyKeyUserDBKit.SEEDecryptor.dataAreaSize
    let key = KeyKeyUserDBKit.UserPhraseTextFileObj.exportKey
    let plainBytes = Array(databaseData)

    guard plainBytes.count % pageSize == 0 else {
      throw FixtureError(message: "測試資料庫大小並非頁面大小的倍數。")
    }

    var encrypted: [UInt8] = []
    for pageNumber in 0 ..< (plainBytes.count / pageSize) {
      let pageStart = pageNumber * pageSize
      let plainPage = Array(plainBytes[pageStart ..< pageStart + pageSize])

      // 每頁使用固定的測試 nonce（16 bytes，置於加密頁面末端）。
      var nonce = [UInt8](repeating: 0, count: 16)
      for i in 0 ..< 16 {
        nonce[i] = UInt8((pageNumber * 16 + i) & 0xFF)
      }
      let baseCounter = UInt32(
        littleEndian: nonce[4 ..< 8].withUnsafeBytes { $0.load(as: UInt32.self) }
      )

      var encryptedPage = [UInt8](repeating: 0, count: pageSize)
      for blockIdx in 0 ..< (dataAreaSize / 16) {
        let counter = baseCounter &+ UInt32(blockIdx)
        var counterBytes = nonce
        withUnsafeBytes(of: counter.littleEndian) { counterPtr in
          for i in 0 ..< 4 {
            counterBytes[4 + i] = counterPtr[i]
          }
        }

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
          throw FixtureError(message: "AES 加密失敗。")
        }

        let blockStart = blockIdx * 16
        if pageNumber == 0, blockIdx == 1 {
          // Page 1 特殊處理：bytes 16-23 保持明文，bytes 24-31 加密。
          for i in 0 ..< 8 {
            encryptedPage[16 + i] = plainPage[16 + i]
          }
          for i in 8 ..< 16 {
            encryptedPage[16 + i] = plainPage[16 + i] ^ keystream[i]
          }
        } else {
          for i in 0 ..< 16 {
            encryptedPage[blockStart + i] = plainPage[blockStart + i] ^ keystream[i]
          }
        }
      }
      // Nonce 置於頁面末端（保留區的最後 16 bytes）。
      encryptedPage.replaceSubrange((pageSize - 16) ..< pageSize, with: nonce)
      encrypted.append(contentsOf: encryptedPage)
    }
    return encrypted
  }
}
