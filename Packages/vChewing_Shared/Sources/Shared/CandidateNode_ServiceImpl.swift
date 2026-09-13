// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

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
