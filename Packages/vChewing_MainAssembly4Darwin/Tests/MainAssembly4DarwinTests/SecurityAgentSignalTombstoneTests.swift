// (c) 2022 and onwards The vChewing Project (MulanPSL-2.0 License).
// ====================
// This code is released under the SPDX-License-Identifier: `MulanPSL-2.0`.

import Foundation
import Shared
import SwiftExtension
import Testing

@testable import MainAssembly4Darwin

// MARK: - SecurityAgentSignalTombstoneTests

/// 墓碑之兩半：訊號處理器內的手寫十進位，與起動時的解析。
///
/// 前者只跑一次、且跑在不得配置記憶體的場合，故其正確性只能靠測試釘住；後者要能容忍半截之
/// 列（上一輪可能正好寫到一半就被殺）。
struct SecurityAgentSignalTombstoneTests {
  static func renderDecimal(_ value: Int32) -> String {
    withUnsafeTemporaryAllocation(of: UInt8.self, capacity: 64) { buffer in
      let written = securityAgentWriteDecimal(value, into: buffer, at: 0)
      return String(decoding: UnsafeBufferPointer(rebasing: buffer[0 ..< written]), as: UTF8.self)
    }
  }

  @Test
  func testDecimalWriterMatchesStringInterpolation() {
    let samples: [Int32] = [0, 7, 10, 42, 100, 9_999, 12_758, 1_000_000, .max]
    for value in samples {
      #expect(Self.renderDecimal(value) == "\(value)", "value=\(value)")
    }
  }

  @Test
  func testDecimalWriterHandlesNegatives() {
    let samples: [Int32] = [-1, -42, -12_758, .min + 1]
    for value in samples {
      #expect(Self.renderDecimal(value) == "\(value)", "value=\(value)")
    }
  }

  @Test
  func testDecimalWriterStartsAtTheGivenOffset() {
    withUnsafeTemporaryAllocation(of: UInt8.self, capacity: 64) { buffer in
      buffer[0] = 0x58 // X
      let written = securityAgentWriteDecimal(321, into: buffer, at: 1)
      #expect(written == 3)
      let text = String(decoding: UnsafeBufferPointer(rebasing: buffer[0 ..< (1 + written)]), as: UTF8.self)
      #expect(text == "X321")
    }
  }

  @Test
  func testParseAcceptsWellFormedLines() {
    let records = SecurityAgentSignalTombstone.parse("15\t888\n15\t0\n2\t4242\n")
    #expect(records == [
      .init(signal: 15, senderPID: 888),
      .init(signal: 15, senderPID: 0),
      .init(signal: 2, senderPID: 4_242),
    ])
  }

  @Test
  func testParseSkipsMalformedLines() {
    // 第二列係上一輪寫到一半者：訊號已落、PID 未落。
    let text = "15\t888\n15\t\nnot-a-record\n\n9\tx\tz\n"
    #expect(SecurityAgentSignalTombstone.parse(text) == [.init(signal: 15, senderPID: 888)])
  }

  @Test
  func testParseOfEmptyTextIsEmpty() {
    #expect(SecurityAgentSignalTombstone.parse("").isEmpty)
    #expect(SecurityAgentSignalTombstone.parse("\n\n").isEmpty)
  }

  @Test
  func testSupervisedSignalsExcludeTheUncatchableOnes() {
    let supervised = SecurityAgentSignalTombstone.supervisedSignals
    #expect(supervised.contains(SIGTERM))
    #expect(supervised.contains(SIGINT))
    #expect(supervised.contains(SIGHUP))
    #expect(!supervised.contains(SIGKILL))
    // SIGSEGV 一類者屬崩潰，另有系統之 crash report 可稽，故不在此列。
    #expect(!supervised.contains(SIGSEGV))
  }

  @Test
  func testExecutablePathResolvesForTheCurrentProcess() {
    #expect(SecurityAgentSignalTombstone.executablePath(ofSenderPID: getpid()) != nil)
    #expect(SecurityAgentSignalTombstone.executablePath(ofSenderPID: 0) == nil)
    #expect(SecurityAgentSignalTombstone.executablePath(ofSenderPID: -1) == nil)
  }
}
