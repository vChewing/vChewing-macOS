// Copyright (c) 2021 and onwards The vChewing Project (MIT-NTL License).
/*
Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

1. The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

2. No trademark license is granted to use the trade names, trademarks, service
marks, or product names of Contributor, except as required to fulfill notice
requirements above.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

import Foundation

extension vChewing {
  public enum LMConsolidator {
    public static let kPragmaHeader = "# đľđžđđźđ°đ đđđ.đđđđđđđđ¸đđđ.đđđđđ đđđ.đđđđđťđđđđđđđđźđđđđđłđđđ.đđđđđđđđđ"

    /// ćŞ˘ćĽçľŚĺŽćŞćĄçć¨é ­ćŻĺŚć­Łĺ¸¸ă
    /// - Parameter path: çľŚĺŽćŞćĄčˇŻĺžă
    /// - Returns: çľćć­Łĺ¸¸ĺçşçďźĺśé¤çşĺă
    public static func checkPragma(path: String) -> Bool {
      if FileManager.default.fileExists(atPath: path) {
        let fileHandle = FileHandle(forReadingAtPath: path)!
        do {
          let lineReader = try LineReader(file: fileHandle)
          for strLine in lineReader {  // ä¸éčŚ i=0ďźĺ çşçŹŹä¸éčż´ĺĺ°ąĺşçľćă
            if strLine != kPragmaHeader {
              IME.prtDebugIntel("Header Mismatch, Starting In-Place Consolidation.")
              return false
            } else {
              IME.prtDebugIntel("Header Verification Succeeded: \(strLine).")
              return true
            }
          }
        } catch {
          IME.prtDebugIntel("Header Verification Failed: File Access Error.")
          return false
        }
      }
      IME.prtDebugIntel("Header Verification Failed: File Missing.")
      return false
    }

    /// ćŞ˘ćĽćŞćĄćŻĺŚäťĽçŠşčĄçľĺ°žďźĺŚćçźşĺ¤ąĺčŁĺäšă
    /// - Parameter path: çľŚĺŽćŞćĄčˇŻĺžă
    /// - Returns: çľćć­Łĺ¸¸ćäżŽĺžŠé ĺŠĺçşçďźĺśé¤çşĺă
    @discardableResult public static func fixEOF(path: String) -> Bool {
      let urlPath = URL(fileURLWithPath: path)
      if FileManager.default.fileExists(atPath: path) {
        var strIncoming = ""
        do {
          strIncoming += try String(contentsOf: urlPath, encoding: .utf8)
          /// ćł¨ćďźSwift ç LMConsolidator ä¸ŚćŞĺ¨ć­¤ĺŽćĺ° EOF çĺťéč¤ĺˇĽĺşă
          /// ä˝éĺĺ˝ĺźĺˇčĄĺŽäšĺžĺžĺžĺ°ąć consolidate() ć´çć źĺźďźćäťĽä¸ććĺˇŽă
          if !strIncoming.hasSuffix("\n") {
            IME.prtDebugIntel("EOF Fix Necessity Confirmed, Start Fixing.")
            if let writeFile = FileHandle(forUpdatingAtPath: path),
              let endl = "\n".data(using: .utf8)
            {
              writeFile.seekToEndOfFile()
              writeFile.write(endl)
              writeFile.closeFile()
            } else {
              return false
            }
          }
        } catch {
          IME.prtDebugIntel("EOF Fix Failed w/ File: \(path)")
          IME.prtDebugIntel("EOF Fix Failed w/ Error: \(error).")
          return false
        }
        IME.prtDebugIntel("EOF Successfully Ensured (with possible autofixes performed).")
        return true
      }
      IME.prtDebugIntel("EOF Fix Failed: File Missing at \(path).")
      return false
    }

    /// çľąć´çľŚĺŽçćŞćĄçć źĺźă
    /// - Parameters:
    ///   - path: çľŚĺŽćŞćĄčˇŻĺžă
    ///   - shouldCheckPragma: ćŻĺŚĺ¨ćŞćĄć¨é ­ĺŽĺĽ˝çĄćçććłä¸çĽéĺ°ć źĺźçć´çă
    /// - Returns: čĽć´çé ĺŠćçĄé ć´çďźĺçşçďźĺäšçşĺă
    @discardableResult public static func consolidate(path: String, pragma shouldCheckPragma: Bool) -> Bool {
      let pragmaResult = checkPragma(path: path)
      if shouldCheckPragma {
        if pragmaResult {
          return true
        }
      }

      let urlPath = URL(fileURLWithPath: path)
      if FileManager.default.fileExists(atPath: path) {
        var strProcessed = ""
        do {
          strProcessed += try String(contentsOf: urlPath, encoding: .utf8)

          // Step 1: Consolidating formats per line.
          // -------
          // CJKWhiteSpace (\x{3000}) to ASCII Space
          // NonBreakWhiteSpace (\x{A0}) to ASCII Space
          // Tab to ASCII Space
          // çľąć´éŁçşçŠşć źçşä¸ĺ ASCII çŠşć ź
          strProcessed.regReplace(pattern: #"(Â +|ă+| +|\t+)+"#, replaceWith: " ")
          // ĺťé¤čĄĺ°žčĄéŚçŠşć ź
          strProcessed.regReplace(pattern: #"(^ | $)"#, replaceWith: "")
          strProcessed.regReplace(pattern: #"(\n | \n)"#, replaceWith: "\n")
          // CR & FF to LF, ä¸ĺťé¤éč¤čĄ
          strProcessed.regReplace(pattern: #"(\f+|\r+|\n+)+"#, replaceWith: "\n")
          if strProcessed.prefix(1) == " " {  // ĺťé¤ćŞćĄéé ­çŠşć ź
            strProcessed.removeFirst()
          }
          if strProcessed.suffix(1) == " " {  // ĺťé¤ćŞćĄçľĺ°žçŠşć ź
            strProcessed.removeLast()
          }

          // Step 2: Add Formatted Pragma, the Sorted Header:
          if !pragmaResult {
            strProcessed = kPragmaHeader + "\n" + strProcessed  // Add Sorted Header
          }

          // Step 3: Deduplication.
          let arrData = strProcessed.split(separator: "\n")
          // ä¸é˘ĺŠčĄç reversed ćŻéŚĺ°žéĄĺďźĺĺžç ´ĺŁćć°ç override čłč¨ă
          let arrDataDeduplicated = Array(NSOrderedSet(array: arrData.reversed()).array as! [String])
          strProcessed = arrDataDeduplicated.reversed().joined(separator: "\n") + "\n"

          // Step 4: Remove duplicated newlines at the end of the file.
          strProcessed.regReplace(pattern: #"\n+"#, replaceWith: "\n")

          // Step 5: Write consolidated file contents.
          try strProcessed.write(to: urlPath, atomically: false, encoding: .utf8)

        } catch {
          IME.prtDebugIntel("Consolidation Failed w/ File: \(path)")
          IME.prtDebugIntel("Consolidation Failed w/ Error: \(error).")
          return false
        }
        IME.prtDebugIntel("Either Consolidation Successful Or No-Need-To-Consolidate.")
        return true
      }
      IME.prtDebugIntel("Consolidation Failed: File Missing at \(path).")
      return false
    }
  }
}

// MARK: - String Extension

extension String {
  fileprivate mutating func regReplace(pattern: String, replaceWith: String = "") {
    // Ref: https://stackoverflow.com/a/40993403/4162914 && https://stackoverflow.com/a/71291137/4162914
    do {
      let regex = try NSRegularExpression(
        pattern: pattern, options: [.caseInsensitive, .anchorsMatchLines]
      )
      let range = NSRange(startIndex..., in: self)
      self = regex.stringByReplacingMatches(
        in: self, options: [], range: range, withTemplate: replaceWith
      )
    } catch { return }
  }
}
