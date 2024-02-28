// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation

public extension CandidateNode {
  convenience init(
    name: String, services: [CandidateTextService], previous: CandidateNode? = nil
  ) {
    self.init(name: name, members: services.map(\.asCandidateNode), previous: previous)
  }

  var asServiceMenuNode: ServiceMenuNode? {
    self as? ServiceMenuNode
  }

  var containsCandidateServices: Bool {
    !members.compactMap(\.asServiceMenuNode).isEmpty
  }

  class ServiceMenuNode: CandidateNode {
    public var service: CandidateTextService
    public init(
      name: String, service givenService: CandidateTextService, previous: CandidateNode? = nil
    ) {
      service = givenService
      super.init(name: name, previous: previous)
    }
  }
}

public extension CandidateTextService {
  var asCandidateNode: CandidateNode.ServiceMenuNode {
    .init(name: menuTitle, service: self)
  }

  static func getCurrentServiceMenu(
    fromMap map: [String]? = nil, candidate: String, reading: [String]
  ) -> CandidateNode? {
    let fetchedRaw = map ?? PrefMgr().candidateServiceMenuContents
    let fetched = fetchedRaw.parseIntoCandidateTextServiceStack(candidate: candidate, reading: reading)
    return fetched.isEmpty ? nil : .init(name: candidate, services: fetched)
  }
}
