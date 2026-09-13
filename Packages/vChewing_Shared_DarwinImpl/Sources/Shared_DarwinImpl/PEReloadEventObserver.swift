// (c) 2022 and onwards The vChewing Project (MulanPSL-2.0 License).
// ====================
// This code is released under the SPDX-License-Identifier: `MulanPSL-2.0`.

import AppKit
import Combine

// MARK: - PEReloadEventObserver

@available(macOS 14, *)
@MainActor
@Observable
public final class PEReloadEventObserver {
  // MARK: Lifecycle

  public init() {
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

  @ObservationIgnored
  private var observation: NSKeyValueObservation?
}
