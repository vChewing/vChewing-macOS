// (c) 2022 and onwards Shaps Benkau (MIT License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)

import SwiftUI

@available(macOS 10.15, *)
@available(tvOS, deprecated: 13)
@available(macOS, deprecated: 10.15)
@available(watchOS, deprecated: 6)
extension View {
  /// Sets whether this presentation should act as a `modal`, preventing interactive dismissals
  /// - Parameter isModal: If `true` the user will not be able to interactively dismiss
  @ViewBuilder
  @available(iOS, deprecated: 13, renamed: "backport.interactiveDismissDisabled(_:)")
  public func presentation(isModal: Bool) -> some View {
    #if os(iOS)
      if #available(iOS 15, *) {
        backport.interactiveDismissDisabled(isModal)
      } else {
        self
      }
    #else
      self
    #endif
  }

  @available(macOS 10.15, *)
  /// Provides fine-grained control over the dismissal.
  /// - Parameters:
  ///   - isModal: If `true`, the user will not be able to interactively dismiss
  ///   - onAttempt: A closure that will be called when an interactive dismiss attempt occurs.
  ///   You can use this as an opportunity to present an ActionSheet to prompt the user.
  @ViewBuilder
  @available(iOS, deprecated: 13, renamed: "backport.interactiveDismissDisabled(_:onAttempt:)")
  public func presentation(isModal: Bool = true, _ onAttempt: @escaping () -> Void) -> some View {
    #if os(iOS)
      if #available(iOS 15, *) {
        backport.interactiveDismissDisabled(isModal, onAttempt: onAttempt)
      } else {
        self
      }
    #else
      self
    #endif
  }
}
