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
  @frozen public struct Span {
    private var mutLengthNodeMap: [Int: Megrez.Node]
    private var mutMaximumLength: Int
    var maximumLength: Int {
      mutMaximumLength
    }

    public init() {
      mutLengthNodeMap = [:]
      mutMaximumLength = 0
    }

    mutating func clear() {
      mutLengthNodeMap.removeAll()
      mutMaximumLength = 0
    }

    mutating func insert(node: Node, length: Int) {
      mutLengthNodeMap[length] = node
      if length > mutMaximumLength {
        mutMaximumLength = length
      }
    }

    mutating func removeNodeOfLengthGreaterThan(_ length: Int) {
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

    public func node(length: Int) -> Node? {
      mutLengthNodeMap[length]
    }
  }
}
