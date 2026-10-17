// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation
import Testing

@testable import Shared

// MARK: - UserDefStoreSeamTests

/// 驗證 P316 之 `UserDef` 匯入／匯出 API 已可逐容器指定，不再以行程級全域為域。
@Suite("UserDefStoreSeam")
final class UserDefStoreSeamTests {
  @Test("Exports and imports stay within the given store")
  func exportAndImportStayWithinGivenStore() throws {
    let storeA = InMemoryDefaultsStore()
    let storeB = InMemoryDefaultsStore()

    storeA.set("1,2,3,4,5,6,7,8,9", forKey: UserDef.kCandidateKeys.rawValue)

    let data = try #require(UserDef.exportAsJSON(store: storeA))
    let result = UserDef.importFromJSON(data, store: storeB)
    #expect(result.failures.isEmpty)

    #expect(storeB.object(forKey: UserDef.kCandidateKeys.rawValue) as? String == "1,2,3,4,5,6,7,8,9")
    // 另一容器之內容不受影響。
    storeB.set("9,8,7", forKey: UserDef.kCandidateKeys.rawValue)
    #expect(storeA.object(forKey: UserDef.kCandidateKeys.rawValue) as? String == "1,2,3,4,5,6,7,8,9")
  }

  @Test("resetAll only clears the given store")
  func resetAllOnlyClearsGivenStore() {
    let storeA = InMemoryDefaultsStore()
    let storeB = InMemoryDefaultsStore()

    storeA.set("123456789", forKey: UserDef.kCandidateKeys.rawValue)
    storeB.set("123456789", forKey: UserDef.kCandidateKeys.rawValue)

    UserDef.resetAll(store: storeA)

    #expect(storeA.object(forKey: UserDef.kCandidateKeys.rawValue) == nil)
    #expect(storeB.object(forKey: UserDef.kCandidateKeys.rawValue) as? String == "123456789")
  }
}
