// (c) 2022 and onwards Shaps Benkau (MIT License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)

import SwiftUI

@available(macOS 10.15, *)
@available(iOS, deprecated: 14)
@available(macOS, deprecated: 11)
@available(tvOS, deprecated: 14)
@available(watchOS, deprecated: 7)
/// A type that applies a custom appearance to all labels within a view.
///
/// To configure the current label style for a view hierarchy, use the
/// ``View/labelStyle(_:)`` modifier.
public protocol BackportLabelStyle {
  /// The properties of a label.
  typealias Configuration = Backport<Any>.LabelStyleConfiguration

  /// A view that represents the body of a label.
  associatedtype Body: View

  @available(macOS 10.15, *)
  /// Creates a view that represents the body of a label.
  ///
  /// The system calls this method for each ``Label`` instance in a view
  /// hierarchy where this style is the current label style.
  ///
  /// - Parameter configuration: The properties of the label.
  @ViewBuilder func makeBody(configuration: Configuration) -> Body
}

@available(macOS 10.15, *)
@available(iOS, deprecated: 14)
@available(macOS, deprecated: 11)
@available(tvOS, deprecated: 14.0)
@available(watchOS, deprecated: 7.0)
extension Backport where Wrapped: View {
  public func labelStyle<S: BackportLabelStyle>(_ style: S) -> some View {
    content.environment(\.backportLabelStyle, .init(style))
  }
}

@available(macOS 10.15, *)
internal struct AnyLabelStyle: BackportLabelStyle {
  let _makeBody: (Backport<Any>.LabelStyleConfiguration) -> AnyView

  @available(macOS 10.15, *)
  init<S: BackportLabelStyle>(_ style: S) {
    _makeBody = { config in
      AnyView(style.makeBody(configuration: config))
    }
  }

  @available(macOS 10.15, *)
  func makeBody(configuration: Configuration) -> some View {
    _makeBody(configuration)
  }
}

@available(macOS 10.15, *)
private struct BackportLabelStyleEnvironmentKey: EnvironmentKey {
  static var defaultValue: AnyLabelStyle?
}

@available(macOS 10.15, *)
extension EnvironmentValues {
  var backportLabelStyle: AnyLabelStyle? {
    get { self[BackportLabelStyleEnvironmentKey.self] }
    set { self[BackportLabelStyleEnvironmentKey.self] = newValue }
  }
}
