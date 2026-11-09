// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation

// MARK: - LXAssembly.LXCandidateSequence

extension LXAssembly {
  /// 使用者自訂候選字詞排序表。
  ///
  /// 資料以「一個讀音一行」表達：行首為讀音（後置聲調註記之注音讀音），其後依序為該讀音下
  /// 想要優先陳列的候選字詞，彼此以半形空白或定位字元分隔：
  ///
  /// ```
  /// # 讀音　候選（依序）
  /// ㄅㄚ    八 巴 吧
  /// ㄗㄞˋ   在 再
  /// ```
  ///
  /// 列出的候選會依序移到最前面；其餘候選維持原本的相對順序接在其後。此表只調整
  /// 辭典既有候選之次序，不新增辭典內查無的候選。同一讀音出現多行時以最後一行為準。
  /// 本表之優先權高於倚天中文 DOS 候選序，惟逐字選字模式與磁帶模式不套用本表。
  struct LXCandidateSequence {
    // MARK: Lifecycle

    init() {}

    // MARK: Internal

    /// 本資料模組之儲存後端。預設沿用行程級之 `LXAssembly.userDataLocator`；
    /// 注入專屬的後端即可讓該模組之讀取完全脫離硬碟。
    var locator: any UserDataLocator = LXAssembly.userDataLocator

    /// 讀音 → 候選字詞（依陳列順序）。
    private(set) var sequenceMap: [String: [String]] = [:]

    /// 檔案原文（供語彙編輯器讀回與存檔；保留註解與列序）。
    private(set) var rawText: String = ""

    /// 本模組最後一次成功讀取的路徑。
    private(set) var filePath: String?

    var count: Int { sequenceMap.count }

    var isLoaded: Bool { !sequenceMap.isEmpty }

    /// 解析整份排序表。
    ///
    /// 逐列處理：空列與 `#` 起首之列（含既有使用者資料檔之 pragma 列）一律忽略；
    /// 其餘每列切分為「讀音 ＋ 一至多個候選字詞」，候選字詞去重且保序。
    /// 不足兩欄之列、或讀音為空者一律忽略。
    static func parse(_ rawStrData: String) -> [String: [String]] {
      var result: [String: [String]] = [:]
      rawStrData.split(whereSeparator: { $0.isNewline }).forEach { rawLine in
        let line = rawLine.trimmingCharacters(in: .whitespaces)
        guard !line.isEmpty, !line.hasPrefix("#") else { return }
        let tokens = line.split(whereSeparator: \.isWhitespace).map(String.init)
        guard tokens.count >= 2 else { return }
        let reading = tokens[0]
        guard !reading.isEmpty else { return }
        var values: [String] = []
        var seen = Set<String>()
        tokens.dropFirst().forEach { value in
          guard !value.isEmpty, seen.insert(value).inserted else { return }
          values.append(value)
        }
        guard !values.isEmpty else { return }
        // 同一讀音多行 ⇒ 後者覆蓋前者（「保留最後一次出現」與既有使用者資料之整理語義一致）。
        result[reading] = values
      }
      return result
    }

    /// 給定讀音之自訂候選序；無此讀音時回傳空陣列。
    func values(for reading: String) -> [String] {
      sequenceMap[reading] ?? []
    }

    mutating func clear() {
      filePath = nil
      rawText = ""
      sequenceMap.removeAll(keepingCapacity: false)
    }

    /// 將資料從檔案讀入。讀取失敗時只清空本模組、不波及呼叫端。
    /// - Parameter path: 給定路徑。
    /// - Returns: 是否成功讀入（空檔案視為成功、表內無資料）。
    @discardableResult
    mutating func open(_ path: String) -> Bool {
      if isLoaded { clear() }
      let oldPath = filePath
      filePath = nil
      do {
        let text = try LXAssembly.withFileHandleQueueSync {
          try locator.readText(at: URL(fileURLWithPath: path))
        }
        replaceData(textData: text)
      } catch {
        filePath = oldPath
        vCLMLog("\(error)")
        vCLMLog("↑ Exception happened when reading candidate sequence at: \(path).")
        return false
      }
      filePath = path
      return true
    }

    mutating func replaceData(textData rawStrData: String) {
      rawText = rawStrData
      sequenceMap = Self.parse(rawStrData)
    }

    /// 將 `rawText` 原樣寫回檔案（語彙編輯器之存檔路徑）。
    func saveData() {
      guard let filePath else { return }
      LXAssembly.withFileHandleQueueSync {
        do {
          try locator.write(Data(rawText.utf8), to: URL(fileURLWithPath: filePath))
        } catch {
          vCLMLog("Failed to save candidate sequence to: \(filePath)")
        }
      }
    }
  }
}
