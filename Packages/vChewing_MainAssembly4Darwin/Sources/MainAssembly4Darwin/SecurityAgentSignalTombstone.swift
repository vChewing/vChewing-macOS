// (c) 2022 and onwards The vChewing Project (MulanPSL-2.0 License).
// ====================
// This code is released under the SPDX-License-Identifier: `MulanPSL-2.0`.

import Darwin
import Foundation

// MARK: - SecurityAgentSignalTombstone

/// 訊號墓碑：記下「本行程係被誰的哪一個訊號收掉」。
///
/// 訊號處理器裡能做的事極少——不得配置記憶體、不得取鎖、不得遞迴、亦不得呼叫任何會走
/// OSLog 或 `UserDefaults` 的路徑。故處理器只做兩件事：把「訊號編號」與「發送者 PID」以
/// 手寫的十進位寫進一條**早就開好的** fd，然後把該訊號之處置還原為預設值並重新投遞。
/// 其餘一切（讀檔、解析、認人）一律留到下一輪起動、在正常上下文裡做。
///
/// 何以不自持 `UserDefaults` 帳本：帳本取鎖，而處理器可能打斷正持鎖的那一段。故本型別自持
/// 一條 append-only 的文字檔；它只在兩種場合被讀——起動時（回收上一輪）與人工檢視時。
enum SecurityAgentSignalTombstone {
  // MARK: Internal

  /// 一條墓碑：訊號編號與發送者 PID。
  struct Record: Equatable {
    var signal: Int32
    var senderPID: Int32
  }

  /// 受監聽之訊號。`SIGKILL` 本即不可捕捉，故不在此列。
  static let supervisedSignals: [Int32] = [SIGTERM, SIGINT, SIGHUP]

  static var logFileURL: URL? {
    let base = URL(fileURLWithPath: NSHomeDirectory())
      .appendingPathComponent("Library/Logs/vChewing", isDirectory: true)
    do {
      try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
    } catch {
      return nil
    }
    return base.appendingPathComponent("SecurityAgentSignals.log")
  }

  /// 安裝處理器；`fd` 開不起來即靜默略過（寧可沒有墓碑，也不可讓輸入法因診斷而失能）。
  static func install() {
    guard descriptor < 0 else { return }
    guard let fileURL = logFileURL else { return }
    let opened = fileURL.path.withCString { path in
      open(path, O_WRONLY | O_CREAT | O_APPEND, 0o644)
    }
    guard opened >= 0 else { return }
    descriptor = opened
    supervisedSignals.forEach { signalNumber in
      var action = sigaction()
      action.sa_flags = SA_SIGINFO
      action.__sigaction_u.__sa_sigaction = handleSignal
      _ = sigaction(signalNumber, &action, nil)
    }
  }

  /// 讀出歷來留下的墓碑並清空該檔。
  static func drainPreviousRecords() -> [Record] {
    guard let fileURL = logFileURL else { return [] }
    guard let text = try? String(contentsOf: fileURL, encoding: .utf8) else { return [] }
    let records = parse(text)
    guard !records.isEmpty else { return [] }
    try? Data().write(to: fileURL)
    // 追加模式之 fd 不受此清空影響；此後寫入仍自檔尾續之。
    return records
  }

  /// 解析墓碑檔之內容；壞列一律略過。
  static func parse(_ text: String) -> [Record] {
    text.split(whereSeparator: \.isNewline).compactMap { line in
      let fields = line.split(separator: "\t", omittingEmptySubsequences: false)
      guard fields.count == 2,
            let signalNumber = Int32(fields[0]),
            let senderPID = Int32(fields[1])
      else { return nil }
      return Record(signal: signalNumber, senderPID: senderPID)
    }
  }

  /// 以當前行程是否仍存在為前提，回傳發送者之路徑；已消失者回傳 `nil`。
  ///
  /// `proc_pidpath` 之宣告住 `libproc.h`，而 13.3 之 SDK 未把它曝露給 Swift（5.10 之 legacy
  /// 支線即因此編不過）。故一律以 `dlsym` 取符號：該符號自 10.3 起即在 libSystem 內、逐代皆在，
  /// 取不到時退為「查無路徑」。
  static func executablePath(ofSenderPID senderPID: Int32) -> String? {
    guard senderPID > 0, let procPidPath = procPidPathFunction else { return nil }
    var buffer = [CChar](repeating: 0, count: Int(4 * MAXPATHLEN))
    let length = buffer.withUnsafeMutableBufferPointer { pointer in
      procPidPath(senderPID, pointer.baseAddress, UInt32(pointer.count))
    }
    guard length > 0 else { return nil }
    // 不比 `String(cString:)`：該初始化器已棄用，且此處本就有 `length`，不必再掃一次 NUL。
    return String(decoding: buffer.prefix(Int(length)).map { UInt8(bitPattern: $0) }, as: UTF8.self)
  }

  // MARK: Fileprivate

  /// 墓碑檔之 fd；`-1` 即未安裝。
  /// - Important: 處理器會直接讀它，故不得受任何隔離域約束。
  nonisolated(unsafe) fileprivate static var descriptor: Int32 = -1

  // MARK: Private

  /// `proc_pidpath` 之函式簽名（見 `libproc.h`）：`(pid, buffer, buffersize) -> 路徑長`。
  private typealias ProcPidPathFunction = @convention(c) (
    Int32, UnsafeMutablePointer<CChar>?, UInt32
  )
    -> Int32

  /// 以 `dlsym` 取得之 `proc_pidpath`；取不到即 `nil`。
  private nonisolated static let procPidPathFunction: ProcPidPathFunction? = {
    // `RTLD_DEFAULT` 之 Swift 拼法：`UnsafeMutableRawPointer(bitPattern: -2)`。
    guard let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "proc_pidpath") else {
      return nil
    }
    return unsafeBitCast(symbol, to: ProcPidPathFunction.self)
  }()

  /// 訊號處理器本體：只做「寫兩個整數」與「還原處置後重新投遞」。
  private nonisolated static let handleSignal:
    @convention(c) (Int32, UnsafeMutablePointer<siginfo_t>?, UnsafeMutableRawPointer?) -> () = {
      signalNumber, info, _ in
      let senderPID = info?.pointee.si_pid ?? 0
      withUnsafeTemporaryAllocation(of: UInt8.self, capacity: 64) { buffer in
        var cursor = 0
        cursor += securityAgentWriteDecimal(signalNumber, into: buffer, at: cursor)
        buffer[cursor] = 0x09 // \t
        cursor += 1
        cursor += securityAgentWriteDecimal(senderPID, into: buffer, at: cursor)
        buffer[cursor] = 0x0A // \n
        cursor += 1
        _ = write(descriptor, buffer.baseAddress, cursor)
      }
      signal(signalNumber, SIG_DFL)
      raise(signalNumber)
    }
}

/// 把手寫之十進位寫進緩衝；全程不配置記憶體——此函式只會在訊號處理器內被呼叫。
nonisolated func securityAgentWriteDecimal(
  _ value: Int32,
  into buffer: UnsafeMutableBufferPointer<UInt8>,
  at index: Int
)
  -> Int {
  let isNegative = value < 0
  var remaining = value.magnitude
  var written = 0
  repeat {
    buffer[index + written] = UInt8(0x30 + remaining % 10)
    remaining /= 10
    written += 1
  } while remaining > 0
  if isNegative {
    buffer[index + written] = 0x2D // -
    written += 1
  }
  // 上述係低位先寫，故就地反轉。
  var lower = index
  var upper = index + written - 1
  while lower < upper {
    buffer.swapAt(lower, upper)
    lower += 1
    upper -= 1
  }
  return written
}
