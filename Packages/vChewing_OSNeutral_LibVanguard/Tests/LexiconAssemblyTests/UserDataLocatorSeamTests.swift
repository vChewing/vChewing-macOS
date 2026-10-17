// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

// 使用者資料 I/O 之實例化縫（P315）。
//
// 本套房證明：`LXPerceptor` 一旦以 `init(… locator:)` 建構，其快照與日誌即只走該後端，
// 不再回看 `LXAssembly.userDataLocator` 這顆行程級全域。注意本套房**不置換全域**
// （置換在全域層仍是全有全無，於並行執行下必成競態）；改以「同一路徑、兩個互不相屬之
// 記憶體後端」證明彼此隔離，並以「全域後端看不見該路徑」證明寫入確實沒回頭落在全域。

import Foundation
import Testing

@testable import LexiconAssembly

@Suite("使用者資料之實例化縫")
struct UserDataLocatorSeamTests {
  @Test("兩個實例各持一後端：同一路徑互不相屬，且皆不落行程級全域")
  func instancesKeepTheirOwnBackend() throws {
    let url = URL(fileURLWithPath: "/vChewing-SeamTest/\(UUID().uuidString).json")
    let storeA = InMemoryUserDataLocator()
    let storeB = InMemoryUserDataLocator()

    let pomA = LXAssembly.LXPerceptor(capacity: 10, dataURL: url, locator: storeA)
    let pomB = LXAssembly.LXPerceptor(capacity: 10, dataURL: url, locator: storeB)

    pomA.memorizePerception(
      (ngramKey: "(seam,A)&(probe,a)", candidate: "甲"),
      timestamp: Date.now.timeIntervalSince1970
    )
    pomB.memorizePerception(
      (ngramKey: "(seam,B)&(probe,b)", candidate: "乙"),
      timestamp: Date.now.timeIntervalSince1970
    )
    pomA.saveData(toURL: url)
    pomB.saveData(toURL: url)

    #expect(storeA.exists(at: url))
    #expect(storeB.exists(at: url))
    // 同一路徑、兩份內容：證明兩者確實各寫各的後端。
    let dataA = try storeA.read(at: url)
    let dataB = try storeB.read(at: url)
    #expect(dataA != dataB)
    // 全域後端自始至終未見過該路徑。
    #expect(!LXAssembly.userDataLocator.exists(at: url))
  }

  @Test("實例後端之寫入可被同一後端之另一實例讀回")
  func instanceBackendRoundTrips() {
    let url = URL(fileURLWithPath: "/vChewing-SeamTest/\(UUID().uuidString).json")
    let store = InMemoryUserDataLocator()
    let probeKey = "(seam,roundtrip)&(probe,rt)"

    let pom = LXAssembly.LXPerceptor(capacity: 10, dataURL: url, locator: store)
    pom.memorizePerception(
      (ngramKey: probeKey, candidate: "丙"),
      timestamp: Date.now.timeIntervalSince1970
    )
    pom.saveData(toURL: url)

    let reloaded = LXAssembly.LXPerceptor(capacity: 10, dataURL: url, locator: store)
    reloaded.loadData(fromURL: url)
    let recovered = reloaded.getSavableData().contains { pair in
      pair.key == probeKey && pair.perception.overrides.keys.contains("丙")
    }
    #expect(recovered)
  }
}
