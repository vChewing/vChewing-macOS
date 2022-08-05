// Swiftified by (c) 2022 and onwards The vChewing Project (MIT-NTL License).
// Rebranded from (c) Lukhnos Liu's C++ library "Gramambular" (MIT License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

extension Megrez {
  /// 幅位。
  @frozen public struct SpanUnit {
    /// 辭典：以節點長度為索引，以節點為資料值。
    private var lengthNodeMap: [Int: Megrez.Node] = [:]
    /// 最長幅距。
    private(set) var maxLength: Int = 0

    /// 自我清空，各項參數歸零。
    mutating func clear() {
      lengthNodeMap.removeAll()
      maxLength = 0
    }

    /// 往自身插入一個節點、及給定的節點長度。
    /// - Parameters:
    ///   - node: 節點。
    ///   - length: 給定的節點長度。
    mutating func insert(node: Node, length: Int) {
      let length = abs(length)  // 防呆
      lengthNodeMap[length] = node
      maxLength = max(maxLength, length)
    }

    /// 移除任何比給定的長度更長的節點。
    /// - Parameters:
    ///   - length: 給定的節點長度。
    mutating func dropNodesBeyond(length: Int) {
      let length = abs(length)  // 防呆
      if length > maxLength { return }
      var lenMax = 0
      var removalList: [Int: Megrez.Node] = [:]
      for key in lengthNodeMap.keys {
        if key > length {
          removalList[key] = lengthNodeMap[key]
        } else {
          lenMax = max(lenMax, key)
        }
      }
      for key in removalList.keys {
        lengthNodeMap.removeValue(forKey: key)
      }
      maxLength = lenMax
    }

    /// 給定節點長度，獲取節點。
    /// - Parameters:
    ///   - length: 給定的節點長度。
    public func nodeOf(length: Int) -> Node? {
      // 防呆 Abs()
      lengthNodeMap.keys.contains(abs(length)) ? lengthNodeMap[abs(length)] : nil
    }
  }
}
