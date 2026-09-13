// (c) 2022 and onwards The vChewing Project (MulanPSL-2.0 License).
// ====================
// This code is released under the SPDX-License-Identifier: `MulanPSL-2.0`.

import Foundation
@testable import InstallerAssembly4Darwin
import Testing

@Suite
struct InstallerStagingTests {
  @Test
  func testStagingURLLandsInsideGivenDirectory() throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let staging = makeStagingURL(inDirectory: directory)
    #expect(staging.deletingLastPathComponent().standardizedFileURL == directory.standardizedFileURL)
    #expect(!FileManager.default.fileExists(atPath: staging.path))
  }

  @Test
  func testStagingURLIsHiddenSoItCannotBeMistakenForAnInstalledBundle() {
    let staging = makeStagingURL(inDirectory: FileManager.default.temporaryDirectory)
    #expect(staging.lastPathComponent.hasPrefix("."))
  }

  @Test
  func testConsecutiveStagingURLsDoNotCollide() {
    let directory = FileManager.default.temporaryDirectory
    var seen = Set<String>()
    for _ in 0 ..< 64 {
      seen.insert(makeStagingURL(inDirectory: directory).path)
    }
    #expect(seen.count == 64)
  }

  @Test
  func testStagingURLSkipsExistingEntry() throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let first = makeStagingURL(inDirectory: directory)
    try FileManager.default.createDirectory(at: first, withIntermediateDirectories: true)

    let second = makeStagingURL(inDirectory: directory)
    #expect(second != first)
    #expect(!FileManager.default.fileExists(atPath: second.path))
  }

  @Test
  func testRetrySecondsRemainingCountsDownFromDeadline() {
    var config = InstallerUIConfig()
    #expect(config.retrySecondsRemaining == kInstallRetryTimeout)
    config.retryDeadline = Date().addingTimeInterval(3)
    #expect(config.retrySecondsRemaining == 3)
    config.retryDeadline = Date().addingTimeInterval(-1)
    #expect(config.retrySecondsRemaining == 0)
  }
}
