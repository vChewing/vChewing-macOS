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
	public class Walker {
		var mutGrid: Grid

		public init(grid: Megrez.Grid = Megrez.Grid()) {
			mutGrid = grid
		}

		public func reverseWalk(at location: Int, score accumulatedScore: Double = 0.0) -> [NodeAnchor] {
			if location == 0 || location > mutGrid.width() {
				return [] as [NodeAnchor]
			}

			var paths: [[NodeAnchor]] = []
			let nodes: [NodeAnchor] = mutGrid.nodesEndingAt(location: location)

			for n in nodes {
				var n = n
				if n.node == nil {
					continue
				}

				n.accumulatedScore = accumulatedScore + n.node!.score()

				var path: [NodeAnchor] = reverseWalk(
					at: location - n.spanningLength,
					score: n.accumulatedScore
				)
				path.insert(n, at: 0)

				paths.append(path)
			}

			if !paths.isEmpty {
				if var result = paths.first {
					for value in paths {
						if let vLast = value.last, let rLast = result.last {
							if vLast.accumulatedScore > rLast.accumulatedScore {
								result = value
							}
						}
					}
					return result
				}
			}
			return [] as [NodeAnchor]
		}
	}
}
