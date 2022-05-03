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
  public class BlockReadingBuilder {
    let kMaximumBuildSpanLength = 10  // 規定最多可以組成的詞的字數上限為 10
    var mutCursorIndex: Int = 0
    var mutReadings: [String] = []
    var mutGrid: Grid = .init()
    var mutLM: LanguageModel
    var mutJoinSeparator: String = ""

    public init(lm: LanguageModel) {
      mutLM = lm
    }

    public func clear() {
      mutCursorIndex = 0
      mutReadings.removeAll()
      mutGrid.clear()
    }

    public func length() -> Int { mutReadings.count }

    public func cursorIndex() -> Int { mutCursorIndex }

    public func setCursorIndex(newIndex: Int) {
      mutCursorIndex = min(newIndex, mutReadings.count)
    }

    public func insertReadingAtCursor(reading: String) {
      mutReadings.insert(reading, at: mutCursorIndex)
      mutGrid.expandGridByOneAt(location: mutCursorIndex)
      build()
      mutCursorIndex += 1
    }

    public func readings() -> [String] { mutReadings }

    @discardableResult public func deleteReadingBeforeCursor() -> Bool {
      if mutCursorIndex == 0 {
        return false
      }

      mutReadings.remove(at: mutCursorIndex - 1)
      mutCursorIndex -= 1
      mutGrid.shrinkGridByOneAt(location: mutCursorIndex)
      build()
      return true
    }

    @discardableResult public func deleteReadingAfterCursor() -> Bool {
      if mutCursorIndex == mutReadings.count {
        return false
      }

      mutReadings.remove(at: mutCursorIndex)
      mutGrid.shrinkGridByOneAt(location: mutCursorIndex)
      build()
      return true
    }

    @discardableResult public func removeHeadReadings(count: Int) -> Bool {
      if count > length() {
        return false
      }

      var i = 0
      while i < count {
        if mutCursorIndex != 0 {
          mutCursorIndex -= 1
        }
        mutReadings.removeFirst()
        mutGrid.shrinkGridByOneAt(location: 0)
        build()
        i += 1
      }

      return true
    }

    public func setJoinSeparator(separator: String) {
      mutJoinSeparator = separator
    }

    public func joinSeparator() -> String { mutJoinSeparator }

    public func grid() -> Grid { mutGrid }

    public func build() {
      // if (mutLM == nil) { return } // 這個出不了 nil，所以註釋掉。

      let itrBegin: Int =
        (mutCursorIndex < kMaximumBuildSpanLength) ? 0 : mutCursorIndex - kMaximumBuildSpanLength
      let itrEnd: Int = min(mutCursorIndex + kMaximumBuildSpanLength, mutReadings.count)

      var p = itrBegin
      while p < itrEnd {
        var q = 1
        while q <= kMaximumBuildSpanLength, p + q <= itrEnd {
          let strSlice = mutReadings[p..<(p + q)]
          let combinedReading: String = join(slice: strSlice, separator: mutJoinSeparator)
          if !mutGrid.hasMatchedNode(location: p, spanningLength: q, key: combinedReading) {
            let unigrams: [Unigram] = mutLM.unigramsFor(key: combinedReading)
            if !unigrams.isEmpty {
              let n = Node(key: combinedReading, unigrams: unigrams)
              mutGrid.insertNode(node: n, location: p, spanningLength: q)
            }
          }
          q += 1
        }
        p += 1
      }
    }

    public func join(slice strSlice: ArraySlice<String>, separator: String) -> String {
      var arrResult: [String] = []
      for value in strSlice {
        arrResult.append(value)
      }
      return arrResult.joined(separator: separator)
    }
  }
}
