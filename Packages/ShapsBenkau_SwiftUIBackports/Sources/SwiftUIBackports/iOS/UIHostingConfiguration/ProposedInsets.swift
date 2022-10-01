// (c) 2022 and onwards Shaps Benkau (MIT License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)

import SwiftUI

@available(macOS 10.15, *)
/// Provides optional inset values. `nil` is interpreted as: use system default
internal struct ProposedInsets: Equatable {
  /// The proposed leading margin measured in points.
  ///
  /// A value of `nil` tells the system to use a default value
  public var leading: CGFloat?

  @available(macOS 10.15, *)
  /// The proposed trailing margin measured in points.
  ///
  /// A value of `nil` tells the system to use a default value
  public var trailing: CGFloat?

  @available(macOS 10.15, *)
  /// The proposed top margin measured in points.
  ///
  /// A value of `nil` tells the system to use a default value
  public var top: CGFloat?

  @available(macOS 10.15, *)
  /// The proposed bottom margin measured in points.
  ///
  /// A value of `nil` tells the system to use a default value
  public var bottom: CGFloat?

  @available(macOS 10.15, *)
  /// An insets proposal with all dimensions left unspecified.
  public static var unspecified: ProposedInsets { .init() }

  @available(macOS 10.15, *)
  /// An insets proposal that contains zero for all dimensions.
  public static var zero: ProposedInsets { .init(leading: 0, trailing: 0, top: 0, bottom: 0) }
}
