// Copyright (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// Refactored from the ObjCpp-version of this class by:
// (c) 2011 and onwards The OpenVanilla Project (MIT License).
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
  @frozen public struct LMReplacments {
    var keyValueMap: [String: String] = [:]

    public var count: Int {
      keyValueMap.count
    }

    public init() {
      keyValueMap = [:]
    }

    public func isLoaded() -> Bool {
      !keyValueMap.isEmpty
    }

    @discardableResult public mutating func open(_ path: String) -> Bool {
      if isLoaded() {
        return false
      }

      LMConsolidator.fixEOF(path: path)
      LMConsolidator.consolidate(path: path, pragma: true)

      var arrData: [String] = []

      do {
        arrData = try String(contentsOfFile: path, encoding: .utf8).components(separatedBy: "\n")

      } catch {
        IME.prtDebugIntel("\(error)")
        IME.prtDebugIntel("↑ Exception happened when reading Associated Phrases data.")
        return false
      }

      for (lineID, lineContent) in arrData.enumerated() {
        if !lineContent.hasPrefix("#") {
          let lineContent = lineContent.replacingOccurrences(of: "\t", with: " ")
          if lineContent.components(separatedBy: " ").count < 2 {
            if lineContent != "", lineContent != " " {
              IME.prtDebugIntel("Line #\(lineID + 1) Wrecked: \(lineContent)")
            }
            continue
          }
          var currentKV = Megrez.KeyValuePair()
          for (unitID, unitContent) in lineContent.components(separatedBy: " ").enumerated() {
            switch unitID {
              case 0:
                currentKV.key = unitContent
              case 1:
                currentKV.value = unitContent
              default: break
            }
          }
          keyValueMap[currentKV.key] = currentKV.value
        }
      }
      return true
    }

    public mutating func close() {
      if isLoaded() {
        keyValueMap.removeAll()
      }
    }

    public func dump() {
      var strDump = ""
      for entry in keyValueMap {
        strDump += entry.key + " " + entry.value + "\n"
      }
      IME.prtDebugIntel(strDump)
    }

    public func valuesFor(key: String) -> String {
      keyValueMap[key] ?? ""
    }
  }
}
