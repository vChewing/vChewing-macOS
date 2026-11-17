// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation
import SwiftExtension
import Testing

// MARK: - LibVanguardTestsRoot.SwiftExtensionLogWriteLaneTests

// 歸入本測試目標唯一根 suite（見 `LibVanguardTests_Root.swift`）；各 suite 自持 `TestEnvironment`（P316），故可並行。
extension LibVanguardTestsRoot {
  /// 系統記錄之寫入巷：次序、有界、非阻塞、重入。
  ///
  /// 本型別之所以存在，是要讓 `os_log`／`NSLog` 之同步寫入離開 IMK 事件鏈路。故這裡要守的
  /// 不是「寫得快」，而是**生產端永不被寫出端拖住**——寫出端被卡住時，入列仍須立即返回，
  /// 且記憶體不得隨積壓無限增長。
  @Suite("SwiftExtensionLogWriteLaneTests")
  struct SwiftExtensionLogWriteLaneTests {
    /// 入列之次序即寫出之次序（單一生產者）。
    @Test
    func testLaneWritesInEnqueueOrder() {
      let sink = LogLineSink()
      let lane = LogWriteLane(label: "org.vChewing.tests.order") { sink.append($0) }
      for index in 0 ..< 200 {
        lane.enqueue("line \(index)")
      }
      lane.flush()
      lane.flush() // 空排空亦不得出事
      #expect(sink.lines == (0 ..< 200).map { "line \($0)" })
      #expect(lane.pendingLineCount == 0)
      #expect(lane.droppedLineCount == 0)
    }

    /// 寫出端被卡住時，入列仍立刻返回；積壓以 `capacity` 為界，超出者丟棄並計數。
    ///
    /// 「立刻返回」以「於另一條執行緒入列、並以逾時觀察其返回」證明：若入列會就地寫出，
    /// 該執行緒即卡在寫出端，逾時檢查便會失敗（且不會把整個測試行程吊死）。
    @Test
    func testLaneNeverBlocksItsProducer() {
      let gate = DispatchSemaphore(value: 0)
      let enteredWriter = DispatchSemaphore(value: 0)
      let state = LogLineSink(gate: gate) { enteredWriter.signal() }
      let capacity = 8
      let lane = LogWriteLane(label: "org.vChewing.tests.bounded", capacity: capacity) {
        state.append($0)
      }
      defer { gate.signal() }

      let producerDone = DispatchSemaphore(value: 0)
      Thread.detachNewThread {
        lane.enqueue("blocker")
        producerDone.signal()
      }
      let producerReturned = producerDone.wait(timeout: .now() + 10)
      #expect(producerReturned == .success)
      let writerEntered = enteredWriter.wait(timeout: .now() + 10)
      #expect(writerEntered == .success)

      // 此刻寫出端正卡在閉包裡；以下 100 次入列不得被它拖住。
      let startedAt = Date()
      for index in 0 ..< 100 {
        lane.enqueue("line \(index)")
      }
      let elapsed = Date().timeIntervalSince(startedAt)
      #expect(elapsed < 0.5)
      #expect(lane.pendingLineCount == capacity)
      #expect(lane.droppedLineCount == 100 - capacity)

      gate.signal()
      lane.flush()
      // 首批（阻塞的那一則）先出，其次才是丟棄通知與倖存之各列。
      #expect(state.lines.first == "blocker")
      #expect(state.lines.count == 1 + 1 + capacity)
      #expect(state.lines[1].hasPrefix("[LogWriteLane] dropped 92 line(s)"))
      #expect(Array(state.lines.suffix(capacity)) == (0 ..< capacity).map { "line \($0)" })
    }

    /// 於寫出巷自身之執行緒上呼叫 `flush()` 不得自死鎖。
    ///
    /// 危險在於「對自己所在的佇列 `sync`」：libdispatch 視之為用戶端錯誤。測試本身亦以另一條
    /// 執行緒承載，故一旦回歸成死鎖，是逾時失敗而非整個測試行程吊死。
    @Test
    func testFlushFromInsideTheLaneDoesNotDeadlock() {
      let box = LogLineBox()
      let lane = LogWriteLane(label: "org.vChewing.tests.reentrant") { line in
        if line == "first" {
          box.lane?.flush()
        }
        box.append(line)
      }
      box.lane = lane

      let done = DispatchSemaphore(value: 0)
      Thread.detachNewThread {
        lane.enqueue("first")
        lane.flush()
        done.signal()
      }
      let finished = done.wait(timeout: .now() + 10)
      #expect(finished == .success)
      #expect(box.lines == ["first"])
    }

    /// 多生產者併發入列：額度足夠時一則不失、一字不重。
    @Test
    func testConcurrentProducersLoseNothing() {
      let sink = LogLineSink()
      let lane = LogWriteLane(label: "org.vChewing.tests.concurrent", capacity: 8_192) {
        sink.append($0)
      }
      let workers = 8
      let perWorker = 200
      let group = DispatchGroup()
      for worker in 0 ..< workers {
        DispatchQueue.global().async(group: group) {
          for index in 0 ..< perWorker {
            lane.enqueue("w\(worker)-\(index)")
          }
        }
      }
      let groupDone = group.wait(timeout: .now() + 20)
      #expect(groupDone == .success)
      lane.flush()
      #expect(lane.droppedLineCount == 0)
      #expect(sink.lines.count == workers * perWorker)
      #expect(Set(sink.lines).count == workers * perWorker)
    }
  }
}

// MARK: - LogLineSink

/// 收集寫出巷吐出之各列。
private final class LogLineSink: @unchecked Sendable {
  // MARK: Lifecycle

  /// - Parameters:
  ///   - gate: 非 `nil` 時，首則寫出將阻塞至該號誌被放行（供「生產端不被拖住」之測試）。
  ///   - onWriterEntered: 首次進入寫出閉包時之通知。
  nonisolated init(gate: DispatchSemaphore? = nil, onWriterEntered: @escaping @Sendable () -> () = {}) {
    self.gate = gate
    self.onWriterEntered = onWriterEntered
  }

  // MARK: Internal

  nonisolated var lines: [String] { stateLock.withLockRead { $0 } }

  nonisolated func append(_ line: String) {
    let isFirst = stateLock.withLock { lines -> Bool in
      let isFirst = lines.isEmpty
      lines.append(line)
      return isFirst
    }
    guard isFirst, let gate else { return }
    onWriterEntered()
    _ = gate.wait(timeout: .now() + 30)
  }

  // MARK: Private

  nonisolated private let gate: DispatchSemaphore?
  nonisolated private let onWriterEntered: @Sendable () -> ()
  nonisolated private let stateLock = NSMutex<[String]>([])
}

// MARK: - LogLineBox

/// 供重入測試用：寫出閉包需要巷自身的參照。
private final class LogLineBox: @unchecked Sendable {
  // MARK: Internal

  nonisolated(unsafe) var lane: LogWriteLane?

  nonisolated var lines: [String] { stateLock.withLockRead { $0 } }

  nonisolated func append(_ line: String) {
    stateLock.withLock { $0.append(line) }
  }

  // MARK: Private

  nonisolated private let stateLock = NSMutex<[String]>([])
}
