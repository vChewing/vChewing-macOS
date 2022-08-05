#!/usr/bin/env swift

// Copyright (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation

// MARK: - 前導工作

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

// MARK: - StringView Ranges Extension (by Isaac Xen)

extension String {
  fileprivate func ranges(splitBy separator: Element) -> [Range<String.Index>] {
    var startIndex = startIndex
    return split(separator: separator).reduce(into: []) { ranges, substring in
      _ = range(of: substring, range: startIndex..<endIndex).map { range in
        ranges.append(range)
        startIndex = range.upperBound
      }
    }
  }
}

// MARK: - 引入小數點位數控制函式

// Ref: https://stackoverflow.com/a/32581409/4162914
extension Double {
  fileprivate func rounded(toPlaces places: Int) -> Double {
    let divisor = pow(10.0, Double(places))
    return (self * divisor).rounded() / divisor
  }
}

// MARK: - 引入冪乘函式

// Ref: https://stackoverflow.com/a/41581695/4162914
precedencegroup ExponentiationPrecedence {
  associativity: right
  higherThan: MultiplicationPrecedence
}

infix operator **: ExponentiationPrecedence

func ** (_ base: Double, _ exp: Double) -> Double {
  pow(base, exp)
}

// MARK: - 定義檔案結構

struct Unigram: CustomStringConvertible {
  var key: String = ""
  var value: String = ""
  var score: Double = -1.0
  var count: Int = 0
  var description: String {
    "(\(key), \(value), \(score))"
  }
}

// MARK: - 注音加密，減少 plist 體積

func cnvPhonabetToASCII(_ incoming: String) -> String {
  let dicPhonabet2ASCII = [
    "ㄅ": "b", "ㄆ": "p", "ㄇ": "m", "ㄈ": "f", "ㄉ": "d", "ㄊ": "t", "ㄋ": "n", "ㄌ": "l", "ㄍ": "g", "ㄎ": "k", "ㄏ": "h",
    "ㄐ": "j", "ㄑ": "q", "ㄒ": "x", "ㄓ": "Z", "ㄔ": "C", "ㄕ": "S", "ㄖ": "r", "ㄗ": "z", "ㄘ": "c", "ㄙ": "s", "ㄧ": "i",
    "ㄨ": "u", "ㄩ": "v", "ㄚ": "a", "ㄛ": "o", "ㄜ": "e", "ㄝ": "E", "ㄞ": "B", "ㄟ": "P", "ㄠ": "M", "ㄡ": "F", "ㄢ": "D",
    "ㄣ": "T", "ㄤ": "N", "ㄥ": "L", "ㄦ": "R", "ˊ": "2", "ˇ": "3", "ˋ": "4", "˙": "5",
  ]
  var strOutput = incoming
  if !strOutput.contains("_") {
    for Unigram in dicPhonabet2ASCII {
      strOutput = strOutput.replacingOccurrences(of: Unigram.key, with: Unigram.value)
    }
  }
  return strOutput
}

// MARK: - 登記全局根常數變數

private let urlCurrentFolder = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

private let urlCHSforCustom: String = "./components/chs/phrases-custom-chs.txt"
private let urlCHSforTABE: String = "./components/chs/phrases-tabe-chs.txt"
private let urlCHSforMOE: String = "./components/chs/phrases-moe-chs.txt"
private let urlCHSforVCHEW: String = "./components/chs/phrases-vchewing-chs.txt"

private let urlCHTforCustom: String = "./components/cht/phrases-custom-cht.txt"
private let urlCHTforTABE: String = "./components/cht/phrases-tabe-cht.txt"
private let urlCHTforMOE: String = "./components/cht/phrases-moe-cht.txt"
private let urlCHTforVCHEW: String = "./components/cht/phrases-vchewing-cht.txt"

private let urlKanjiCore: String = "./components/common/char-kanji-core.txt"
private let urlMiscBPMF: String = "./components/common/char-misc-bpmf.txt"
private let urlMiscNonKanji: String = "./components/common/char-misc-nonkanji.txt"

private let urlPunctuation: String = "./components/common/data-punctuations.txt"
private let urlSymbols: String = "./components/common/data-symbols.txt"
private let urlZhuyinwen: String = "./components/common/data-zhuyinwen.txt"
private let urlCNS: String = "./components/common/char-kanji-cns.txt"

private let urlPlistSymbols: String = "./data-symbols.plist"
private let urlPlistZhuyinwen: String = "./data-zhuyinwen.plist"
private let urlPlistCNS: String = "./data-cns.plist"

private let urlOutputCHS: String = "./data-chs.txt"
private let urlPlistCHS: String = "./data-chs.plist"
private let urlOutputCHT: String = "./data-cht.txt"
private let urlPlistCHT: String = "./data-cht.plist"

// MARK: - 載入詞組檔案且輸出陣列

func rawDictForPhrases(isCHS: Bool) -> [Unigram] {
  var arrUnigramRAW: [Unigram] = []
  var strRAW = ""
  let urlCustom: String = isCHS ? urlCHSforCustom : urlCHTforCustom
  let urlTABE: String = isCHS ? urlCHSforTABE : urlCHTforTABE
  let urlMOE: String = isCHS ? urlCHSforMOE : urlCHTforMOE
  let urlVCHEW: String = isCHS ? urlCHSforVCHEW : urlCHTforVCHEW
  let i18n: String = isCHS ? "簡體中文" : "繁體中文"
  // 讀取內容
  do {
    strRAW += try String(contentsOfFile: urlCustom, encoding: .utf8)
    strRAW += "\n"
    strRAW += try String(contentsOfFile: urlTABE, encoding: .utf8)
    strRAW += "\n"
    strRAW += try String(contentsOfFile: urlMOE, encoding: .utf8)
    strRAW += "\n"
    strRAW += try String(contentsOfFile: urlVCHEW, encoding: .utf8)
  } catch {
    NSLog(" - Exception happened when reading raw phrases data.")
    return []
  }
  // 預處理格式
  strRAW = strRAW.replacingOccurrences(of: " #MACOS", with: "")  // 去掉 macOS 標記
  // CJKWhiteSpace (\x{3000}) to ASCII Space
  // NonBreakWhiteSpace (\x{A0}) to ASCII Space
  // Tab to ASCII Space
  // 統整連續空格為一個 ASCII 空格
  strRAW.regReplace(pattern: #"( +|　+| +|\t+)+"#, replaceWith: " ")
  strRAW.regReplace(pattern: #"(^ | $)"#, replaceWith: "")  // 去除行尾行首空格
  strRAW.regReplace(pattern: #"(\f+|\r+|\n+)+"#, replaceWith: "\n")  // CR & Form Feed to LF, 且去除重複行
  strRAW.regReplace(pattern: #"^(#.*|.*#WIN32.*)$"#, replaceWith: "")  // 以#開頭的行都淨空+去掉所有 WIN32 特有的行
  // 正式整理格式，現在就開始去重複：
  let arrData = Array(
    NSOrderedSet(array: strRAW.components(separatedBy: "\n")).array as! [String])
  for lineData in arrData {
    // 第三欄開始是注音
    let arrLineData = lineData.components(separatedBy: " ")
    var varLineDataProcessed = ""
    var count = 0
    for currentCell in arrLineData {
      count += 1
      if count < 3 {
        varLineDataProcessed += currentCell + "\t"
      } else if count < arrLineData.count {
        varLineDataProcessed += currentCell + "-"
      } else {
        varLineDataProcessed += currentCell
      }
    }
    // 然後直接乾脆就轉成 Unigram 吧。
    let arrCells: [String] = varLineDataProcessed.components(separatedBy: "\t")
    count = 0  // 不需要再定義，因為之前已經有定義過了。
    var phone = ""
    var phrase = ""
    var occurrence = 0
    for cell in arrCells {
      count += 1
      switch count {
        case 1: phrase = cell
        case 3: phone = cell
        case 2: occurrence = Int(cell) ?? 0
        default: break
      }
    }
    if phrase != "" {  // 廢掉空數據；之後無須再這樣處理。
      arrUnigramRAW += [
        Unigram(
          key: phone, value: phrase, score: 0.0,
          count: occurrence
        )
      ]
    }
  }
  NSLog(" - \(i18n): 成功生成詞語語料辭典（權重待計算）。")
  return arrUnigramRAW
}

// MARK: - 載入單字檔案且輸出陣列

func rawDictForKanjis(isCHS: Bool) -> [Unigram] {
  var arrUnigramRAW: [Unigram] = []
  var strRAW = ""
  let i18n: String = isCHS ? "簡體中文" : "繁體中文"
  // 讀取內容
  do {
    strRAW += try String(contentsOfFile: urlKanjiCore, encoding: .utf8)
  } catch {
    NSLog(" - Exception happened when reading raw core kanji data.")
    return []
  }
  // 預處理格式
  strRAW = strRAW.replacingOccurrences(of: " #MACOS", with: "")  // 去掉 macOS 標記
  // CJKWhiteSpace (\x{3000}) to ASCII Space
  // NonBreakWhiteSpace (\x{A0}) to ASCII Space
  // Tab to ASCII Space
  // 統整連續空格為一個 ASCII 空格
  strRAW.regReplace(pattern: #"( +|　+| +|\t+)+"#, replaceWith: " ")
  strRAW.regReplace(pattern: #"(^ | $)"#, replaceWith: "")  // 去除行尾行首空格
  strRAW.regReplace(pattern: #"(\f+|\r+|\n+)+"#, replaceWith: "\n")  // CR & Form Feed to LF, 且去除重複行
  strRAW.regReplace(pattern: #"^(#.*|.*#WIN32.*)$"#, replaceWith: "")  // 以#開頭的行都淨空+去掉所有 WIN32 特有的行
  // 正式整理格式，現在就開始去重複：
  let arrData = Array(
    NSOrderedSet(array: strRAW.components(separatedBy: "\n")).array as! [String])
  var varLineData = ""
  for lineData in arrData {
    // 簡體中文的話，提取 1,2,4；繁體中文的話，提取 1,3,4。
    let varLineDataPre = lineData.components(separatedBy: " ").prefix(isCHS ? 2 : 1)
      .joined(
        separator: "\t")
    let varLineDataPost = lineData.components(separatedBy: " ").suffix(isCHS ? 1 : 2)
      .joined(
        separator: "\t")
    varLineData = varLineDataPre + "\t" + varLineDataPost
    let arrLineData = varLineData.components(separatedBy: " ")
    var varLineDataProcessed = ""
    var count = 0
    for currentCell in arrLineData {
      count += 1
      if count < 3 {
        varLineDataProcessed += currentCell + "\t"
      } else if count < arrLineData.count {
        varLineDataProcessed += currentCell + "-"
      } else {
        varLineDataProcessed += currentCell
      }
    }
    // 然後直接乾脆就轉成 Unigram 吧。
    let arrCells: [String] = varLineDataProcessed.components(separatedBy: "\t")
    count = 0  // 不需要再定義，因為之前已經有定義過了。
    var phone = ""
    var phrase = ""
    var occurrence = 0
    for cell in arrCells {
      count += 1
      switch count {
        case 1: phrase = cell
        case 3: phone = cell
        case 2: occurrence = Int(cell) ?? 0
        default: break
      }
    }
    if phrase != "" {  // 廢掉空數據；之後無須再這樣處理。
      arrUnigramRAW += [
        Unigram(
          key: phone, value: phrase, score: 0.0,
          count: occurrence
        )
      ]
    }
  }
  NSLog(" - \(i18n): 成功生成單字語料辭典（權重待計算）。")
  return arrUnigramRAW
}

// MARK: - 載入非漢字檔案且輸出陣列

func rawDictForNonKanjis(isCHS: Bool) -> [Unigram] {
  var arrUnigramRAW: [Unigram] = []
  var strRAW = ""
  let i18n: String = isCHS ? "簡體中文" : "繁體中文"
  // 讀取內容
  do {
    strRAW += try String(contentsOfFile: urlMiscBPMF, encoding: .utf8)
    strRAW += "\n"
    strRAW += try String(contentsOfFile: urlMiscNonKanji, encoding: .utf8)
  } catch {
    NSLog(" - Exception happened when reading raw core kanji data.")
    return []
  }
  // 預處理格式
  strRAW = strRAW.replacingOccurrences(of: " #MACOS", with: "")  // 去掉 macOS 標記
  // CJKWhiteSpace (\x{3000}) to ASCII Space
  // NonBreakWhiteSpace (\x{A0}) to ASCII Space
  // Tab to ASCII Space
  // 統整連續空格為一個 ASCII 空格
  strRAW.regReplace(pattern: #"( +|　+| +|\t+)+"#, replaceWith: " ")
  strRAW.regReplace(pattern: #"(^ | $)"#, replaceWith: "")  // 去除行尾行首空格
  strRAW.regReplace(pattern: #"(\f+|\r+|\n+)+"#, replaceWith: "\n")  // CR & Form Feed to LF, 且去除重複行
  strRAW.regReplace(pattern: #"^(#.*|.*#WIN32.*)$"#, replaceWith: "")  // 以#開頭的行都淨空+去掉所有 WIN32 特有的行
  // 正式整理格式，現在就開始去重複：
  let arrData = Array(
    NSOrderedSet(array: strRAW.components(separatedBy: "\n")).array as! [String])
  var varLineData = ""
  for lineData in arrData {
    varLineData = lineData
    // 先完成某兩步需要分行處理才能完成的格式整理。
    varLineData = varLineData.components(separatedBy: " ").prefix(3).joined(
      separator: "\t")  // 提取前三欄的內容。
    let arrLineData = varLineData.components(separatedBy: " ")
    var varLineDataProcessed = ""
    var count = 0
    for currentCell in arrLineData {
      count += 1
      if count < 3 {
        varLineDataProcessed += currentCell + "\t"
      } else if count < arrLineData.count {
        varLineDataProcessed += currentCell + "-"
      } else {
        varLineDataProcessed += currentCell
      }
    }
    // 然後直接乾脆就轉成 Unigram 吧。
    let arrCells: [String] = varLineDataProcessed.components(separatedBy: "\t")
    count = 0  // 不需要再定義，因為之前已經有定義過了。
    var phone = ""
    var phrase = ""
    var occurrence = 0
    for cell in arrCells {
      count += 1
      switch count {
        case 1: phrase = cell
        case 3: phone = cell
        case 2: occurrence = Int(cell) ?? 0
        default: break
      }
    }
    if phrase != "" {  // 廢掉空數據；之後無須再這樣處理。
      arrUnigramRAW += [
        Unigram(
          key: phone, value: phrase, score: 0.0,
          count: occurrence
        )
      ]
    }
  }
  NSLog(" - \(i18n): 成功生成非漢字語料辭典（權重待計算）。")
  return arrUnigramRAW
}

func weightAndSort(_ arrStructUncalculated: [Unigram], isCHS: Bool) -> [Unigram] {
  let i18n: String = isCHS ? "簡體中文" : "繁體中文"
  var arrStructCalculated: [Unigram] = []
  let fscale = 2.7
  var norm = 0.0
  for unigram in arrStructUncalculated {
    if unigram.count >= 0 {
      norm += fscale ** (Double(unigram.value.count) / 3.0 - 1.0)
        * Double(unigram.count)
    }
  }
  // norm 計算完畢，開始將 norm 作為新的固定常數來為每個詞條記錄計算權重。
  // 將新酷音的詞語出現次數數據轉換成小麥引擎可讀的數據形式。
  // 對出現次數小於 1 的詞條，將 0 當成 0.5 來處理、以防止除零。
  for unigram in arrStructUncalculated {
    var weight: Double = 0
    switch unigram.count {
      case -2:  // 拗音假名
        weight = -13
      case -1:  // 單個假名
        weight = -13
      case 0:  // 墊底低頻漢字與詞語
        weight = log10(
          fscale ** (Double(unigram.value.count) / 3.0 - 1.0) * 0.25 / norm)
      default:
        weight = log10(
          fscale ** (Double(unigram.value.count) / 3.0 - 1.0)
            * Double(unigram.count) / norm)  // Credit: MJHsieh.
    }
    let weightRounded: Double = weight.rounded(toPlaces: 3)  // 為了節省生成的檔案體積，僅保留小數點後三位。
    arrStructCalculated += [
      Unigram(
        key: unigram.key, value: unigram.value, score: weightRounded,
        count: unigram.count
      )
    ]
  }
  NSLog(" - \(i18n): 成功計算權重。")
  // ==========================================
  // 接下來是排序，先按照注音遞減排序一遍、再按照權重遞減排序一遍。
  let arrStructSorted: [Unigram] = arrStructCalculated.sorted(by: { lhs, rhs -> Bool in
    (lhs.key, rhs.count) < (rhs.key, lhs.count)
  })
  NSLog(" - \(i18n): 排序整理完畢，準備編譯要寫入的檔案內容。")
  return arrStructSorted
}

func fileOutput(isCHS: Bool) {
  let i18n: String = isCHS ? "簡體中文" : "繁體中文"
  var strPunctuation = ""
  var rangeMap: [String: [Data]] = [:]
  let pathOutput = urlCurrentFolder.appendingPathComponent(
    isCHS ? urlOutputCHS : urlOutputCHT)
  let plistURL = urlCurrentFolder.appendingPathComponent(
    isCHS ? urlPlistCHS : urlPlistCHT)
  var strPrintLine = ""
  // 讀取標點內容
  do {
    strPunctuation = try String(contentsOfFile: urlPunctuation, encoding: .utf8).replacingOccurrences(
      of: "\t", with: " "
    )
    strPrintLine += try String(contentsOfFile: urlPunctuation, encoding: .utf8).replacingOccurrences(
      of: "\t", with: " "
    )
  } catch {
    NSLog(" - \(i18n): Exception happened when reading raw punctuation data.")
  }
  NSLog(" - \(i18n): 成功插入標點符號與西文字母數據（txt）。")
  // 統合辭典內容
  strPunctuation.ranges(splitBy: "\n").forEach {
    let neta = strPunctuation[$0].split(separator: " ")
    let line = String(strPunctuation[$0])
    if neta.count >= 2 {
      let theKey = String(neta[0])
      let theValue = String(neta[1])
      if !neta[0].isEmpty, !neta[1].isEmpty, line.first != "#" {
        rangeMap[cnvPhonabetToASCII(theKey), default: []].append(theValue.data(using: .utf8)!)
      }
    }
  }
  var arrStructUnified: [Unigram] = []
  arrStructUnified += rawDictForKanjis(isCHS: isCHS)
  arrStructUnified += rawDictForNonKanjis(isCHS: isCHS)
  arrStructUnified += rawDictForPhrases(isCHS: isCHS)
  // 計算權重且排序
  arrStructUnified = weightAndSort(arrStructUnified, isCHS: isCHS)

  // 資料重複性檢查
  NSLog(" - \(i18n): 執行資料重複性檢查，會在之後再給出對應的檢查結果。")
  var setAlreadyInserted = Set<String>()
  var arrFoundedDuplications = [String]()

  // 健康狀況檢查
  NSLog(" - \(i18n): 執行資料健康狀況檢查。")
  print(healthCheck(arrStructUnified))
  for unigram in arrStructUnified {
    if setAlreadyInserted.contains(unigram.value + "\t" + unigram.key) {
      arrFoundedDuplications.append(unigram.value + "\t" + unigram.key)
    } else {
      setAlreadyInserted.insert(unigram.value + "\t" + unigram.key)
    }

    let theKey = unigram.key
    let theValue = (String(unigram.score) + " " + unigram.value)
    rangeMap[cnvPhonabetToASCII(theKey), default: []].append(theValue.data(using: .utf8)!)
    strPrintLine +=
      unigram.key + " " + unigram.value + " " + String(unigram.score)
      + "\n"
  }
  NSLog(" - \(i18n): 要寫入檔案的 txt 內容編譯完畢。")
  do {
    try strPrintLine.write(to: pathOutput, atomically: false, encoding: .utf8)
    let plistData = try PropertyListSerialization.data(fromPropertyList: rangeMap, format: .binary, options: 0)
    try plistData.write(to: plistURL)
  } catch {
    NSLog(" - \(i18n): Error on writing strings to file: \(error)")
  }
  NSLog(" - \(i18n): 寫入完成。")
  if !arrFoundedDuplications.isEmpty {
    NSLog(" - \(i18n): 尋得下述重複項目，請務必手動排查：")
    print("-------------------")
    print(arrFoundedDuplications.joined(separator: "\n"))
  }
  print("===================")
}

func commonFileOutput() {
  let i18n = "語言中性"
  var strSymbols = ""
  var strZhuyinwen = ""
  var strCNS = ""
  var mapSymbols: [String: [Data]] = [:]
  var mapZhuyinwen: [String: [Data]] = [:]
  var mapCNS: [String: [Data]] = [:]
  // 讀取標點內容
  do {
    strSymbols = try String(contentsOfFile: urlSymbols, encoding: .utf8).replacingOccurrences(of: "\t", with: " ")
    strZhuyinwen = try String(contentsOfFile: urlZhuyinwen, encoding: .utf8).replacingOccurrences(of: "\t", with: " ")
    strCNS = try String(contentsOfFile: urlCNS, encoding: .utf8).replacingOccurrences(of: "\t", with: " ")
  } catch {
    NSLog(" - \(i18n): Exception happened when reading raw punctuation data.")
  }
  NSLog(" - \(i18n): 成功取得標點符號與西文字母原始資料（plist）。")
  // 統合辭典內容
  strSymbols.ranges(splitBy: "\n").forEach {
    let neta = strSymbols[$0].split(separator: " ")
    let line = String(strSymbols[$0])
    if neta.count >= 2 {
      let theKey = String(neta[1])
      let theValue = String(neta[0])
      if !neta[0].isEmpty, !neta[1].isEmpty, line.first != "#" {
        mapSymbols[cnvPhonabetToASCII(theKey), default: []].append(theValue.data(using: .utf8)!)
      }
    }
  }
  strZhuyinwen.ranges(splitBy: "\n").forEach {
    let neta = strZhuyinwen[$0].split(separator: " ")
    let line = String(strZhuyinwen[$0])
    if neta.count >= 2 {
      let theKey = String(neta[1])
      let theValue = String(neta[0])
      if !neta[0].isEmpty, !neta[1].isEmpty, line.first != "#" {
        mapZhuyinwen[cnvPhonabetToASCII(theKey), default: []].append(theValue.data(using: .utf8)!)
      }
    }
  }
  strCNS.ranges(splitBy: "\n").forEach {
    let neta = strCNS[$0].split(separator: " ")
    let line = String(strCNS[$0])
    if neta.count >= 2 {
      let theKey = String(neta[1])
      let theValue = String(neta[0])
      if !neta[0].isEmpty, !neta[1].isEmpty, line.first != "#" {
        mapCNS[cnvPhonabetToASCII(theKey), default: []].append(theValue.data(using: .utf8)!)
      }
    }
  }
  NSLog(" - \(i18n): 要寫入檔案的內容編譯完畢。")
  do {
    try PropertyListSerialization.data(fromPropertyList: mapSymbols, format: .binary, options: 0).write(
      to: URL(fileURLWithPath: urlPlistSymbols))
    try PropertyListSerialization.data(fromPropertyList: mapZhuyinwen, format: .binary, options: 0).write(
      to: URL(fileURLWithPath: urlPlistZhuyinwen))
    try PropertyListSerialization.data(fromPropertyList: mapCNS, format: .binary, options: 0).write(
      to: URL(fileURLWithPath: urlPlistCNS))
  } catch {
    NSLog(" - \(i18n): Error on writing strings to file: \(error)")
  }
  NSLog(" - \(i18n): 寫入完成。")
}

// MARK: - 主執行緒

func main() {
  NSLog("// 準備編譯符號表情ㄅ文語料檔案。")
  commonFileOutput()
  NSLog("// 準備編譯繁體中文核心語料檔案。")
  fileOutput(isCHS: false)
  NSLog("// 準備編譯簡體中文核心語料檔案。")
  fileOutput(isCHS: true)
}

main()

// MARK: - 辭庫健康狀況檢查專用函式

func healthCheck(_ data: [Unigram]) -> String {
  var result = ""
  var unigramMonoChar = [String: Unigram]()
  var valueToScore = [String: Double]()
  let unigramMonoCharCounter = data.filter { $0.score > -14 && $0.key.split(separator: "-").count == 1 }.count
  let unigramPolyCharCounter = data.filter { $0.score > -14 && $0.key.split(separator: "-").count > 1 }.count

  // 核心字詞庫的內容頻率一般大於 -10，但也得考慮某些包含假名的合成詞。
  for neta in data.filter({ $0.score > -14 }) {
    valueToScore[neta.value] = max(neta.score, valueToScore[neta.value] ?? -14)
    let theKeySliceArr = neta.key.split(separator: "-")
    guard let theKey = theKeySliceArr.first, theKeySliceArr.count == 1 else { continue }
    if unigramMonoChar.keys.contains(String(theKey)), let theRecord = unigramMonoChar[String(theKey)] {
      if neta.score > theRecord.score { unigramMonoChar[String(theKey)] = neta }
    } else {
      unigramMonoChar[String(theKey)] = neta
    }
  }

  var faulty = [Unigram]()
  var indifferents: [(String, String, Double, [Unigram], Double)] = []
  var insufficients: [(String, String, Double, [Unigram], Double)] = []
  var competingUnigrams = [(String, Double, String, Double)]()

  for neta in data.filter({ $0.key.split(separator: "-").count >= 2 && $0.score > -14 }) {
    var competants = [Unigram]()
    var tscore: Double = 0
    var bad = false
    for x in neta.key.split(separator: "-") {
      if !unigramMonoChar.keys.contains(String(x)) {
        bad = true
        break
      }
      guard let u = unigramMonoChar[String(x)] else { continue }
      tscore += u.score
      competants.append(u)
    }
    if bad {
      faulty.append(neta)
      continue
    }
    if tscore >= neta.score {
      let instance = (neta.key, neta.value, neta.score, competants, neta.score - tscore)
      let valueJoined = String(competants.map(\.value).joined(separator: ""))
      if neta.value == valueJoined {
        indifferents.append(instance)
      } else {
        if valueToScore.keys.contains(valueJoined), neta.value != valueJoined {
          if let valueJoinedScore = valueToScore[valueJoined], neta.score < valueJoinedScore {
            competingUnigrams.append((neta.value, neta.score, valueJoined, valueJoinedScore))
          }
        }
        insufficients.append(instance)
      }
    }
  }

  insufficients = insufficients.sorted(by: { lhs, rhs -> Bool in
    (lhs.2) > (rhs.2)
  })
  competingUnigrams = competingUnigrams.sorted(by: { lhs, rhs -> Bool in
    (lhs.1 - lhs.3) > (rhs.1 - rhs.3)
  })

  let separator: String = {
    var result = ""
    for _ in 0..<72 { result += "-" }
    return result
  }()

  func printl(_ input: String) {
    result += input + "\n"
  }

  printl(separator)
  printl("持單個字符的有效單元圖數量：\(unigramMonoCharCounter)")
  printl("持多個字符的有效單元圖數量：\(unigramPolyCharCounter)")

  printl(separator)
  printl("總結一下那些容易被單個漢字的字頻干擾輸入的詞組單元圖：")
  printl("因干擾組件和字詞本身完全重疊、而不需要處理的單元圖的數量：\(indifferents.count)")
  printl(
    "有 \(insufficients.count) 個複字單元圖被自身成分讀音對應的其它單字單元圖奪權，約佔全部有效單元圖的 \(insufficients.count / unigramPolyCharCounter * 100)%，"
  )
  printl("\n其中有：")

  var insufficientsMap = [Int: [(String, String, Double, [Unigram], Double)]]()
  for x in 2...10 {
    insufficientsMap[x] = insufficients.filter { $0.0.split(separator: "-").count == x }
  }

  printl("  \(insufficientsMap[2]?.count ?? 0) 個有效雙字單元圖")
  printl("  \(insufficientsMap[3]?.count ?? 0) 個有效三字單元圖")
  printl("  \(insufficientsMap[4]?.count ?? 0) 個有效四字單元圖")
  printl("  \(insufficientsMap[5]?.count ?? 0) 個有效五字單元圖")
  printl("  \(insufficientsMap[6]?.count ?? 0) 個有效六字單元圖")
  printl("  \(insufficientsMap[7]?.count ?? 0) 個有效七字單元圖")
  printl("  \(insufficientsMap[8]?.count ?? 0) 個有效八字單元圖")
  printl("  \(insufficientsMap[9]?.count ?? 0) 個有效九字單元圖")
  printl("  \(insufficientsMap[10]?.count ?? 0) 個有效十字單元圖")

  if let insufficientsMap2 = insufficientsMap[2], !insufficientsMap2.isEmpty {
    printl(separator)
    printl("前二十五個被奪權的有效雙字單元圖")
    for (i, content) in insufficientsMap2.enumerated() {
      if i == 25 { break }
      var contentToPrint = "{"
      contentToPrint += content.0 + ","
      contentToPrint += content.1 + ","
      contentToPrint += String(content.2) + ","
      contentToPrint += "[" + content.3.map(\.description).joined(separator: ",") + "]" + ","
      contentToPrint += String(content.4) + "}"
      printl(contentToPrint)
    }
  }

  if let insufficientsMap3 = insufficientsMap[3], !insufficientsMap3.isEmpty {
    printl(separator)
    printl("前二十五個被奪權的有效三字單元圖")
    for (i, content) in insufficientsMap3.enumerated() {
      if i == 25 { break }
      var contentToPrint = "{"
      contentToPrint += content.0 + ","
      contentToPrint += content.1 + ","
      contentToPrint += String(content.2) + ","
      contentToPrint += "[" + content.3.map(\.description).joined(separator: ",") + "]" + ","
      contentToPrint += String(content.4) + "}"
      printl(contentToPrint)
    }
  }

  if let insufficientsMap4 = insufficientsMap[4], !insufficientsMap4.isEmpty {
    printl(separator)
    printl("前二十五個被奪權的有效四字單元圖")
    for (i, content) in insufficientsMap4.enumerated() {
      if i == 25 { break }
      var contentToPrint = "{"
      contentToPrint += content.0 + ","
      contentToPrint += content.1 + ","
      contentToPrint += String(content.2) + ","
      contentToPrint += "[" + content.3.map(\.description).joined(separator: ",") + "]" + ","
      contentToPrint += String(content.4) + "}"
      printl(contentToPrint)
    }
  }

  if let insufficientsMap5 = insufficientsMap[5], !insufficientsMap5.isEmpty {
    printl(separator)
    printl("前二十五個被奪權的有效五字單元圖")
    for (i, content) in insufficientsMap5.enumerated() {
      if i == 25 { break }
      var contentToPrint = "{"
      contentToPrint += content.0 + ","
      contentToPrint += content.1 + ","
      contentToPrint += String(content.2) + ","
      contentToPrint += "[" + content.3.map(\.description).joined(separator: ",") + "]" + ","
      contentToPrint += String(content.4) + "}"
      printl(contentToPrint)
    }
  }

  if let insufficientsMap6 = insufficientsMap[6], !insufficientsMap6.isEmpty {
    printl(separator)
    printl("前二十五個被奪權的有效六字單元圖")
    for (i, content) in insufficientsMap6.enumerated() {
      if i == 25 { break }
      var contentToPrint = "{"
      contentToPrint += content.0 + ","
      contentToPrint += content.1 + ","
      contentToPrint += String(content.2) + ","
      contentToPrint += "[" + content.3.map(\.description).joined(separator: ",") + "]" + ","
      contentToPrint += String(content.4) + "}"
      printl(contentToPrint)
    }
  }

  if let insufficientsMap7 = insufficientsMap[7], !insufficientsMap7.isEmpty {
    printl(separator)
    printl("前二十五個被奪權的有效七字單元圖")
    for (i, content) in insufficientsMap7.enumerated() {
      if i == 25 { break }
      var contentToPrint = "{"
      contentToPrint += content.0 + ","
      contentToPrint += content.1 + ","
      contentToPrint += String(content.2) + ","
      contentToPrint += "[" + content.3.map(\.description).joined(separator: ",") + "]" + ","
      contentToPrint += String(content.4) + "}"
      printl(contentToPrint)
    }
  }

  if let insufficientsMap8 = insufficientsMap[8], !insufficientsMap8.isEmpty {
    printl(separator)
    printl("前二十五個被奪權的有效八字單元圖")
    for (i, content) in insufficientsMap8.enumerated() {
      if i == 25 { break }
      var contentToPrint = "{"
      contentToPrint += content.0 + ","
      contentToPrint += content.1 + ","
      contentToPrint += String(content.2) + ","
      contentToPrint += "[" + content.3.map(\.description).joined(separator: ",") + "]" + ","
      contentToPrint += String(content.4) + "}"
      printl(contentToPrint)
    }
  }

  if let insufficientsMap9 = insufficientsMap[9], !insufficientsMap9.isEmpty {
    printl(separator)
    printl("前二十五個被奪權的有效九字單元圖")
    for (i, content) in insufficientsMap9.enumerated() {
      if i == 25 { break }
      var contentToPrint = "{"
      contentToPrint += content.0 + ","
      contentToPrint += content.1 + ","
      contentToPrint += String(content.2) + ","
      contentToPrint += "[" + content.3.map(\.description).joined(separator: ",") + "]" + ","
      contentToPrint += String(content.4) + "}"
      printl(contentToPrint)
    }
  }

  if let insufficientsMap10 = insufficientsMap[10], !insufficientsMap10.isEmpty {
    printl(separator)
    printl("前二十五個被奪權的有效十字單元圖")
    for (i, content) in insufficientsMap10.enumerated() {
      if i == 25 { break }
      var contentToPrint = "{"
      contentToPrint += content.0 + ","
      contentToPrint += content.1 + ","
      contentToPrint += String(content.2) + ","
      contentToPrint += "[" + content.3.map(\.description).joined(separator: ",") + "]" + ","
      contentToPrint += String(content.4) + "}"
      printl(contentToPrint)
    }
  }

  if !competingUnigrams.isEmpty {
    printl(separator)
    printl("也發現有 \(competingUnigrams.count) 個複字單元圖被某些由高頻單字組成的複字單元圖奪權的情況，")
    printl("例如（前二十五例）：")
    for (i, content) in competingUnigrams.enumerated() {
      if i == 25 { break }
      var contentToPrint = "{"
      contentToPrint += content.0 + ","
      contentToPrint += String(content.1) + ","
      contentToPrint += content.2 + ","
      contentToPrint += String(content.3) + "}"
      printl(contentToPrint)
    }
  }

  if !faulty.isEmpty {
    printl(separator)
    printl("下述單元圖用到了漢字核心表當中尚未收錄的讀音，可能無法正常輸入：")
    for content in faulty {
      printl(content.description)
    }
  }

  result += "\n"
  return result
}
