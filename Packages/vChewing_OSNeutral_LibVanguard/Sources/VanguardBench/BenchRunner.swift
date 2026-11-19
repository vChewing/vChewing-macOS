// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation
import LexiconAssembly
import LibVanguard
import Shared
import SwiftExtension

/// 跨平台之 ARC 暫存池：`autoreleasepool` 只存在於帶 Objective-C 執行期之平台（Darwin），
/// Linux 與 Windows 之 Swift 找不到該符號，故於彼處直接執行。
@inline(__always)
func withARCPool<T>(_ body: () throws -> T) rethrows -> T {
  #if canImport(ObjectiveC)
    return try autoreleasepool(invoking: body)
  #else
    return try body()
  #endif
}

// MARK: - BenchRunner

/// 以真 `InputSession` 驅動合成之按鍵，量測每一次 `handleEvent` 之耗時。
///
/// - Note: 本工具**不捆**任何辭典：原廠辭典由 `vChewing-VanguardLexicon` 帶外產製、由宿主注入
///   資源 bundle，故此處以 `--textmap <path>` 收外部路徑（同 `VanguardLexiconDebugger -d` 之
///   做法）。LibVanguard 自身只帶測試樣本（`LXAssemblyMaterials4Tests`）。
enum BenchRunner {
  // MARK: Internal

  /// 虛擬鍵碼表（US QWERTY／ANSI 之 `kVK_ANSI_*`）。
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

  /// 連上外部辭典並建好會話；成功回傳 `nil`，失敗回傳原因。
  static func prepare(textMapPath: String) -> String? {
    guard FileManager.default.fileExists(atPath: textMapPath) else {
      return "找不到辭典檔：\(textMapPath)"
    }
    // 同步載入：bench 要的是「載入完成之後」的穩定量測。
    LXAssembly.LXFacade.asyncLoadingUserData = false
    LXAssembly.LXFacade.connectFactoryDictionary(textMapPath: textMapPath, validateValues: true)
    guard FactoryDictionary.shared.trie != nil else {
      return "辭典載入失敗：\(textMapPath)"
    }
    // 與單元測試同制：令 asyncOnMain 走同步分支，量到的才是「一次按鍵做完多少事」。
    OSUtils.isRunningUnitTests = true
    let host = SessionHost()
    host.isCoreDBConnected = { true }
    host.factoryDictionary = FactoryDictionary.shared
    host.buzz = {}
    host.notify = { _ in }
    host.ui = { benchUI }
    let theSession = InputSession(
      preallocated: (),
      manuallyAssignedClientProxy: clientProxy,
      host: host
    )
    if theSession.inputMode == .imeModeNULL {
      theSession.inputMode = .imeModeCHT
    }
    theSession.buzzer = {}
    session = theSession
    return nil
  }

  /// 反覆驅動按鍵序列並量測。回傳 `nil` 代表序列無可用按鍵。
  static func run(
    keys: String,
    count: Int,
    warmup: Int,
    resetEachRound: Bool
  )
    -> (stats: BenchStats, committed: String, perChar: [Character: Double])? {
    guard let session else { return nil }
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
    guard !sequence.isEmpty, !sourceChars.isEmpty else { return nil }

    for _ in 0 ..< Swift.max(0, warmup) {
      for event in sequence { _ = session.handleEvent(event) }
    }
    clientProxy.resetRecording()

    var samples: [Double] = []
    samples.reserveCapacity(sequence.count * count)
    for _ in 0 ..< Swift.max(1, count) {
      if resetEachRound {
        session.switchState(.ofAbortion())
        session.resetInputHandler(forceComposerCleanup: true)
        clientProxy.resetRecording()
      }
      for event in sequence {
        // 每鍵各自一個自動釋放池：真輸入法每個事件都由 run loop 收工時排空一次。
        withARCPool {
          let started = DispatchTime.now().uptimeNanoseconds
          _ = session.handleEvent(event)
          samples.append(Double(DispatchTime.now().uptimeNanoseconds - started) / 1_000.0)
        }
      }
    }

    var perChar: [Character: Double] = [:]
    var buckets: [Character: [Double]] = [:]
    for (index, sample) in samples.enumerated() {
      buckets[sourceChars[index % sourceChars.count], default: []].append(sample)
    }
    for (character, values) in buckets {
      perChar[character] = BenchStats(samples: values).p50
    }
    return (BenchStats(samples: samples), clientProxy.committedText, perChar)
  }

  // MARK: Private

  private static let clientProxy = BenchClientProxy()
  private static let benchUI = BenchSessionUI()
  private static var session: InputSession?
}
