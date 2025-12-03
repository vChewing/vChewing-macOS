// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import OSFrameworkImpl
import XCTest

final class OSFrameworkImplExecTests: XCTestCase {
  func testExecEchoReturnsArgument() throws {
    // Use /bin/echo which is available on macOS
    let out = try NSApplication.exec("/bin/echo", args: ["hello-world"])
    XCTAssertTrue(out.contains("hello-world"), "exec should return the echoed output")
  }

  func testExecDoesNotInterpretMetaCharacters() throws {
    // If args are interpreted by a shell, this would output two words.
    let out = try NSApplication.exec("/bin/echo", args: ["hello; echo injected"]) // payload contains a`;` semi-colon
    // The output should be the single string we passed, not `injected` printed separately by a second shell command.
    XCTAssertTrue(
      out.contains("hello; echo injected"),
      "exec should treat the argument as a single argument, not a shell command"
    )
    // The echo output itself may contain the string 'injected' as it is part of the argument; ensure we did not run a shell command to create a file in the previous step.

    // If args are interpreted by a shell, injection might run `touch` and create a file.
    let tmpFile = FileManager.default.temporaryDirectory.appendingPathComponent("vchewing_exec_injected_test")
    try? FileManager.default.removeItem(at: tmpFile)
    let suspiciousArg = "; touch \(tmpFile.path)"
    _ = try NSApplication.exec("/bin/echo", args: [suspiciousArg])
    // The temporary file should NOT exist, as the `touch` should not be executed by exec.
    XCTAssertFalse(
      FileManager.default.fileExists(atPath: tmpFile.path),
      "exec should not invoke shell and thus should not execute the injected 'touch' command"
    )
  }
}
