// (c) 2022 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import AppKit
import Combine

// MARK: - PEReloadEventObserver

@available(macOS 10.15, *)
public final class PEReloadEventObserver: NSObject, ObservableObject {
  // MARK: Lifecycle

  override public init() {
    super.init()
    self.observation = Broadcaster.shared
      .observe(\.eventForReloadingPhraseEditor, options: [.new]) { [weak self] _, _ in
        self?.touch()
      }
  }

  deinit {
    mainSync { observation?.invalidate() }
  }

  // MARK: Public

  public static let shared = PEReloadEventObserver()

  @Published
  public var id = UUID().uuidString

  public static func == (
    lhs: PEReloadEventObserver,
    rhs: PEReloadEventObserver
  )
    -> Bool { lhs.id == rhs.id }

  nonisolated public func touch() {
    mainSync {
      id = UUID().uuidString
    }
  }

  // MARK: Private

  private var observation: NSKeyValueObservation?
}
