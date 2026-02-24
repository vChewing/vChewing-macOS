// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

open class CandidateNode {
  // MARK: Lifecycle

  public init(name: String, members: [CandidateNode] = [], previous: CandidateNode? = nil) {
    self.name = name
    self.members = members
    members.forEach { $0.previous = self }
    self.previous = previous
  }

  public init(name: String, symbols: [String]) {
    self.name = name
    self.members = symbols.map { CandidateNode(name: $0, symbols: []) }
    members.forEach { $0.previous = self }
  }

  // MARK: Public

  public static var root: CandidateNode = .init(name: "/")

  public var name: String
  public var members: [CandidateNode]
  public weak var previous: CandidateNode?
}
