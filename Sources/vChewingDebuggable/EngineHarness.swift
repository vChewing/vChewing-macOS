// (c) 2022 and onwards The vChewing Project (MulanPSL-2.0 License).
// ====================
// This code is released under the SPDX-License-Identifier: `MulanPSL-2.0`.

import AppKit
import LibVanguard
import MainAssembly4Darwin
import Shared
import SwiftExtension

// MARK: - HarnessClientProxy

/// 測試掛具專用之客體替身：不接任何真實 App，只把輸入法遞交／標記的內容留在記憶體內。
///
/// 之所以需要它：`InputSession` 只認得 `SessionClientProxy` 這個跨平台抽象；本掛具以此取代
/// IMK 客體，故整條打字路徑（分診、組音、組句、遞交、選字）都不經 IMK、不受系統事件投遞之影響。
final class HarnessClientProxy: SessionClientProxy {
  /// 已遞交之文字（依遞交次序累積）。
  private(set) var committedText: String = ""
  /// 最近一次標記文字（未遞交之組字內容）。
  private(set) var markedText: String = ""
  /// 假客體之 bundle identifier。
  var clientBundleID: String = "com.apple.TextEdit"
  /// 已接收之標記文字寫入次數（真實輸入法每一次都是一趟 IMK 客體呼叫）。
  private(set) var markedTextSetupCount = 0
  /// 已接收之文字遞交次數。
  private(set) var textInsertionCount = 0

  func resetRecording() {
    committedText = ""
    markedText = ""
    markedTextSetupCount = 0
    textInsertionCount = 0
  }

  // MARK: - SessionClientProxy

  func hasClient() -> Bool { true }

  func clientTextInsertion(with text: String, replacementRange _: NSRange) {
    committedText += text
    textInsertionCount += 1
  }

  func clientMarkedTextSetup(
    with text: NSAttributedString,
    selectionRange _: NSRange,
    replacementRange _: NSRange
  ) {
    markedText = text.string
    markedTextSetupCount += 1
  }

  func clientBundleIdentifier() -> String? { clientBundleID }

  func clientSelectMode(withModeIdentifier _: String) {}

  func clientOverrideKeyboard(withName _: String) {}

  func clientAttributesForCharacterIndex(
    atU16Pos _: UInt,
    lineHeightRectangle _: UnsafeMutablePointer<CGRect>
  )
    -> [AnyHashable: Any]? { nil }

  func clientLineHeightRect(forU16CursorPos _: UInt) -> CGRect {
    .init(x: 0, y: 0, width: 1, height: 16)
  }
}

// MARK: - HarnessSessionUI

/// 會話 UI 之替身：只實作引擎會問到的部分。
///
/// 其中 `candidateUI` 不可省：`InputHandler.handleCandidate(input:)` 的頭兩道守衛即
/// 「有無 controller」與「controller 是否可見」，兩者皆假時，選字狀態下的一切按鍵（含
/// 空白鍵遞交）都會被當成未處理——掛具若無此物件，選字之後就再也無法遞交任何字。
final class HarnessSessionUI: SessionUIProtocol {
  var currentSessionID = UUID()
  let shiftKeyUpChecker: (any ShiftKeyUpCheckerProtocol)? = HarnessShiftKeyUpChecker()
  let capsLockHitChecker: (any HitCheckerProtocol)? = HarnessNeverHitChecker()
  let capsLockToggler: (any CapsLockTogglerProtocol)? = HarnessCapsLockToggler()
  let pcb: (any PCBProtocol)? = nil
  let tooltipUI: (any TooltipUIProtocol)? = nil
  let statusUI: (any TooltipUIProtocol)? = nil
  let candidateUI: (any CtlCandidateProtocol)? = HarnessCandidateUI()
}

// MARK: - HarnessCandidateUI

/// 選字窗替身：恆為可見，游標索引由引擎自行增減。
final class HarnessCandidateUI: CtlCandidateProtocol {
  var delegate: CtlCandidateDelegate?
  var highlightedIndex: Int = 0
  var visible: Bool = true
  var expanded: Bool = false
  var currentLayout: UILayoutOrientation = .horizontal

  func showNextPage() -> Bool { true }
  func showPreviousPage() -> Bool { true }
  func showNextLine() -> Bool { true }
  func showPreviousLine() -> Bool { true }
  func highlightNextCandidate() -> Bool { true }
  func highlightPreviousCandidate() -> Bool { true }
  func candidateIndexAtKeyLabelIndex(_ index: Int) -> Int? { index }
  func set(
    windowTopLeftPoint _: CGPoint,
    bottomOutOfScreenAdjustmentHeight _: Double,
    useGCD _: Bool,
    animated _: Bool
  ) {}
}

// MARK: - HarnessShiftKeyUpChecker

/// 中英切換鍵偵測之替身：一律不判定為點按。
final class HarnessShiftKeyUpChecker: ShiftKeyUpCheckerProtocol {
  var toggleWithLShift = false
  var toggleWithRShift = false

  func check(_: some InputSignalProtocol) -> Bool { false }
}

// MARK: - HarnessNeverHitChecker

/// 熱鍵命中偵測之替身：一律不命中。
final class HarnessNeverHitChecker: HitCheckerProtocol {
  func check(_: some InputSignalProtocol) -> Bool { false }
}

// MARK: - HarnessCapsLockToggler

/// Caps Lock 替身：永遠未開啟。
final class HarnessCapsLockToggler: CapsLockTogglerProtocol {
  var isOn = false
}

// MARK: - MemoizingDefaultsStore

/// 讀穿快取之偏好容器：量「把每鍵數十次偏好讀取收斂」能省多少。
///
/// 只為量測而存在，不進生產碼：外部改動（cfprefsd 通知）不會令其失效。
final class MemoizingDefaultsStore: DefaultsStore, @unchecked Sendable {
  // MARK: Lifecycle

  init(wrapping wrapped: any DefaultsStore) {
    self.wrapped = wrapped
  }

  // MARK: Internal

  nonisolated func object(forKey key: String) -> Any? {
    lock.lock()
    if let hit = cache[key] {
      lock.unlock()
      return hit.value
    }
    lock.unlock()
    let value = wrapped.object(forKey: key)
    lock.lock()
    cache[key] = (value, true)
    lock.unlock()
    return value
  }

  nonisolated func set(_ value: Any?, forKey key: String) {
    wrapped.set(value, forKey: key)
    lock.lock()
    cache[key] = (value, true)
    lock.unlock()
  }

  nonisolated func removeObject(forKey key: String) {
    wrapped.removeObject(forKey: key)
    lock.lock()
    cache.removeValue(forKey: key)
    lock.unlock()
  }

  // MARK: Private

  nonisolated private let wrapped: any DefaultsStore
  nonisolated private let lock = NSLock()
  nonisolated(unsafe) private var cache: [String: (value: Any?, present: Bool)] = [:]
}

// MARK: - CountingDefaultsStore

/// 包一層 `DefaultsStore`，只計 `object(forKey:)` 之次數——用來量「每顆按鍵讀了幾次偏好」。
final class CountingDefaultsStore: DefaultsStore, @unchecked Sendable {
  // MARK: Lifecycle

  nonisolated init(wrapping wrapped: any DefaultsStore) {
    self.wrapped = wrapped
  }

  // MARK: Internal

  nonisolated var reads: Int {
    lock.lock()
    defer { lock.unlock() }
    return readCount
  }

  nonisolated func resetReads() {
    lock.lock()
    readCount = 0
    lock.unlock()
  }

  nonisolated func object(forKey key: String) -> Any? {
    lock.lock()
    readCount += 1
    lock.unlock()
    return wrapped.object(forKey: key)
  }

  nonisolated func set(_ value: Any?, forKey key: String) {
    wrapped.set(value, forKey: key)
  }

  nonisolated func removeObject(forKey key: String) {
    wrapped.removeObject(forKey: key)
  }

  // MARK: Private

  nonisolated private let wrapped: any DefaultsStore
  nonisolated private let lock = NSLock()
  nonisolated(unsafe) private var readCount = 0
}

// MARK: - EngineHarness

/// 打字引擎之測試掛具：在 `vChewingDebuggable` 進程內另立一個 `InputSession`，直接以 `KBEvent`
/// 驅動，量測「每次按鍵在主執行緒上花了多少時間」。
///
/// 使用方式（外部控制，經既有之 `vchewingdbg://` URL 通道）：
///
///     open -g "vchewingdbg://bench?keys=su3%20&count=200"
///     open -g "vchewingdbg://state"
///     open -g "vchewingdbg://reset"
///
/// 結果寫進 `~/Library/Logs/vChewingDebuggable.log`（與既有診斷日誌同檔）。
@MainActor
enum EngineHarness {
  /// 一次量測之統計結果（單位：微秒）。
  struct Stats {
    // MARK: Internal

    let samples: [Double]

    var count: Int { samples.count }
    var total: Double { samples.reduce(0, +) }

    var p50: Double { percentile(0.50) }
    var p90: Double { percentile(0.90) }
    var p99: Double { percentile(0.99) }
    var max: Double { samples.max() ?? 0 }

    // MARK: Private

    private func percentile(_ q: Double) -> Double {
      guard !samples.isEmpty else { return 0 }
      let sorted = samples.sorted()
      let index = Swift.min(sorted.count - 1, Int(Double(sorted.count - 1) * q))
      return sorted[index]
    }
  }

  /// 虛擬鍵碼表（US QWERTY／ANSI 之 `kVK_ANSI_*`；與實體鍵盤一致，故組音器認得）。
  /// 虛擬鍵碼表（US QWERTY／ANSI 之 `kVK_ANSI_*`；與實體鍵盤一致，故組音器認得）。
  ///
  /// 帶 Shift 之鍵亦一併列出：`<`／`>`／`?` 一類符號在 ANSI 佈局上是 Shift＋既有鍵，
  /// 只給字元、不給 Shift 旗標的話，分診會把它當成未按 Shift 的那個鍵。
  static let keyCodeMap: [Character: (code: UInt16, flags: KBEvent.ModifierFlags)] = [
    "a": (0, []), "s": (1, []), "d": (2, []), "f": (3, []), "h": (4, []),
    "g": (5, []), "z": (6, []), "x": (7, []), "c": (8, []), "v": (9, []),
    "b": (11, []), "q": (12, []), "w": (13, []), "e": (14, []), "r": (15, []),
    "y": (16, []), "t": (17, []), "1": (18, []), "2": (19, []), "3": (20, []),
    "4": (21, []), "6": (22, []), "5": (23, []), "=": (24, []), "9": (25, []),
    "7": (26, []), "-": (27, []), "8": (28, []), "0": (29, []), "]": (30, []),
    "o": (31, []), "u": (32, []), "[": (33, []), "i": (34, []), "p": (35, []),
    "l": (37, []), "j": (38, []), "'": (39, []), "k": (40, []), ";": (41, []),
    "\\": (42, []), ",": (43, []), "/": (44, []), "n": (45, []), "m": (46, []),
    ".": (47, []), " ": (49, []), "\n": (36, []), "`": (50, []),
    // Shift 組合（ANSI 佈局）。
    "_": (27, [.shift]), "+": (24, [.shift]), "{": (33, [.shift]), "}": (30, [.shift]),
    "|": (42, [.shift]), ":": (41, [.shift]), "\"": (39, [.shift]), "<": (43, [.shift]),
    ">": (47, [.shift]), "?": (44, [.shift]), "~": (50, [.shift]), "!": (18, [.shift]),
    "@": (19, [.shift]), "#": (20, [.shift]), "$": (21, [.shift]), "%": (23, [.shift]),
    "^": (22, [.shift]), "&": (26, [.shift]), "*": (28, [.shift]), "(": (25, [.shift]),
    ")": (29, [.shift]),
  ]

  /// 掛具持有之會話（首次使用時建立）。
  private(set) static var session: InputSession?

  /// 客體替身。
  static let clientProxy = HarnessClientProxy()

  /// 會話 UI 替身（選字窗須可見，見 `HarnessSessionUI`）。
  static let harnessUI = HarnessSessionUI()

  /// 確保辭典與會話就緒。回傳 nil 表示成功，否則回傳失敗原因。
  static func prepareSession(forceRebuild: Bool = false) -> String? {
    SessionHost.wireUp()
    if forceRebuild {
      session = nil
    }
    // 原廠辭典：本掛具借用 IME 之資源 bundle（`LXMgr` 之路徑解析即為此用途而設）。
    if FactoryDictionary.shared.trie == nil {
      LXMgr.connectCoreDB()
      let deadline = Date().addingTimeInterval(20)
      while FactoryDictionary.shared.trie == nil, Date() < deadline {
        RunLoop.main.run(until: Date().addingTimeInterval(0.02))
      }
      guard FactoryDictionary.shared.trie != nil else {
        return "FactoryDictionary 未載入（20 秒逾時）"
      }
    }
    guard session == nil else { return nil }
    let host = SessionHost()
    // 掛具自帶之宿主：只補上引擎必需者。`isCoreDBConnected` 尤其要緊——其預設為假，
    // 未設時每一顆按鍵都會落進「辭典未載入」之分支（回 true 但不組字，且附帶一次錯誤處理）。
    host.isCoreDBConnected = { true }
    host.factoryDictionary = FactoryDictionary.shared
    host.isKeyboardJIS = { false }
    host.buzz = {}
    host.notify = { _ in }
    host.ui = { harnessUI }
    let theSession = InputSession(
      preallocated: (),
      manuallyAssignedClientProxy: clientProxy,
      host: host
    )
    if theSession.inputMode == .imeModeNULL {
      theSession.inputMode = .imeModeCHT
    }
    // 蜂鳴走 `SessionHost.shared.buzz`（＝IMEApp.buzz），實測每次約 5 ms；掛具不需要它。
    theSession.buzzer = {}
    session = theSession
    return nil
  }

  /// 以指定之按鍵序列反覆驅動引擎，量測每次 `handleEvent` 之耗時。
  ///
  /// - Parameters:
  ///   - keys: 按鍵序列；每個字元即一次 `keyDown`（空格＝遞交、換行＝ Enter）。
  ///   - repeats: 整段序列重複幾次。
  /// - Returns: 報告字串（單行，便於外部解析）與統計。
  static func runBench(
    keys: String,
    repeats: Int,
    emulateRealLogging: Bool = false,
    resetEachRound: Bool = false,
    skipWarmup: Bool = false,
    memoizeStore: Bool = false
  )
    -> (report: String, stats: Stats)? {
    if let failure = prepareSession() {
      return ("[BENCH] ERROR: \(failure)", Stats(samples: []))
    }
    guard let session else { return ("[BENCH] ERROR: session 不可用", Stats(samples: [])) }
    // 真實輸入法之「日誌開著」情境：本 app 平時以 `OSUtils.isRunningUnitTests` 靜音，
    // 故 `vCLogIsEnabled()` 恆假；此模式下暫時解除該旗標，令日誌量與真輸入法一致。
    let previousUnitTestFlag = OSUtils.isRunningUnitTests
    if emulateRealLogging { OSUtils.isRunningUnitTests = false }
    // 量測期間把偏好容器包上一層計數器：每顆按鍵讀幾次偏好，是這輪要盯的數字之一。
    let originalStore = OSUtils.defaultsStore
    let countingStore = CountingDefaultsStore(
      wrapping: memoizeStore ? MemoizingDefaultsStore(wrapping: originalStore) : originalStore
    )
    OSUtils.defaultsStore = countingStore
    defer {
      OSUtils.isRunningUnitTests = previousUnitTestFlag
      OSUtils.defaultsStore = originalStore
    }
    clientProxy.resetRecording()

    var sourceChars: [Character] = []
    let sequence: [KBEvent] = keys.compactMap { character in
      guard let entry = keyCodeMap[character] else { return nil }
      sourceChars.append(character)
      return KBEvent(
        with: .keyDown,
        modifierFlags: entry.flags,
        timestamp: nil,
        windowNumber: 0,
        characters: String(character),
        charactersIgnoringModifiers: String(character),
        isARepeat: false,
        keyCode: entry.code
      )
    }
    guard !sequence.isEmpty else {
      return ("[BENCH] ERROR: 無可用之按鍵（keys=\(keys)）", Stats(samples: []))
    }

    // 暖機：讓辭典查詢快取、鍵盤解析器與會話狀態先落定，免得第一輪污染分佈。
    // `skipWarmup` 則是相反之用：量「剛開始打字」那幾鍵的冷啟動成本。
    if !skipWarmup {
      for _ in 0 ..< 10 {
        for event in sequence { _ = session.handleEvent(event) }
      }
    }
    clientProxy.resetRecording()

    var samples: [Double] = []
    samples.reserveCapacity(sequence.count * repeats)
    let startedAt = Date()
    countingStore.resetReads()
    for _ in 0 ..< repeats {
      // 每輪先把組字狀態清乾淨：否則第二輪起引擎已無從吸納新鍵（狀態飽和），
      // 量到的只是「飽和後的低成本」，與真實打字無關。
      if resetEachRound {
        session.switchState(.ofAbortion())
        session.resetInputHandler(forceComposerCleanup: true)
        clientProxy.resetRecording()
      }
      for event in sequence {
        // 每鍵各自一個自動釋放池：真輸入法每個事件都由 run loop 收工時排空一次；
        // 緊迴圈裡不排空的話，累積的暫存物件會把後面的鍵拖慢（實測可差數倍）。
        autoreleasepool {
          let t0 = DispatchTime.now().uptimeNanoseconds
          _ = session.handleEvent(event)
          samples.append(Double(DispatchTime.now().uptimeNanoseconds - t0) / 1_000.0)
        }
      }
    }
    let elapsed = Date().timeIntervalSince(startedAt)
    let prefReads = countingStore.reads

    let stats = Stats(samples: samples)
    // 漂移：把樣本按次序切成五段，看每段之 p50 是否隨「打得多」而上漂。
    func bucketP50(_ values: [Double], parts: Int) -> [Double] {
      let size = Swift.max(1, values.count / parts)
      return (0 ..< parts).map { index in
        let lower = index * size
        let upper = Swift.min(values.count, lower + size)
        guard lower < upper else { return 0 }
        return Stats(samples: Array(values[lower ..< upper])).p50
      }
    }
    let buckets = bucketP50(samples, parts: 5)
    let cut = Swift.max(1, samples.count / 5)
    let firstCut = Stats(samples: Array(samples.prefix(cut))).p50
    let lastCut = Stats(samples: Array(samples.suffix(cut))).p50
    let bucketText = buckets.map { String(format: "%.0f", $0) }.joined(separator: "/")
    let committedSample = String(clientProxy.committedText.prefix(12))
    let perKeyReads = Double(prefReads) / Double(Swift.max(1, stats.count))
    // 逐字統計：同一顆字鍵在「句長不同」時的成本差，就是聲調鍵隨句長上漂之量。
    var byChar: [Character: [Double]] = [:]
    if !sourceChars.isEmpty {
      for (index, sample) in samples.enumerated() {
        byChar[sourceChars[index % sourceChars.count], default: []].append(sample)
      }
    }
    let charText = byChar
      .map { ($0.key, Stats(samples: $0.value)) }
      .sorted { $0.1.p50 > $1.1.p50 }
      .prefix(6)
      .map { String(format: "%@:%.0f/%.0f", String($0.0), $0.1.p50, $0.1.p99) }
      .joined(separator: " ")
    // 以字串插值組報告：`String(format:)` 之占位符與引數一旦對不上（此處曾在擴充欄位時漏改
    // 格式字串），就會以錯誤型別解讀引數而 SIGSEGV——掛具不該有這種地雷。
    let report = "[BENCH] pid=\(ProcessInfo.processInfo.processIdentifier)"
      + " keys=\"\(keys.replacingOccurrences(of: "\n", with: "<CR>"))\""
      + " repeats=\(repeats) n=\(stats.count)"
      + String(
        format: " p50=%.1fµs p90=%.1fµs p99=%.1fµs max=%.1fµs total=%.1fms wall=%.0fms",
        stats.p50, stats.p90, stats.p99, stats.max, stats.total / 1_000, elapsed * 1_000
      )
      + " committed=\(clientProxy.committedText.count)"
      + String(format: " drift=%.0f/%.0f", firstCut, lastCut)
      + " buckets=[\(bucketText)]"
      + " logging=\(emulateRealLogging ? "on" : "off") reset=\(resetEachRound ? "on" : "off")"
      + " prefReads=\(prefReads)(\(String(format: "%.1f", perKeyReads))/key)"
      +
      " setMarked=\(clientProxy.markedTextSetupCount)(\(String(format: "%.2f", Double(clientProxy.markedTextSetupCount) / Double(Swift.max(1, stats.count))))/key)"
      + " perChar=[\(charText)] memo=\(memoizeStore ? "on" : "off")"
      + " sample=\"\(committedSample)\""
    return (report, stats)
  }

  /// 延後執行之 bench：供外部先起取樣器、再讓 bench 落在取樣窗口內。
  static func scheduleBench(
    keys: String,
    repeats: Int,
    delay: TimeInterval,
    emulateRealLogging: Bool = false,
    resetEachRound: Bool = false,
    skipWarmup: Bool = false,
    memoizeStore: Bool = false,
    log: @escaping (String) -> ()
  ) {
    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
      MainActor.assumeIsolated {
        if let result = runBench(
          keys: keys,
          repeats: repeats,
          emulateRealLogging: emulateRealLogging,
          resetEachRound: resetEachRound,
          skipWarmup: skipWarmup,
          memoizeStore: memoizeStore
        ) {
          log(result.report)
        }
      }
    }
    log("[BENCH] scheduled in \(delay)s: keys=\(keys) repeats=\(repeats)")
  }

  /// 逐鍵送入指定序列，並回報每一步之後的狀態與已遞交字數（診斷用）。
  static func typeKeys(_ keys: String) -> String {
    if let failure = prepareSession() {
      return "[TYPE] ERROR: \(failure)"
    }
    guard let session else { return "[TYPE] ERROR: session 不可用" }
    var lines: [String] = []
    for character in keys {
      guard let entry = keyCodeMap[character] else {
        lines.append("[\(character)] no keycode")
        continue
      }
      let event = KBEvent(
        with: .keyDown,
        modifierFlags: entry.flags,
        timestamp: nil,
        windowNumber: 0,
        characters: String(character),
        charactersIgnoringModifiers: String(character),
        isARepeat: false,
        keyCode: entry.code
      )
      let t0 = DispatchTime.now().uptimeNanoseconds
      let handled = session.handleEvent(event)
      let us = Double(DispatchTime.now().uptimeNanoseconds - t0) / 1_000.0
      lines.append(
        "[\(character)] handled=\(handled) type=\(session.state.type.rawValue) "
          + "displayed=\"\(session.state.displayedText)\" cand=\(session.state.candidates.count) "
          + "committed=\(clientProxy.committedText.count) \(String(format: "%.0fµs", us))"
      )
    }
    return "[TYPE] keys=\"\(keys.replacingOccurrences(of: "\n", with: "<CR>"))\" " + lines.joined(separator: " | ")
  }

  /// 命令列入口：`--bench <keys> [--count N] [--reset 1] [--logging 1] [--delay S]`。
  ///
  /// 何以需要：Debug 與 Release 兩份 `.app` 共用同一個 bundle identifier，`open vchewingdbg://…`
  /// 由 LaunchServices 派送，實際接到的是哪一份並不可控（實測會落到另一份建置）。命令列入口
  /// 直接綁定「本行程」，量測與取樣才對得上。
  static func handleCommandLineIfPresent(log: @escaping (String) -> ()) {
    let args = CommandLine.arguments
    guard let index = args.firstIndex(of: "--bench"), index + 1 < args.count else { return }
    func value(_ flag: String) -> String? {
      guard let i = args.firstIndex(of: flag), i + 1 < args.count else { return nil }
      return args[i + 1]
    }
    let keys = args[index + 1]
    let repeats = Int(value("--count") ?? "100") ?? 100
    let resetEachRound = (value("--reset") ?? "0") == "1"
    let emulateRealLogging = (value("--logging") ?? "0") == "1"
    let delay = Double(value("--delay") ?? "2") ?? 2
    let skipWarmup = (value("--cold") ?? "0") == "1"
    let memoizeStore = (value("--memo") ?? "0") == "1"
    log(
      "[BENCH] cli pid=\(ProcessInfo.processInfo.processIdentifier) keys=\(keys) "
        + "count=\(repeats) reset=\(resetEachRound) logging=\(emulateRealLogging)"
    )
    scheduleBench(
      keys: keys,
      repeats: repeats,
      delay: delay,
      emulateRealLogging: emulateRealLogging,
      resetEachRound: resetEachRound,
      skipWarmup: skipWarmup,
      memoizeStore: memoizeStore,
      log: log
    )
  }

  /// 回報當前組字狀態（供外部確認引擎確實在組字）。
  static func stateSnapshot() -> String {
    if let failure = prepareSession() {
      return "[STATE] ERROR: \(failure)"
    }
    guard let session else { return "[STATE] ERROR: session 不可用" }
    let state = session.state
    let displayed = state.displayedText
    let candidates = state.candidates.map(\.value).joined(separator: "|")
    let prefs = session.prefs
    // 單鍵探針：送一顆 `s` 並回報其結果與前後狀態，用以分辨「未抵達引擎」與「被分診拒絕」。
    let probe = KBEvent(
      with: .keyDown,
      modifierFlags: [],
      timestamp: nil,
      windowNumber: 0,
      characters: "s",
      charactersIgnoringModifiers: "s",
      isARepeat: false,
      keyCode: 1
    )
    let before = session.state.type.rawValue
    let t0 = DispatchTime.now().uptimeNanoseconds
    let handled = session.handleEvent(probe)
    let probeUS = Double(DispatchTime.now().uptimeNanoseconds - t0) / 1_000.0
    let after = session.state.type.rawValue
    // 偏好讀取成本：`@AppProperty` 每次取值都向 `defaultsStore` 問一次；沙箱下可能經 cfprefsd。
    let prefProbeCount = 1_000
    let prefT0 = DispatchTime.now().uptimeNanoseconds
    for _ in 0 ..< prefProbeCount { _ = prefs.keyboardParser }
    let prefReadUS = Double(DispatchTime.now().uptimeNanoseconds - prefT0) / 1_000.0 / Double(prefProbeCount)
    let dictLoaded = FactoryDictionary.shared.trie != nil
    let hasUnigramN = session.currentLexicon.lxQuerier.hasUnigrams(for: ["ㄋ"])
    return """
    [STATE] type=\(state.type.rawValue) displayed="\(displayed)" \
    candidates=\(state.candidates.count) [\(candidates.prefix(120))] \
    marked="\(clientProxy.markedText)" committed=\(clientProxy.committedText.count) \
    | mode=\(session.inputMode.rawValue) handler=\(session.inputHandler != nil) \
    parser=\(prefs.keyboardParser) zhuyinParser=\(prefs.keyboardParser4Zhuyin) \
    | probe(s): handled=\(handled) \(before)->\(after) \(String(format: "%.0fµs", probeUS)) \
    | dict=\(dictLoaded) hasUnigram(ㄋ)=\(hasUnigramN) prefRead=\(String(format: "%.2fµs", prefReadUS)) \
    sandboxed=\(ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil)
    """
  }

  /// 重建會話（清掉殘留之組字狀態）。
  static func resetSession() {
    session = nil
    clientProxy.resetRecording()
  }
}
