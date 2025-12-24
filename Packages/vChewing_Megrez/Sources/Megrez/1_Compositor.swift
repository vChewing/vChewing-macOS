// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

// MARK: - Megrez.Compositor

extension Megrez {
  /// 智慧組字引擎的主要處理單元，專門處理索引鍵序列到資料值集合的轉換任務。
  ///
  /// 在輸入法使用情境下，處理器接收注音符號序列並產生對應的中文詞彙組合。
  /// 另外也具備文本分析能力：將中文字符作為輸入，輸出經過語意分析的詞彙分段結果。
  public final class Compositor {
    // MARK: Lifecycle

    /// 建立組字引擎處理器副本。
    /// - Parameter langModel: 指定要整合的語言模型介面。
    public init(with langModel: LangModelProtocol, separator: String = "-") {
      self.langModel = langModel
      self.separator = separator
    }

    /// 複製指定的組字引擎處理器。
    /// - Remark: 由於 Node 採用類別設計而非結構體，因此在 Compositor 複製過程中無法自動執行深層複製。
    /// 這會導致複製後的 Composer 副本中的 Node 變更會影響到原始的 Composer 副本。
    /// 為了避免此類非預期的互動影響，特別提供此複製建構函數。
    public init(from target: Compositor) {
      self.config = target.config.hardCopy
      self.langModel = target.langModel
    }

    // MARK: Public

    /// 基於文字書寫習慣的方向性定義。
    public enum TypingDirection { case front, rear }
    /// 軌格調整操作模式。
    public enum ResizeBehavior { case expand, shrink }

    /// 複合讀音索引鍵中用於分隔各個讀音組成部分的預設分隔符號，預設為「-」。
    nonisolated(unsafe) public static var theSeparator: String = "-"

    public private(set) var config = CompositorConfig()

    /// 軌格系統允許的最大區段涵蓋長度限制。
    public var maxSegLength: Int {
      get { config.maxSegLength }
      set { config.maxSegLength = newValue }
    }

    /// 最近一次組句操作的執行結果。
    public var assembledSentence: [Megrez.GramInPath] {
      get { config.assembledSentence }
      set { config.assembledSentence = newValue }
    }

    /// 該組字器已經插入的的索引鍵，以陣列的形式存放。
    public private(set) var keys: [String] {
      get { config.keys }
      set { config.keys = newValue }
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

    /// 多字讀音鍵當中用以分割漢字讀音的記號，預設為「-」。
    public var separator: String {
      get { config.separator }
      set { config.separator = newValue }
    }

    /// 該組字器的長度，組字器內已經插入的單筆索引鍵的數量，也就是內建漢字讀音的數量（唯讀）。
    /// - Remark: 理論上而言，segments.count 也是這個數。
    /// 但是，為了防止萬一，就用了目前的方法來計算。
    public var length: Int { config.length }

    /// 組字器是否為空。
    public var isEmpty: Bool { segments.isEmpty && keys.isEmpty }

    /// 該組字器所使用的語言模型（被 LangModelRanked 所封裝）。
    public var langModel: LangModelProtocol {
      didSet { clear() }
    }

    /// 該組字器的硬拷貝。
    /// - Remark: 因為 Node 不是 Struct，所以會在 Compositor 被拷貝的時候無法被真實複製。
    /// 這樣一來，Compositor 複製品當中的 Node 的變化會被反應到原先的 Compositor 身上。
    /// 這在某些情況下會造成意料之外的混亂情況，所以需要引入一個拷貝用的建構子。
    public var copy: Compositor { .init(from: self) }

    /// 生成用以交給 GraphViz 診斷的資料檔案內容，純文字。
    public var dumpDOT: String {
      var strOutput = "digraph {\ngraph [ rankdir=LR ];\nBOS;\n"
      segments.enumerated().forEach { p, segment in
        segment.keys.sorted().forEach { ni in
          guard let np = segment[ni] else { return }
          let npValue = np.value
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

    /// 創建所有節點的覆寫狀態鏡照。
    /// - Returns: 包含所有節點 ID 到覆寫狀態映射的字典。
    public func createNodeOverrideStatusMirror() -> [FIUUID: NodeOverrideStatus] {
      config.createNodeOverrideStatusMirror()
    }

    /// 從節點覆寫狀態鏡照恢復所有節點的覆寫狀態。
    /// - Parameter mirror: 包含節點 ID 到覆寫狀態映射的字典。
    public func restoreFromNodeOverrideStatusMirror(_ mirror: [FIUUID: NodeOverrideStatus]) {
      config.restoreFromNodeOverrideStatusMirror(mirror)
    }

    /// 重置包括游標在內的各項參數，且清空各種由組字器生成的內部資料。
    ///
    /// 將已經被插入的索引鍵陣列與幅節單元陣列（包括其內的節點）全部清空。
    /// 最近一次的組句結果陣列也會被清空。游標跳轉換算表也會被清空。
    public func clear() {
      config.clear()
    }

    /// 在游標位置插入給定的索引鍵。
    /// - Parameter key: 要插入的索引鍵。
    /// - Returns: 該操作是否成功執行。
    @discardableResult
    public func insertKey(_ key: String) -> Bool {
      guard !key.isEmpty, key != separator,
            langModel.hasUnigramsFor(keyArray: [key]) else { return false }
      keys.insert(key, at: cursor)
      let gridBackup = segments.map(\.hardCopy)
      resizeGrid(at: cursor, do: .expand)
      let nodesInserted = assignNodes()
      // 用來在 langModel.hasUnigramsFor() 結果不準確的時候防呆、恢復被搞壞的 segments。
      if nodesInserted == 0 {
        segments = gridBackup
        return false
      }
      cursor += 1 // 游標必須得在執行 update() 之後才可以變動。
      return true
    }

    /// 朝著指定方向砍掉一個與游標相鄰的讀音。
    ///
    /// 在 Megrez 的術語體系當中，「與文字輸入方向相反的方向」為向後（Rear），反之則為向前（Front）。
    /// 如果是朝著與文字輸入方向相反的方向砍的話，游標位置會自動遞減。
    /// - Parameter direction: 指定方向（相對於文字輸入方向而言）。
    /// - Returns: 該操作是否成功執行。
    @discardableResult
    public func dropKey(direction: TypingDirection) -> Bool {
      guard !keys.isEmpty else { return false }
      guard !isCursorAtEdge(direction: direction) else { return false }
      let isBackSpace: Bool = direction == .rear ? true : false
      keys.remove(at: cursor - (isBackSpace ? 1 : 0))
      cursor -= isBackSpace ? 1 : 0 // 在縮節之前。
      resizeGrid(at: cursor, do: .shrink)
      assignNodes()
      return true
    }

    /// 獲取當前標記得範圍。這個函式只能是函式、而非只讀變數。
    /// - Returns: 當前標記範圍。
    public func currentMarkedRange() -> Range<Int> {
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
    )
      -> Bool {
      let delta: Int = switch direction {
      case .front: 1
      case .rear: -1
      }
      var pos: Int {
        get { isMarker ? marker : cursor }
        set { isMarker ? { marker = newValue }() : { cursor = newValue }() }
      }
      guard !isCursorAtEdge(direction: direction, isMarker: isMarker) else {
        return false
      }
      pos += delta
      if isCursorCuttingChar(isMarker: isMarker) {
        return jumpCursorBySegment(to: direction, isMarker: isMarker)
      }
      return true
    }

    /// 按幅節來前後移動游標。
    ///
    /// 在 Megrez 的術語體系當中，「與文字輸入方向相反的方向」為向後（Rear），反之則為向前（Front）。
    /// - Parameters:
    ///   - direction: 指定移動方向（相對於文字輸入方向而言）。
    ///   - isMarker: 要移動的是否為作為選擇標記的副游標（而非打字用的主游標）。
    /// 具體用法可以是這樣：你在標記模式下，
    /// 如果出現了「副游標切了某個字音數量不相等的節點」的情況的話，
    /// 則直接用這個函式將副游標往前推到接下來的正常的位置上。
    /// - Returns: 該操作是否順利完成。
    @discardableResult
    public func jumpCursorBySegment(
      to direction: TypingDirection,
      isMarker: Bool = false
    )
      -> Bool {
      var target = isMarker ? marker : cursor
      switch direction {
      case .front:
        if target == length { return false }
      case .rear:
        if target == 0 { return false }
      }
      guard let currentRegion = assembledSentence.cursorRegionMap[target] else { return false }
      let guardedCurrentRegion = min(assembledSentence.count - 1, currentRegion)
      let aRegionForward = max(currentRegion - 1, 0)
      let currentRegionBorderRear: Int = assembledSentence[0 ..< currentRegion].map(\.segLength)
        .reduce(
          0,
          +
        )
      switch target {
      case currentRegionBorderRear:
        switch direction {
        case .front:
          target =
            (currentRegion > assembledSentence.count)
              ? keys.count : assembledSentence[0 ... guardedCurrentRegion].map(\.segLength).reduce(
                0,
                +
              )
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
      return true
    }

    /// 根據當前狀況更新整個組字器的節點文脈。
    /// - Parameter updateExisting: 是否根據目前的語言模型的資料狀態來對既有節點更新其內部的單元圖陣列資料。
    /// 該特性可以用於「在選字窗內屏蔽了某個詞之後，立刻生效」這樣的軟體功能需求的實現。
    /// - Returns: 新增或影響了多少個節點。如果返回「0」則表示可能發生了錯誤。
    @discardableResult
    public func assignNodes(updateExisting: Bool = false) -> Int {
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
      var queryBuffer: [[String]: [Megrez.Unigram]] = [:]
      rangeOfPositions.forEach { position in
        let rangeOfLengths = 1 ... min(maxSegLength, rangeOfPositions.upperBound - position)
        rangeOfLengths.forEach { theLength in
          guard position + theLength <= keys.count, position >= 0 else { return }
          let keyArraySliced = keys[position ..< (position + theLength)].map(\.description)
          if (0 ..< segments.count).contains(position),
             let theNode = segments[position][theLength] {
            if !updateExisting { return }
            let unigrams = getSortedUnigrams(keyArray: keyArraySliced, cache: &queryBuffer)
            // 自動銷毀無效的節點。
            if unigrams.isEmpty {
              if theNode.keyArray.count == 1 { return }
              segments[position][theNode.segLength] = nil
            } else {
              theNode.syncingUnigrams(from: unigrams)
            }
            nodesChangedCounter += 1
            return
          }
          let unigrams = getSortedUnigrams(keyArray: keyArraySliced, cache: &queryBuffer)
          guard !unigrams.isEmpty else { return }
          // 這裡原本用 Segment.addNode 來完成的，但直接當作字典來互動的話也沒差。
          segments[position][theLength] = .init(
            keyArray: keyArraySliced, segLength: theLength, unigrams: unigrams
          )
          nodesChangedCounter += 1
        }
      }
      queryBuffer.removeAll() // 手動清理，免得 ARC 拖時間。
      if nodesChangedCounter > 0 {
        assemble()
      }
      return nodesChangedCounter
    }

    // MARK: Private

    private func getSortedUnigrams(
      keyArray: [String],
      cache: inout [[String]: [Megrez.Unigram]]
    )
      -> [Megrez.Unigram] {
      if let cached = cache[keyArray] {
        return cached.map(\.copy)
      }
      let canonical = langModel
        .unigramsFor(keyArray: keyArray)
        .map { source -> Megrez.Unigram in
          if source.keyArray == keyArray {
            return source.copy
          }
          return source.copy(withKeyArray: keyArray)
        }
        .sorted { $0.score > $1.score }
      cache[keyArray] = canonical
      return canonical.map(\.copy)
    }
  }
}

// MARK: - Internal Methods (Maybe Public)

extension Megrez.Compositor {
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
  func dropWreckedNodes(at location: Int) {
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

// MARK: - Megrez.CompositorConfig

extension Megrez {
  public struct CompositorConfig: Codable, Equatable, Hashable {
    /// 最近一次組句結果。
    public var assembledSentence: [Megrez.GramInPath] = []
    /// 該組字器已經插入的的索引鍵，以陣列的形式存放。
    public var keys = [String]()
    /// 該組字器的幅節單元陣列。
    public var segments = [Segment]()

    /// 該組字器的敲字游標位置。
    public var cursor: Int = 0 {
      didSet {
        cursor = max(0, min(cursor, length))
        marker = cursor
      }
    }

    /// 該軌格內可以允許的最大幅節長度。
    public var maxSegLength: Int = 10 {
      didSet {
        _ = (maxSegLength < 6) ? maxSegLength = 6 : dropNodesBeyondMaxSegLength()
      }
    }

    /// 該組字器的標記器（副游標）位置。
    public var marker: Int = 0 { didSet { marker = max(0, min(marker, length)) } }
    /// 多字讀音鍵當中用以分割漢字讀音的記號，預設為「-」。
    public var separator = Megrez.Compositor.theSeparator {
      didSet {
        Megrez.Compositor.theSeparator = separator
      }
    }

    /// 該組字器的長度，組字器內已經插入的單筆索引鍵的數量，也就是內建漢字讀音的數量（唯讀）。
    /// - Remark: 理論上而言，segments.count 也是這個數。
    /// 但是，為了防止萬一，就用了目前的方法來計算。
    public var length: Int { keys.count }

    /// 該組字器的硬拷貝。
    /// - Remark: 因為 Node 不是 Struct，所以會在 Compositor 被拷貝的時候無法被真實複製。
    /// 這樣一來，Compositor 複製品當中的 Node 的變化會被反應到原先的 Compositor 身上。
    /// 這在某些情況下會造成意料之外的混亂情況，所以需要引入一個拷貝用的建構子。
    public var hardCopy: Self {
      var newCopy = self
      newCopy.assembledSentence = assembledSentence
      newCopy.segments = segments.map(\.hardCopy)
      return newCopy
    }

    /// 重置包括游標在內的各項參數，且清空各種由組字器生成的內部資料。
    ///
    /// 將已經被插入的索引鍵陣列與幅節單元陣列（包括其內的節點）全部清空。
    /// 最近一次的組句結果陣列也會被清空。游標跳轉換算表也會被清空。
    public mutating func clear() {
      assembledSentence.removeAll()
      keys.removeAll()
      segments.removeAll()
      cursor = 0
      marker = 0
    }

    /// 清除所有幅長超過 MaxSegLength 的節點。
    public mutating func dropNodesBeyondMaxSegLength() {
      segments.indices.forEach { currentPos in
        segments[currentPos].keys.forEach { currentSegLength in
          if currentSegLength > maxSegLength {
            segments[currentPos].removeValue(forKey: currentSegLength)
          }
        }
      }
    }

    /// 創建所有節點的覆寫狀態鏡照。
    /// - Returns: 包含所有節點 ID 到覆寫狀態映射的字典。
    public func createNodeOverrideStatusMirror() -> [FIUUID: NodeOverrideStatus] {
      var mirror: [FIUUID: NodeOverrideStatus] = [:]
      segments.forEach { segment in
        segment.values.forEach { node in
          mirror[node.id] = node.overrideStatus
        }
      }
      return mirror
    }

    /// 從節點覆寫狀態鏡照恢復所有節點的覆寫狀態。
    /// - Parameter mirror: 包含節點 ID 到覆寫狀態映射的字典。
    public mutating func restoreFromNodeOverrideStatusMirror(
      _ mirror: [FIUUID: NodeOverrideStatus]
    ) {
      segments.indices.forEach { segmentIndex in
        segments[segmentIndex].keys.forEach { segLength in
          guard let node = segments[segmentIndex][segLength] else { return }
          if let status = mirror[node.id] {
            node.overrideStatus = status
          }
        }
      }
    }
  }
}
