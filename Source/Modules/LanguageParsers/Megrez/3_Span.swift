// Swiftified by (c) 2022 and onwards The vChewing Project (MIT-NTL License).
// Rebranded from (c) Lukhnos Liu's C++ library "Gramambular" (MIT License).
/*
Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

1. The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

2. No trademark license is granted to use the trade names, trademarks, service
marks, or product names of Contributor, except as required to fulfill notice
requirements above.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

extension Megrez {
  /// 幅位。
  @frozen public struct Span {
    /// 辭典：以節點長度為索引，以節點為資料值。
    private var mutLengthNodeMap: [Int: Megrez.Node] = [:]
    /// 最大節點長度。
    private var mutMaximumLength: Int = 0

    /// 公開：最長幅距（唯讀）。
    var maximumLength: Int {
      mutMaximumLength
    }

    /// 自我清空，各項參數歸零。
    mutating func clear() {
      mutLengthNodeMap.removeAll()
      mutMaximumLength = 0
    }

    /// 往自身插入一個節點、及給定的節點長度。
    /// - Parameters:
    ///   - node: 節點。
    ///   - length: 給定的節點長度。
    mutating func insert(node: Node, length: Int) {
      let length = abs(length)  // 防呆
      mutLengthNodeMap[length] = node
      if length > mutMaximumLength {
        mutMaximumLength = length
      }
    }

    /// 移除任何比給定的長度更長的節點。
    /// - Parameters:
    ///   - length: 給定的節點長度。
    mutating func removeNodeOfLengthGreaterThan(_ length: Int) {
      let length = abs(length)  // 防呆
      if length > mutMaximumLength { return }
      var max = 0
      var removalList: [Int: Megrez.Node] = [:]
      for key in mutLengthNodeMap.keys {
        if key > length {
          removalList[key] = mutLengthNodeMap[key]
        } else {
          if key > max {
            max = key
          }
        }
      }
      for key in removalList.keys {
        mutLengthNodeMap.removeValue(forKey: key)
      }
      mutMaximumLength = max
    }

    /// 給定節點長度，獲取節點。
    /// - Parameters:
    ///   - length: 給定的節點長度。
    public func node(length: Int) -> Node? {
      mutLengthNodeMap[abs(length)]  // 防呆
    }
  }
}
