// (c) 2025 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import CommonCrypto
import Foundation

// MARK: - KeyKeyUserDBKit.SEEDecryptor

extension KeyKeyUserDBKit {
  /// Yahoo! 奇摩輸入法 (KeyKey) 使用者資料庫解密器
  ///
  /// 此解密器可解密 SmartMandarinUserData.db 等使用 SQLite SEE AES-128 加密的資料庫。
  ///
  /// ## 加密方式分析
  /// - 使用 SQLite SEE (SQLite Encryption Extension) with AES-128
  /// - Page size: 1024 bytes
  /// - Reserved bytes per page: 32 bytes (16 bytes nonce + 16 bytes MAC)
  /// - 加密範圍：每頁的前 992 bytes (data area)
  /// - Page 1 的 bytes 16-23 是未加密的 (SQLite header 格式資訊)
  ///
  /// ## Keystream 產生方式
  /// - AES-128-ECB(key, counter_block)
  /// - counter_block 結構：nonce 的副本，但 bytes 4-7 是 4-byte little-endian counter
  /// - Counter 從 nonce[4:8] 的原始值開始，每個 16-byte block 遞增 1
  public struct SEEDecryptor: Sendable {
    // MARK: Lifecycle

    // MARK: - Initializers

    /// 使用自訂密鑰初始化解密器
    /// - Parameter key: 16 bytes AES-128 密鑰
    public init(key: [UInt8]) {
      precondition(key.count == Self.keySize, "Key must be 16 bytes for AES-128")
      self.key = key
    }

    /// 使用預設密鑰初始化解密器
    public init() {
      self.key = Self.defaultKey
    }

    // MARK: Public

    // MARK: - Constants

    /// AES-128 密鑰長度
    public static let keySize = 16

    /// 預設密鑰 (前 16 bytes of "yahookeykeyuserdb")
    public static let defaultKey: [UInt8] = Array("yahookeykeyuserdb".utf8.prefix(keySize))

    /// 頁面大小
    public static let pageSize = 1_024

    /// 保留區域大小 (nonce + MAC)
    public static let reservedBytes = 32

    /// 資料區域大小
    public static let dataAreaSize = pageSize - reservedBytes // 992 bytes

    /// 檢查資料庫檔案是否為加密的（非標準 SQLite 格式）
    /// - Parameter url: 資料庫檔案 URL
    /// - Returns: 如果檔案是加密的回傳 true，否則回傳 false
    public static func isEncryptedDatabase(at url: URL) -> Bool {
      guard FileManager.default.fileExists(atPath: url.path) else {
        return false
      }

      do {
        let data = try Data(contentsOf: url)
        guard data.count >= sqliteMagic.count else {
          return true // 檔案太小，可能是加密的
        }

        // 如果開頭不是 SQLite 魔術數字，則是加密的
        return Array(data.prefix(sqliteMagic.count)) != sqliteMagic
      } catch {
        return true // 無法讀取，假設是加密的
      }
    }

    // MARK: - Public Methods

    /// 解密整個資料庫檔案
    /// - Parameter encryptedData: 加密的資料庫二進位資料
    /// - Returns: 解密後的資料庫二進位資料
    /// - Throws: `DecryptionError` 如果解密失敗
    public func decrypt(encryptedData: Data) throws -> Data {
      guard encryptedData.count % Self.pageSize == 0 else {
        throw DecryptionError.invalidSize(
          expected: "multiple of \(Self.pageSize)",
          actual: encryptedData.count
        )
      }

      let numPages = encryptedData.count / Self.pageSize
      var output = Data(capacity: encryptedData.count)

      for pageNum in 0 ..< numPages {
        let pageStart = pageNum * Self.pageSize
        let pageEnd = pageStart + Self.pageSize
        let pageData = encryptedData[pageStart ..< pageEnd]

        let decryptedData = try decryptPage(Array(pageData), pageNumber: pageNum)

        if pageNum == 0 {
          // Page 0 特殊處理：bytes 16-23 是未加密的
          output.append(contentsOf: decryptedData[0 ..< 16])
          output.append(contentsOf: pageData[16 ..< 24])
          output.append(contentsOf: decryptedData[24...])
        } else {
          output.append(contentsOf: decryptedData)
        }

        // Reserved area 填充零
        output.append(contentsOf: [UInt8](repeating: 0, count: Self.reservedBytes))
      }

      return output
    }

    /// 從檔案解密資料庫
    /// - Parameters:
    ///   - inputURL: 加密資料庫檔案路徑
    ///   - outputURL: 輸出解密資料庫檔案路徑
    /// - Throws: `DecryptionError` 如果解密失敗
    public func decryptFile(at inputURL: URL, to outputURL: URL) throws {
      let encryptedData = try Data(contentsOf: inputURL)
      let decryptedData = try decrypt(encryptedData: encryptedData)
      try decryptedData.write(to: outputURL)
    }

    // MARK: Private

    /// SQLite 資料庫魔術數字
    private static let sqliteMagic: [UInt8] = Array("SQLite format 3\0".utf8)

    private let key: [UInt8]

    // MARK: - Private Methods

    /// 解密單一頁面
    private func decryptPage(_ page: [UInt8], pageNumber _: Int) throws -> [UInt8] {
      guard page.count == Self.pageSize else {
        throw DecryptionError.invalidPageSize(expected: Self.pageSize, actual: page.count)
      }

      // Nonce 是頁面的最後 16 bytes
      let nonce = Array(page[(Self.pageSize - 16)...])

      // Counter 是 4 bytes，little-endian，位於 nonce 的 bytes 4-7
      let baseCounter = UInt32(
        littleEndian: nonce[4 ..< 8].withUnsafeBytes { $0.load(as: UInt32.self) }
      )

      var decrypted = [UInt8]()
      decrypted.reserveCapacity(Self.dataAreaSize)

      let numBlocks = (Self.dataAreaSize + 15) / 16 // 62 blocks

      for blockIdx in 0 ..< numBlocks {
        // 建構 counter block
        var counterBlock = nonce
        let newCounter = baseCounter &+ UInt32(blockIdx)
        withUnsafeBytes(of: newCounter.littleEndian) { bytes in
          counterBlock[4] = bytes[0]
          counterBlock[5] = bytes[1]
          counterBlock[6] = bytes[2]
          counterBlock[7] = bytes[3]
        }

        // 產生 keystream (AES-ECB encrypt counter block)
        let keystream = try aesECBEncrypt(block: counterBlock)

        // XOR 解密
        let start = blockIdx * 16
        let end = min(start + 16, Self.dataAreaSize)

        for i in start ..< end {
          decrypted.append(page[i] ^ keystream[i - start])
        }
      }

      return decrypted
    }

    /// AES-128-ECB 加密單一 block
    private func aesECBEncrypt(block: [UInt8]) throws -> [UInt8] {
      try aesECBEncryptCommonCrypto(block: block)
    }

    /// 使用 CommonCrypto 進行 AES-ECB 加密
    private func aesECBEncryptCommonCrypto(block: [UInt8]) throws -> [UInt8] {
      var outBuffer = [UInt8](repeating: 0, count: kCCBlockSizeAES128)
      var numBytesEncrypted: size_t = 0

      let status = CCCrypt(
        CCOperation(kCCEncrypt),
        CCAlgorithm(kCCAlgorithmAES),
        CCOptions(kCCOptionECBMode),
        key, key.count,
        nil, // No IV for ECB
        block, block.count,
        &outBuffer, outBuffer.count,
        &numBytesEncrypted
      )

      guard status == kCCSuccess else {
        throw DecryptionError.cryptoError(status: Int32(status))
      }

      return outBuffer
    }
  }
}

// MARK: - KeyKeyUserDBKit.DecryptionError

extension KeyKeyUserDBKit {
  /// 解密錯誤類型
  public enum DecryptionError: Error, LocalizedError {
    /// 無效的資料庫大小
    case invalidSize(expected: String, actual: Int)
    /// 無效的頁面大小
    case invalidPageSize(expected: Int, actual: Int)
    /// 加密操作失敗
    case cryptoError(status: Int32)
    /// 檔案不存在
    case fileNotFound(path: String)

    // MARK: Public

    /// 錯誤描述
    public var errorDescription: String? {
      switch self {
      case let .invalidSize(expected, actual):
        return "Invalid database size: expected \(expected), got \(actual) bytes"
      case let .invalidPageSize(expected, actual):
        return "Invalid page size: expected \(expected), got \(actual)"
      case let .cryptoError(status):
        return "Crypto operation failed with status: \(status)"
      case let .fileNotFound(path):
        return "File not found: \(path)"
      }
    }
  }
}
