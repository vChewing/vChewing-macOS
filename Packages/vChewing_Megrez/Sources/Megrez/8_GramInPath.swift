// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

// MARK: - Megrez.GramInPath

extension Megrez {
  /// 輕量化節點封裝，便於將節點內的有效資訊以 Sendable 形式獨立傳遞。
  ///
  /// 該結構體的所有成員均為不可變狀態。
  @frozen
  public struct GramInPath: Codable, Hashable {
    // MARK: Lifecycle

    public init(keyArray: [String], gram: Unigram, isOverridden: Bool) {
      self.keyArray = keyArray
      self.gram = gram
      self.isOverridden = isOverridden
      self.isReadingMismatched = keyArray.count != gram.value.count
    }

    // MARK: Public

    public let gram: Unigram
    public let isOverridden: Bool
    public let keyArray: [String]
    public let isReadingMismatched: Bool

    public var value: String { gram.value }
    public var score: Double { gram.score }
    public var segLength: Int { keyArray.count }

    /// 該節點當前狀態所展示的鍵值配對。
    public var asCandidatePair: KeyValuePaired {
      .init(keyArray: keyArray, value: value)
    }

    /// 將當前單元圖的讀音陣列按照給定的分隔符銜接成一個字串。
    /// - Parameter separator: 給定的分隔符，預設值為 Assembler.theSeparator。
    /// - Returns: 已經銜接完畢的字串。
    public func joinedCurrentKey(by separator: String) -> String {
      keyArray.joined(separator: separator)
    }
  }
}

extension Array where Element == Megrez.GramInPath {
  /// 從一個節點陣列當中取出目前的選字字串陣列。
  public var values: [String] { compactMap(\.value) }

  /// 從一個節點陣列當中取出目前的索引鍵陣列。
  public func joinedKeys(by separator: String) -> [String] {
    map { $0.keyArray.joined(separator: separator) }
  }

  /// 從一個節點陣列當中取出目前的索引鍵陣列。
  public var keyArrays: [[String]] { map(\.keyArray) }

  /// 返回一連串的節點起點。結果為 (Result A, Result B) 字典陣列。
  /// Result A 以索引查座標，Result B 以座標查索引。
  private var gramBorderPointDictPair: (regionCursorMap: [Int: Int], cursorRegionMap: [Int: Int]) {
    // Result A 以索引查座標，Result B 以座標查索引。
    var resultA = [Int: Int]()
    var resultB: [Int: Int] = [-1: 0] // 防呆
    var cursorCounter = 0
    enumerated().forEach { gramCounter, neta in
      resultA[gramCounter] = cursorCounter
      neta.keyArray.forEach { _ in
        resultB[cursorCounter] = gramCounter
        cursorCounter += 1
      }
    }
    resultA[count] = cursorCounter
    resultB[cursorCounter] = count
    return (resultA, resultB)
  }

  /// 返回一個字典，以座標查索引。允許以游標位置查詢其屬於第幾個幅節座標（從 0 開始算）。
  public var cursorRegionMap: [Int: Int] { gramBorderPointDictPair.cursorRegionMap }

  /// 總讀音單元數量。在絕大多數情況下，可視為總幅節長度。
  public var totalKeyCount: Int { map(\.keyArray.count).reduce(0, +) }

  /// 根據給定的游標，返回其前後最近的節點邊界。
  /// - Parameter cursor: 給定的游標。
  public func contextRange(ofGivenCursor cursor: Int) -> Range<Int> {
    guard !isEmpty else { return 0 ..< 0 }
    let frontestSegLength = reversed()[0].keyArray.count
    var nilReturn = (totalKeyCount - frontestSegLength) ..< totalKeyCount
    if cursor >= totalKeyCount { return nilReturn } // 防呆
    let cursor = Swift.max(0, cursor) // 防呆
    nilReturn = cursor ..< cursor
    // 下文按道理來講不應該會出現 nilReturn。
    let mapPair = gramBorderPointDictPair
    guard let rearNodeID = mapPair.cursorRegionMap[cursor] else { return nilReturn }
    guard let rearIndex = mapPair.regionCursorMap[rearNodeID]
    else { return nilReturn }
    guard let frontIndex = mapPair.regionCursorMap[rearNodeID + 1]
    else { return nilReturn }
    return rearIndex ..< frontIndex
  }

  /// 在陣列內以給定游標位置找出對應的節點。
  /// - Parameters:
  ///   - cursor: 給定游標位置。
  /// - Returns: 查找結果。
  public func findGram(at cursor: Int) -> (gram: Megrez.GramInPath, range: Range<Int>)? {
    guard !isEmpty else { return nil }
    let cursor = Swift.max(0, Swift.min(cursor, totalKeyCount - 1)) // 防呆
    let range = contextRange(ofGivenCursor: cursor)
    guard let rearNodeID = cursorRegionMap[cursor] else { return nil }
    guard count - 1 >= rearNodeID else { return nil }
    return (self[rearNodeID], range)
  }

  /// 偵測是否出現游標切斷組字區內字元的情況。
  ///
  /// 此處不需要針對 cursor 做邊界檢查。
  public func isCursorCuttingChar(cursor: Int) -> Bool {
    let index = cursor
    var isBound = (index == contextRange(ofGivenCursor: index).lowerBound)
    if index == totalKeyCount { isBound = true }
    let rawResult = findGram(at: index)?.gram.isReadingMismatched ?? false
    return !isBound && rawResult
  }

  public func isCursorCuttingRegion(cursor: Int) -> Bool {
    let index = cursor
    var isBound = (index == contextRange(ofGivenCursor: index).lowerBound)
    if index == totalKeyCount { isBound = true }
    return !isBound
  }

  /// 提供一組逐字的字音配對陣列（不使用 Homa 的 KeyValuePaired 類型），但字音不相符的節點除外。
  public var smashedPairs: [(key: String, value: String)] {
    var arrData = [(key: String, value: String)]()
    forEach { gram in
      if gram.isReadingMismatched, !gram.keyArray.joined().isEmpty {
        arrData.append(
          (key: gram.keyArray.joined(separator: "\t"), value: gram.value)
        )
        return
      }
      let arrValueChars = gram.value.map(\.description)
      gram.keyArray.enumerated().forEach { i, key in
        arrData.append((key: key, value: arrValueChars[i]))
      }
    }
    return arrData
  }

  /// 生成用以洞察使用者覆寫行為的複元圖索引鍵，最多支援 3-gram。
  ///
  /// - Remark: 除非有專門指定游標，否則身為 `[GramInPath]` 自身的
  /// 「陣列最尾端」（也就是打字方向上最前方）的那個 Gram 會被當成 Head。
  public func generateKeyForPerception(
    cursor: Int? = nil
  )
    -> (ngramKey: String, candidate: String, headReading: String)? {
    let perceptedGIP: Megrez.GramInPath?
    if let cursor, (0 ..< self.totalKeyCount).contains(cursor) {
      perceptedGIP = findGram(at: cursor)?.gram
    } else {
      perceptedGIP = last
    }
    guard let perceptedGIP else { return nil }
    var arrGIPs = self
    while arrGIPs.last?.gram != perceptedGIP.gram { arrGIPs.removeLast() }
    var isHead = true
    var outputCells = [String]()
    loopProc: while !arrGIPs.isEmpty, let frontendPair = arrGIPs.last {
      defer { arrGIPs = arrGIPs.dropLast() }

      func makeNGramKeyCell(isHead: Bool) -> String? {
        // 字音數與字數不一致的內容會被拋棄。
        guard !frontendPair.isReadingMismatched else { return nil }
        guard !frontendPair.value.isEmpty else { return nil }
        guard !frontendPair.keyArray.joined().isEmpty else { return nil }
        let keyChain = frontendPair.keyArray.joined(separator: "-")
        guard !keyChain.contains("_") else { return nil }
        // 前置單元只記錄讀音，在其後的單元則同時記錄讀音與字詞
        return isHead ? keyChain : "(\(keyChain):\(frontendPair.value))"
      }

      guard let keyCellStr = makeNGramKeyCell(isHead: isHead) else { break loopProc }
      outputCells.insert(keyCellStr, at: 0)
      if outputCells.count >= 3 { break loopProc }
      if isHead { isHead = false }
    }
    guard !outputCells.isEmpty else { return nil }
    return (
      "(\(outputCells.joined(separator: ",")))",
      perceptedGIP.gram.value,
      perceptedGIP.joinedCurrentKey(by: "-")
    )
  }
}
