// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import AppKit
import OSFrameworkImpl
import Testing

@Suite(.serialized)
struct OSFrameworkImplExecTests {
  @Test
  func testExecEchoReturnsArgument() throws {
    // 使用 macOS 上可用的 /bin/echo
    let out = try NSApplication.exec("/bin/echo", args: ["hello-world"])
    #expect(out.contains("hello-world"), "exec should return the echoed output")
  }

  @Test
  func testExecDoesNotInterpretMetaCharacters() throws {
    // 若 args 被 shell 解析，會輸出兩個單詞。
    let out = try NSApplication.exec("/bin/echo", args: ["hello; echo injected"]) // payload 包含 `;` 分號
    // 輸出應該是我們傳遞的單一字串，而非由第二個 shell 指令分別印出 `injected`。
    #expect(
      out.contains("hello; echo injected"),
      "exec should treat the argument as a single argument, not a shell command"
    )
    // echo 輸出本身可能包含字串 'injected'，因為它是參數的一部分；
    // 確保我們在前一步驟中沒有執行 shell 指令來建立檔案。

    // 若 args 被 shell 解析，注入可能會執行 `touch` 並建立檔案。
    let tmpFile = FileManager.default.temporaryDirectory.appendingPathComponent("vchewing_exec_injected_test")
    try? FileManager.default.removeItem(at: tmpFile)
    let suspiciousArg = "; touch \(tmpFile.path)"
    _ = try NSApplication.exec("/bin/echo", args: [suspiciousArg])
    // 臨時檔案應該不存在，因為 `touch` 不應該被 exec 執行。
    #expect(
      !FileManager.default.fileExists(atPath: tmpFile.path),
      "exec should not invoke shell and thus should not execute the injected 'touch' command"
    )
  }
}
