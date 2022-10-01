// (c) 2022 and onwards Shaps Benkau (MIT License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)

import SwiftUI

@available(macOS 10.15, *)
private struct BackportDynamicTypeKey: EnvironmentKey {
  static var defaultValue: Backport.DynamicTypeSize = .large
}

@available(macOS 10.15, *)
@available(iOS, deprecated: 15)
@available(tvOS, deprecated: 15)
@available(macOS, deprecated: 12)
@available(watchOS, deprecated: 8)
extension EnvironmentValues {
  /// Sets the Dynamic Type size within the view to the given value.
  ///
  /// As an example, you can set a Dynamic Type size in `ContentView` to be
  /// ``DynamicTypeSize/xLarge`` (this can be useful in previews to see your
  /// content at a different size) like this:
  ///
  ///     ContentView()
  ///         .backport.dynamicTypeSize(.xLarge)
  ///
  /// If a Dynamic Type size range is applied after setting a value,
  /// the value is limited by that range:
  ///
  ///     ContentView() // Dynamic Type size will be .large
  ///         .backport.dynamicTypeSize(...DynamicTypeSize.large)
  ///         .backport.dynamicTypeSize(.xLarge)
  ///
  /// When limiting the Dynamic Type size, consider if adding a
  /// large content view with ``View/accessibilityShowsLargeContentViewer()``
  /// would be appropriate.
  ///
  /// - Parameter size: The size to set for this view.
  ///
  /// - Returns: A view that sets the Dynamic Type size to the specified
  ///   `size`.
  public var backportDynamicTypeSize: Backport<Any>.DynamicTypeSize {
    get { .init(self[keyPath: \.sizeCategory]) }
    set { self[keyPath: \.sizeCategory] = newValue.sizeCategory }
  }
}

@available(macOS 10.15, *)
private struct DynamicTypeRangeKey: EnvironmentKey {
  static var defaultValue: Range<Backport<Any>.DynamicTypeSize> {
    .init(uncheckedBounds: (lower: .xSmall, upper: .accessibility5))
  }
}

@available(macOS 10.15, *)
extension EnvironmentValues {
  var dynamicTypeRange: Range<Backport<Any>.DynamicTypeSize> {
    get { self[DynamicTypeRangeKey.self] }
    set {
      let current = self[DynamicTypeRangeKey.self]
      self[DynamicTypeRangeKey.self] = current.clamped(to: newValue)
    }
  }
}
