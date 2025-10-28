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

    public init(gram: Unigram, isOverridden: Bool) {
      self.gram = gram
      self.isOverridden = isOverridden
    }

    // MARK: Public

    public let gram: Unigram
    public let isOverridden: Bool

    public var keyArray: [String] { gram.keyArray }
    public var value: String { gram.value }
    public var score: Double { gram.score }
    public var segLength: Int { gram.segLength }
    public var isReadingMismatched: Bool { gram.isReadingMismatched }

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
  public var values: [String] { map(\.value) }

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

  /// 生成用以洞察使用者覆寫行為的複元圖索引鍵，最多支援指定長度的 n-gram（預設 3-gram）。
  ///
  /// - Remark: 除非有專門指定游標，否則身為 `[GramInPath]` 自身的
  /// 「陣列最尾端」（也就是打字方向上最前方）的那個 Gram 會被當成 Head。
  /// 若游標落在多字詞節點內，Head 會選擇游標右方（文字輸入方向上的下一個）讀音。
  /// - Parameters:
  ///   - cursor: 指定用於當作 head 的游標位置；若為 nil 則取陣列尾端。
  ///   - maxContext: 最多向前取用的上下文節點數（含 head），預設 3。
  public func generateKeyForPerception(
    cursor: Int? = nil,
    maxContext: Int = 3
  )
    -> (ngramKey: String, candidate: String, headReading: String)? {
    guard maxContext > 0 else { return nil }

    let headInfo: (pair: Megrez.GramInPath, range: Range<Int>)?
    let resolvedCursor: Int
    if let cursor, (0 ..< totalKeyCount).contains(cursor), let hit = findGram(at: cursor) {
      headInfo = (pair: hit.gram, range: hit.range)
      resolvedCursor = Swift.max(
        hit.range.lowerBound,
        Swift.min(cursor, hit.range.upperBound - 1)
      )
    } else if let tail = last {
      let lowerBound = totalKeyCount - tail.keyArray.count
      headInfo = (pair: tail, range: lowerBound ..< totalKeyCount)
      resolvedCursor = Swift.max(lowerBound, totalKeyCount - 1)
    } else {
      headInfo = nil
      resolvedCursor = 0
    }

    guard let headInfo else { return nil }
    let headPair = headInfo.pair
    let headRange = headInfo.range
    let headKeyOffset = Swift.max(0, resolvedCursor - headRange.lowerBound)
    guard headPair.keyArray.indices.contains(headKeyOffset) else { return nil }

    let placeholder = "()"
    let readingSeparator = Megrez.Compositor.theSeparator

    func isPunctuation(_ pair: Megrez.GramInPath) -> Bool {
      guard let firstReading = pair.keyArray.first else { return false }
      return firstReading.first == "_"
    }

    func combinedString(for pair: Megrez.GramInPath) -> String? {
      guard !pair.value.isEmpty else { return nil }
      guard !pair.keyArray.isEmpty else { return nil }
      let reading = pair.joinedCurrentKey(by: readingSeparator)
      guard !reading.isEmpty else { return nil }
      return "(\(reading),\(pair.value))"
    }

    let headIndex = lastIndex(where: { $0.gram.id == headPair.gram.id })
      ?? lastIndex(where: { $0 == headPair })
    guard let headIndex else { return nil }

    var resultCells = [String](repeating: placeholder, count: maxContext)
    resultCells[maxContext - 1] = combinedString(for: headPair) ?? placeholder

    var contextSlot = maxContext - 2
    var currentIndex = headIndex - 1
    var encounteredPunctuation = false

    while contextSlot >= 0 {
      guard currentIndex >= 0 else {
        resultCells[contextSlot] = placeholder
        contextSlot -= 1
        continue
      }
      let currentPair = self[currentIndex]
      currentIndex -= 1

      if encounteredPunctuation || isPunctuation(currentPair) {
        encounteredPunctuation = true
        resultCells[contextSlot] = placeholder
        contextSlot -= 1
        continue
      }

      resultCells[contextSlot] = combinedString(for: currentPair) ?? placeholder
      contextSlot -= 1
    }

    let headReading = headPair.keyArray[headKeyOffset]
    return (
      resultCells.joined(separator: "&"),
      headPair.value,
      headReading
    )
  }
}
