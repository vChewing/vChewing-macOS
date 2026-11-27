// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation

// MARK: - Usage

let usage = """
vanguard-bench —— 以外部辭典驅動真 InputSession，量測每次按鍵之耗時。

用法：
  swift run VanguardBench --textmap <path> [選項]

必要參數：
  --textmap <path>   `.txtMap` 辭典檔之路徑（本倉不捆原廠辭典，須自外部傳入）。

選項：
  --keys <string>    按鍵序列；每字元即一次 keyDown，`\\n` 為 Enter（預設 `su3\\n`）。
  --count <int>      序列重複次數（預設 100）。
  --warmup <int>     暖機輪數（預設 10；不計入統計）。
  --reset            每輪開始前清空組字狀態（否則第二輪起會量到「狀態飽和後」的低成本）。
  --defaults K=V     以行程級偏好注入一組鍵值；可重複。值先試 bool、次試 int、皆非則字串。
                     用途：量測須切換偏好之功能（如 CNS 模式、狂打）時無須改動生產碼。
  --json             以 JSON 輸出（便於腳本解析）。
  --help             顯示本說明。

輸出：
  單行 `[bench] …`（或 `--json` 之 JSON 物件）至標準輸出；錯誤至標準錯誤，退出碼 2（用法／
  檔案問題）或 3（辭典或引擎問題）。
"""

/// 把換行等控制字元轉成可單行輸出之形式（遞交內容可能含換行）。
func escape(_ text: String) -> String {
  text
    .replacingOccurrences(of: "\n", with: "<CR>")
    .replacingOccurrences(of: "\t", with: "<TAB>")
}

// MARK: - Options

struct Options {
  var textMapPath: String = ""
  var keys: String = "su3\n"
  var count: Int = 100
  var warmup: Int = 10
  var resetEachRound: Bool = false
  var defaults: [(key: String, value: String)] = []
  var json: Bool = false
}

func parse(_ arguments: [String]) -> Options? {
  var options = Options()
  var index = 0
  while index < arguments.count {
    let argument = arguments[index]
    func value() -> String? {
      guard index + 1 < arguments.count else { return nil }
      index += 1
      return arguments[index]
    }
    switch argument {
    case "--help", "-h":
      print(usage)
      exit(0)
    case "--textmap":
      guard let raw = value() else { return nil }
      options.textMapPath = raw
    case "--keys":
      guard let raw = value() else { return nil }
      options.keys = raw.replacingOccurrences(of: "\\n", with: "\n")
    case "--count":
      guard let raw = value(), let number = Int(raw), number > 0 else { return nil }
      options.count = number
    case "--warmup":
      guard let raw = value(), let number = Int(raw), number >= 0 else { return nil }
      options.warmup = number
    case "--reset":
      options.resetEachRound = true
    case "--defaults":
      guard let raw = value(), let separator = raw.firstIndex(of: "=") else { return nil }
      let key = String(raw[raw.startIndex ..< separator])
      let setting = String(raw[raw.index(after: separator)...])
      guard !key.isEmpty else { return nil }
      options.defaults.append((key: key, value: setting))
    case "--json":
      options.json = true
    default:
      return nil
    }
    index += 1
  }
  guard !options.textMapPath.isEmpty else { return nil }
  return options
}

// MARK: - Main

guard let options = parse(Array(CommandLine.arguments.dropFirst())) else {
  FileHandle.standardError.write(Data("參數有誤。\n\n\(usage)\n".utf8))
  exit(2)
}

/// 把 `--defaults` 之鍵值寫進行程級偏好容器。
///
/// `OSUtils.defaultsStore` 之生產值即 `UserDefaults.standard`，故寫入此處即等於使用者偏好
/// 之行程內注入。bool／int 者以原生型別寫入，其餘以字串寫入（`AppProperty` 之解析器負責轉型）。
func applyDefaults(_ defaults: [(key: String, value: String)]) {
  for entry in defaults {
    if entry.value == "true" || entry.value == "false" {
      UserDefaults.standard.set(entry.value == "true", forKey: entry.key)
    } else if let number = Int(entry.value) {
      UserDefaults.standard.set(number, forKey: entry.key)
    } else {
      UserDefaults.standard.set(entry.value, forKey: entry.key)
    }
  }
}

applyDefaults(options.defaults)

if let failure = BenchRunner.prepare(textMapPath: options.textMapPath) {
  FileHandle.standardError.write(Data("\(failure)\n".utf8))
  exit(3)
}

guard let result = BenchRunner.run(
  keys: options.keys,
  count: options.count,
  warmup: options.warmup,
  resetEachRound: options.resetEachRound
) else {
  FileHandle.standardError.write(Data("按鍵序列無可用字元。\n".utf8))
  exit(2)
}

let stats = result.stats
let keysDisplay = escape(options.keys)
let preview = escape(String(result.committed.prefix(12)))
if options.json {
  let perChar = result.perChar
    .sorted { $0.value > $1.value }
    .map { "\"\(escape(String($0.key)))\":\(String(format: "%.1f", $0.value))" }
    .joined(separator: ",")
  print(
    """
    {"textmap":"\(options.textMapPath)","keys":"\(keysDisplay)","count":\(options.count),\
    "n":\(stats.count),"p50":\(String(format: "%.1f", stats.p50)),\
    "p90":\(String(format: "%.1f", stats.p90)),"p99":\(String(format: "%.1f", stats.p99)),\
    "max":\(String(format: "%.1f", stats.max)),\
    "committed":\(result.committed.count),"preview":"\(preview)","perChar":{\(perChar)}}
    """
  )
} else {
  let perChar = result.perChar
    .sorted { $0.value > $1.value }
    .prefix(6)
    .map { String(format: "%@:%.0f", escape(String($0.key)), $0.value) }
    .joined(separator: " ")
  print(
    "[bench] textmap=\"\(options.textMapPath)\" keys=\"\(keysDisplay)\" count=\(options.count)"
      + " n=\(stats.count)"
      + String(
        format: " p50=%.1fµs p90=%.1fµs p99=%.1fµs max=%.1fµs",
        stats.p50, stats.p90, stats.p99, stats.max
      )
      + " committed=\(result.committed.count) preview=\"\(preview)\""
      + " perChar=[\(perChar)]"
  )
}
