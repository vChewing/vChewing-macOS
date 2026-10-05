#!/usr/bin/env swift

// (c) 2026 and onwards The vChewing Project (MulanPSL-2.0 License).
// ====================
// This code is released under the SPDX-License-Identifier: `MulanPSL-2.0`.

// 將官網倉（`vChewing-HomePage.io`）之 `manual/shortcuts.md` 同步為本倉之繁體中文原文副本：
// 內文與 front matter 之鍵皆以官網倉者為準，另加本產製器所需之註解。用法見同目錄之 `README.md`。

import Foundation

private let mirrorRelativePath = "Sources/vChewingIME_macOS/Resources/shortcuts-src/shortcuts.zh-Hant.md"
private let defaultHomePageRepo = "../../../vChewing-HomePage.io"
private let homePageMarkdownPath = "manual/shortcuts.md"

/// 副本獨有之註解（官網倉不需要、亦不應有）。
private let mirrorComments = """
# 【同步副本】繁體中文之權威原文係官網倉 `vChewing-HomePage.io` 之 `manual/shortcuts.md`；
# 本檔隨 `Scripts/Markdown2HTML/` 之產製流程入庫，以免官網倉不在手邊時無從產製。
# 改動一律先落官網倉、再同步本檔（內文逐字相同；front matter 之鍵亦逐字保留）。
# 本產製器另認 `note-list: ordered|unordered`（官網視為未知鍵）；本檔之導言九條以 `1.` 行之，
# 故無須該鍵。
# 簡體中文版（`shortcuts.zh-Hans.md`）由本檔推得：只作字元簡化、語彙一律沿用臺灣用語。
"""

private func fail(_ message: String) -> Never {
  FileHandle.standardError.write(Data(("!! " + message + "\n").utf8))
  exit(1)
}

let scriptPath = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL.path
let scriptDirectory = URL(fileURLWithPath: scriptPath).deletingLastPathComponent()
let repoRoot = scriptDirectory.deletingLastPathComponent().deletingLastPathComponent().path
let homePageRepo = ProcessInfo.processInfo.environment["VCHEWING_HOMEPAGE"]
  ?? (repoRoot + "/" + defaultHomePageRepo)
let sourcePath = homePageRepo + "/" + homePageMarkdownPath
let mirrorPath = repoRoot + "/" + mirrorRelativePath

guard let source = try? String(contentsOfFile: sourcePath, encoding: .utf8) else {
  fail("讀不到官網倉之 `\(sourcePath)`——可用環境變數 `VCHEWING_HOMEPAGE` 指定其位置。")
}

/// 剝除 front matter 之註解行（官網側不應有，若有亦不帶入副本）。
private func splitFrontMatter(_ text: String) -> (keys: [String], body: String) {
  let lines = text.components(separatedBy: "\n")
  guard lines.first == "---", let closing = lines.dropFirst().firstIndex(of: "---") else {
    return ([], text)
  }
  let keys = lines[1 ..< closing].filter { !$0.hasPrefix("#") }
  return (keys, lines[(closing + 1)...].joined(separator: "\n"))
}

let (keys, body) = splitFrontMatter(source)
guard !keys.isEmpty else { fail("官網倉之 `\(sourcePath)` 沒有 front matter 之鍵。") }

let mirror = (["---"] + keys + mirrorComments.components(separatedBy: "\n") + ["---"])
  .joined(separator: "\n") + "\n" + body
guard let data = mirror.data(using: .utf8) else { fail("副本無法以 UTF-8 編碼。") }
do {
  try data.write(to: URL(fileURLWithPath: mirrorPath))
} catch {
  fail("寫入 `\(mirrorPath)` 失敗：\(error)")
}

let bodyLines = body.components(separatedBy: "\n").count
print("→ 已同步 \(mirrorRelativePath)（內文 \(bodyLines) 行；front matter 鍵 \(keys.count) 個）。")
