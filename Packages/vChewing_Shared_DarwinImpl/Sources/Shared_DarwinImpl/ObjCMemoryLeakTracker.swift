// (c) 2025 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation

// MARK: - ObjCMemoryLeakTracker

/// Tracks NSObject instances by memory address and type, using
/// `DeallocSentinel` (via `objc_setAssociatedObject`) to automatically
/// unregister entries when the tracked object is deallocated.
///
/// - Note: This type is intentionally **not** an NSObject subclass and is
///   not exposed to Objective-C. All storage is integer-address-based
///   (`UInt`), so no ARC participation occurs on the tracker side.
public final class ObjCMemoryLeakTracker: @unchecked Sendable {
  // MARK: Lifecycle

  private init() {}

  // MARK: Public

  public static let shared = ObjCMemoryLeakTracker()

  /// Returns the current tracked-object counts keyed by type string.
  public var trackedCountByType: [String: Int] {
    registry.withLockRead { registry in
      var result = [String: Int]()
      for entry in registry.values {
        result[entry.type, default: 0] += 1
      }
      return result
    }
  }

  /// Register an AnyObject for tracking. A `DeallocSentinel` is attached
  /// via `objc_setAssociatedObject` so that deallocation automatically
  /// calls `unregister(addr:)`. Re-tracking the same object is a no-op.
  ///
  /// NSProxy subclasses cannot host associated objects; for those, only
  /// the registry entry is stored without a sentinel.
  public func track(_ object: AnyObject, type: String) {
    let addr = UInt(bitPattern: Unmanaged.passUnretained(object).toOpaque())
    guard registry.withLockRead({ $0[addr] }) == nil else { return }
    registry.withLock { $0[addr] = TrackedEntry(addr: addr, type: type) }
    guard let nsObject = object as? NSObject, !nsObject.isProxy() else { return }
    let sentinel = DeallocSentinel { [weak self] in
      self?.unregister(addr: addr)
    }
    Self.sentinelKey.withLock { varSentinelKey in
      objc_setAssociatedObject(
        nsObject,
        &varSentinelKey,
        sentinel,
        .OBJC_ASSOCIATION_RETAIN_NONATOMIC
      )
    }
  }

  /// Returns whether an address is currently registered.
  public func isTracked(addr: UInt) -> Bool {
    registry.withLockRead { $0[addr] } != nil
  }

  /// Manually unregister a tracked address.
  public func unregister(addr: UInt) {
    registry.withLock { $0[addr] = nil }
  }

  // MARK: Internal

  struct TrackedEntry {
    let addr: UInt
    let type: String
  }

  // MARK: Private

  private static let sentinelKey: NSMutex<UInt8> = .init(0)

  private let registry = NSMutex([UInt: TrackedEntry]())
}
