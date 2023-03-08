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
      LMMgr.checkIfUserPhraseExist(userPhrase: value, mode: inputMode, keyArray: keyArray)
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

      let theType: vChewingLM.ReplacableUserDataType = toFilter ? .theFilter : .thePhrases
      let theURL = LMMgr.userDictDataURL(mode: inputMode, type: theType)

      if let writeFile = FileHandle(forUpdatingAtPath: theURL.path),
         let data = "\n\(description)\n".data(using: .utf8)
      {
        writeFile.seekToEndOfFile()
        writeFile.write(data)
        writeFile.closeFile()
      } else {
        return false
      }

      // We enforce the format consolidation here, since the pragma header
      // will let the UserPhraseLM bypasses the consolidating process on load.
      if !vChewingLM.LMConsolidator.consolidate(path: theURL.path, pragma: false) {
        return false
      }

      return true
    }
  }
}
