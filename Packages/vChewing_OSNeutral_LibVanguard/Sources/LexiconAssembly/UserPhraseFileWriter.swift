// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation
import SwiftExtension

// MARK: - LXAssembly.UserPhraseFileWriter

extension LXAssembly {
  /// 使用者片語資料列之落盤器。
  ///
  /// **職責邊界**：本型別只做**位元組 I/O**，不查詢、亦不改動任何語言模組狀態。故它可以在
  /// ``LXAssembly/userDataWriteQueue`` 這條背景巷上執行。反過來說，「這筆詞音配對是否已在濾除
  /// 清單內」「這筆是否與既有條目重複」「目標檔是哪一顆」一類**決策**，一律由呼叫端於主執行緒
  /// 備妥、連同內容一併裝進 ``WritePlan``——寫入巷上不得回頭詢問語言模組。
  ///
  /// 之所以如此切分：語言模組是主執行緒的單一持有物（P314／P315／P316 三 phase 之隔離紀律），
  /// 而磁碟卻可能慢到讓 IMK 的鍵盤事件鏈路失去回應（GH Issue #625）。把「決策」留在主執行緒、
  /// 把「落盤」趕到背景巷，兩者才互不牽扯。
  public enum UserPhraseFileWriter {
    // MARK: Public

    /// 本次落盤要做的事。
    public enum Kind: Sendable {
      /// 於目標檔尾端追加一列（就地加詞／降權／升權／加入濾除清單）。
      case append
      /// 就地把目標檔內該詞音配對之內容改寫為 NUL（自濾除清單移出）。
      case unfilter
    }

    /// 一次落盤所需的全部資料。決策已於主執行緒完成，故本結構可安全跨執行緒傳遞。
    public struct WritePlan: Sendable {
      // MARK: Lifecycle

      public init(
        kind: Kind,
        targetURL: URL,
        cells: [String],
        templateURL: URL? = nil,
        locator: any UserDataLocator = LXAssembly.userDataLocator
      ) {
        self.kind = kind
        self.targetURL = targetURL
        self.cells = cells
        self.templateURL = templateURL
        self.locator = locator
      }

      // MARK: Public

      public let kind: Kind
      /// 目標檔（片語表或濾除清單）。
      public let targetURL: URL
      /// 該列之內容格（第 0 格為詞值、第 1 格為讀音；其餘為權重與標記）。
      public let cells: [String]
      /// 目標檔不存在時用以建立之範本；`nil` 者即建空檔。
      public let templateURL: URL?
      /// 本次落盤所使用之資料後端（於主執行緒配妥，測試可注入專屬者）。
      public let locator: any UserDataLocator
    }

    /// 落盤結果。
    public enum Outcome: Sendable, Equatable {
      case succeeded
      case failed(reason: String)

      // MARK: Public

      public var isSucceeded: Bool { self == .succeeded }
    }

    /// 執行落盤。**只碰檔案、不碰語言模組**，故可於寫入巷上執行。
    nonisolated public static func perform(_ plan: WritePlan) -> Outcome {
      switch plan.kind {
      case .append: return append(plan)
      case .unfilter: return unfilter(plan)
      }
    }

    // MARK: Private

    /// 追加一列。與 P72 以來之行為一致：先確保目標檔存在（必要時鋪範本），
    /// 再於檔尾追加；若既有內容未以斷行收尾，先補一個斷行。
    nonisolated private static func append(_ plan: WritePlan) -> Outcome {
      if let creationFailure = ensureTargetExists(plan) { return creationFailure }
      // 非檔案系統後端（測試之記憶體後端）：整檔讀回、補斷行、寫回。檔案必小，故不必快徑。
      guard plan.locator.isBackedByFileSystem else {
        do {
          var data = (try? plan.locator.read(at: plan.targetURL)) ?? Data()
          if !data.isEmpty, data.last != 0x0A { data.append(0x0A) }
          data.append(lineContent(of: plan))
          try plan.locator.write(data, to: plan.targetURL)
          return .succeeded
        } catch {
          return .failed(reason: "Failed from appending the line: \(error)")
        }
      }
      return LXAssembly.withUserDataFileLock { () -> Outcome in
        guard let fileSize = fileSize(at: plan.targetURL) else {
          return .failed(reason: "Target file size is null.")
        }
        guard let writeFile = FileHandle(forUpdatingAtPath: plan.targetURL.path) else {
          return .failed(reason: "Failed from initiating file handle.")
        }
        defer { try? writeFile.closeTheFile() }
        var dataToInsert = lineContent(of: plan)
        if fileSize > 0 {
          try? writeFile.seek(to: fileSize - 1)
          if (try? writeFile.read(upTo: 1))?.first != 0x0A {
            dataToInsert.insert(0x0A, at: 0)
          }
        }
        _ = try? writeFile.seekToEOF()
        try? writeFile.writeData(dataToInsert)
        return .succeeded
      }
    }

    /// 該列之內容（含結尾斷行）。
    nonisolated private static func lineContent(of plan: WritePlan) -> Data {
      Data("\(plan.cells.joined(separator: " "))\n".utf8)
    }

    /// 自濾除清單移出：把命中之列就地改寫為 NUL（最小化磁碟寫入）。
    /// 一次掃描找不到時，先強制整理格式再掃一次——與 P72 以來之行為一致。
    nonisolated private static func unfilter(_ plan: WritePlan) -> Outcome {
      guard plan.locator.isBackedByFileSystem else { return unfilterInMemory(plan) }
      switch scanAndBleachUnfilteredRows(plan) {
      case .succeeded: return .succeeded
      case let .failed(reason):
        guard LXAssembly.LXConsolidator.consolidate(
          path: plan.targetURL.path, pragma: false, using: plan.locator
        ) else {
          return .failed(reason: "\(reason) Consolidation also failed.")
        }
        return scanAndBleachUnfilteredRows(plan)
      }
    }

    /// 掃描目標檔、把命中之列改寫為 NUL。全程持檔案鎖。
    nonisolated private static func scanAndBleachUnfilteredRows(_ plan: WritePlan) -> Outcome {
      let usefulCells = plan.cells.prefix(2)
      guard usefulCells.count == 2 else {
        return .failed(reason: "The pair is invalid.")
      }
      guard let spaceSeparated = usefulCells.joined(separator: " ").data(using: .utf8),
            let tabSeparated = usefulCells.joined(separator: "\t").data(using: .utf8)
      else {
        return .failed(reason: "Failed from preparing the matching data.")
      }
      let bufferLength = spaceSeparated.count // 兩者等長
      return LXAssembly.withUserDataFileLock { () -> Outcome in
        guard let fileSize = fileSize(at: plan.targetURL) else {
          return .failed(reason: "Failed from getting the file size of the filter list file.")
        }
        guard fileSize >= bufferLength else {
          return .failed(reason: "This pair is not in the filtered list.")
        }
        guard let fileHandle = FileHandle(forUpdatingAtPath: plan.targetURL.path) else {
          return .failed(reason: "Failed from handling the filter list file.")
        }
        defer { try? fileHandle.closeTheFile() }
        let blankData = Data([UInt8](repeating: 0x0, count: bufferLength))
        let sharpData = Data([0x23]) // Sharp Sign (#)
        let lfData = Data([0x0A]) // Line Feed '\n'
        var didBleach = false
        try? fileHandle.seek(to: 0) // 從頭開始讀取處理。
        for currentWorkingOffset in 0 ... (Int(fileSize) - bufferLength) {
          /// !! 注意：FileHandle 的 seek 位置會在每次 readData() / write() 之後都有變動。
          // 只在「行首或換行（LF）之後」嘗試匹配；此外，若前一位元組是 # 則略過。
          if currentWorkingOffset > 0 {
            try? fileHandle.seek(to: UInt64(currentWorkingOffset - 1))
            let previousByte = (try? fileHandle.read(upTo: 1)) ?? Data()
            if previousByte == sharpData { continue }
            guard previousByte == lfData else { continue }
          }
          // 開始手術
          try? fileHandle.seek(to: UInt64(currentWorkingOffset))
          let dataScoped = (try? fileHandle.read(upTo: bufferLength)) ?? Data()
          guard [spaceSeparated, tabSeparated].contains(dataScoped) else { continue }
          try? fileHandle.seek(to: UInt64(currentWorkingOffset))
          try? fileHandle.writeData(blankData)
          didBleach = true
        }
        return didBleach
          ? .succeeded
          : .failed(reason: "This pair is not in the filtered list.")
      }
    }

    /// 非檔案系統後端之移出：整檔讀回、逐列比對、命中列以等長之 NUL 取代、寫回。
    nonisolated private static func unfilterInMemory(_ plan: WritePlan) -> Outcome {
      let usefulCells = plan.cells.prefix(2)
      guard usefulCells.count == 2 else { return .failed(reason: "The pair is invalid.") }
      let spaceSeparated = usefulCells.joined(separator: " ")
      let tabSeparated = usefulCells.joined(separator: "\t")
      guard var text = try? plan.locator.readText(at: plan.targetURL) else {
        return .failed(reason: "Failed from reading the filter list file.")
      }
      var didBleach = false
      let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map { line -> String in
        guard !line.hasPrefix("#"), line == spaceSeparated || line == tabSeparated else {
          return String(line)
        }
        didBleach = true
        return String(repeating: "\u{0}", count: line.utf8.count)
      }
      guard didBleach else { return .failed(reason: "This pair is not in the filtered list.") }
      text = lines.joined(separator: "\n")
      do {
        try plan.locator.write(Data(text.utf8), to: plan.targetURL)
        return .succeeded
      } catch {
        return .failed(reason: "Failed from writing the filter list file: \(error)")
      }
    }

    /// 確保目標檔存在：不存在時建立（含所需目錄），範本存在則以其內容鋪底。
    nonisolated private static func ensureTargetExists(_ plan: WritePlan) -> Outcome? {
      guard !plan.locator.exists(at: plan.targetURL) else { return nil }
      let folderURL = plan.targetURL.deletingLastPathComponent()
      try? FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
      var templateData = Data()
      if let templateURL = plan.templateURL,
         let data = try? Data(contentsOf: templateURL) {
        templateData = data
      }
      do {
        try plan.locator.write(templateData, to: plan.targetURL)
        return nil
      } catch {
        return .failed(reason: "Failed from deploying the target file: \(error)")
      }
    }

    /// 檔案位元組數（不經 locator：本函式總是在檔案鎖內被呼叫）。
    nonisolated private static func fileSize(at url: URL) -> UInt64? {
      guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path) else {
        return nil
      }
      return (attributes[.size] as? NSNumber)?.uint64Value
    }
  }
}
