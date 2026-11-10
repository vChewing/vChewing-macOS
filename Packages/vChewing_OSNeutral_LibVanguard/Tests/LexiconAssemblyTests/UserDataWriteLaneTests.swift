// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

// 使用者資料寫入巷（P345，GH Issue #625）。
//
// 本套房釘死三件事：
// ① 使用者資料檔之讀寫確實發生在**非主執行緒**的寫入巷上，主執行緒只收到結果；
// ② 寫入巷之呼叫是非阻塞的（`withUserDataWriteQueueAsync` 即刻返回）；
// ③ 片語列之落盤器（`UserPhraseFileWriter`）之三種行為（追加、補斷行、NUL 改寫）
//    與其失敗路徑皆如實。
//
// 之所以需要這些測試：這條巷的存在理由是「鍵盤事件鏈路不得被磁碟卡住」，那是一個**排程**
// 性質，功能測試看不出來。故以「誰在哪條佇列上碰了檔案」直接斷言。
//
// **判準一律用 `isOnMainQueue()`、不用 `Thread.isMainThread`**：在 swift-corelibs 平台
// （Linux／Windows）上，主佇列的工作可能由 dispatch worker 執行——那條執行緒之 `isMainThread`
// 為假，卻已持有主佇列之 drain 鎖。用 `Thread.isMainThread` 判「是否在 main」在該兩平台必假、
// 於是「回呼在主佇列」一類斷言必然撲空（GH CI 之 `test-linux-LibVanguard` 即因此轉紅）。

import Foundation
import SwiftExtension
import Testing

@testable import LexiconAssembly

// MARK: - ThreadRecordingLocator

/// 包住另一顆資料通道，記錄「讀／寫當下是否在主執行緒」。
private final class ThreadRecordingLocator: UserDataLocator, @unchecked Sendable {
  // MARK: Lifecycle

  nonisolated init(base: any UserDataLocator) {
    self.base = base
  }

  // MARK: Internal

  nonisolated var isBackedByFileSystem: Bool { base.isBackedByFileSystem }

  nonisolated var readRanOnMainThread: Bool? { storage.withLockRead { $0.read } }
  nonisolated var appendRanOnMainThread: Bool? { storage.withLockRead { $0.append } }

  nonisolated func exists(at url: URL) -> Bool { base.exists(at: url) }

  nonisolated func read(at url: URL) throws -> Data {
    let onMain = isOnMainQueue()
    storage.withLock { $0.read = onMain }
    return try base.read(at: url)
  }

  nonisolated func write(_ data: Data, to url: URL) throws {
    let onMain = isOnMainQueue()
    storage.withLock { $0.write = onMain }
    try base.write(data, to: url)
  }

  nonisolated func append(_ data: Data, to url: URL) throws {
    let onMain = isOnMainQueue()
    storage.withLock { $0.append = onMain }
    try base.append(data, to: url)
  }

  nonisolated func remove(at url: URL) throws { try base.remove(at: url) }

  nonisolated func byteSize(at url: URL) -> UInt64? { base.byteSize(at: url) }

  // MARK: Private

  private struct Record {
    var read: Bool?
    var write: Bool?
    var append: Bool?
  }

  private let base: any UserDataLocator
  private let storage: NSMutex<Record> = .init(Record())
}

// MARK: - ResultBox

/// 供非同步回呼寫入結果之用（`@Sendable` 閉包不得捕獲可變區域變數）。
private final class ResultBox: @unchecked Sendable {
  nonisolated(unsafe) var content: String?
  nonisolated(unsafe) var callbackRanOnMainThread: Bool?
  nonisolated(unsafe) var ranOnMainThread: Bool?
  nonisolated(unsafe) var failures = 0
}

// MARK: - UserDataWriteLaneTests

@Suite("使用者資料寫入巷")
struct UserDataWriteLaneTests {
  // MARK: Internal

  @Test("寫入巷確實在非主執行緒上執行")
  func writeQueueRunsOffMainThread() async {
    let box = ResultBox()
    LXAssembly.withUserDataWriteQueueAsync {
      box.callbackRanOnMainThread = isOnMainQueue()
      box.failures = LXAssembly.isOnUserDataWriteQueue ? 0 : 1
    }
    await waitUntil { box.callbackRanOnMainThread != nil }
    #expect(box.callbackRanOnMainThread == false)
    #expect(box.failures == 0, "工作排入寫入巷之後，`isOnUserDataWriteQueue` 應為真。")
  }

  @Test("寫入巷上之同步包裝就地執行、不再繞回主執行緒")
  func syncWrapperRunsInlineOnWriteQueue() async {
    let box = ResultBox()
    LXAssembly.withUserDataWriteQueueAsync {
      box.ranOnMainThread = LXAssembly.onUserDataWriteQueueSync { isOnMainQueue() }
    }
    await waitUntil { box.ranOnMainThread != nil }
    #expect(box.ranOnMainThread == false)
  }

  @Test("非同步讀檔之 I/O 不在主執行緒、回呼在主執行緒")
  func asyncReadKeepsIOOffMainThread() async throws {
    let url = try makeTemporaryFile(content: "甲 乙\n")
    defer { try? FileManager.default.removeItem(at: url) }
    let recording = ThreadRecordingLocator(base: DiskUserDataLocator())
    let box = ResultBox()

    LXAssembly.readFileContentAsync(
      path: url.path,
      shouldConsolidate: false,
      using: recording,
      completion: { content in
        box.content = content
        box.callbackRanOnMainThread = isOnMainQueue()
      }
    )

    await waitUntil { box.callbackRanOnMainThread != nil }
    #expect(recording.readRanOnMainThread == false, "讀檔不得在主執行緒上發生。")
    #expect(box.content == "甲 乙\n")
    #expect(box.callbackRanOnMainThread == true, "回呼須在主執行緒上交付（語言模組由主執行緒持有）。")
  }

  @Test("非同步讀檔之失敗回呼亦在主執行緒")
  func asyncReadFailureDeliversOnMainThread() async {
    let url = URL(fileURLWithPath: "/vChewing-NoSuchVolume/\(UUID().uuidString).txt")
    let recording = ThreadRecordingLocator(base: DiskUserDataLocator())
    let box = ResultBox()

    LXAssembly.readFileContentAsync(
      path: url.path,
      shouldConsolidate: false,
      using: recording,
      completion: { _ in box.content = "unexpected" },
      onFailure: { box.failures += 1 }
    )

    await waitUntil { box.failures != 0 }
    #expect(box.failures == 1)
    #expect(recording.readRanOnMainThread == false)
  }

  // MARK: - 落盤器

  @Test("追加一列：內容逐位元組如實")
  func appendWritesExactlyOneLine() throws {
    let url = try makeTemporaryFile(content: "")
    defer { try? FileManager.default.removeItem(at: url) }
    let plan = LXAssembly.UserPhraseFileWriter.WritePlan(
      kind: .append,
      targetURL: url,
      cells: ["家主", "ㄐㄧㄚ ㄓㄨ"],
      locator: DiskUserDataLocator()
    )
    #expect(LXAssembly.UserPhraseFileWriter.perform(plan) == .succeeded)
    let content = try String(contentsOf: url, encoding: .utf8)
    #expect(content == "家主 ㄐㄧㄚ ㄓㄨ\n")
  }

  @Test("追加一列：既有內容未以斷行收尾時先補一個斷行")
  func appendRepairsMissingTrailingNewline() throws {
    let url = try makeTemporaryFile(content: "前 列")
    defer { try? FileManager.default.removeItem(at: url) }
    let plan = LXAssembly.UserPhraseFileWriter.WritePlan(
      kind: .append,
      targetURL: url,
      cells: ["後", "ㄏㄡˋ"],
      locator: DiskUserDataLocator()
    )
    #expect(LXAssembly.UserPhraseFileWriter.perform(plan) == .succeeded)
    let content = try String(contentsOf: url, encoding: .utf8)
    #expect(content == "前 列\n後 ㄏㄡˋ\n")
  }

  @Test("追加一列：目標檔不存在時就地建立")
  func appendCreatesMissingTargetFile() throws {
    let folder = FileManager.default.temporaryDirectory
      .appendingPathComponent("vChewingWriteLane-\(UUID().uuidString)")
    let url = folder.appendingPathComponent("userdata-cht.txt")
    defer { try? FileManager.default.removeItem(at: folder) }
    let plan = LXAssembly.UserPhraseFileWriter.WritePlan(
      kind: .append,
      targetURL: url,
      cells: ["新", "ㄒㄧㄣ"],
      locator: DiskUserDataLocator()
    )
    #expect(LXAssembly.UserPhraseFileWriter.perform(plan) == .succeeded)
    let content = try String(contentsOf: url, encoding: .utf8)
    #expect(content == "新 ㄒㄧㄣ\n")
  }

  @Test("自濾除清單移出：命中列就地改寫為 NUL、其餘不動")
  func unfilterBleachesTheRowInPlace() throws {
    let content = "甲 ㄐㄧㄚ\n乙 ㄧˇ\n"
    let url = try makeTemporaryFile(content: content)
    defer { try? FileManager.default.removeItem(at: url) }
    let plan = LXAssembly.UserPhraseFileWriter.WritePlan(
      kind: .unfilter,
      targetURL: url,
      cells: ["乙", "ㄧˇ"],
      locator: DiskUserDataLocator()
    )
    #expect(LXAssembly.UserPhraseFileWriter.perform(plan) == .succeeded)
    let result = try Data(contentsOf: url)
    // 命中列「乙 ㄧˇ」整段換成等長之 NUL；其餘內容原樣保留。
    let pairByteCount = Data("乙 ㄧˇ".utf8).count
    let expectation = Data("甲 ㄐㄧㄚ\n".utf8)
      + Data(repeating: 0, count: pairByteCount)
      + Data("\n".utf8)
    #expect(result == expectation)
  }

  @Test("自濾除清單移出：查無此列時據實失敗")
  func unfilterReportsFailureWhenRowIsAbsent() throws {
    let url = try makeTemporaryFile(content: "甲 ㄐㄧㄚ\n")
    defer { try? FileManager.default.removeItem(at: url) }
    let plan = LXAssembly.UserPhraseFileWriter.WritePlan(
      kind: .unfilter,
      targetURL: url,
      cells: ["丙", "ㄅㄧㄥˇ"],
      locator: DiskUserDataLocator()
    )
    guard case .failed = LXAssembly.UserPhraseFileWriter.perform(plan) else {
      Issue.record("查無此列時應回報失敗。")
      return
    }
  }

  @Test("記憶體後端亦受支援：追加與移出皆不落盤")
  func inMemoryBackendRoundTrips() throws {
    let store = InMemoryUserDataLocator()
    let url = URL(fileURLWithPath: "/vChewing-WriteLaneTest/\(UUID().uuidString).txt")
    let cells = ["家主", "ㄐㄧㄚ-ㄓㄨ"]
    let appendPlan = LXAssembly.UserPhraseFileWriter.WritePlan(
      kind: .append,
      targetURL: url,
      cells: cells,
      locator: store
    )
    #expect(LXAssembly.UserPhraseFileWriter.perform(appendPlan) == .succeeded)
    var content = try store.readText(at: url)
    #expect(content == "家主 ㄐㄧㄚ-ㄓㄨ\n")

    let unfilterPlan = LXAssembly.UserPhraseFileWriter.WritePlan(
      kind: .unfilter,
      targetURL: url,
      cells: cells,
      locator: store
    )
    #expect(LXAssembly.UserPhraseFileWriter.perform(unfilterPlan) == .succeeded)
    content = try store.readText(at: url)
    let blank = String(repeating: "\u{0}", count: cells.joined(separator: " ").utf8.count)
    #expect(content == blank + "\n")
  }

  // MARK: Private

  // MARK: - 輔助

  private func makeTemporaryFile(content: String) throws -> URL {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("vChewingWriteLane-\(UUID().uuidString).txt")
    try Data(content.utf8).write(to: url)
    return url
  }

  /// 讓出主執行緒數拍，直到條件成立或超出上限。
  /// - Important: 不得以信號量等同步手段等待——回呼本身要回到主執行緒排隊。
  private func waitUntil(
    _ condition: () -> Bool,
    limit: Int = 400
  )
    async {
    for _ in 0 ..< limit {
      if condition() { return }
      await Task.yield()
      try? await Task.sleep(nanoseconds: 5_000_000)
    }
  }
}
