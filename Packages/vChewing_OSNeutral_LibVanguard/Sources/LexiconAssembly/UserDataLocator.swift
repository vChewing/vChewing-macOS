// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation
import SwiftExtension

// MARK: - UserDataLocator

/// 使用者資料之檔案系統存取縫。
///
/// 「使用者資料」指**會被寫回**的那些檔：使用者片語、過濾清單、關聯詞、替換表、以及 POM
/// 之快照與日誌。這些檔的內容隨使用者輸入而變，單元測試一旦真的落在磁碟上，多個測試用例就會
/// 讀寫同一片硬碟區域——症狀是「同一批用例時過時不過」。本協定把「檔案系統」這一層析出為可
/// 替換之存在型別，使測試得以整條路徑改走 ``InMemoryUserDataLocator``（各用例各持一顆、互不
/// 相涉），或以 ``DisabledUserDataLocator`` 讓落盤語意徹底關閉。
///
/// - Important: 縫**只管檔案系統**。唯讀之資源（語料 Cassette、內建資料）與純記憶體快取不走此
///   縫——它們不需要隔離，走了只會讓語意模糊。故 `isBackedByFileSystem` 為假時，呼叫端應一併
///   略過「僅對真實檔案有意義」的前置／善後（例如文字語料之 EOF 修補與整併）。
public protocol UserDataLocator: Sendable {
  /// 此實作是否真的以檔案系統為後端。
  nonisolated var isBackedByFileSystem: Bool { get }

  /// 該路徑是否已存在。
  nonisolated func exists(at url: URL) -> Bool

  /// 讀出該路徑之全部位元組。
  nonisolated func read(at url: URL) throws -> Data

  /// 覆寫該路徑。
  ///
  /// - Note: 檔案系統後端以 `.atomic` 語意落地；記憶體後端即為整筆取代。
  nonisolated func write(_ data: Data, to url: URL) throws

  /// 於該路徑尾端追加位元組；路徑不存在時即建立之。
  nonisolated func append(_ data: Data, to url: URL) throws

  /// 刪除該路徑；不存在時不視為錯誤。
  nonisolated func remove(at url: URL) throws

  /// 該路徑之位元組數；不存在或無法取得時回傳 `nil`。
  nonisolated func byteSize(at url: URL) -> UInt64?
}

// MARK: - Convenience

extension UserDataLocator {
  /// 以 UTF-8 讀出文字；非法位元組一律視為讀取失敗。
  nonisolated public func readText(at url: URL) throws -> String {
    let data = try read(at: url)
    guard let text = String(data: data, encoding: .utf8) else {
      throw CocoaError(
        .fileReadInapplicableStringEncoding,
        userInfo: [NSFilePathErrorKey: url.path]
      )
    }
    return text
  }
}

// MARK: - DiskUserDataLocator

/// ``UserDataLocator`` 之檔案系統後端——生產環境之唯一實作。
public final class DiskUserDataLocator: UserDataLocator, @unchecked Sendable {
  // MARK: Lifecycle

  nonisolated public init() {}

  // MARK: Public

  nonisolated public var isBackedByFileSystem: Bool { true }

  nonisolated public func exists(at url: URL) -> Bool {
    FileManager.default.fileExists(atPath: url.path)
  }

  nonisolated public func read(at url: URL) throws -> Data {
    try Data(contentsOf: url)
  }

  nonisolated public func write(_ data: Data, to url: URL) throws {
    try data.write(to: url, options: .atomic)
  }

  /// - Note: 一律走 `SwiftExtension` 為 macOS 10.9 鋪的 `FileHandle` 相容層
  ///   （`seekToEOF()`／`writeData(_:)`／`closeTheFile()`）——拋錯之新式 API 起自 macOS 10.15.4，
  ///   於 legacy 側之建置目標會直接以 availability 錯誤擋下。
  nonisolated public func append(_ data: Data, to url: URL) throws {
    if !FileManager.default.fileExists(atPath: url.path) {
      FileManager.default.createFile(atPath: url.path, contents: nil)
    }
    let fileHandle = try FileHandle(forWritingTo: url)
    defer { try? fileHandle.closeTheFile() }
    _ = try fileHandle.seekToEOF()
    try fileHandle.writeData(data)
  }

  nonisolated public func remove(at url: URL) throws {
    if FileManager.default.fileExists(atPath: url.path) {
      try FileManager.default.removeItem(at: url)
    }
  }

  nonisolated public func byteSize(at url: URL) -> UInt64? {
    guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path) else {
      return nil
    }
    return (attributes[.size] as? NSNumber)?.uint64Value
  }
}

// MARK: - InMemoryUserDataLocator

/// ``UserDataLocator`` 之記憶體後端：不觸及磁碟、不跨行程，且可逐測試用例各持一份。
///
/// 這是「以語意開關檔案系統」在測試側的著陸點：測試用例只要在起手處把
/// `LXAssembly.userDataLocator` 換成自己的一顆實例，整條使用者資料路徑就不會再碰硬碟。
public final class InMemoryUserDataLocator: UserDataLocator, @unchecked Sendable {
  // MARK: Lifecycle

  nonisolated public init() {}

  // MARK: Public

  nonisolated public var isBackedByFileSystem: Bool { false }

  /// 當前全部路徑之快照（排序後，供診斷與斷言使用）。
  nonisolated public var sortedPaths: [String] {
    storage.withLockRead { $0.keys.sorted() }
  }

  nonisolated public func exists(at url: URL) -> Bool {
    storage.withLockRead { $0[url.path] != nil }
  }

  nonisolated public func read(at url: URL) throws -> Data {
    let path = url.path
    guard let data = storage.withLockRead({ $0[path] }) else {
      throw CocoaError(.fileReadNoSuchFile, userInfo: [NSFilePathErrorKey: path])
    }
    return data
  }

  nonisolated public func write(_ data: Data, to url: URL) throws {
    let path = url.path
    storage.withLock { $0[path] = data }
  }

  nonisolated public func append(_ data: Data, to url: URL) throws {
    let path = url.path
    storage.withLock { dict in
      var existing = dict[path] ?? Data()
      existing.append(data)
      dict[path] = existing
    }
  }

  nonisolated public func remove(at url: URL) throws {
    let path = url.path
    storage.withLock { $0[path] = nil }
  }

  nonisolated public func byteSize(at url: URL) -> UInt64? {
    storage.withLockRead { $0[url.path].map { UInt64($0.count) } }
  }

  // MARK: Private

  private let storage: NSMutex<[String: Data]> = NSMutex([:])
}

// MARK: - DisabledUserDataLocator

/// ``UserDataLocator`` 之停用後端：任何讀寫皆不落地，且讀取一律以「檔案不存在」回應。
///
/// 供「本用例根本不該碰使用者資料」之場合：把縫換成此實作後，一旦被測路徑真的嘗試落盤，
/// 讀取端就會拿到檔案不存在的錯誤，而不是靜默地成功。
public final class DisabledUserDataLocator: UserDataLocator, @unchecked Sendable {
  // MARK: Lifecycle

  nonisolated public init() {}

  // MARK: Public

  nonisolated public var isBackedByFileSystem: Bool { false }

  nonisolated public func exists(at url: URL) -> Bool { false }

  nonisolated public func read(at url: URL) throws -> Data {
    throw CocoaError(.fileReadNoSuchFile, userInfo: [NSFilePathErrorKey: url.path])
  }

  nonisolated public func write(_ data: Data, to url: URL) throws {}

  nonisolated public func append(_ data: Data, to url: URL) throws {}

  nonisolated public func remove(at url: URL) throws {}

  nonisolated public func byteSize(at url: URL) -> UInt64? { nil }
}
