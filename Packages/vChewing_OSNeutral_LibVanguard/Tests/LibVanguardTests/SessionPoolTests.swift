// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation
import Shared
import SwiftExtension
import Testing

@testable import LibVanguard

// MARK: - LibVanguardTestsRoot.SessionPoolTests

/// 驗證 P318 之會話池不變量：同一 controller 恆對應同一格、格子有界、回收以 liveness 為
/// 判準、滿格時先回收已死之持有者、再否則淘汰最久未用者；查詢本身不配格。
extension LibVanguardTestsRoot {
  @Suite("SessionPool")
  final class SessionPoolTests {
    // MARK: Internal

    /// 可變之外部狀態：測試以 `class` 盒承載「誰還活著」與「已造幾枚 session」。
    final class Box {
      // MARK: Lifecycle

      init(alive: Set<UInt>) {
        self.alive = alive
      }

      // MARK: Internal

      var alive: Set<UInt>
      var created = 0
    }

    @Test("SS-Pool-001 The same controller keeps the same slot, and lookup never allocates")
    func sameControllerKeepsItsSlot() {
      let ctrlA = NSObject()
      let addrA = address(of: ctrlA)
      let box = Box(alive: [addrA])
      let pool = makePool(capacity: 4, box: box)

      // 查詢只查不配。
      #expect(pool.session(for: addrA) == nil)
      #expect(box.created == 0)

      let first = pool.acquire(for: addrA)
      #expect(box.created == 1)
      #expect(pool.session(for: addrA) === first)
      #expect(pool.acquire(for: addrA) === first)
      #expect(box.created == 1)
      #expect(pool.occupiedCount == 1)
    }

    @Test("SS-Pool-002 Slots are bounded; a full pool recycles an existing session object")
    func slotsAreBounded() {
      let ctrls = (0 ..< 3).map { _ in NSObject() }
      let addrs = ctrls.map(address(of:))
      let box = Box(alive: Set(addrs))
      let pool = makePool(capacity: 2, box: box)

      let first = pool.acquire(for: addrs[0])
      _ = pool.acquire(for: addrs[1])
      #expect(pool.occupiedCount == 2)

      // 第三枚進來：已無空格、也無死持有者 ⇒ 淘汰最久未用者（addrs[0]）。
      let third = pool.acquire(for: addrs[2])
      #expect(third === first)
      #expect(box.created == 2, "淘汰只換持有者，不另造 session。")
      #expect(pool.occupiedCount == 2)
      #expect(pool.session(for: addrs[0]) == nil)
      #expect(pool.session(for: addrs[2]) === third)
    }

    @Test("SS-Pool-003 A dead owner is reclaimed before the least recently used one")
    func deadOwnerReclaimedFirst() {
      let ctrls = (0 ..< 3).map { _ in NSObject() }
      let addrs = ctrls.map(address(of:))
      let box = Box(alive: [addrs[0], addrs[1]])
      let pool = makePool(capacity: 2, box: box)

      let sessionA = pool.acquire(for: addrs[0])
      let sessionB = pool.acquire(for: addrs[1])
      #expect(sessionA !== sessionB)

      // addrs[1] 最久未用？非也——刻意讓 addrs[1] 先被 touch，addrs[0] 才是 LRU 候選。
      _ = pool.session(for: addrs[1])
      box.alive.remove(addrs[0])

      let third = pool.acquire(for: addrs[2])
      #expect(third === sessionA, "應回收持有者已死之格，而非淘汰 LRU 的 addrs[1]。")
      #expect(pool.session(for: addrs[1]) === sessionB)
      #expect(pool.session(for: addrs[0]) == nil)
    }

    @Test("SS-Pool-004 Release returns the slot but keeps the session object for reuse")
    func releaseReturnsSlot() {
      let ctrlA = NSObject()
      let ctrlB = NSObject()
      let addrA = address(of: ctrlA)
      let addrB = address(of: ctrlB)
      let box = Box(alive: [addrA, addrB])
      let pool = makePool(capacity: 2, box: box)

      let sessionA = pool.acquire(for: addrA)
      pool.release(for: addrA)
      #expect(pool.session(for: addrA) == nil)
      #expect(pool.occupiedCount == 0)
      #expect(pool.acquire(for: addrB) === sessionA)
      #expect(box.created == 1)
    }

    // MARK: Private

    private func makePool(
      capacity: Int,
      box: Box
    )
      -> SessionPool {
      let env = TestEnvironment()
      return SessionPool(
        capacity: capacity,
        makeSession: {
          box.created += 1
          return InputSession(preallocated: (), host: env.host)
        },
        isOwnerAlive: { box.alive.contains($0) }
      )
    }

    private func address(of object: NSObject) -> UInt {
      UInt(bitPattern: Unmanaged.passUnretained(object).toOpaque())
    }
  }
}
