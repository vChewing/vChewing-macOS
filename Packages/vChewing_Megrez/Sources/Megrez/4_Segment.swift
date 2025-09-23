// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

// MARK: - Megrez.Segment

extension Megrez {
  /// 組字引擎內的區段管理單元。實質上是一個以涵蓋長度為索引鍵、以節點為資料值的字典結構。
  public typealias Segment = [Int: Node]
}

extension Megrez.Segment {
  /// 區段管理單元的複製建構函數。
  /// - Remark: 由於 Node 採用類別設計而非結構體，因此在 Compositor 複製過程中無法自動執行深層複製。
  /// 這會導致複製後的 Compositor 副本中的 Node 變更會影響到原始的 Compositor 副本。
  /// 為了避免此類非預期的互動影響，特別提供此複製功能。
  public init(segment target: Megrez.Segment) {
    self.init()
    target.forEach { theKey, theValue in
      self[theKey] = theValue.copy
    }
  }

  /// 區段的深層複製版本。
  public var hardCopy: Megrez.Segment { .init(segment: self) }

  // MARK: - Dynamic Variables

  /// 區段單元內所有節點中具有最大涵蓋範圍的節點長度數值。
  /// 此數值會隨著區段操作而自動更新。
  public var maxLength: Int { keys.max() ?? 0 }
}

// MARK: - Related Compositor Implementations.

extension Megrez.Compositor {
  /// 找出所有與該位置重疊的節點。其返回值為一個節錨陣列（包含節點、以及其起始位置）。
  /// - Parameter location: 游標位置。
  /// - Returns: 一個包含所有與該位置重疊的節點的陣列。
  public func fetchOverlappingNodes(at givenLocation: Int) -> [(location: Int, node: Megrez.Node)] {
    var results = [(location: Int, node: Megrez.Node)]()
    let givenLocation = max(0, min(givenLocation, keys.count - 1))
    guard segments.indices.contains(givenLocation) else { return results }

    // 先獲取該位置的所有單字節點。
    segments[givenLocation].keys.sorted().forEach { theSegLength in
      guard let node = segments[givenLocation][theSegLength] else { return }
      Self.insertAnchor(segmentIndex: givenLocation, node: node, to: &results)
    }

    // 再獲取以當前位置結尾或開頭的節點。
    let begin: Int = givenLocation - min(givenLocation, maxSegLength - 1)
    (begin ..< givenLocation).forEach { theLocation in
      let (A, B): (Int, Int) = (givenLocation - theLocation + 1, segments[theLocation].maxLength)
      guard A <= B else { return }
      (A ... B).forEach { theLength in
        guard let node = segments[theLocation][theLength] else { return }
        Self.insertAnchor(segmentIndex: theLocation, node: node, to: &results)
      }
    }

    return results
  }

  /// 要在 fetchOverlappingNodes() 內使用的一個工具函式。
  private static func insertAnchor(
    segmentIndex location: Int, node: Megrez.Node,
    to targetContainer: inout [(location: Int, node: Megrez.Node)]
  ) {
    guard !node.keyArray.joined().isEmpty else { return }
    let anchor = (location: location, node: node)
    for i in 0 ... targetContainer.count {
      guard !targetContainer.isEmpty else { break }
      guard targetContainer[i].node.segLength <= anchor.node.segLength else { continue }
      targetContainer.insert(anchor, at: i)
      return
    }
    guard targetContainer.isEmpty else { return }
    targetContainer.append(anchor)
  }
}
