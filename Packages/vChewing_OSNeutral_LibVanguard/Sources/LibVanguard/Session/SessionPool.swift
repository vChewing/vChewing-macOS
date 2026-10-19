// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation
import SwiftExtension

// MARK: - SessionPool

/// 定額會話池：以「客體所屬之 controller」為鍵的分配器。
///
/// 與先前的極性雙緩衝（`sessionEven`／`sessionOdd`、`gen & 1`）之別：極性版是**函數式**
/// 映射——兩枚 controller 只要世代同奇偶就共用同一枚 session，其組字狀態、候選窗與客體
/// 綁定因而互相干擾；本池是**分配式**——每枚 controller 於建構時領一格，同時間至多
/// `capacity` 枚。
///
/// 不變量：
/// - 同一 controller 位址在其存活期間恆對應同一格（除非該格被淘汰）。
/// - `session(for:)` 只查不配；未曾領格者回 `nil`，呼叫端據此記 `UnresolvableController`。
/// - 收格以 `isOwnerAlive` 為判準，**不**掛在 `dealloc` 上：IMK 之延遲拆除（停用後三秒）
///   並不代表 controller 已亡（見 P317）。
public final class SessionPool {
  // MARK: Lifecycle

  public init(
    capacity: Int = 4,
    makeSession: @escaping () -> InputSession = { InputSession(preallocated: ()) },
    isOwnerAlive: @escaping (UInt) -> Bool = { SessionHost.shared.isControllerAddressAlive($0) }
  ) {
    let capacity = max(1, capacity)
    self.capacity = capacity
    self.makeSession = makeSession
    self.isOwnerAlive = isOwnerAlive
    self.slots = Array(repeating: nil, count: capacity)
    self.owners = Array(repeating: nil, count: capacity)
    self.stamps = Array(repeating: 0, count: capacity)
  }

  // MARK: Public

  public static let shared = SessionPool(capacity: 4)

  public let capacity: Int

  /// 已領格數（診斷／測試用）。
  public var occupiedCount: Int {
    lock.lock()
    defer { lock.unlock() }
    return owners.compactMap { $0 }.count
  }

  /// 查詢該 controller 所領之格；未曾領格回 `nil`。此查詢會刷新其使用時刻。
  public func session(for controllerAddr: UInt) -> InputSession? {
    lock.lock()
    defer { lock.unlock() }
    guard let index = index(ofOwner: controllerAddr), let session = slots[index] else { return nil }
    touch(index)
    return session
  }

  /// 為該 controller 領一格：同址已領則回原格；否則取首個空格、再否則回收持有者已死者、
  /// 再否則淘汰最久未用者。
  ///
  /// - Note: 被淘汰之格的 session 物件**不銷毀**（重用），故呼叫端須在領得後
  ///   `reassign(to:)` 並重設其狀態。
  @discardableResult
  public func acquire(for controllerAddr: UInt) -> InputSession {
    lock.lock()
    defer { lock.unlock() }
    if let index = index(ofOwner: controllerAddr), let session = slots[index] {
      touch(index)
      return session
    }
    let index = indexForClaim()
    let session = slots[index] ?? makeSession()
    slots[index] = session
    owners[index] = controllerAddr
    touch(index)
    return session
  }

  /// 交還該 controller 之格（清持有者，保留 session 物件）。
  ///
  /// - Note: 生產端不掛在 `dealloc` 上；此入口供宿主在確定 controller 已亡時主動交還，
  ///   或供測試使用。常態之回收走 `acquire` 之 liveness 判定。
  public func release(for controllerAddr: UInt) {
    lock.lock()
    defer { lock.unlock() }
    guard let index = index(ofOwner: controllerAddr) else { return }
    owners[index] = nil
  }

  // MARK: Private

  private let makeSession: () -> InputSession
  private let isOwnerAlive: (UInt) -> Bool

  private var slots: [InputSession?]
  private var owners: [UInt?]
  private var stamps: [UInt64]
  private var clock: UInt64 = 0
  private let lock = NSLock()

  private func touch(_ index: Int) {
    clock &+= 1
    stamps[index] = clock
  }

  private func index(ofOwner controllerAddr: UInt) -> Int? {
    owners.firstIndex(where: { $0 == controllerAddr })
  }

  private func indexForClaim() -> Int {
    if let index = owners.firstIndex(where: { $0 == nil }) { return index }
    if let index = owners.firstIndex(where: { addr in addr.map { !isOwnerAlive($0) } ?? true }) {
      return index
    }
    if let index = stamps.indices.min(by: { stamps[$0] < stamps[$1] }) { return index }
    return 0
  }
}
