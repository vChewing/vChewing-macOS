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
            let lineIterator = ByteLineIterator(file: fileHandle)
            // 不需要 i=0，因為只取第一行就出結果。
            if let firstLine = lineIterator.nextLine() {
              let strLine = String(decoding: firstLine, as: UTF8.self)
              if strLine != kPragmaHeader {
                vCLMLog("Header Mismatch, Starting In-Place Consolidation.")
                return false
              } else {
                vCLMLog("Header Verification Succeeded: \(strLine).")
                return true
              }
            }
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
      var pragmaResult: Bool {
        let realPragmaHeader = kPragmaHeader + "\n"
        if strProcessed.count <= kPragmaHeader.count { return false }
        let range = 0 ..< (realPragmaHeader.count)
        let fetchedPragma = ContiguousArray(strProcessed.utf8CString[range])
        return fetchedPragma == realPragmaHeader.utf8CString
      }

      if shouldCheckPragma, pragmaResult { return }

      // Step 1: Consolidating formats per line.
      // -------
      // CJKWhiteSpace (\x{3000}) to ASCII Space
      // NonBreakWhiteSpace (\x{A0}) to ASCII Space
      // Tab to ASCII Space
      // 統整連續空格為一個 ASCII 空格
      strProcessed.regReplace(pattern: #"( +|　+| +|\t+)+"#, replaceWith: " ")
      // 去除行尾行首空格
      strProcessed.regReplace(pattern: #"(^ | $)"#, replaceWith: "")
      strProcessed.regReplace(pattern: #"(\n | \n)"#, replaceWith: "\n")
      // CR & FF to LF, 且去除重複行
      strProcessed.regReplace(pattern: #"(\f+|\r+|\n+)+"#, replaceWith: "\n")
      strProcessed.regReplace(pattern: "^\(kPragmaHeader)$", replaceWith: "")
      if strProcessed.prefix(1) == " " { // 去除檔案開頭空格
        strProcessed.removeFirst()
      }
      if strProcessed.suffix(1) == " " { // 去除檔案結尾空格
        strProcessed.removeLast()
      }

      // Step 3: Deduplication.
      let arrData = strProcessed.split(separator: "\n")
      // 下面兩行的 reversed 是首尾顛倒，免得破壞最新的 override 資訊。
      let arrDataDeduplicated = Array(arrData.reversed()).deduplicated
      strProcessed = arrDataDeduplicated.reversed().joined(separator: "\n") + "\n"

      // Step 4: Remove duplicated newlines at the end of the file.
      strProcessed.regReplace(pattern: #"\n+"#, replaceWith: "\n")

      // Step 5: Add pragma header back.
      strProcessed = kPragmaHeader + "\n" + strProcessed // Add Pragma Header
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
            var strProcessed = try String(contentsOf: urlPath, encoding: .utf8)
            consolidate(text: &strProcessed, pragma: shouldCheckPragma)
            // Write consolidated file contents.
            try strProcessed.write(to: urlPath, atomically: false, encoding: .utf8)
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
  }
}
