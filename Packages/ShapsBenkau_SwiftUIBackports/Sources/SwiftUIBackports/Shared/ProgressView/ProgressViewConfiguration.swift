// (c) 2022 and onwards Shaps Benkau (MIT License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)

import SwiftUI

@available(macOS 10.15, *)
@available(iOS, deprecated: 14)
@available(macOS, deprecated: 11)
@available(tvOS, deprecated: 14.0)
@available(watchOS, deprecated: 7.0)
extension Backport where Wrapped == Any {
  /// The properties of a progress view instance.
  public struct ProgressViewStyleConfiguration {
    internal enum Kind {
      case circular
      case linear
    }

    @available(macOS 10.15, *)
    /// A type-erased label describing the task represented by the progress
    /// view.
    public struct Label: View {
      let content: AnyView
      public var body: some View { content }
      init<Content: View>(content: Content) {
        self.content = .init(content)
      }
    }

    @available(macOS 10.15, *)
    /// A type-erased label that describes the current value of a progress view.
    public struct CurrentValueLabel: View {
      let content: AnyView
      public var body: some View { content }
      init<Content: View>(content: Content) {
        self.content = .init(content)
      }
    }

    @available(macOS 10.15, *)
    /// The completed fraction of the task represented by the progress view,
    /// from `0.0` (not yet started) to `1.0` (fully complete), or `nil` if the
    /// progress is indeterminate or relative to a date interval.
    public let fractionCompleted: Double?

    @available(macOS 10.15, *)
    /// A view that describes the task represented by the progress view.
    ///
    /// If `nil`, then the task is self-evident from the surrounding context,
    /// and the style does not need to provide any additional description.
    ///
    /// If the progress view is defined using a `Progress` instance, then this
    /// label is equivalent to its `localizedDescription`.
    public var label: Label?

    @available(macOS 10.15, *)
    /// A view that describes the current value of a progress view.
    ///
    /// If `nil`, then the value of the progress view is either self-evident
    /// from the surrounding context or unknown, and the style does not need to
    /// provide any additional description.
    ///
    /// If the progress view is defined using a `Progress` instance, then this
    /// label is equivalent to its `localizedAdditionalDescription`.
    public var currentValueLabel: CurrentValueLabel?

    @available(macOS 10.15, *)
    internal let preferredKind: Kind
    internal var min: Double = 0
    internal var max: Double = 1
  }
}
