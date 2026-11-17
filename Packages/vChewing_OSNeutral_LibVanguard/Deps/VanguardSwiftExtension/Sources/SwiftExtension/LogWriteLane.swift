// (c) 2022 and onwards The vChewing Project (MulanPSL-2.0 License).
// ====================
// This code is released under the SPDX-License-Identifier: `MulanPSL-2.0`.

import Foundation

// MARK: - LogWriteLane

/// 系統記錄之寫入巷：把實際的寫入動作自呼叫端之執行緒移開，令其在一條專屬的序列佇列上非同步進行。
///
/// **何以需要**：`os_log`（`Logger`）與 `NSLog` 之寫入都是同步呼叫。當有人在串流讀取系統記錄
/// （Console.app 之即時檢視、`log stream` 一類），記錄守護行程消化不及時，其回壓即落在呼叫端
/// 那一條執行緒上。若呼叫端是輸入法之 IMK 事件鏈路（主執行緒上之同步區段），這份等待就直接
/// 變成打字遲鈍——一則診斷日誌換一次卡頓，並不划算。
///
/// **有界**：積壓達到 `capacity` 則拒絕新到之訊息並計數，於下一次排空時補記一則
/// 「dropped N line(s)」。取捨是「寧可丟記錄，不可拖慢呼叫端」：生產端（打字）恆為非阻塞，
/// 記憶體亦不隨積壓無限增長。丟棄的是**較新**的訊息，緣由見 `enqueue(_:)`。
///
/// **執行緒歸屬**：`enqueue(_:)` 可在任意執行緒呼叫；`writer` 恆在同一條序列佇列上被呼叫
/// （`flush()` 則就地在呼叫端排空），故寫出之次序即入列之次序。`flush()` 由 `flushConsoleLog()`
/// 於強制日誌（`vCLog(forced:)`）時呼叫，使「相隔數日才發作」之故障證據不因行程結束而遺失。
public final class LogWriteLane: @unchecked Sendable {
  // MARK: Lifecycle

  public nonisolated init(
    label: String,
    capacity: Int = 1_024,
    writer: @escaping Writer
  ) {
    self.capacity = Swift.max(1, capacity)
    self.writer = writer
    let queue = DispatchQueue(label: label)
    queue.setSpecific(key: Self.queueKey, value: 1)
    self.queue = queue
  }

  // MARK: Public

  public typealias Writer = @Sendable (String) -> ()

  /// 佇列之上限（以「則」計）。併發之生產者共用此額度。
  public nonisolated let capacity: Int

  /// 尚有幾則未寫出。
  public nonisolated var pendingLineCount: Int {
    stateLock.lock()
    defer { stateLock.unlock() }
    return pendingLines.count
  }

  /// 自開始以來累計丟棄之則數。非零即表示寫出端追不上生產端，該批次之記錄不完整。
  public nonisolated var droppedLineCount: Int {
    stateLock.lock()
    defer { stateLock.unlock() }
    return droppedLineTotal
  }

  /// 將一則訊息排入佇列。本呼叫不等待寫出、亦不因寫出端阻塞而阻塞。
  ///
  /// 之所以丟棄**較新**者而非較舊者：滿載即表示「連先前那些都還沒寫出去」，此時較早之上下文
  /// （故障發生前的那幾行）比後續之重複行更有用；而丟棄本身必留一則通知，故不會靜默。
  public nonisolated func enqueue(_ line: String) {
    stateLock.lock()
    if pendingLines.count >= capacity {
      droppedLineTotal += 1
    } else {
      pendingLines.append(line)
    }
    let shouldSchedule = !isDrainScheduled
    if shouldSchedule { isDrainScheduled = true }
    stateLock.unlock()
    guard shouldSchedule else { return }
    queue.async { self.drain() }
  }

  /// 就地排空佇列，返回時所有已入列之訊息皆已交給 `writer`。
  ///
  /// 於寫入巷自身之執行緒上呼叫時直接排空（不再 `sync` 進同一條佇列——那會自我死鎖）；
  /// 其餘情形一律經該佇列同步執行，故與在途之排空互斥、次序不亂。
  public nonisolated func flush() {
    if DispatchQueue.getSpecific(key: Self.queueKey) != nil {
      drain()
      return
    }
    queue.sync { self.drain() }
  }

  // MARK: Private

  nonisolated private static let queueKey = DispatchSpecificKey<UInt8>()

  nonisolated private let stateLock = NSLock()
  nonisolated private let writer: Writer
  nonisolated private let queue: DispatchQueue
  /// 以下三項一律只於 `stateLock` 之內讀寫。
  nonisolated(unsafe) private var pendingLines: [String] = []
  nonisolated(unsafe) private var droppedLineTotal = 0
  nonisolated(unsafe) private var isDrainScheduled = false

  /// 逐批取走並寫出，直到佇列見底為止。
  ///
  /// 取走時即釋放鎖，故 `writer` 阻塞（正是本型別要吸收的那種阻塞）不會妨礙生產端繼續入列；
  /// 期間新到之訊息落在下一批。`isDrainScheduled` 只在「見到佇列已空」時才歸假，故不會有
  /// 「已排空卻無人接手」之空窗。
  nonisolated private func drain() {
    while true {
      stateLock.lock()
      if pendingLines.isEmpty, droppedLineTotal == 0 {
        isDrainScheduled = false
        stateLock.unlock()
        return
      }
      let lines = pendingLines
      let dropped = droppedLineTotal
      pendingLines.removeAll(keepingCapacity: true)
      droppedLineTotal = 0
      stateLock.unlock()
      if dropped > 0 {
        writer("[LogWriteLane] dropped \(dropped) line(s) before this drain.")
      }
      for line in lines {
        writer(line)
      }
    }
  }
}
