// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

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

  public static var factoryRoot: CandidateNode = .init(name: "/")
  public static var userSupplied: CandidateNode?

  public static var root: CandidateNode {
    let merge = !PrefMgr.sharedSansDidSetOps.replaceSymbolMenuNodeWithUserSuppliedData
    if merge != shouldMerge {
      cachedFinalRoot = nil
      shouldMerge = merge
    }
    return makeRootNodeUsingCurrentSettings()
  }

  public var name: String
  public var members: [CandidateNode]
  public weak var previous: CandidateNode?

  // MARK: Private

  private static var shouldMerge = PrefMgr.sharedSansDidSetOps.replaceSymbolMenuNodeWithUserSuppliedData
  private static var cachedFinalRoot: CandidateNode?

  private static func makeRootNodeUsingCurrentSettings() -> CandidateNode {
    guard let userSupplied else { return factoryRoot }
    guard shouldMerge else { return userSupplied }
    return CandidateNode(
      name: "/",
      members: factoryRoot.members + [userSupplied],
      previous: nil
    )
  }
}
