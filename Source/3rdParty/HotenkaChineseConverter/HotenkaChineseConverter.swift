// Swiftified by (c) 2022 and onwards The vChewing Project (MIT-NTL License).
// Rebranded from (c) Nick Chen's Obj-C library "NCChineseConverter" (MIT License).
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

public enum DictType {
  case zhHantTW
  case zhHantHK
  case zhHansSG
  case zhHansJP
  case zhHantKX
  case zhHansCN
}

public class HotenkaChineseConverter {
  private(set) var dict: [String: [String: String]]
  private var dictFiles: [String: [String]]

  public init(plistDir: String) {
    dictFiles = .init()
    do {
      let rawData = try Data(contentsOf: URL(fileURLWithPath: plistDir))
      let rawPlist: [String: [String: String]] =
        try PropertyListSerialization.propertyList(from: rawData, format: nil) as? [String: [String: String]] ?? .init()
      dict = rawPlist
    } catch {
      NSLog("// Exception happened when reading dict plist at: \(plistDir).")
      dict = .init()
    }
  }

  public init(dictDir: String) {
    dictFiles = [
      "zh2TW": [String](),
      "zh2HK": [String](),
      "zh2SG": [String](),
      "zh2JP": [String](),
      "zh2KX": [String](),
      "zh2CN": [String](),
    ]
    dict = [
      "zh2TW": [String: String](),
      "zh2HK": [String: String](),
      "zh2SG": [String: String](),
      "zh2JP": [String: String](),
      "zh2KX": [String: String](),
      "zh2CN": [String: String](),
    ]

    let enumerator = FileManager.default.enumerator(atPath: dictDir)
    guard let filePaths = enumerator?.allObjects as? [String] else { return }
    let arrFiles = filePaths.filter { $0.contains(".txt") }.compactMap { URL(string: dictDir + $0) }
    for theURL in arrFiles {
      let fullFilename = theURL.lastPathComponent
      let mainFilename = (fullFilename as NSString).substring(to: (fullFilename as NSString).range(of: ".").location)

      if var neta = dictFiles[mainFilename] {
        neta.append(theURL.path)
        dictFiles[mainFilename] = neta
      } else {
        dictFiles[mainFilename] = [theURL.path]
      }
    }

    for dictType in dictFiles.keys {
      guard let arrFiles = dictFiles[dictType] else { continue }
      if arrFiles.count <= 0 {
        continue
      }

      for filePath in arrFiles {
        if !FileManager.default.fileExists(atPath: filePath) {
          continue
        }
        do {
          let arrLines = try String(contentsOfFile: filePath, encoding: .utf8).split(separator: "\n")
          for line in arrLines {
            let arrWords = line.split(separator: "\t")
            if arrWords.count == 2 {
              if var theSubDict = dict[dictType] {
                theSubDict[String(arrWords[0])] = String(arrWords[1])
                dict[dictType] = theSubDict
              } else {
                dict[dictType] = .init()
              }
            }
          }
        } catch {
          continue
        }
      }
    }
    sleep(1)
  }

  // MARK: - Public Methods

  func convert(_ target: String, to dictType: DictType) -> String {
    var dictTypeKey: String

    switch dictType {
      case .zhHantTW:
        dictTypeKey = "zh2TW"
      case .zhHantHK:
        dictTypeKey = "zh2HK"
      case .zhHansSG:
        dictTypeKey = "zh2SG"
      case .zhHansJP:
        dictTypeKey = "zh2JP"
      case .zhHantKX:
        dictTypeKey = "zh2KX"
      case .zhHansCN:
        dictTypeKey = "zh2CN"
    }

    var result = ""
    guard let useDict = dict[dictTypeKey] else { return target }

    var i = 0
    while i < (target.count) {
      let max = (target.count) - i
      var j: Int
      j = max

      innerloop: while j > 0 {
        let start = target.index(target.startIndex, offsetBy: i)
        let end = target.index(target.startIndex, offsetBy: i + j)
        guard let useDictSubStr = useDict[String(target[start..<end])] else {
          j -= 1
          continue
        }
        result = result + useDictSubStr
        break innerloop
      }

      if j == 0 {
        let start = target.index(target.startIndex, offsetBy: i)
        let end = target.index(target.startIndex, offsetBy: i + 1)
        result = result + String(target[start..<end])
        i += 1
      } else {
        i += j
      }
    }

    return result
  }
}
