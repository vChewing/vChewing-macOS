// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation

public class CandidateNode {
  public var name: String
  public var members: [CandidateNode]
  public var previous: CandidateNode?

  public init(name: String, members: [CandidateNode] = [], previous: CandidateNode? = nil) {
    self.name = name
    self.members = members
    members.forEach { $0.previous = self }
    self.previous = previous
  }

  public init(name: String, symbols: [String]) {
    self.name = name
    members = symbols.map { CandidateNode(name: $0, symbols: []) }
    members.forEach { $0.previous = self }
  }

  public static var root: CandidateNode = .init(name: "/")
}
