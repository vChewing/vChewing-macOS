// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation
import LangModelAssembly
import Shared

// MARK: - 使用者語彙類型定義

public extension LMMgr {
  struct UserPhrase {
    public private(set) var keyArray: [String]
    public private(set) var value: String
    public private(set) var inputMode: Shared.InputMode
    public private(set) var isConverted: Bool = false
    public var weight: Double?

    private var isDuplicated: Bool {
      LMMgr.checkIfPhrasePairExists(userPhrase: value, mode: inputMode, keyArray: keyArray)
    }

    public var description: String {
      var result = [String]()
      result.append(value)
      result.append(keyArray.joined(separator: "-"))
      if let weight = weight {
        result.append(weight.description)
      }
      if isDuplicated {
        result.append("#𝙾𝚟𝚎𝚛𝚛𝚒𝚍𝚎")
      }
      if isConverted {
        result.append("#𝙃𝙪𝙢𝙖𝙣𝘾𝙝𝙚𝙘𝙠𝙍𝙚𝙦𝙪𝙞𝙧𝙚𝙙")
      }
      return result.joined(separator: " ")
    }

    public var crossConverted: UserPhrase {
      if isConverted { return self }
      var result = self
      result.value = ChineseConverter.crossConvert(value)
      result.inputMode = inputMode.reversed
      result.isConverted = true
      return result
    }

    public func write(toFilter: Bool) -> Bool {
      guard LMMgr.chkUserLMFilesExist(inputMode) else { return false }

      /// 施工筆記：
      /// 有些使用者的語彙檔案已經過於龐大了（超過一千行），
      /// 每次寫入時都全文整理格式的話，會引發嚴重的效能問題。
      /// 所以這裡不再強制要求整理格式。
      let theType: vChewingLM.ReplacableUserDataType = toFilter ? .theFilter : .thePhrases
      let theURL = LMMgr.userDictDataURL(mode: inputMode, type: theType)
      var fileSize: UInt64?
      do {
        let dict = try FileManager.default.attributesOfItem(atPath: theURL.path)
        if let value = dict[FileAttributeKey.size] as? UInt64 { fileSize = value }
      } catch {
        return false
      }
      guard let fileSize = fileSize else { return false }
      guard var dataToInsert = "\(description)\n".data(using: .utf8) else { return false }
      guard let writeFile = FileHandle(forUpdatingAtPath: theURL.path) else { return false }
      defer { writeFile.closeFile() }
      if fileSize > 0 {
        writeFile.seek(toFileOffset: fileSize - 1)
        if writeFile.readDataToEndOfFile().first != 0x0A {
          dataToInsert.insert(0x0A, at: 0)
        }
      }
      writeFile.seekToEndOfFile()
      writeFile.write(dataToInsert)
      return true
    }
  }
}
