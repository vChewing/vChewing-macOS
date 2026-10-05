#!/usr/bin/env swift

// (c) 2026 and onwards The vChewing Project (MulanPSL-2.0 License).
// ====================
// This code is released under the SPDX-License-Identifier: `MulanPSL-2.0`.

// 自本倉之繁體中文原文副本推得簡體中文原文：**只作字元簡化、語彙一律沿用臺灣用語**
// （`設定 → 设定`、`資料 → 资料`、`視窗 → 视窗`、`滑鼠 → 滑鼠`…）。用法見同目錄之 `README.md`。

import Foundation

private let hantRelativePath = "Sources/vChewingIME_macOS/Resources/shortcuts-src/shortcuts.zh-Hant.md"
private let hansRelativePath = "Sources/vChewingIME_macOS/Resources/shortcuts-src/shortcuts.zh-Hans.md"

/// ICU 之 `Hant-Hans` 未收之字形（實測），就地補正。
private let glyphOverrides: [(traditional: String, simplified: String)] = [
  ("鍵", "键"), ("冊", "册"), ("熱", "热"), ("彙", "汇"), ("體", "体"), ("網", "网"),
  ("臺", "台"), ("灣", "湾"), ("倉", "仓"), ("蝨", "虱"), ("螢", "荧")
]

/// 簡體版 front matter 之註解：本文書群之正文一律 zh-Hant-TW，故不受字元簡化。
private let hansComments = """
# 本檔係 `shortcuts.zh-Hant.md`（官網倉 `vChewing-HomePage.io` 之 `manual/shortcuts.md` 的同步副本）
# 之簡體對位：只作字元簡化、語彙一律沿用臺灣用語。
"""

private func fail(_ message: String) -> Never {
  FileHandle.standardError.write(Data(("!! " + message + "\n").utf8))
  exit(1)
}

/// 切出 front matter（含註解行）與內文。
private func splitFrontMatter(_ text: String) -> (front: [String], body: String)? {
  let lines = text.components(separatedBy: "\n")
  guard lines.first == "---", let closing = lines.dropFirst().firstIndex(of: "---") else {
    return nil
  }
  return (Array(lines[1 ..< closing]), lines[(closing + 1)...].joined(separator: "\n"))
}

let scriptPath = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL.path
let scriptDirectory = URL(fileURLWithPath: scriptPath).deletingLastPathComponent()
let repoRoot = scriptDirectory.deletingLastPathComponent().deletingLastPathComponent().path
let hantPath = repoRoot + "/" + hantRelativePath
let hansPath = repoRoot + "/" + hansRelativePath

guard let hant = try? String(contentsOfFile: hantPath, encoding: .utf8),
      let (front, body) = splitFrontMatter(hant) else {
  fail("讀不到 `\(hantPath)`、或其沒有 front matter。")
}

// 內文逐行簡化；front matter 之鍵逐字保留（其註解另以 `hansComments` 取代）。
var simplified = body.components(separatedBy: "\n").map { line -> String in
  let output = NSMutableString(string: line)
  CFStringTransform(output, nil, "Hant-Hans" as CFString, false)
  return output as String
}.joined(separator: "\n")
for (traditional, simplifiedGlyph) in glyphOverrides {
  simplified = simplified.replacingOccurrences(of: traditional, with: simplifiedGlyph)
}

let keys = front.filter { !$0.hasPrefix("#") }
guard !keys.isEmpty else { fail("`\(hantRelativePath)` 之 front matter 沒有鍵。") }
let result = (["---"] + keys + hansComments.components(separatedBy: "\n") + ["---"])
  .joined(separator: "\n") + "\n" + simplified

guard let data = result.data(using: .utf8) else { fail("簡體版無法以 UTF-8 編碼。") }
do {
  try data.write(to: URL(fileURLWithPath: hansPath))
} catch {
  fail("寫入 `\(hansPath)` 失敗：\(error)")
}

print("→ 已推得 \(hansRelativePath)（\(result.components(separatedBy: "\n").count) 行）。")
