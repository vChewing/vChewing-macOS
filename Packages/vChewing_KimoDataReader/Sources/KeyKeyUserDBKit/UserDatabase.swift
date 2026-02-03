// (c) 2025 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import CSQLite3Lib
import Foundation

// MARK: - KeyKeyUserDBKit.UserDatabase

extension KeyKeyUserDBKit {
  /// 使用者資料庫讀取器
  public final class UserDatabase: Sendable, UserPhraseDataSource {
    // MARK: Lifecycle

    // MARK: - Initializers

    /// 開啟解密後的資料庫
    /// - Parameter path: 解密後的資料庫檔案路徑
    public init(path: String) throws {
      self.path = path
      self.actor = .init(label: "KeyKeyUserDBQueue.\(UUID().uuidString)")
      self.inMemoryData = nil

      // sbooth/CSQLite is built with SQLITE_OMIT_AUTOINIT,
      // so we need to call sqlite3_initialize() first.
      // However, the current project does not use that. Skipping that step.

      var dbPointer: OpaquePointer?
      guard sqlite3_open(path, &dbPointer) == SQLITE_OK else {
        let errorMessage: String
        if let dbPointer {
          errorMessage = String(cString: sqlite3_errmsg(dbPointer))
          sqlite3_close(dbPointer)
        } else {
          errorMessage = "Unknown error"
        }
        throw DatabaseError.openFailed(message: errorMessage)
      }
      self.db = dbPointer
    }

    /// 從記憶體中的資料開啟資料庫（無需寫入臨時檔案）
    /// - Parameter data: 解密後的資料庫二進位資料
    /// - Throws: `DatabaseError` 如果開啟失敗
    public init(data: Data) throws {
      self.path = nil
      self.actor = .init(label: "KeyKeyUserDBQueue.\(UUID().uuidString)")

      // sbooth/CSQLite is built with SQLITE_OMIT_AUTOINIT,
      // so we need to call sqlite3_initialize() first.
      // However, the current project does not use that. Skipping that step.

      // 開啟一個記憶體資料庫
      var dbPointer: OpaquePointer?
      guard sqlite3_open(":memory:", &dbPointer) == SQLITE_OK else {
        let errorMessage: String
        if let dbPointer {
          errorMessage = String(cString: sqlite3_errmsg(dbPointer))
          sqlite3_close(dbPointer)
        } else {
          errorMessage = "Unknown error"
        }
        throw DatabaseError.openFailed(message: errorMessage)
      }

      // 複製 data 到可變的記憶體區塊（sqlite3_deserialize 需要）
      // 使用 sqlite3_malloc64 分配記憶體，讓 SQLite 管理生命週期
      let dataSize = Int64(data.count)
      guard let buffer = sqlite3_malloc64(UInt64(dataSize)) else {
        sqlite3_close(dbPointer)
        throw DatabaseError.openFailed(message: "Failed to allocate memory for database")
      }

      // 複製資料到緩衝區
      data.withUnsafeBytes { bytes in
        guard let baseAddress = bytes.baseAddress else { return }
        memcpy(buffer, baseAddress, data.count)
      }

      // 使用 sqlite3_deserialize 載入資料庫
      // SQLITE_DESERIALIZE_FREEONCLOSE: 當資料庫關閉時，SQLite 會自動釋放緩衝區
      // SQLITE_DESERIALIZE_RESIZEABLE: 允許資料庫調整大小（雖然我們只讀取）
      let result = sqlite3_deserialize(
        dbPointer,
        "main",
        buffer.assumingMemoryBound(to: UInt8.self),
        dataSize,
        dataSize,
        UInt32(SQLITE_DESERIALIZE_FREEONCLOSE | SQLITE_DESERIALIZE_RESIZEABLE)
      )

      guard result == SQLITE_OK else {
        let errorMessage = String(cString: sqlite3_errmsg(dbPointer))
        sqlite3_close(dbPointer)
        throw DatabaseError.openFailed(message: "Failed to deserialize database: \(errorMessage)")
      }

      self.db = dbPointer
      self.inMemoryData = nil // 記憶體由 SQLite 管理，不需要保留引用
    }

    deinit {
      actor.sync {
        if let db {
          sqlite3_close(db)
        }
      }
    }

    // MARK: Public

    /// 候選字覆蓋記錄的預設權重
    public static let candidateOverrideProbability: Double = 114.514

    /// 從加密的資料庫檔案載入到記憶體資料庫（無需寫入臨時檔案）
    /// - Parameters:
    ///   - url: 加密資料庫檔案的 URL
    ///   - decryptor: 用於解密的 SEEDecryptor 實例（預設使用預設密鑰）
    /// - Returns: 已開啟的記憶體資料庫
    /// - Throws: `DecryptionError` 或 `DatabaseError`
    public static func openEncrypted(
      at url: URL,
      decryptor: SEEDecryptor = .init()
    ) throws
      -> UserDatabase {
      let encryptedData = try Data(contentsOf: url)
      let decryptedData = try decryptor.decrypt(encryptedData: encryptedData)
      return try UserDatabase(data: decryptedData)
    }

    // MARK: - Public Methods

    /// 讀取所有使用者單元圖
    public func fetchUnigrams() throws -> [Gram] {
      try actor.sync {
        let sql = "SELECT qstring, current, probability FROM user_unigrams"
        var statement: OpaquePointer?

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
          throw DatabaseError.queryFailed(message: String(cString: sqlite3_errmsg(db)))
        }

        defer { sqlite3_finalize(statement) }

        var results: [Gram] = []

        while sqlite3_step(statement) == SQLITE_ROW {
          let qstring = String(cString: sqlite3_column_text(statement, 0))
          let current = String(cString: sqlite3_column_text(statement, 1))
          let probability = sqlite3_column_double(statement, 2)

          let keyArray = PhonaSet.decodeQueryStringAsKeyArray(qstring)
          results.append(Gram(keyArray: keyArray, current: current, probability: probability))
        }

        return results
      }
    }

    /// 讀取使用者雙元圖快取
    /// - Parameter limit: 限制回傳筆數 (nil 表示全部)
    public func fetchBigrams(limit: Int? = nil) throws -> [Gram] {
      try actor.sync {
        var sql = "SELECT qstring, previous, current FROM user_bigram_cache"
        if let limit {
          sql += " LIMIT \(limit)"
        }

        var statement: OpaquePointer?

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
          throw DatabaseError.queryFailed(message: String(cString: sqlite3_errmsg(db)))
        }

        defer { sqlite3_finalize(statement) }

        var results: [Gram] = []

        while sqlite3_step(statement) == SQLITE_ROW {
          let qstring = String(cString: sqlite3_column_text(statement, 0))
          let previous = String(cString: sqlite3_column_text(statement, 1))
          let current = String(cString: sqlite3_column_text(statement, 2))

          let keyArray = PhonaSet.decodeQueryStringAsKeyArray(qstring)
          results.append(Gram(keyArray: keyArray, current: current, previous: previous))
        }

        return results
      }
    }

    /// 讀取候選字覆蓋快取
    public func fetchCandidateOverrides() throws -> [Gram] {
      try actor.sync {
        let sql = "SELECT qstring, current FROM user_candidate_override_cache"
        var statement: OpaquePointer?

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
          throw DatabaseError.queryFailed(message: String(cString: sqlite3_errmsg(db)))
        }

        defer { sqlite3_finalize(statement) }

        var results: [Gram] = []

        while sqlite3_step(statement) == SQLITE_ROW {
          let qstring = String(cString: sqlite3_column_text(statement, 0))
          let current = String(cString: sqlite3_column_text(statement, 1))

          let keyArray = PhonaSet.decodeQueryStringAsKeyArray(qstring)
          results.append(
            Gram(
              keyArray: keyArray,
              current: current,
              probability: Self.candidateOverrideProbability,
              isCandidateOverride: true
            )
          )
        }

        return results
      }
    }

    /// 讀取所有使用者資料，回傳包含所有 Unigram、Bigram 和 CandidateOverride 的陣列
    /// - Returns: 包含所有結果的 `[Gram]` 陣列
    public func fetchAllGrams() throws -> [Gram] {
      var allGrams: [Gram] = []
      allGrams.append(contentsOf: try fetchUnigrams())
      allGrams.append(contentsOf: try fetchBigrams())
      allGrams.append(contentsOf: try fetchCandidateOverrides())
      return allGrams
    }

    /// 建立一個迭代器，逐行讀取所有使用者資料（Unigram、Bigram、CandidateOverride）
    /// - Returns: `GramIterator` 迭代器
    public func makeIterator() -> GramIterator {
      GramIterator(database: self)
    }

    // MARK: Fileprivate

    // MARK: - Query Execution Helper

    fileprivate func executeQuery<T>(
      sql: String,
      rowMapper: (OpaquePointer) -> T
    ) throws
      -> [T] {
      try actor.sync {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
          throw DatabaseError.queryFailed(message: String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(statement) }

        var results: [T] = []
        while sqlite3_step(statement) == SQLITE_ROW {
          results.append(rowMapper(statement!))
        }
        return results
      }
    }

    fileprivate func prepareStatement(sql: String) throws -> OpaquePointer {
      try actor.sync {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
          throw DatabaseError.queryFailed(message: String(cString: sqlite3_errmsg(db)))
        }
        return statement!
      }
    }

    fileprivate func stepStatement(_ statement: OpaquePointer) -> Int32 {
      actor.sync {
        sqlite3_step(statement)
      }
    }

    fileprivate func finalizeStatement(_ statement: OpaquePointer) {
      _ = actor.sync {
        sqlite3_finalize(statement)
      }
    }

    // MARK: Private

    private nonisolated(unsafe) let db: OpaquePointer?
    private let path: String?
    private let actor: DispatchQueue
    /// 保留記憶體資料的引用（如果需要的話）
    private let inMemoryData: Data?
  }
}

// MARK: - KeyKeyUserDBKit.UserDatabase + Sequence

extension KeyKeyUserDBKit.UserDatabase: Sequence {
  public typealias Iterator = GramIterator

  /// 用於逐行迭代資料庫中所有 Gram 的迭代器
  public final class GramIterator: IteratorProtocol, Sendable {
    // MARK: Lifecycle

    fileprivate init(database: KeyKeyUserDBKit.UserDatabase) {
      self.database = database
      self.iteratorQueue = DispatchQueue(label: "GramIterator.\(UUID().uuidString)")
      self._phase = .unigrams
      self._currentStatement = nil
    }

    deinit {
      cleanupCurrentStatement()
    }

    // MARK: Public

    public typealias Element = KeyKeyUserDBKit.Gram

    public func next() -> KeyKeyUserDBKit.Gram? {
      iteratorQueue.sync {
        while true {
          // 如果還沒有 statement，就準備下一個 phase 的 statement
          if _currentStatement == nil {
            do {
              try prepareNextPhase()
            } catch {
              return nil
            }
            // 如果 phase 已經結束
            if _currentStatement == nil {
              return nil
            }
          }

          // 嘗試從當前 statement 讀取下一行
          guard let statement = _currentStatement else { return nil }

          let result = database.stepStatement(statement)
          if result == SQLITE_ROW {
            return mapCurrentRow(statement: statement)
          } else {
            // 當前 phase 結束，清理並進入下一個 phase
            cleanupCurrentStatementUnsafe()
            advancePhase()
            // 繼續迴圈以嘗試下一個 phase
          }
        }
      }
    }

    // MARK: Private

    private enum Phase: Sendable {
      case unigrams
      case bigrams
      case candidateOverrides
      case done
    }

    private let database: KeyKeyUserDBKit.UserDatabase
    private let iteratorQueue: DispatchQueue
    private nonisolated(unsafe) var _phase: Phase
    private nonisolated(unsafe) var _currentStatement: OpaquePointer?

    private func prepareNextPhase() throws {
      switch _phase {
      case .unigrams:
        let sql = "SELECT qstring, current, probability FROM user_unigrams"
        _currentStatement = try database.prepareStatement(sql: sql)
      case .bigrams:
        let sql = "SELECT qstring, previous, current FROM user_bigram_cache"
        _currentStatement = try database.prepareStatement(sql: sql)
      case .candidateOverrides:
        let sql = "SELECT qstring, current FROM user_candidate_override_cache"
        _currentStatement = try database.prepareStatement(sql: sql)
      case .done:
        _currentStatement = nil
      }
    }

    private func mapCurrentRow(statement: OpaquePointer) -> KeyKeyUserDBKit.Gram {
      switch _phase {
      case .unigrams:
        let qstring = String(cString: sqlite3_column_text(statement, 0))
        let current = String(cString: sqlite3_column_text(statement, 1))
        let probability = sqlite3_column_double(statement, 2)
        let keyArray = KeyKeyUserDBKit.PhonaSet.decodeQueryStringAsKeyArray(qstring)
        return KeyKeyUserDBKit.Gram(keyArray: keyArray, current: current, probability: probability)

      case .bigrams:
        let qstring = String(cString: sqlite3_column_text(statement, 0))
        let previous = String(cString: sqlite3_column_text(statement, 1))
        let current = String(cString: sqlite3_column_text(statement, 2))
        let keyArray = KeyKeyUserDBKit.PhonaSet.decodeQueryStringAsKeyArray(qstring)
        return KeyKeyUserDBKit.Gram(keyArray: keyArray, current: current, previous: previous)

      case .candidateOverrides:
        let qstring = String(cString: sqlite3_column_text(statement, 0))
        let current = String(cString: sqlite3_column_text(statement, 1))
        let keyArray = KeyKeyUserDBKit.PhonaSet.decodeQueryStringAsKeyArray(qstring)
        return KeyKeyUserDBKit.Gram(
          keyArray: keyArray,
          current: current,
          probability: KeyKeyUserDBKit.UserDatabase.candidateOverrideProbability,
          isCandidateOverride: true
        )

      case .done:
        fatalError("Should not map row in done phase")
      }
    }

    private func advancePhase() {
      switch _phase {
      case .unigrams:
        _phase = .bigrams
      case .bigrams:
        _phase = .candidateOverrides
      case .candidateOverrides:
        _phase = .done
      case .done:
        break
      }
    }

    private func cleanupCurrentStatement() {
      iteratorQueue.sync {
        cleanupCurrentStatementUnsafe()
      }
    }

    private func cleanupCurrentStatementUnsafe() {
      if let statement = _currentStatement {
        database.finalizeStatement(statement)
        _currentStatement = nil
      }
    }
  }
}

// MARK: - KeyKeyUserDBKit.UserDatabase.AsyncGramSequence

#if canImport(Darwin)
  @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, *)
#endif
extension KeyKeyUserDBKit.UserDatabase {
  /// 取得非同步序列，用於在 async 環境中迭代資料庫
  ///
  /// 使用範例：
  /// ```swift
  /// for await gram in db.async {
  ///     print(gram.current)
  /// }
  /// ```
  public var async: AsyncGramSequence {
    AsyncGramSequence(database: self)
  }

  /// 用於非同步迭代資料庫中所有 Gram 的序列
  public struct AsyncGramSequence: AsyncSequence {
    // MARK: Public

    public typealias Element = KeyKeyUserDBKit.Gram

    public func makeAsyncIterator() -> AsyncGramIterator {
      AsyncGramIterator(database: database)
    }

    // MARK: Fileprivate

    fileprivate let database: KeyKeyUserDBKit.UserDatabase
  }

  /// 用於非同步逐行迭代資料庫中所有 Gram 的迭代器
  public final class AsyncGramIterator: AsyncIteratorProtocol, Sendable {
    // MARK: Lifecycle

    fileprivate init(database: KeyKeyUserDBKit.UserDatabase) {
      self.database = database
      self.iteratorQueue = DispatchQueue(label: "AsyncGramIterator.\(UUID().uuidString)")
      self._phase = .unigrams
      self._currentStatement = nil
    }

    deinit {
      cleanupCurrentStatement()
    }

    // MARK: Public

    public typealias Element = KeyKeyUserDBKit.Gram

    public func next() async -> KeyKeyUserDBKit.Gram? {
      iteratorQueue.sync {
        while true {
          // 如果還沒有 statement，就準備下一個 phase 的 statement
          if _currentStatement == nil {
            do {
              try prepareNextPhase()
            } catch {
              return nil
            }
            // 如果 phase 已經結束
            if _currentStatement == nil {
              return nil
            }
          }

          // 嘗試從當前 statement 讀取下一行
          guard let statement = _currentStatement else { return nil }

          let result = database.stepStatement(statement)
          if result == SQLITE_ROW {
            return mapCurrentRow(statement: statement)
          } else {
            // 當前 phase 結束，清理並進入下一個 phase
            cleanupCurrentStatementUnsafe()
            advancePhase()
            // 繼續迴圈以嘗試下一個 phase
          }
        }
      }
    }

    // MARK: Private

    private enum Phase: Sendable {
      case unigrams
      case bigrams
      case candidateOverrides
      case done
    }

    private let database: KeyKeyUserDBKit.UserDatabase
    private let iteratorQueue: DispatchQueue
    private nonisolated(unsafe) var _phase: Phase
    private nonisolated(unsafe) var _currentStatement: OpaquePointer?

    private func prepareNextPhase() throws {
      switch _phase {
      case .unigrams:
        let sql = "SELECT qstring, current, probability FROM user_unigrams"
        _currentStatement = try database.prepareStatement(sql: sql)
      case .bigrams:
        let sql = "SELECT qstring, previous, current FROM user_bigram_cache"
        _currentStatement = try database.prepareStatement(sql: sql)
      case .candidateOverrides:
        let sql = "SELECT qstring, current FROM user_candidate_override_cache"
        _currentStatement = try database.prepareStatement(sql: sql)
      case .done:
        _currentStatement = nil
      }
    }

    private func mapCurrentRow(statement: OpaquePointer) -> KeyKeyUserDBKit.Gram {
      switch _phase {
      case .unigrams:
        let qstring = String(cString: sqlite3_column_text(statement, 0))
        let current = String(cString: sqlite3_column_text(statement, 1))
        let probability = sqlite3_column_double(statement, 2)
        let keyArray = KeyKeyUserDBKit.PhonaSet.decodeQueryStringAsKeyArray(qstring)
        return KeyKeyUserDBKit.Gram(keyArray: keyArray, current: current, probability: probability)

      case .bigrams:
        let qstring = String(cString: sqlite3_column_text(statement, 0))
        let previous = String(cString: sqlite3_column_text(statement, 1))
        let current = String(cString: sqlite3_column_text(statement, 2))
        let keyArray = KeyKeyUserDBKit.PhonaSet.decodeQueryStringAsKeyArray(qstring)
        return KeyKeyUserDBKit.Gram(keyArray: keyArray, current: current, previous: previous)

      case .candidateOverrides:
        let qstring = String(cString: sqlite3_column_text(statement, 0))
        let current = String(cString: sqlite3_column_text(statement, 1))
        let keyArray = KeyKeyUserDBKit.PhonaSet.decodeQueryStringAsKeyArray(qstring)
        return KeyKeyUserDBKit.Gram(
          keyArray: keyArray,
          current: current,
          probability: KeyKeyUserDBKit.UserDatabase.candidateOverrideProbability,
          isCandidateOverride: true
        )

      case .done:
        fatalError("Should not map row in done phase")
      }
    }

    private func advancePhase() {
      switch _phase {
      case .unigrams:
        _phase = .bigrams
      case .bigrams:
        _phase = .candidateOverrides
      case .candidateOverrides:
        _phase = .done
      case .done:
        break
      }
    }

    private func cleanupCurrentStatement() {
      iteratorQueue.sync {
        cleanupCurrentStatementUnsafe()
      }
    }

    private func cleanupCurrentStatementUnsafe() {
      if let statement = _currentStatement {
        database.finalizeStatement(statement)
        _currentStatement = nil
      }
    }
  }
}

// MARK: - KeyKeyUserDBKit.DatabaseError

extension KeyKeyUserDBKit {
  /// 資料庫錯誤類型
  public enum DatabaseError: Error, LocalizedError {
    /// 開啟資料庫失敗
    case openFailed(message: String)
    /// 查詢失敗
    case queryFailed(message: String)

    // MARK: Public

    /// 錯誤描述
    public var errorDescription: String? {
      switch self {
      case let .openFailed(message):
        return "Failed to open database: \(message)"
      case let .queryFailed(message):
        return "Query failed: \(message)"
      }
    }
  }
}
