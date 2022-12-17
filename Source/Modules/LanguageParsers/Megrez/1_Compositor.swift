// Swiftified by (c) 2022 and onwards The vChewing Project (MIT License).
// Rebranded from (c) Lukhnos Liu's C++ library "Gramambular 2" (MIT License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)

extension Megrez {
  /// 一個組字器用來在給定一系列的索引鍵的情況下（藉由一系列的觀測行為）返回一套資料值。
  ///
  /// 用於輸入法的話，給定的索引鍵可以是注音、且返回的資料值都是漢語字詞組合。該組字器
  /// 還可以用來對文章做分節處理：此時的索引鍵為漢字，返回的資料值則是漢語字詞分節組合。
  ///
  /// - Remark: 雖然這裡用了隱性 Markov 模型（HMM）的術語，但實際上在爬軌時用到的則是更
  /// 簡單的貝氏推論：因為底層的語言模組只會提供單元圖資料。一旦將所有可以組字的單元圖
  /// 作為節點塞到組字器內，就可以用一個簡單的有向無環圖爬軌過程、來利用這些隱性資料值
  /// 算出最大相似估算結果。
  public struct Compositor {
    /// 就文字輸入方向而言的方向。
    public enum TypingDirection { case front, rear }
    /// 軌格增減行為。
    public enum ResizeBehavior { case expand, shrink }
    /// 該軌格內可以允許的最大幅位長度。
    public static var maxSpanLength: Int = 10 { didSet { maxSpanLength = max(6, maxSpanLength) } }
    /// 公開：多字讀音鍵當中用以分割漢字讀音的記號的預設值，是「-」。
    public static let kDefaultSeparator: String = "-"
    /// 該組字器的游標位置。
    public var cursor: Int = 0 {
      didSet {
        cursor = max(0, min(cursor, length))
        marker = cursor
      }
    }

    /// 該組字器的標記器位置。
    public var marker: Int = 0 { didSet { marker = max(0, min(marker, length)) } }
    /// 公開：多字讀音鍵當中用以分割漢字讀音的記號，預設為「-」。
    public var separator = kDefaultSeparator
    /// 公開：組字器內已經插入的單筆索引鍵的數量。
    public var width: Int { keys.count }
    /// 公開：最近一次爬軌結果。
    public var walkedNodes: [Node] = []
    /// 公開：該組字器的長度，也就是內建漢字讀音的數量（唯讀）。
    public var length: Int { keys.count }
    /// 公開：組字器是否為空。
    public var isEmpty: Bool { spans.isEmpty && keys.isEmpty }

    /// 該組字器的索引鍵陣列。
    private(set) var keys = [String]()
    /// 該組字器的幅位陣列。
    private(set) var spans = [Span]()
    /// 該組字器所使用的語言模型（被 LangModelRanked 所封裝）。
    private(set) var langModel: LangModelRanked
    /// 允許查詢當前游標位置屬於第幾個幅位座標（從 0 開始算）。
    private(set) var cursorRegionMap: [Int: Int] = .init()

    /// 初期化一個組字器。
    /// - Parameter langModel: 要對接的語言模組。
    public init(with langModel: LangModelProtocol, separator: String = "-") {
      self.langModel = .init(withLM: langModel)
      self.separator = separator
    }

    public mutating func clear() {
      cursor = 0
      keys.removeAll()
      spans.removeAll()
      walkedNodes.removeAll()
      cursorRegionMap.removeAll()
    }

    /// 在游標位置插入給定的索引鍵。
    /// - Parameter key: 要插入的索引鍵。
    /// - Returns: 該操作是否成功執行。
    @discardableResult public mutating func insertKey(_ key: String) -> Bool {
      guard !key.isEmpty, key != separator, langModel.hasUnigramsFor(key: key) else { return false }
      keys.insert(key, at: cursor)
      resizeGrid(at: cursor, do: .expand)
      update()
      cursor += 1  // 游標必須得在執行 update() 之後才可以變動。
      return true
    }

    /// 朝著指定方向砍掉一個與游標相鄰的讀音。
    ///
    /// 在威注音的術語體系當中，「與文字輸入方向相反的方向」為向後（Rear），反之則為向前（Front）。
    /// 如果是朝著與文字輸入方向相反的方向砍的話，游標位置會自動遞減。
    /// - Parameter direction: 指定方向（相對於文字輸入方向而言）。
    /// - Returns: 該操作是否成功執行。
    @discardableResult public mutating func dropKey(direction: TypingDirection) -> Bool {
      let isBackSpace: Bool = direction == .rear ? true : false
      guard cursor != (isBackSpace ? 0 : keys.count) else { return false }
      keys.remove(at: cursor - (isBackSpace ? 1 : 0))
      cursor -= isBackSpace ? 1 : 0  // 在縮節之前。
      resizeGrid(at: cursor, do: .shrink)
      update()
      return true
    }

    /// 按幅位來前後移動游標。
    /// - Parameters:
    ///   - direction: 移動方向。
    ///   - isMarker: 要移動的是否為選擇標記（而非游標）。
    /// - Returns: 該操作是否順利完成。
    @discardableResult public mutating func jumpCursorBySpan(to direction: TypingDirection, isMarker: Bool = false)
      -> Bool
    {
      var target = isMarker ? marker : cursor
      switch direction {
        case .front:
          if target == width { return false }
        case .rear:
          if target == 0 { return false }
      }
      guard let currentRegion = cursorRegionMap[target] else { return false }

      let aRegionForward = max(currentRegion - 1, 0)
      let currentRegionBorderRear: Int = walkedNodes[0..<currentRegion].map(\.spanLength).reduce(0, +)
      switch target {
        case currentRegionBorderRear:
          switch direction {
            case .front:
              target =
                (currentRegion > walkedNodes.count)
                ? keys.count : walkedNodes[0...currentRegion].map(\.spanLength).reduce(0, +)
            case .rear:
              target = walkedNodes[0..<aRegionForward].map(\.spanLength).reduce(0, +)
          }
        default:
          switch direction {
            case .front:
              target = currentRegionBorderRear + walkedNodes[currentRegion].spanLength
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

    /// 生成用以交給 GraphViz 診斷的資料檔案內容，純文字。
    public var dumpDOT: String {
      var strOutput = "digraph {\ngraph [ rankdir=LR ];\nBOS;\n"
      for (p, span) in spans.enumerated() {
        for ni in 0...(span.maxLength) {
          guard let np = span.nodeOf(length: ni) else { continue }
          if p == 0 {
            strOutput += "BOS -> \(np.value);\n"
          }
          strOutput += "\(np.value);\n"
          if (p + ni) < spans.count {
            let destinationSpan = spans[p + ni]
            for q in 0...(destinationSpan.maxLength) {
              guard let dn = destinationSpan.nodeOf(length: q) else { continue }
              strOutput += np.value + " -> " + dn.value + ";\n"
            }
          }
          guard (p + ni) == spans.count else { continue }
          strOutput += np.value + " -> EOS;\n"
        }
      }
      strOutput += "EOS;\n}\n"
      return strOutput
    }
  }
}

// MARK: - Internal Methods

extension Megrez.Compositor {
  // MARK: Internal methods for maintaining the grid.

  /// 在該軌格的指定幅位座標擴增或減少一個幅位。
  /// - Parameters:
  ///   - location: 給定的幅位座標。
  ///   - action: 指定是擴張還是縮減一個幅位。
  mutating func resizeGrid(at location: Int, do action: ResizeBehavior) {
    let location = max(min(location, spans.count), 0)  // 防呆
    switch action {
      case .expand:
        spans.insert(Span(), at: location)
        if [0, spans.count].contains(location) { return }
      case .shrink:
        if spans.count == location { return }
        spans.remove(at: location)
    }
    dropWreckedNodes(at: location)
  }

  /// 扔掉所有被 resizeGrid() 損毀的節點。
  ///
  /// 拿新增幅位來打比方的話，在擴增幅位之前：
  /// ```
  /// Span Index 0   1   2   3
  ///                (---)
  ///                (-------)
  ///            (-----------)
  /// ```
  /// 在幅位座標 2 (SpanIndex = 2) 的位置擴增一個幅位之後:
  /// ```
  /// Span Index 0   1   2   3   4
  ///                (---)
  ///                (XXX?   ?XXX) <-被扯爛的節點
  ///            (XXXXXXX?   ?XXX) <-被扯爛的節點
  /// ```
  /// 拿縮減幅位來打比方的話，在縮減幅位之前：
  /// ```
  /// Span Index 0   1   2   3
  ///                (---)
  ///                (-------)
  ///            (-----------)
  /// ```
  /// 在幅位座標 2 的位置就地砍掉一個幅位之後:
  /// ```
  /// Span Index 0   1   2   3   4
  ///                (---)
  ///                (XXX? <-被砍爛的節點
  ///            (XXXXXXX? <-被砍爛的節點
  /// ```
  /// - Parameter location: 給定的幅位座標。
  func dropWreckedNodes(at location: Int) {
    let location = max(min(location, spans.count), 0)  // 防呆
    guard !spans.isEmpty else { return }
    let affectedLength = Megrez.Compositor.maxSpanLength - 1
    let begin = max(0, location - affectedLength)
    guard location >= begin else { return }
    for i in begin..<location {
      spans[i].dropNodesOfOrBeyond(length: location - i + 1)
    }
  }

  @discardableResult func insertNode(_ node: Node, at location: Int) -> Bool {
    let location = max(min(location, spans.count - 1), 0)  // 防呆
    spans[location].append(node: node)
    return true
  }

  func getJointKey(range: Range<Int>) -> String {
    // 下面這句不能用 contains，不然會要求至少 macOS 13 Ventura。
    guard range.upperBound <= keys.count, range.lowerBound >= 0 else { return "" }
    return keys[range].joined(separator: separator)
  }

  func getJointKeyArray(range: Range<Int>) -> [String] {
    // 下面這句不能用 contains，不然會要求至少 macOS 13 Ventura。
    guard range.upperBound <= keys.count, range.lowerBound >= 0 else { return [] }
    return keys[range].map { String($0) }
  }

  func hasNode(at location: Int, length: Int, key: String) -> Bool {
    let location = max(min(location, spans.count), 0)  // 防呆
    guard let node = spans[location].nodeOf(length: length) else { return false }
    return key == node.key
  }

  func update() {
    let maxSpanLength = Megrez.Compositor.maxSpanLength
    let range = max(0, cursor - maxSpanLength)..<min(cursor + maxSpanLength, keys.count)
    for position in range {
      for theLength in 1...min(maxSpanLength, range.upperBound - position) {
        let jointKeyArray = getJointKeyArray(range: position..<(position + theLength))
        let jointKey = getJointKey(range: position..<(position + theLength))
        if hasNode(at: position, length: theLength, key: jointKey) { continue }
        let unigrams = langModel.unigramsFor(key: jointKey)
        guard !unigrams.isEmpty else { continue }
        insertNode(
          .init(keyArray: jointKeyArray, spanLength: theLength, unigrams: unigrams, keySeparator: separator),
          at: position
        )
      }
    }
  }

  mutating func updateCursorJumpingTables(_ walkedNodes: [Node]) {
    var cursorRegionMapDict = [Int: Int]()
    cursorRegionMapDict[-1] = 0  // 防呆
    var counter = 0
    for (i, anchor) in walkedNodes.enumerated() {
      for _ in 0..<anchor.spanLength {
        cursorRegionMapDict[counter] = i
        counter += 1
      }
    }
    cursorRegionMapDict[counter] = walkedNodes.count
    cursorRegionMap = cursorRegionMapDict
  }
}
