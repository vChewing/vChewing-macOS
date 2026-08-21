// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation
import SwiftExtension

// Apple artificially gated the modern FileHandle API names behind macOS 10.15 / 10.15.4,
// even though these APIs have no version restriction on Linux/Windows.
// Use @backDeployed to provide fallbacks on older Darwin via the legacy names.
#if canImport(Darwin)
  nonisolated extension FileHandle {
    @backDeployed(before: macOS 10.15)
    public final func close() throws {
      closeFile()
    }

    @backDeployed(before: macOS 10.15)
    public final func seek(toOffset offset: UInt64) throws {
      seek(toFileOffset: offset)
    }

    @backDeployed(before: macOS 10.15)
    @discardableResult
    public final func seekToEnd() throws -> UInt64 {
      seekToEndOfFile()
    }

    @backDeployed(before: macOS 10.15)
    public final func readToEnd() throws -> Data? {
      let data = readDataToEndOfFile()
      return data.isEmpty ? nil : data
    }

    @backDeployed(before: macOS 10.15)
    public final func write(contentsOf data: Data) throws {
      write(data)
    }
  }
#endif

// MARK: - LMAssembly.LMConsolidator

extension LMAssembly {
  nonisolated public enum LMConsolidator {
    // MARK: Public

    public static let kPragmaHeader =
      "# 𝙵𝙾𝚁𝙼𝙰𝚃 𝚘𝚛𝚐.𝚊𝚝𝚎𝚕𝚒𝚎𝚛𝙸𝚗𝚖𝚞.𝚟𝚌𝚑𝚎𝚠𝚒𝚗𝚐.𝚞𝚜𝚎𝚛𝙻𝚊𝚗𝚐𝚞𝚊𝚐𝚎𝙼𝚘𝚍𝚎𝚕𝙳𝚊𝚝𝚊.𝚏𝚘𝚛𝚖𝚊𝚝𝚝𝚎𝚍"

    /// 檢查給定檔案的標頭是否正常。
    /// - Parameter path: 給定檔案路徑。
    /// - Returns: 結果正常則為真，其餘為假。
    public static func checkPragma(path: String) -> Bool {
      LMAssembly.withFileHandleQueueSync {
        if FileManager.default.fileExists(atPath: path) {
          do {
            guard let fileHandle = FileHandle(forReadingAtPath: path) else {
              throw FileErrors.fileHandleError("")
            }
            defer { try? fileHandle.close() }
            // 純前綴判定：檔頭須與 pragma 的 UTF-8 位元組完全一致，且其後須為斷行或 EOF。
            guard let head = try fileHandle.read(upToCount: kPragmaHeaderBytes.count),
                  head.elementsEqual(kPragmaHeaderBytes) else {
              vCLMLog("Header Mismatch, Starting In-Place Consolidation.")
              return false
            }
            let nextByte = try fileHandle.read(upToCount: 1)?.first
            guard nextByte == nil || nextByte == 0x0A || nextByte == 0x0D else {
              vCLMLog("Header Mismatch, Starting In-Place Consolidation.")
              return false
            }
            vCLMLog("Header Verification Succeeded: \(kPragmaHeader).")
            return true
          } catch {
            vCLMLog("Header Verification Failed: File Access Error.")
            return false
          }
        }
        vCLMLog("Header Verification Failed: File Missing.")
        return false
      }
    }

    /// 檢查檔案是否以空行結尾，如果缺失則補充之。
    /// - Parameter path: 給定檔案路徑。
    /// - Returns: 結果正常或修復順利則為真，其餘為假。
    @discardableResult
    public static func fixEOF(path: String) -> Bool {
      LMAssembly.withFileHandleQueueSync {
        var fileSize: UInt64?
        do {
          let dict = try FileManager.default.attributesOfItem(atPath: path)
          if let value = dict[FileAttributeKey.size] as? UInt64 { fileSize = value }
        } catch {
          vCLMLog("EOF Fix Failed: File Missing at \(path).")
          return false
        }
        guard let fileSize = fileSize else { return false }
        guard let writeFile = FileHandle(forUpdatingAtPath: path) else {
          vCLMLog("EOF Fix Failed: File Not Writable at \(path).")
          return false
        }
        defer { try? writeFile.close() }
        /// 注意：Swift 版 LMConsolidator 並未在此安排對 EOF 的去重複工序。
        /// 但這個函式執行完之後往往就會 consolidate() 整理格式，所以不會有差。
        if fileSize >= 1 {
          try? writeFile.seek(toOffset: fileSize - 1)
        }
        if (try? writeFile.readToEnd())?.first != 0x0A {
          vCLMLog("EOF Missing Confirmed, Start Fixing.")
          var newData = Data()
          newData.append(0x0A)
          try? writeFile.write(contentsOf: newData)
          vCLMLog("EOF Successfully Assured.")
        }
        return true
      }
    }

    /// 統整給定的字串。
    /// - Parameters:
    ///   - text: 操作對象。
    ///   - shouldCheckPragma: 是否在檔案標頭完好無損的情況下略過對格式的整理。
    public static func consolidate(
      text strProcessed: inout String,
      pragma shouldCheckPragma: Bool
    ) {
      if shouldCheckPragma, Self.hasIntactPragmaHeader(bytes: strProcessed.utf8) { return }
      var buffer = [UInt8](strProcessed.utf8)
      buffer = Self.consolidateNormalize(bytes: buffer)
      strProcessed = String(decoding: buffer, as: UTF8.self)
    }

    /// 統整給定的檔案的格式。
    /// - Parameters:
    ///   - path: 給定檔案路徑。
    ///   - shouldCheckPragma: 是否在檔案標頭完好無損的情況下略過對格式的整理。
    /// - Returns: 若整理順利或無須整理，則為真；反之為假。
    @discardableResult
    public static func consolidate(
      path: String,
      pragma shouldCheckPragma: Bool
    )
      -> Bool {
      LMAssembly.withFileHandleQueueSync {
        let pragmaResult = checkPragma(path: path)
        if shouldCheckPragma {
          if pragmaResult {
            return true
          }
        }

        let urlPath = URL(fileURLWithPath: path)
        if FileManager.default.fileExists(atPath: path) {
          do {
            var buffer = [UInt8](try Data(contentsOf: urlPath))
            buffer = Self.consolidateNormalize(bytes: buffer)
            // 以原始位元組寫回：非法 UTF-8 內容原樣保留（不再經 String 解碼轉成 U+FFFD）。
            try Data(buffer).write(to: urlPath)
          } catch {
            vCLMLog("Consolidation Failed w/ File: \(path), error: \(error)")
            return false
          }
          vCLMLog("Either Consolidation Successful Or No-Need-To-Consolidate.")
          return true
        }
        vCLMLog("Consolidation Failed: File Missing at \(path).")
        return false
      }
    }

    // MARK: Internal

    static let kPragmaHeaderBytes = [UInt8](kPragmaHeader.utf8)

    /// 純記憶體版標頭判定：給定內容是否以 pragma 標頭的 UTF-8 位元組開頭、其後為斷行或 EOF。
    /// 與 `checkPragma(path:)` 的語義一致，供 `consolidate(text:pragma:)` 在零配置下短路。
    static func hasIntactPragmaHeader<C: Collection>(bytes: C) -> Bool where C.Element == UInt8 {
      guard bytes.starts(with: kPragmaHeaderBytes) else { return false }
      guard let next = bytes.dropFirst(kPragmaHeaderBytes.count).first else { return true } // EOF 視為通過
      return next == 0x0A || next == 0x0D
    }

    /// 判斷位元組緩衝於指定位置是否為一個完整空白序列（ASCII 空格／Tab／NBSP／全形空格）。
    /// 是則回傳其長度（1–3），否則為 0。
    static func whitespaceSequenceLength(_ bytes: [UInt8], at index: Int) -> Int {
      let b = bytes[index]
      if b == 0x20 || b == 0x09 { return 1 }
      if b == 0xC2, index + 1 < bytes.count, bytes[index + 1] == 0xA0 { return 2 } // NBSP
      if b == 0xE3, index + 2 < bytes.count, bytes[index + 1] == 0x80, bytes[index + 2] == 0x80 { return 3 } // 全形空格
      return 0
    }

    /// 判斷位元組緩衝於指定位置是否為一個 ICU 斷行序列（`^`／`$` 行錨依據）。
    /// 是則回傳其長度（1–3），否則為 0。CRLF 視為單一斷行。
    /// - Remark: ICU 行錨集合含 LF／CR／VT／FF／CRLF／NEL／LS／PS（等同 CharacterSet.newlines）。
    static func lineTerminatorLength(_ bytes: [UInt8], at index: Int) -> Int {
      switch bytes[index] {
      case 0x0A, 0x0B, 0x0C:
        return 1
      case 0x0D:
        return index + 1 < bytes.count && bytes[index + 1] == 0x0A ? 2 : 1
      case 0xC2:
        return index + 1 < bytes.count && bytes[index + 1] == 0x85 ? 2 : 0 // NEL
      case 0xE2:
        if index + 2 < bytes.count, bytes[index + 1] == 0x80,
           bytes[index + 2] == 0xA8 || bytes[index + 2] == 0xA9 { return 3 } // LS／PS
        return 0
      default:
        return 0
      }
    }

    /// Step 1: 將連續空白序列（ASCII 空格／Tab／NBSP／全形空格）收斂為單一 ASCII 空格。
    static func collapseWhitespaceRuns(_ source: [UInt8]) -> [UInt8] {
      var out = [UInt8]()
      out.reserveCapacity(source.count)
      var index = 0
      while index < source.count {
        let length = whitespaceSequenceLength(source, at: index)
        if length == 0 {
          out.append(source[index])
          index += 1
        } else {
          while index < source.count, whitespaceSequenceLength(source, at: index) > 0 {
            index += whitespaceSequenceLength(source, at: index)
          }
          out.append(0x20)
        }
      }
      return out
    }

    /// Step 2: 剝除各行之行首行尾空格（行錨依據 ICU 斷行集合，含檔案首尾）。
    static func stripLineEdgeSpaces(_ source: [UInt8]) -> [UInt8] {
      var out = [UInt8]()
      out.reserveCapacity(source.count)
      var atLineStart = true
      var index = 0
      while index < source.count {
        let b = source[index]
        if b == 0x20 {
          let nextIsLineEnd = index + 1 == source.count
            || lineTerminatorLength(source, at: index + 1) > 0
          if atLineStart || nextIsLineEnd {
            index += 1
            continue
          }
          out.append(b)
          index += 1
        } else {
          let length = lineTerminatorLength(source, at: index)
          if length > 0 {
            out.append(contentsOf: source[index ..< index + length])
            index += length
            atLineStart = true
          } else {
            out.append(b)
            index += 1
            atLineStart = false
          }
        }
      }
      return out
    }

    /// Step 3: 將 LF／CR／FF 斷行連續收斂為單一 LF。
    static func collapseNewlineRuns(_ source: [UInt8]) -> [UInt8] {
      var out = [UInt8]()
      out.reserveCapacity(source.count)
      var index = 0
      while index < source.count {
        let b = source[index]
        if b == 0x0A || b == 0x0D || b == 0x0C {
          while index < source.count, source[index] == 0x0A || source[index] == 0x0D || source[index] == 0x0C {
            index += 1
          }
          out.append(0x0A)
        } else {
          out.append(b)
          index += 1
        }
      }
      return out
    }

    /// 以位元組層級統整內容格式：空白收斂 → 行邊空格剝除 → 斷行收斂 → 移除標頭列 →
    /// 依「保留最後一次出現」去重複 → 補回 pragma 標頭。
    /// - Remark: 全程僅觸及完整 UTF-8 序列，不會切斷多位元組字元。
    static func consolidateNormalize(bytes source: [UInt8]) -> [UInt8] {
      let pass1 = collapseWhitespaceRuns(source)
      let pass2 = stripLineEdgeSpaces(pass1)
      let pass3 = collapseNewlineRuns(pass2)
      // 依 0x0A 分割（省略空列，與舊實作 String.split 一致），並移除內容恰等於 pragma 標頭的列。
      let lines = pass3.split(separator: 0x0A)
      let filteredLines = lines.filter { !$0.elementsEqual(kPragmaHeaderBytes) }
      // 反轉後去重複 = 保留最後一次出現，再反轉回原始順序（不破壞最新的 override 資訊）。
      let deduplicated = Array(filteredLines.reversed()).deduplicated
      var result = [UInt8]()
      result.reserveCapacity(pass3.count)
      for (offset, line) in deduplicated.reversed().enumerated() {
        if offset > 0 { result.append(0x0A) }
        result.append(contentsOf: line)
      }
      result.append(0x0A) // 檔尾斷行
      result = collapseNewlineRuns(result) // 防呆（對應舊 `\n+` → `\n`）
      return kPragmaHeaderBytes + [0x0A] + result // 補回 pragma 標頭
    }
  }
}
