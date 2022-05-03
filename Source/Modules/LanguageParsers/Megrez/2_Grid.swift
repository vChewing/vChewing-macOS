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
  public class Grid {
    var mutSpans: [Megrez.Span]

    public init() {
      mutSpans = [Megrez.Span]()
    }

    public func clear() {
      mutSpans = [Megrez.Span]()
    }

    public func insertNode(node: Node, location: Int, spanningLength: Int) {
      if location >= mutSpans.count {
        let diff = location - mutSpans.count + 1
        var i = 0
        while i < diff {
          mutSpans.append(Span())
          i += 1
        }
      }
      mutSpans[location].insert(node: node, length: spanningLength)
    }

    public func hasMatchedNode(location: Int, spanningLength: Int, key: String) -> Bool {
      if location > mutSpans.count {
        return false
      }

      let n = mutSpans[location].node(length: spanningLength)
      return n == nil ? false : key == n?.key()
    }

    public func expandGridByOneAt(location: Int) {
      mutSpans.append(Span())
      if location > 0, location < mutSpans.count {
        var i = 0
        while i < location {
          // zaps overlapping spans
          mutSpans[i].removeNodeOfLengthGreaterThan(location - i)
          i += 1
        }
      }
    }

    public func shrinkGridByOneAt(location: Int) {
      if location >= mutSpans.count {
        return
      }

      mutSpans.remove(at: location)
      var i = 0
      while i < location {
        // zaps overlapping spans
        mutSpans[i].removeNodeOfLengthGreaterThan(location - i)
        i += 1
      }
    }

    public func width() -> Int { mutSpans.count }

    public func nodesEndingAt(location: Int) -> [NodeAnchor] {
      var results: [NodeAnchor] = []
      if !mutSpans.isEmpty, location <= mutSpans.count {
        var i = 0
        while i < location {
          let span = mutSpans[i]
          if i + span.maximumLength >= location {
            if let np = span.node(length: location - i) {
              results.append(
                NodeAnchor(
                  node: np,
                  location: i,
                  spanningLength: location - i
                )
              )
            }
          }
          i += 1
        }
      }
      return results
    }

    public func nodesCrossingOrEndingAt(location: Int) -> [NodeAnchor] {
      var results: [NodeAnchor] = []
      if !mutSpans.isEmpty, location <= mutSpans.count {
        var i = 0
        while i < location {
          let span = mutSpans[i]
          if i + span.maximumLength >= location {
            var j = 1
            while j <= span.maximumLength {
              if i + j < location {
                j += 1
                continue
              }
              if let np = span.node(length: j) {
                results.append(
                  NodeAnchor(
                    node: np,
                    location: i,
                    spanningLength: location - i
                  )
                )
              }
              j += 1
            }
          }
          i += 1
        }
      }
      return results
    }

    public func fixNodeSelectedCandidate(location: Int, value: String) -> NodeAnchor {
      var node = NodeAnchor()
      let nodes = nodesCrossingOrEndingAt(location: location)
      for nodeAnchor in nodes {
        // Reset the candidate-fixed state of every node at the location.
        let candidates = nodeAnchor.node?.candidates() ?? []
        nodeAnchor.node?.resetCandidate()

        for (i, candidate) in candidates.enumerated() {
          if candidate.value == value {
            nodeAnchor.node?.selectCandidateAt(index: i)
            node = nodeAnchor
            break
          }
        }
      }
      return node
    }

    public func overrideNodeScoreForSelectedCandidate(location: Int, value: inout String, overridingScore: Double) {
      for nodeAnchor in nodesCrossingOrEndingAt(location: location) {
        var nodeAnchor = nodeAnchor
        if let theNode = nodeAnchor.node {
          let candidates = theNode.candidates()
          // Reset the candidate-fixed state of every node at the location.
          theNode.resetCandidate()
          nodeAnchor.node = theNode

          for (i, candidate) in candidates.enumerated() {
            if candidate.value == value {
              theNode.selectFloatingCandidateAt(index: i, score: overridingScore)
              nodeAnchor.node = theNode
              break
            }
          }
        }
      }
    }
  }
}
