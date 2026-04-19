// (c) 2025 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

// MARK: - Homa.AssemblerConfig

extension Homa {
  /// 用於組字器的組態設定。
  public struct Config: Codable, Hashable {
    // MARK: Lifecycle

    public init(
      assembledSentence: [GramInPath] = [],
      keys: [String] = [],
      segments: [Segment] = [],
      cursor: Int = 0,
      maxSegLength: Int = 10,
      marker: Int = 0
    ) {
      self.assembledSentence = assembledSentence
      self.keys = keys
      self.segments = segments
      self.cursor = cursor
      self.maxSegLength = max(6, maxSegLength)
      self.marker = marker
    }

    // MARK: Public

    /// 最近一次組句結果。
    public var assembledSentence: [GramInPath] = []
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

    /// 該組字器的長度，組字器內已經插入的單筆索引鍵的數量，也就是內建漢字讀音的數量（唯讀）。
    /// - Remark: 理論上而言，segments.count 也是這個數。
    /// 但是，為了防止萬一，就用了目前的方法來計算。
    public var length: Int { keys.count }

    /// 該組字器的硬拷貝。
    /// - Remark: 因為 Node 不是 Struct，所以會在 Assembler 被拷貝的時候無法被真實複製。
    /// 這樣一來，Assembler 複製品當中的 Node 的變化會被反應到原先的 Assembler 身上。
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

    /// 生成所有節點的覆寫狀態鏡照。
    /// - Returns: 節點 ID 與覆寫狀態的對應字典。
    public func createNodeOverrideStatusMirror() -> [FIUUID: Homa.NodeOverrideStatus] {
      var result: [FIUUID: Homa.NodeOverrideStatus] = [:]
      for segment in segments {
        for (_, node) in segment {
          result[node.id] = node.overrideStatus
        }
      }
      return result
    }

    /// 從鏡照資料恢復所有節點的覆寫狀態。
    /// - Parameter mirror: 節點 ID 與覆寫狀態的對應字典。
    public func restoreFromNodeOverrideStatusMirror(_ mirror: [FIUUID: Homa.NodeOverrideStatus]) {
      for segment in segments {
        for (_, node) in segment {
          if let status = mirror[node.id] {
            node.overrideStatus = status
          }
        }
      }
    }
  }
}
