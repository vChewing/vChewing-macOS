// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

extension CandidateNode {
  public convenience init(
    name: String, services: [CandidateTextService], previous: CandidateNode? = nil
  ) {
    self.init(name: name, members: services.map(\.asCandidateNode), previous: previous)
  }

  public var asServiceMenuNode: ServiceMenuNode? {
    self as? ServiceMenuNode
  }

  public var containsCandidateServices: Bool {
    !members.compactMap(\.asServiceMenuNode).isEmpty
  }

  public final class ServiceMenuNode: CandidateNode {
    // MARK: Lifecycle

    public init(
      name: String, service givenService: CandidateTextService, previous: CandidateNode? = nil
    ) {
      self.service = givenService
      super.init(name: name, previous: previous)
    }

    // MARK: Public

    public var service: CandidateTextService
  }
}

extension CandidateTextService {
  public var asCandidateNode: CandidateNode.ServiceMenuNode {
    .init(name: menuTitle, service: self)
  }

  public static func getCurrentServiceMenu(
    fromMap map: [String]? = nil, candidate: String, reading: [String]
  )
    -> CandidateNode? {
    let fetchedRaw = map ?? PrefMgr.sharedSansDidSetOps.candidateServiceMenuContents
    let fetched = fetchedRaw.parseIntoCandidateTextServiceStack(
      candidate: candidate,
      reading: reading
    )
    return fetched.isEmpty ? nil : .init(name: candidate, services: fetched)
  }
}
