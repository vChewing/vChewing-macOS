// (c) 2022 and onwards Shaps Benkau (MIT License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)

import SwiftUI

@available(macOS 10.15, *)
@available(iOS, deprecated: 16)
@available(tvOS, deprecated: 16)
@available(macOS, deprecated: 13)
@available(watchOS, deprecated: 9)
extension Backport where Wrapped == Any {
  /// The visibility of scroll indicators of a UI element.
  ///
  /// Pass a value of this type to the ``View.backport.scrollIndicators(_:axes:)`` method
  /// to specify the preferred scroll indicator visibility of a view hierarchy.
  public struct ScrollIndicatorVisibility: Hashable, CustomStringConvertible {
    internal enum IndicatorVisibility: Hashable {
      case automatic
      case visible
      case hidden
    }

    @available(macOS 10.15, *)
    let visibility: Backport.Visibility

    @available(macOS 10.15, *)
    var scrollViewVisible: Bool {
      visibility != .hidden
    }

    @available(macOS 10.15, *)
    public var description: String {
      String(describing: visibility)
    }

    @available(macOS 10.15, *)
    /// Scroll indicator visibility depends on the
    /// policies of the component accepting the visibility configuration.
    public static var automatic: ScrollIndicatorVisibility {
      .init(visibility: .automatic)
    }

    @available(macOS 10.15, *)
    /// Show the scroll indicators.
    ///
    /// The actual visibility of the indicators depends on platform
    /// conventions like auto-hiding behaviors in iOS or user preference
    /// behaviors in macOS.
    public static var visible: ScrollIndicatorVisibility {
      .init(visibility: .visible)
    }

    @available(macOS 10.15, *)
    /// Hide the scroll indicators.
    ///
    /// By default, scroll views in macOS show indicators when a
    /// mouse is connected. Use ``never`` to indicate
    /// a stronger preference that can override this behavior.
    public static var hidden: ScrollIndicatorVisibility {
      .init(visibility: .hidden)
    }
  }
}
