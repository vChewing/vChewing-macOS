// (c) 2026 and onwards The vChewing Project (MulanPSL-2.0 License).
// ====================
// This code is released under the SPDX-License-Identifier: `MulanPSL-2.0`.

import Foundation
import Testing

/// 護欄：`vChewingKeyLayout.bundle` 內五個 Ukelele 佈局的 **command state**。
///
/// 病灶：`⌘`／`⌃⌘` 系和弦在這些佈局上必須落到拉丁字母表，客體（Chromium 系）才拿得到
/// `c`／`w` 一類字元；若落到注音表或控制字元表，客體的熱鍵即失效（`⌃⌘C` 會得到 `ㄏ`／`0x03`）。
/// Apple 自家的注音佈局（`com.apple.keylayout.ZhuyinBopomofo`／`ZhuyinEten`）在 `⌘`／`⌃⌘` 下一律回
/// 拉丁小寫。故本靶釘住兩件事：
/// ① 每個佈局都存在一條「**必須同時**按住 Command 與 Control」的 `keyMapSelect`，且它**排在**
/// 「只需 Control」那一條之前——IMK 取首個命中者，故此處**位置即判準**；
/// ② 凡 modifier 規格**要求** Command 的條目，其目標 `keyMap` 的字母鍵輸出必須是 ASCII
/// （不得是注音）。
///
/// fixture 以 `#filePath` 錨定工作區根，故無須改動任何 manifest（同 `AssistantContractTests` 之例）。
@Suite(.serialized)
final class KeyLayoutCommandStateTests {
  // MARK: Internal

  @Test
  func testCommandStateMapsToLatinInEveryBundledKeyLayout() throws {
    let names = try FileManager.default.contentsOfDirectory(atPath: Self.layoutDir.path)
      .filter { $0.hasSuffix(".keylayout") }
      .sorted()
    #expect(names.count == 5, "佈局數應為五；實際 \(names)")

    for name in names {
      let xml = try String(contentsOf: Self.layoutDir.appendingPathComponent(name), encoding: .utf8)
      let selects = Self.keyMapSelects(in: xml)
      let maps = Self.keyMaps(in: xml)
      #expect(!selects.isEmpty, "\(name)：解析不到任何 keyMapSelect")

      // ① 同時要求 Command 與 Control 的條目，必須存在、且排在「只要求 Control」者之前。
      let controlOnlyIndex = selects.firstIndex { entry in
        entry.required.contains("control") && !entry.required.contains("command")
      }
      guard let bothIndex = selects.firstIndex(where: {
        $0.required.contains("command") && $0.required.contains("control")
      }) else {
        Issue.record("\(name)：找不到「Command＋Control」的 keyMapSelect（command state 缺口）")
        continue
      }
      if let controlOnlyIndex {
        #expect(
          bothIndex < controlOnlyIndex,
          "\(name)：Command＋Control 條目應排在前（位置即判準）；實得 \(bothIndex) vs \(controlOnlyIndex)"
        )
      }

      // ② 凡要求 Command 者，其目標 map 的字母鍵輸出必須是 ASCII 拉丁字母。
      for entry in selects where entry.required.contains("command") {
        guard let outputs = maps[entry.mapIndex] else {
          Issue.record("\(name)：keyMapSelect 指向不存在的 keyMap \(entry.mapIndex)")
          continue
        }
        for (keyCode, expected) in Self.latinSamples {
          let actual = outputs[keyCode] ?? ""
          #expect(
            actual == expected,
            "\(name)：map\(entry.mapIndex)（\(entry.specs.joined(separator: " ｜ "))）之 keyCode \(keyCode) 應為 \(expected)；實得「\(actual)」"
          )
        }
      }
    }
  }

  // MARK: Private

  private struct Select {
    let mapIndex: String
    let specs: [String]

    var required: Set<String> {
      specs.flatMap { $0.split(separator: " ").map(String.init) }
        .filter { !$0.hasSuffix("?") }
        .reduce(into: Set<String>()) { $0.insert($1) }
    }
  }

  /// 拉丁小寫表在字母鍵上的取值（五個佈局皆同）。
  private static let latinSamples: [Int: String] = [0: "a", 1: "s", 2: "d", 13: "w"]

  private static var layoutDir: URL {
    URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent() // …/MainAssembly4DarwinTests
      .deletingLastPathComponent() // …/Tests
      .deletingLastPathComponent() // …/vChewing_MainAssembly4Darwin
      .deletingLastPathComponent() // …/Packages
      .deletingLastPathComponent() // 工作區根
      .appendingPathComponent(
        "Sources/vChewingIME_macOS/Resources/vChewingKeyLayout.bundle/Contents/Resources"
      )
  }

  private static func keyMapSelects(in xml: String) -> [Select] {
    let pattern = #"<keyMapSelect mapIndex="(\d+)">(.*?)</keyMapSelect>"#
    let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators])
    let ns = xml as NSString
    return (regex?.matches(in: xml, range: NSRange(location: 0, length: ns.length)) ?? []).map { m in
      let index = ns.substring(with: m.range(at: 1))
      let body = ns.substring(with: m.range(at: 2))
      let specs = modifierSpecs(in: body)
      return Select(mapIndex: index, specs: specs)
    }
  }

  private static func modifierSpecs(in body: String) -> [String] {
    let pattern = #"<modifier keys="([^"]*)"\s*/>"#
    let regex = try? NSRegularExpression(pattern: pattern)
    let ns = body as NSString
    return (regex?.matches(in: body, range: NSRange(location: 0, length: ns.length)) ?? [])
      .map { ns.substring(with: $0.range(at: 1)) }
  }

  /// 只取**第一個** `keyMapSet`（＝ANSI 主鍵盤範圍 `first="0" last="17"` 所用者）；
  /// 這些佈局另有一個稀疏的第二 `keyMapSet`，其 map 內容不完整，若一併併入會被覆寫掉。
  private static func keyMaps(in xml: String) -> [String: [Int: String]] {
    let setPattern = #"<keyMapSet[^>]*>(.*?)</keyMapSet>"#
    let setRegex = try? NSRegularExpression(pattern: setPattern, options: [.dotMatchesLineSeparators])
    let xmlNS = xml as NSString
    guard let setMatch = setRegex?.firstMatch(
      in: xml, range: NSRange(location: 0, length: xmlNS.length)
    ) else { return [:] }
    let body = xmlNS.substring(with: setMatch.range(at: 1))

    let pattern = #"<keyMap index="(\d+)"[^>]*>(.*?)</keyMap>"#
    let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators])
    let ns = body as NSString
    var result: [String: [Int: String]] = [:]
    for m in regex?.matches(in: body, range: NSRange(location: 0, length: ns.length)) ?? [] {
      let index = ns.substring(with: m.range(at: 1))
      let mapBody = ns.substring(with: m.range(at: 2))
      let keyPattern = #"<key code="(\d+)" output="([^"]*)"/>"#
      let keyRegex = try? NSRegularExpression(pattern: keyPattern)
      let keyNS = mapBody as NSString
      var outputs: [Int: String] = [:]
      for km in keyRegex?.matches(in: mapBody, range: NSRange(location: 0, length: keyNS.length)) ?? [] {
        guard let code = Int(keyNS.substring(with: km.range(at: 1))) else { continue }
        outputs[code] = keyNS.substring(with: km.range(at: 2))
      }
      if result[index] == nil { result[index] = outputs }
    }
    return result
  }
}
