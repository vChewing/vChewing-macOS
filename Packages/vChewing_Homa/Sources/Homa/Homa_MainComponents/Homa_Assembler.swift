// (c) 2025 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

// MARK: - Homa.Assembler

extension Homa {
  /// 進階組字引擎的核心處理單元，專門負責將輸入索引鍵序列轉換為最佳的資料值組合。
  ///
  /// 在輸入法應用場景中，處理器接收注音符號序列並產生最適合的中文詞彙組合。
  /// 同時具備文本分析功能：將中文字符作為輸入，輸出經過語意最佳化的詞彙分段結果。
  public final class Assembler {
    // MARK: Lifecycle

    /// 建立組字引擎處理器副本。
    /// - Parameters:
    ///   - gramQuerier: 單元圖資料存取專用介面。
    ///   - config: 引擎配置參數。
    public init(
      gramQuerier: @escaping Homa.GramQuerier,
      perceptor: Homa.BehaviorPerceptor? = nil,
      config: Config = Config()
    ) {
      self.gramQuerier = gramQuerier
      self.config = config
      self.perceptor = perceptor
      self.gramQueryCache = [:]
      self.gramQueryCacheOrder = []
    }

    /// 複製指定的組字引擎處理器。
    /// - Remark: 由於 Node 採用類別設計而非結構體，因此在 Assembler 複製過程中無法自動執行深層複製。
    /// 這會導致複製後的 Assembler 副本中的 Node 變更會影響到原始的 Assembler 副本。
    /// 為了避免此類非預期的互動影響，特別提供此複製建構函數。
    public init(from target: Assembler) {
      self.config = target.config.hardCopy
      self.gramQuerier = target.gramQuerier
      self.perceptor = target.perceptor
      self.gramQueryCache = target.gramQueryCache
      self.gramQueryCacheOrder = target.gramQueryCacheOrder
    }

    // MARK: Public

    /// 基於文字書寫習慣的方向性定義。
    public enum TypingDirection { case front, rear }
    /// 軌格調整操作模式。
    public enum ResizeBehavior { case expand, shrink }

    /// 單元圖資料存取專用介面。
    public var gramQuerier: Homa.GramQuerier
    /// 用以洞察使用者字詞節點覆寫行為的 API。
    public var perceptor: BehaviorPerceptor?
    /// 組態設定。
    public private(set) var config = Config()

    /// 最近一次組句結果。
    public var assembledSentence: [GramInPath] {
      get { config.assembledSentence }
      set { config.assembledSentence = newValue }
    }

    /// 該組字器已經插入的的索引鍵，以陣列的形式存放。
    public private(set) var keys: [PossibleKey] {
      get { config.keys }
      set { config.keys = newValue }
    }

    /// 回傳當前組句結果所對應的真實讀音索引鍵陣列。
    ///
    /// 護摩引擎支援對讀音鍵的部分比對，所以需要這個 API 以返回真實結果。
    public var actualKeys: [String] {
      config.assembledSentence.keyArrays.flatMap(\.self)
    }

    /// 該組字器的幅節單元陣列。
    public private(set) var segments: [Segment] {
      get { config.segments }
      set { config.segments = newValue }
    }

    /// 該組字器的敲字游標位置。
    public var cursor: Int {
      get { config.cursor }
      set { config.cursor = newValue }
    }

    /// 該組字器的標記器（副游標）位置。
    public var marker: Int {
      get { config.marker }
      set { config.marker = newValue }
    }

    /// 該軌格內可以允許的最大幅節長度。
    public var maxSegLength: Int {
      get { config.maxSegLength }
      set { config.maxSegLength = newValue }
    }

    /// 該組字器的長度，組字器內已經插入的單筆索引鍵的數量，也就是內建漢字讀音的數量（唯讀）。
    /// - Remark: 理論上而言，segments.count 也是這個數。
    /// 但是，為了防止萬一，就用了目前的方法來計算。
    public var length: Int { config.length }

    /// 組字器是否為空。
    public var isEmpty: Bool { segments.isEmpty && keys.isEmpty }

    /// 該組字器的硬拷貝。
    /// - Remark: 因為 Node 不是 Struct，所以會在 Assembler 被拷貝的時候無法被真實複製。
    /// 這樣一來，Assembler 複製品當中的 Node 的變化會被反應到原先的 Assembler 身上。
    /// 這在某些情況下會造成意料之外的混亂情況，所以需要引入一個拷貝用的建構子。
    public var copy: Assembler { .init(from: self) }

    /// 生成用以交給 GraphViz 診斷的資料檔案內容，純文字。
    public func dumpDOT(verticalGraph: Bool = false) -> String {
      let rankDirection = verticalGraph ? "TB" : "LR"
      var strOutput = "digraph {\ngraph [ rankdir=\(rankDirection) ];\nBOS;\n"
      segments.enumerated().forEach { p, segment in
        segment.keys.sorted().forEach { ni in
          guard let np = segment[ni], let npValue = np.value else { return }
          if p == 0 { strOutput.append("BOS -> \(npValue);\n") }
          strOutput.append("\(npValue);\n")
          if (p + ni) < segments.count {
            let destinationSegment = segments[p + ni]
            destinationSegment.keys.sorted().forEach { q in
              guard let dnValue = destinationSegment[q]?.value else { return }
              strOutput.append(npValue + " -> " + dnValue + ";\n")
            }
          }
          guard (p + ni) == segments.count else { return }
          strOutput.append(npValue + " -> EOS;\n")
        }
      }
      strOutput.append("EOS;\n}\n")
      return strOutput.description
    }

    /// 重置包括游標在內的各項參數，且清空各種由組字器生成的內部資料。
    ///
    /// 將已經被插入的索引鍵陣列與幅節單元陣列（包括其內的節點）全部清空。
    /// 最近一次的組句結果陣列也會被清空。游標跳轉換算表也會被清空。
    public func clear() {
      config.clear()
      gramQueryCache.removeAll(keepingCapacity: true)
      gramQueryCacheOrder.removeAll(keepingCapacity: true)
    }

    /// 在游標位置插入給定的索引鍵（單一讀音，無聲調替代）。
    /// - Parameter key: 要插入的索引鍵。
    public func insertKey(_ key: String) throws {
      try insertKeys([.singleKey(key)])
    }

    /// 在游標位置插入給定的索引鍵（含聲調替代）。
    /// - Parameter key: 要插入的索引鍵（一個位置的所有可能讀音）。
    public func insertKey(_ key: [String]) throws {
      let possibleKey: PossibleKey = key.count == 1 ? .singleKey(key[0]) : .multipleKeys(key)
      try insertKeys([possibleKey])
    }

    /// 在游標位置插入給定的多個索引鍵。
    /// - Parameter keys: 要插入的多個索引鍵。
    public func insertKeys(_ givenKeys: [PossibleKey]) throws {
      guard !givenKeys.isEmpty, givenKeys.allSatisfy(\.isValid) else {
        throw Homa.Exception.givenKeyIsEmpty
      }
      let gridBackup = segments
      var keyExistenceChecked = [GramQueryCacheKey: Bool]()
      var warmupQueryBuffer = [GramQueryCacheKey: [Homa.Gram]]()
      for (cursorAdvancedPosition, possibleKey) in givenKeys.enumerated() {
        let altValues = possibleKey.allValues
        let cacheKey = GramQueryCacheKey(altValues)
        if !(keyExistenceChecked[cacheKey] ?? false) {
          let hasAnyResult = altValues.contains { alt in
            !queryGrams(using: [alt], cache: &warmupQueryBuffer).isEmpty
          }
          guard hasAnyResult else {
            throw Homa.Exception.givenKeyHasNoResults
          }
          keyExistenceChecked[cacheKey] = true
        }
        keys.insert(possibleKey, at: cursor + cursorAdvancedPosition)
        resizeGrid(at: cursor + cursorAdvancedPosition, do: .expand)
      }
      do {
        try assignNodes()
      } catch {
        // 防呆：若 assignNodes() 失敗，恢復被搞壞的 segments。
        segments = gridBackup
        throw error
      }
      cursor += givenKeys.count // 游標必須得在執行 assignNodes() 之後才可以變動。
    }

    /// 在游標位置插入給定的多個索引鍵（由外部傳入的 [[String]] 陣列）。
    /// - Parameter keys: 要插入的多個索引鍵。
    public func insertKeys(_ givenKeys: [[String]]) throws {
      let possibleKeys = givenKeys.map { key -> PossibleKey in
        key.count == 1 ? .singleKey(key[0]) : .multipleKeys(key)
      }
      try insertKeys(possibleKeys)
    }

    /// 在游標位置插入給定的多個索引鍵（相容舊版 [String] 介面）。
    /// - Parameter keys: 要插入的多個索引鍵。
    @available(*, deprecated, message: "Use insertKeys(_: [PossibleKey]) instead")
    public func insertKeys(_ givenKeys: [String]) throws {
      try insertKeys(givenKeys.map { .singleKey($0) })
    }

    /// 朝著指定方向砍掉一個與游標相鄰的讀音。
    ///
    /// 在護摩引擎所遵循的術語體系當中，「與文字輸入方向相反的方向」為向後（Rear），反之則為向前（Front）。
    /// 如果是朝著與文字輸入方向相反的方向砍的話，游標位置會自動遞減。
    /// - Parameter direction: 指定方向（相對於文字輸入方向而言）。
    public func dropKey(direction: TypingDirection) throws {
      guard !keys.isEmpty else { throw Homa.Exception.assemblerIsEmpty }
      guard !isCursorAtEdge(direction: direction) else {
        throw Homa.Exception.deleteKeyAgainstBorder
      }
      let isBackSpace: Bool = direction == .rear ? true : false
      keys.remove(at: cursor - (isBackSpace ? 1 : 0))
      cursor -= isBackSpace ? 1 : 0 // 在縮節之前。
      resizeGrid(at: cursor, do: .shrink)
      try? assignNodes() // 此處拋出的異常已無利用之意義，放行即可。
    }

    /// 獲取當前標記得範圍。這個函式只能是函式、而非只讀變數。
    /// - Returns: 當前標記範圍。
    public func currentMarkedRange() -> Range<Int> {
      // 這必須得是 `[A,B)` 型區間，因為這是用來從 assembledSentence 拿取 KeySequenceSlice 時所使用的。
      min(cursor, marker) ..< max(cursor, marker)
    }

    /// 偵測是否出現游標切斷組字區內字元的情況。
    public func isCursorCuttingChar(isMarker: Bool = false) -> Bool {
      let index = isMarker ? marker : cursor
      return assembledSentence.isCursorCuttingChar(cursor: index)
    }

    /// 判斷游標是否可以繼續沿著給定方向移動。
    /// - Parameters:
    ///   - direction: 指定方向（相對於文字輸入方向而言）。
    ///   - isMarker: 是否為標記游標。
    public func isCursorAtEdge(direction: TypingDirection, isMarker: Bool = false) -> Bool {
      let pos = isMarker ? marker : cursor
      switch direction {
      case .front: return pos == length
      case .rear: return pos == 0
      }
    }

    /// 按步移動游標。如果遇到游標切斷組字區內字元的情況，則繼續移動行為、直至該情況消失為止。
    /// - Parameters:
    ///   - direction: 指定方向（相對於文字輸入方向而言）。
    ///   - isMarker: 是否為標記游標。
    public func moveCursorStepwise(
      to direction: TypingDirection,
      isMarker: Bool = false
    ) throws {
      let delta: Int = switch direction {
      case .front: 1
      case .rear: -1
      }
      var pos: Int {
        get { isMarker ? marker : cursor }
        set { isMarker ? { marker = newValue }() : { cursor = newValue }() }
      }
      guard !isCursorAtEdge(direction: direction, isMarker: isMarker) else {
        throw Exception.cursorAlreadyAtBorder
      }
      pos += delta
      if isCursorCuttingChar(isMarker: isMarker) {
        try jumpCursorBySegment(to: direction, isMarker: isMarker)
      }
    }

    /// 按幅節來前後移動游標。
    ///
    /// 在護摩引擎所遵循的術語體系當中，「與文字輸入方向相反的方向」為向後（Rear），反之則為向前（Front）。
    /// - Parameters:
    ///   - direction: 指定移動方向（相對於文字輸入方向而言）。
    ///   - isMarker: 要移動的是否為作為選擇標記的副游標（而非敲字用的主游標）。
    /// 具體用法可以是這樣：你在標記模式下，
    /// 如果出現了「副游標切了某個字音數量不相等的節點」的情況的話，
    /// 則直接用這個函式將副游標往前推到接下來的正常的位置上。
    public func jumpCursorBySegment(
      to direction: TypingDirection,
      isMarker: Bool = false
    ) throws {
      var target = isMarker ? marker : cursor
      switch (direction, target) {
      case (.front, length), (.rear, 0):
        throw Homa.Exception.cursorAlreadyAtBorder
      default: break
      }
      guard let currentRegion = assembledSentence.cursorRegionMap[target] else {
        throw Homa.Exception.cursorRegionMapMatchingFailure
      }
      let guardedCurrentRegion = min(assembledSentence.count - 1, currentRegion)
      let aRegionForward = max(currentRegion - 1, 0)
      let currentRegionBorderRear: Int = assembledSentence[
        0 ..< currentRegion
      ].map(\.segLength).reduce(0, +)
      switch target {
      case currentRegionBorderRear:
        switch direction {
        case .front:
          target = (currentRegion > assembledSentence.count)
            ? keys.count
            : assembledSentence[0 ... guardedCurrentRegion].map(\.segLength).reduce(0, +)
        case .rear:
          target = assembledSentence[0 ..< aRegionForward].map(\.segLength).reduce(0, +)
        }
      default:
        switch direction {
        case .front:
          target = currentRegionBorderRear + assembledSentence[guardedCurrentRegion].segLength
        case .rear:
          target = currentRegionBorderRear
        }
      }
      switch isMarker {
      case false: cursor = target
      case true: marker = target
      }
    }

    /// 根據當前狀況更新整個組字器的節點文脈。
    /// - Parameter updateExisting: 是否根據目前的語言模型的資料狀態來對既有節點更新其內部的單元圖陣列資料。
    /// 該特性可以用於「在選字窗內屏蔽了某個詞之後，立刻生效」這樣的軟體功能需求的實現。
    public func assignNodes(updateExisting: Bool = false) throws {
      if updateExisting {
        gramQueryCache.removeAll(keepingCapacity: true)
        gramQueryCacheOrder.removeAll(keepingCapacity: true)
      }
      let maxSegLength = maxSegLength
      let rangeOfPositions: Range<Int>
      if updateExisting {
        rangeOfPositions = segments.indices
      } else {
        let lowerbound = Swift.max(0, cursor - maxSegLength)
        let upperbound = Swift.min(cursor + maxSegLength, keys.count)
        rangeOfPositions = lowerbound ..< upperbound
      }
      var nodesChangedCounter = 0
      var queryBuffer: [GramQueryCacheKey: [Homa.Gram]] = [:]
      rangeOfPositions.forEach { position in
        let rangeOfLengths = 1 ... min(maxSegLength, rangeOfPositions.upperBound - position)
        rangeOfLengths.forEach { theLength in
          guard position + theLength <= keys.count, position >= 0 else { return }
          let alternativesSlice = keys[position ..< (position + theLength)]
          let queriedGrams = queryGramsForAlternatives(alternativesSlice, cache: &queryBuffer)
          if (0 ..< segments.count).contains(position),
             let theNode = segments[position][theLength] {
            if !updateExisting { return }
            // 自動銷毀無效的節點。
            if queriedGrams.isEmpty {
              if theNode.keyArray.count == 1 { return }
              segments[position][theLength] = nil
            } else {
              theNode.syncingGrams(from: queriedGrams)
            }
            nodesChangedCounter += 1
            return
          }
          guard !queriedGrams.isEmpty else { return }
          // 這裡原本用 SegmentUnit.addNode 來完成的，但直接當作字典來互動的話也沒差。
          let representativeKeyArray = alternativesSlice.map(\.first)
          segments[position][theLength] = .init(keyArray: representativeKeyArray, grams: queriedGrams)
          nodesChangedCounter += 1
        }
      }
      queryBuffer.removeAll() // 手動清理，免得 ARC 拖時間。
      guard nodesChangedCounter != 0 else { throw Homa.Exception.noNodesAssigned }
      assemble()
    }

    /// 生成所有節點的覆寫狀態鏡照。
    /// - Returns: 節點 ID 與覆寫狀態的對應字典。
    public func createNodeOverrideStatusMirror() -> [FIUUID: Homa.NodeOverrideStatus] {
      config.createNodeOverrideStatusMirror()
    }

    /// 從鏡照資料恢復所有節點的覆寫狀態。
    /// - Parameter mirror: 節點 ID 與覆寫狀態的對應字典。
    public func restoreFromNodeOverrideStatusMirror(_ mirror: [FIUUID: Homa.NodeOverrideStatus]) {
      config.restoreFromNodeOverrideStatusMirror(mirror)
    }

    // MARK: Private

    private struct GramQueryCacheKey: Hashable {
      // MARK: Lifecycle

      init(_ keyArray: [String]) {
        self.keyArray = keyArray
        var hasher = Hasher()
        hasher.combine(keyArray)
        self.precomputedHash = hasher.finalize()
      }

      // MARK: Internal

      let keyArray: [String]

      static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.keyArray == rhs.keyArray
      }

      func hash(into hasher: inout Hasher) {
        hasher.combine(precomputedHash)
      }

      // MARK: Private

      private let precomputedHash: Int
    }

    private static let maxCachedGramQueries = 512

    // 針對連續 insertKey() 的 query 結果快取，避免完整 lexicon partial match 重複查詢。
    // 保留預先計算的雜湊值，但仍以完整 keyArray 判等，避免 Int 雜湊碰撞誤命中。
    private var gramQueryCache: [GramQueryCacheKey: [Homa.Gram]]
    // 記錄插入順序，供淘汰使用（最舊的鍵在最前面）。
    private var gramQueryCacheOrder: [GramQueryCacheKey]

    private static func sortGramRAW(_ lhs: Homa.GramRAW, _ rhs: Homa.GramRAW) -> Bool {
      if lhs.keyArray.count != rhs.keyArray.count {
        return lhs.keyArray.count > rhs.keyArray.count
      }
      if lhs.probability != rhs.probability {
        return lhs.probability > rhs.probability
      }
      if lhs.keyArray != rhs.keyArray {
        return lhs.keyArray.lexicographicallyPrecedes(rhs.keyArray)
      }
      return (lhs.previous ?? "") < (rhs.previous ?? "")
    }

    private static func makeGramIdentityHash(_ raw: Homa.GramRAW) -> Int {
      var hasher = Hasher()
      hasher.combine(raw.keyArray)
      hasher.combine(raw.value)
      hasher.combine(raw.previous)
      return hasher.finalize()
    }

    /// 計算給定陣列陣列的笛卡爾積。
    private static func cartesianProduct<T>(_ arrays: [[T]]) -> [[T]] {
      guard !arrays.isEmpty else { return [[]] }
      guard !arrays.contains(where: \.isEmpty) else { return [] }
      var result: [[T]] = [[]]
      for array in arrays {
        var newResult: [[T]] = []
        newResult.reserveCapacity(result.count * array.count)
        for prefix in result {
          for element in array {
            newResult.append(prefix + [element])
          }
        }
        result = newResult
      }
      return result
    }

    /// 對給定替代讀音陣列展開笛卡爾積、逐一查詢、並合併結果。
    private func queryGramsForAlternatives(
      _ alternativesSlice: ArraySlice<PossibleKey>,
      cache: inout [GramQueryCacheKey: [Homa.Gram]]
    )
      -> [Homa.Gram] {
      // 快速路徑——無替代讀音時直接查詢，無需笛卡爾積展開
      if alternativesSlice.allSatisfy({
        if case .singleKey = $0 { return true } else { return false }
      }) {
        let keyArray = alternativesSlice.map(\.first)
        return queryGrams(using: keyArray, cache: &cache)
      }
      let combinations = Self.cartesianProduct(alternativesSlice.map(\.allValues))
      var mergedGrams: [Homa.Gram] = []
      mergedGrams.reserveCapacity(combinations.count * 4)
      for combination in combinations {
        let grams = queryGrams(using: combination, cache: &cache)
        mergedGrams.append(contentsOf: grams)
      }
      return mergedGrams.sorted {
        if $0.keyArray.count != $1.keyArray.count {
          return $0.keyArray.count > $1.keyArray.count
        }
        if $0.probability != $1.probability {
          return $0.probability > $1.probability
        }
        if $0.keyArray != $1.keyArray {
          return $0.keyArray.lexicographicallyPrecedes($1.keyArray)
        }
        return ($0.previous ?? "") < ($1.previous ?? "")
      }
    }

    /// 從元圖存取專用 API 將獲取的結果轉為元圖、以供 Nodes 使用。
    ///
    /// 此處故意針對不同的 Nodes 單獨建立 Gram 副本，是為了確保它們的記憶體位置不同。
    /// 便於其他函式直接比對記憶體位置（也就是用「===」與「!==」來比對）。
    /// - Parameters:
    ///   - keyArray: 讀音陣列。
    ///   - cache: 快取。
    /// - Returns: 元圖陣列。
    private func queryGrams(
      using keyArray: [String],
      cache: inout [GramQueryCacheKey: [Homa.Gram]]
    )
      -> [Homa.Gram] {
      let cacheKey = GramQueryCacheKey(keyArray)
      if let cached = cache[cacheKey] {
        return cached
      }
      if let cached = gramQueryCache[cacheKey] {
        cache[cacheKey] = cached
        return cached
      }
      var insertedIntel = Set<Int>()
      let newResult: [Homa.Gram] = gramQuerier(keyArray).sorted(by: Self.sortGramRAW).compactMap {
        let intel = Self.makeGramIdentityHash($0)
        guard insertedIntel.insert(intel).inserted else { return nil }
        return Homa.Gram($0)
      }
      cache[cacheKey] = newResult
      if gramQueryCache.count >= Self.maxCachedGramQueries {
        // 淘汰最舊的一半，而非全量清空，以保留最近常用的快取項目。
        let halfCount = gramQueryCacheOrder.count / 2
        gramQueryCacheOrder.prefix(halfCount).forEach { gramQueryCache.removeValue(forKey: $0) }
        gramQueryCacheOrder.removeFirst(halfCount)
      }
      gramQueryCache[cacheKey] = newResult
      gramQueryCacheOrder.append(cacheKey)
      return newResult
    }
  }
}

// MARK: - Internal Methods (Maybe Public)

extension Homa.Assembler {
  /// 在該軌格的指定幅節座標擴增或減少一個幅節單元。
  /// - Parameters:
  ///   - location: 給定的幅節座標。
  ///   - action: 指定是擴張還是縮減一個幅節。
  private func resizeGrid(at location: Int, do action: ResizeBehavior) {
    let location = max(min(location, segments.count), 0) // 防呆
    switch action {
    case .expand:
      segments.insert(.init(), at: location)
      if [0, segments.count].contains(location) { return }
    case .shrink:
      if segments.count == location { return }
      segments.remove(at: location)
    }
    dropWreckedNodes(at: location)
  }

  /// 扔掉所有被 resizeGrid() 損毀的節點。
  ///
  /// 拿新增幅節來打比方的話，在擴增幅節之前：
  /// ```
  /// Segment Index 0   1   2   3
  ///                (---)
  ///                (-------)
  ///            (-----------)
  /// ```
  /// 在幅節座標 2 (SegmentIndex = 2) 的位置擴增一個幅節之後:
  /// ```
  /// Segment Index 0   1   2   3   4
  ///                (---)
  ///                (XXX?   ?XXX) <-被扯爛的節點
  ///            (XXXXXXX?   ?XXX) <-被扯爛的節點
  /// ```
  /// 拿縮減幅節來打比方的話，在縮減幅節之前：
  /// ```
  /// Segment Index 0   1   2   3
  ///                (---)
  ///                (-------)
  ///            (-----------)
  /// ```
  /// 在幅節座標 2 的位置就地砍掉一個幅節之後:
  /// ```
  /// Segment Index 0   1   2   3   4
  ///                (---)
  ///                (XXX? <-被砍爛的節點
  ///            (XXXXXXX? <-被砍爛的節點
  /// ```
  /// - Parameter location: 給定的幅節座標。
  internal func dropWreckedNodes(at location: Int) {
    let location = max(min(location, segments.count), 0) // 防呆
    guard !segments.isEmpty else { return }
    let affectedLength = maxSegLength - 1
    let begin = max(0, location - affectedLength)
    guard location >= begin else { return }
    (begin ..< location).forEach { delta in
      ((location - delta + 1) ... maxSegLength).forEach { theLength in
        segments[delta][theLength] = nil
      }
    }
  }
}
