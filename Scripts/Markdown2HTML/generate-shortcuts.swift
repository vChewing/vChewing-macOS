#!/usr/bin/env swift

// (c) 2026 and onwards The vChewing Project (MulanPSL-2.0 License).
// ====================
// This code is released under the SPDX-License-Identifier: `MulanPSL-2.0`.

// 唯音輸入法「鍵盤熱鍵使用手冊」（`shortcuts.html`）之產製器：將 Markdown 編譯為輸入法所搭載的
// 單檔 HTML。HTML 之骨架、內嵌樣式與 Markdown 之支援子集皆定義於本檔內（單一出處），各語系之
// 內容則為其 Markdown 原文。用法、參數與所支援之語法見同目錄之 `README.md`。

import Foundation

// MARK: - 常數

/// 輸入法所搭載的四個語系；`folder` 即 `Resources/` 之下 `.lproj` 之名。
private let allLocales: [(id: String, folder: String, output: String, source: Source)] = [
  (
    "zh-Hant", "zh-Hant", "Sources/vChewingIME_macOS/Resources/zh-Hant.lproj/shortcuts.html",
    .homePageMarkdown
  ),
  (
    "zh-Hans", "zh-Hans", "Sources/vChewingIME_macOS/Resources/zh-Hans.lproj/shortcuts.html",
    .localMarkdown("Sources/vChewingIME_macOS/Resources/shortcuts-src/shortcuts.zh-Hans.md")
  ),
]

// MARK: - Source

/// 各語系之 Markdown 原文如何取得。
///
/// - `homePageMarkdown`：官網倉（`vChewing-HomePage.io`）之 `manual/shortcuts.md`——繁體中文之
///   權威出處。其內可能帶有 Jekyll 之 YAML front matter，產製時會剔除。官網倉不在手邊時，退回
///   本倉之同步副本（`Sources/…/shortcuts-src/shortcuts.zh-Hant.md`）；兩者若有落差，以官網倉者為準。
/// - `localMarkdown`：本倉之檔案。簡體中文者即由此維護（僅作字元簡化、語彙沿用臺灣用語）。
private enum Source {
  case homePageMarkdown
  case localMarkdown(String)
}

/// 官網倉之預設位置（相對於本倉根）；可用 `--homepage` 或環境變數 `VCHEWING_HOMEPAGE` 覆寫。
private let defaultHomePageRepo = "../../../vChewing-HomePage.io"
/// 官網倉內該文之落點。
private let homePageMarkdownPath = "manual/shortcuts.md"
/// 繁體中文原文在本倉之同步副本（官網倉不在手邊時的退路）。
private let homePageMarkdownMirror = "Sources/vChewingIME_macOS/Resources/shortcuts-src/shortcuts.zh-Hant.md"

// MARK: - 骨架與樣式

/// HTML 骨架：`{LANG}`／`{TITLE}`／`{STYLE}`／`{BODY}` 為佔位符。
private let htmlTemplate = """
<!doctype html>
<html lang="{LANG}">
  <head>
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
    <title>{TITLE}</title>
    <style>
{STYLE}
    </style>
  </head>
  <body>
{BODY}
  </body>
</html>

"""

/// 內嵌樣式（逐字承襲原手寫版本）。
private let htmlStyle = """
    body {
      font: 15px / 1.4 Tahoma;
    }
    @media (prefers-color-scheme: dark) {
      body {
        background: #333;
        color: white;
      }
    }
    td {
      padding-left: 10px;
      padding-right: 10px;
      min-width: auto;
    }
    td:first-child {
      text-align: right;
    }
    tr:nth-child(odd) {
      background-color: #88888820;
    }
    tr:nth-child(even) {
      background-color: #88888830;
    }
    tr:hover {
      background-color: #88888810;
    }
"""

// MARK: - Block

private enum Block {
  case heading(level: Int, text: String)
  case paragraph(String)
  case orderedList([String])
  case unorderedList([String])
  case table(headers: [String], rows: [[String]])
}

// MARK: - 小工具

private func fail(_ message: String) -> Never {
  FileHandle.standardError.write(Data(("!! " + message + "\n").utf8))
  exit(1)
}

private func note(_ message: String) {
  print(message)
}

private func readText(atPath path: String) -> String? {
  guard let data = FileManager.default.contents(atPath: path) else { return nil }
  // 就地把 CRLF／CR 正規化為 LF：產物一律 LF，且不因來源之行尾而異。
  return String(data: data, encoding: .utf8)?
    .replacingOccurrences(of: "\r\n", with: "\n")
    .replacingOccurrences(of: "\r", with: "\n")
}

private func stripFrontMatter(_ raw: String) -> String {
  splitFrontMatter(raw).body
}

/// 將具名之區域展開為 HTML：`<name attr="…">…</name>` 之單行形。
private func wrapLine(_ name: String, _ content: String, attributes: String = "") -> String {
  let attributes = attributes.isEmpty ? "" : " " + attributes
  return "<\(name)\(attributes)>\(content)</\(name)>"
}

private func wrapMultiline(_ name: String, _ content: String, indent: String = "") -> String {
  let inner = content.components(separatedBy: "\n").map { line -> String in
    line.isEmpty ? line : indent + "  " + line
  }.joined(separator: "\n")
  return "\(indent)<\(name)>\n\(inner)\n\(indent)</\(name)>"
}

/// 逐行重排縮排：凡以 `<tag` 起首者為開標籤（`<tag …/>` 之自閉者除外）、`</tag>` 為閉標籤。
/// 如此各區塊之產生端不必各自盤算縮排，且整份產物之縮排只有本處一處決定。
private func reindented(_ html: String, baseDepth: Int = 0) -> String {
  var depth = baseDepth
  return html.components(separatedBy: "\n").map { line -> String in
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return "" }
    guard trimmed.hasPrefix("<") else { return String(repeating: "  ", count: depth) + trimmed }
    if trimmed.hasPrefix("</") { depth = max(0, depth - 1) }
    let rendered = String(repeating: "  ", count: depth) + trimmed
    let isVoid = trimmed.hasSuffix("/>")
      || trimmed.hasPrefix("<!")
      || trimmed.hasPrefix("<?")
    if !trimmed.hasPrefix("</"), !isVoid, !trimmed.contains("</") {
      depth += 1
    }
    return rendered
  }.joined(separator: "\n")
}

/// 切開表格列：跳脫之 `\|` 不視為分隔、且還原為 `|`。
private func splitTableRow(_ line: String) -> [String] {
  var trimmed = line.trimmingCharacters(in: .whitespaces)
  if trimmed.hasPrefix("|") { trimmed.removeFirst() }
  if trimmed.hasSuffix("|") { trimmed.removeLast() }
  var cells: [String] = []
  var current = ""
  var escaped = false
  for char in trimmed {
    if escaped {
      current.append(char == "|" ? "|" : char)
      escaped = false
    } else if char == "\\" {
      escaped = true
    } else if char == "|" {
      cells.append(current.trimmingCharacters(in: .whitespaces))
      current = ""
    } else {
      current.append(char)
    }
  }
  if escaped { current.append("\\") }
  cells.append(current.trimmingCharacters(in: .whitespaces))
  return cells
}

private func isTableSeparator(_ line: String) -> Bool {
  let trimmed = line.trimmingCharacters(in: .whitespaces)
  guard trimmed.contains("-") else { return false }
  guard trimmed.contains("|") else { return false }
  return trimmed.allSatisfy { "|-: \t".contains($0) }
}

private func isOrderedListItem(_ line: String) -> Bool {
  guard let dot = line.firstIndex(of: ".") else { return false }
  let digits = line[line.startIndex ..< dot]
  guard !digits.isEmpty, digits.allSatisfy(\.isNumber) else { return false }
  guard line.index(after: dot) < line.endIndex else { return false }
  return line[line.index(after: dot)] == " "
}

// MARK: - 行內語法

/// 支援之行內語法：`**粗體**`、`` `程式碼` ``、`<br />`。`&`／`<`／`>` 一律先跳脫。
private func renderInline(_ raw: String) -> String {
  var escaped = raw.replacingOccurrences(of: "&", with: "&amp;")
    .replacingOccurrences(of: "<", with: "&lt;")
    .replacingOccurrences(of: ">", with: "&gt;")
  escaped = replaceCodeSpans(in: escaped)
  escaped = replaceBoldSpans(in: escaped)
  return escaped
}

private func replaceCodeSpans(in text: String) -> String {
  var result = ""
  var rest = Substring(text)
  while let opening = rest.firstIndex(of: "`") {
    let afterOpening = rest.index(after: opening)
    guard let closing = rest[afterOpening...].firstIndex(of: "`") else { break }
    result += rest[..<opening]
    result += wrapLine("code", String(rest[afterOpening ..< closing]))
    rest = rest[rest.index(after: closing)...]
  }
  return result + rest
}

private func replaceBoldSpans(in text: String) -> String {
  var result = ""
  var rest = Substring(text)
  while let opening = rest.range(of: "**") {
    guard let closing = rest.range(of: "**", range: opening.upperBound ..< rest.endIndex) else {
      break
    }
    result += rest[..<opening.lowerBound]
    result += wrapLine("strong", String(rest[opening.upperBound ..< closing.lowerBound]))
    rest = rest[closing.upperBound...]
  }
  return result + rest
}

// MARK: - 區塊解析

private func parseBlocks(_ markdown: String) -> [Block] {
  var blocks: [Block] = []
  var paragraph: [String] = []

  func flushParagraph() {
    guard !paragraph.isEmpty else { return }
    blocks.append(.paragraph(paragraph.joined(separator: "\n")))
    paragraph = []
  }

  let lines = markdown.components(separatedBy: "\n")
  var index = 0
  while index < lines.count {
    let line = lines[index]
    let trimmed = line.trimmingCharacters(in: .whitespaces)

    if trimmed.isEmpty {
      flushParagraph()
      index += 1
      continue
    }

    if trimmed.hasPrefix("#") {
      flushParagraph()
      let level = trimmed.prefix(while: { $0 == "#" }).count
      let text = trimmed.drop(while: { $0 == "#" }).trimmingCharacters(in: .whitespaces)
      blocks.append(.heading(level: min(level, 6), text: text))
      index += 1
      continue
    }

    if trimmed.hasPrefix("|"), index + 1 < lines.count,
       isTableSeparator(lines[index + 1]) {
      flushParagraph()
      let headers = splitTableRow(trimmed)
      var rows: [[String]] = []
      index += 2
      while index < lines.count, lines[index].trimmingCharacters(in: .whitespaces).hasPrefix("|") {
        rows.append(splitTableRow(lines[index]))
        index += 1
      }
      blocks.append(.table(headers: headers, rows: rows))
      continue
    }

    if isOrderedListItem(trimmed) {
      flushParagraph()
      var items: [String] = []
      while index < lines.count, isOrderedListItem(lines[index].trimmingCharacters(in: .whitespaces)) {
        let item = lines[index].trimmingCharacters(in: .whitespaces)
        items.append(String(item[item.index(item.firstIndex(of: ".")!, offsetBy: 2)...]))
        index += 1
      }
      blocks.append(.orderedList(items))
      continue
    }

    if trimmed.hasPrefix("- ") {
      flushParagraph()
      var items: [String] = []
      while index < lines.count, lines[index].trimmingCharacters(in: .whitespaces).hasPrefix("- ") {
        let item = lines[index].trimmingCharacters(in: .whitespaces)
        items.append(String(item.dropFirst(2)))
        index += 1
      }
      blocks.append(.unorderedList(items))
      continue
    }

    paragraph.append(trimmed)
    index += 1
  }
  flushParagraph()
  return blocks
}

/// 去掉清單項開頭之「註N：」——清單本身已提供編號（`註`／`注` 兩形兼收，簡繁皆然）。
private func strippingNoteLabel(_ item: String) -> String {
  guard item.hasPrefix("註") || item.hasPrefix("注") else { return item }
  guard let colon = item.firstIndex(of: "：") else { return item }
  let label = item[item.index(after: item.startIndex) ..< colon]
  guard !label.isEmpty, label.allSatisfy(\.isNumber) else { return item }
  return String(item[item.index(after: colon)...])
}

// MARK: - 區塊渲染

/// 將行內所寫之各式換行標記（`<br />`／`<br/>`／`<br>`／`<br >`）一律正規化為 `<br />`；
/// 原文若以真換行書寫（如段落內之續行）則原樣保留。
private func renderLineBreaks(_ raw: String) -> String {
  var normalized = raw
  for variant in ["<br />", "<br/>", "<br >", "<br>"] {
    normalized = normalized.replacingOccurrences(of: variant, with: "<br />")
  }
  return normalized.components(separatedBy: "<br />")
    .map { renderInline($0.trimmingCharacters(in: .whitespaces)) }
    .joined(separator: "<br />")
}

private func renderTableCell(_ content: String) -> String {
  let parts = renderLineBreaks(content).components(separatedBy: "<br />")
  let inner = parts.map { wrapLine("div", $0) }.joined()
  return wrapLine("td", inner)
}

private func renderTableRow(_ cells: [String], isHeader: Bool) -> String {
  let rendered = cells.map { cell -> String in
    guard isHeader else { return renderTableCell(cell) }
    return wrapLine("td", wrapLine("div", wrapLine("strong", renderInline(cell))))
  }.joined(separator: "\n")
  return """
  <tr>
  \(rendered)
  </tr>
  """
}

private func renderBlock(_ block: Block, options: RenderOptions) -> String {
  switch block {
  case let .heading(level, text):
    return wrapLine("h\(level)", wrapLine("strong", renderInline(text)))
  case let .paragraph(text):
    let lines = text.components(separatedBy: "\n").map { renderLineBreaks($0) }
    return wrapLine("div", lines.joined(separator: "\n"))
  case let .orderedList(items), let .unorderedList(items):
    let isOrdered: Bool
    if case .orderedList = block { isOrdered = options.orderedNotes } else { isOrdered = false }
    let body = items.map { wrapLine("li", renderLineBreaks(strippingNoteLabel($0))) }
      .joined(separator: "\n")
    return wrapMultiline(isOrdered ? "ol" : "ul", body)
  case let .table(headers, rows):
    let body = [renderTableRow(headers, isHeader: true)]
      + rows.map { renderTableRow($0, isHeader: false) }
    return wrapMultiline("table", body.joined(separator: "\n"))
  }
}

private func renderBody(_ blocks: [Block], options: RenderOptions) -> String {
  var lines: [String] = []
  for (index, block) in blocks.enumerated() {
    if index > 0, !(block.isTable || blocks[index - 1].isTable) {
      lines.append("")
    }
    lines.append(contentsOf: renderBlock(block, options: options).components(separatedBy: "\n"))
  }
  return lines.joined(separator: "\n")
}

extension Block {
  fileprivate var isTable: Bool {
    if case .table = self { return true }
    return false
  }
}

// MARK: - 產製

private func compile(markdown: String, localeID: String) -> String {
  let (body, options) = splitFrontMatter(markdown)
  let blocks = parseBlocks(body)
  guard let titleBlock = blocks.first, case let .heading(_, title) = titleBlock else {
    fail("Markdown 之第一個區塊必須是一級標題（`# …`）。")
  }
  let rendered = renderBody(blocks, options: options)
  return htmlTemplate
    .replacingOccurrences(of: "{LANG}", with: localeID)
    .replacingOccurrences(of: "{TITLE}", with: renderInline(title))
    .replacingOccurrences(of: "{STYLE}", with: htmlStyle)
    .replacingOccurrences(of: "{BODY}", with: reindented(rendered, baseDepth: 2))
}

// MARK: - Options

private struct Options {
  var repoRoot: String?
  var homePageRepo: String?
  var locales: [String] = []
  var listOnly = false
  var check = false
  var wantsHelp = false
}

private func parseArguments(_ arguments: [String]) -> Options {
  var options = Options()
  var index = 0
  while index < arguments.count {
    let argument = arguments[index]
    func nextValue(_ name: String) -> String {
      index += 1
      guard index < arguments.count else { fail("`\(name)` 缺少參數值。") }
      return arguments[index]
    }
    switch argument {
    case "--help", "-h": options.wantsHelp = true
    case "--list": options.listOnly = true
    case "--check": options.check = true
    case "--locale", "-l": options.locales.append(nextValue(argument))
    case "--repo-root": options.repoRoot = nextValue(argument)
    case "--homepage": options.homePageRepo = nextValue(argument)
    default:
      if argument.hasPrefix("-") { fail("不認得的參數：`\(argument)`。") }
      options.locales.append(argument)
    }
    index += 1
  }
  return options
}

private let usage = """
usage: generate-shortcuts.swift [選項] [語系 …]

將 Markdown 編譯為輸入法所搭載的 `shortcuts.html`。不指定語系時產製全部。

選項：
  -l, --locale <id>     只產製該語系（可重複；同位置參數）
      --list            只列出語系、其原文來源與產物，不寫入
      --check           只比對產物是否為最新（有落差即以非零值收場）
      --repo-root <dir> vChewing-macOS 倉根（預設自本檔位置推得）
      --homepage <dir>  vChewing-HomePage.io 倉根（預設 \(defaultHomePageRepo)，
                        亦可用環境變數 VCHEWING_HOMEPAGE 指定）
  -h, --help            顯示本說明

語系：\(allLocales.map(\.id).joined(separator: "／"))

"""

/// 自本檔之位置推得 vChewing-macOS 之倉根：`<root>/Scripts/Markdown2HTML/<本檔>`。
private func inferRepoRoot() -> String {
  let scriptPath = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL.path
  let scriptDirectory = URL(fileURLWithPath: scriptPath).deletingLastPathComponent()
  return scriptDirectory.deletingLastPathComponent().deletingLastPathComponent().path
}

extension String {
  /// 就地正規化為一顆無多餘 `..`／`.` 段之絕對路徑。
  fileprivate func standardizedRepoRoot() -> String {
    URL(fileURLWithPath: self).standardizedFileURL.path
  }
}

// MARK: - RenderOptions

/// 產製設定：取自 Markdown 之 YAML front matter。官網之該文原有 front matter 供 Jekyll 用，
/// 本產製器另讀 `note-list`（未知鍵，於官網無作用）以決定導言清單之形制。
private struct RenderOptions {
  /// 導言清單之形制：`ordered`（`<ol>`，預設）或 `unordered`（`<ul>`）；由 `note-list` 設定。
  var orderedNotes = true
}

/// 剝除 front matter 並讀取其內之產製設定。
private func splitFrontMatter(_ raw: String) -> (body: String, options: RenderOptions) {
  var options = RenderOptions()
  let lines = raw.components(separatedBy: "\n")
  guard lines.first?.trimmingCharacters(in: .whitespaces) == "---" else { return (raw, options) }
  guard let closing = lines.dropFirst().firstIndex(where: {
    $0.trimmingCharacters(in: .whitespaces) == "---"
  }) else { return (raw, options) }
  for line in lines[1 ..< closing] {
    let pair = line.split(separator: ":", maxSplits: 1).map {
      $0.trimmingCharacters(in: .whitespaces)
    }
    guard pair.count == 2, pair[0] == "note-list" else { continue }
    if pair[1] == "unordered" { options.orderedNotes = false }
  }
  return (lines[(closing + 1)...].joined(separator: "\n"), options)
}

/// 該語系原文之候選路徑（依序取第一個存在者）。
private func sourceCandidates(
  _ source: Source,
  repoRoot: String,
  homePageRepo: String
)
  -> [String] {
  switch source {
  case .homePageMarkdown:
    return [homePageRepo + "/" + homePageMarkdownPath, repoRoot + "/" + homePageMarkdownMirror]
  case let .localMarkdown(relativePath):
    return [repoRoot + "/" + relativePath]
  }
}

// MARK: - 進入點

private func main() {
  let options = parseArguments(Array(CommandLine.arguments.dropFirst()))
  if options.wantsHelp {
    print(usage)
    exit(0)
  }

  let repoRoot = (options.repoRoot ?? inferRepoRoot()).standardizedRepoRoot()
  let rawHomePageRepo = options.homePageRepo
    ?? ProcessInfo.processInfo.environment["VCHEWING_HOMEPAGE"]
    ?? defaultHomePageRepo
  // 相對之官網倉路徑以本倉根為錨；`..` 之類一律就地正規化，免得訊息內的路徑難讀。
  let homePageRepo = rawHomePageRepo.hasPrefix("/")
    ? rawHomePageRepo.standardizedRepoRoot()
    : (repoRoot + "/" + rawHomePageRepo).standardizedRepoRoot()

  guard FileManager.default.fileExists(atPath: repoRoot + "/Package.swift") else {
    fail("`\(repoRoot)` 之下沒有 `Package.swift`——請以 `--repo-root` 指定 vChewing-macOS 倉根。")
  }

  let selected = allLocales.filter { locale in
    options.locales.isEmpty || options.locales.contains(locale.id)
  }
  for requested in options.locales where !allLocales.contains(where: { $0.id == requested }) {
    fail("不認得的語系：`\(requested)`。")
  }

  if options.listOnly {
    for locale in allLocales {
      let candidates = sourceCandidates(
        locale.source, repoRoot: repoRoot, homePageRepo: homePageRepo
      )
      let existing = candidates.first { FileManager.default.fileExists(atPath: $0) }
      let list = candidates.enumerated().map { index, path -> String in
        let mark = FileManager.default.fileExists(atPath: path) ? " " : "✗"
        return "\(mark) \(index == 0 ? " " : "↳") \(path)"
      }.joined(separator: "\n   ")
      note("• \(locale.folder) ⇒ \(locale.output)\(existing == nil ? "  ← 讀不到原文！" : "")")
      note("   \(list)")
    }
    exit(0)
  }

  var stale = 0
  for locale in selected {
    let candidates = sourceCandidates(
      locale.source, repoRoot: repoRoot, homePageRepo: homePageRepo
    )
    guard let sourcePath = candidates.first(where: { FileManager.default.fileExists(atPath: $0) })
    else {
      if case .homePageMarkdown = locale.source {
        fail(
          "讀不到繁體中文之原文——官網倉（`\(candidates[0])`）與本倉之副本"
            + "（`\(candidates[1])`）皆不存在。請以 `--homepage` 指定 vChewing-HomePage.io 之位置。"
        )
      }
      fail("讀不到 `\(candidates[0])`。")
    }
    if sourcePath != candidates[0] {
      note("※ \(locale.id)：官網倉之原文不在手邊，改用本倉之同步副本（\(sourcePath)）。")
    }
    guard let raw = readText(atPath: sourcePath) else { fail("讀不到 `\(sourcePath)`。") }
    let html = compile(markdown: raw, localeID: locale.id)
    let outputPath = repoRoot + "/" + locale.output

    if options.check {
      let existing = readText(atPath: outputPath)
      if existing == html {
        note("✓ \(locale.id)：產物為最新。")
      } else {
        note("✗ \(locale.id)：產物與 Markdown 原文不一致（\(locale.output)）。")
        stale += 1
      }
      continue
    }

    guard let data = html.data(using: .utf8) else { fail("產物無法以 UTF-8 編碼。") }
    do {
      try data.write(to: URL(fileURLWithPath: outputPath))
    } catch {
      fail("寫入 `\(outputPath)` 失敗：\(error)")
    }
    note("→ \(locale.id)：\(locale.output)")
  }

  if options.check, stale > 0 { exit(1) }
}

main()
