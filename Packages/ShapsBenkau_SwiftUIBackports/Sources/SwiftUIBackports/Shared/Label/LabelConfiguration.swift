// (c) 2022 and onwards Shaps Benkau (MIT License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)

import SwiftUI

@available(macOS 10.15, *)
@available(iOS, deprecated: 14)
@available(macOS, deprecated: 11)
@available(tvOS, deprecated: 14)
@available(watchOS, deprecated: 7)
extension Backport where Wrapped == Any {
  /// The properties of a label.
  public struct LabelStyleConfiguration {
    /// A type-erased title view of a label.
    public struct Title: View {
      let content: AnyView
      public var body: some View { content }
      init<Content: View>(content: Content) {
        self.content = .init(content)
      }
    }

    @available(macOS 10.15, *)
    /// A type-erased icon view of a label.
    public struct Icon: View {
      let content: AnyView
      public var body: some View { content }
      init<Content: View>(content: Content) {
        self.content = .init(content)
      }
    }

    @available(macOS 10.15, *)
    /// A description of the labeled item.
    public internal(set) var title: LabelStyleConfiguration.Title

    @available(macOS 10.15, *)
    /// A symbolic representation of the labeled item.
    public internal(set) var icon: LabelStyleConfiguration.Icon

    @available(macOS 10.15, *)
    internal var environment: EnvironmentValues = .init()

    @available(macOS 10.15, *)
    func environment(_ values: EnvironmentValues) -> Self {
      var config = self
      config.environment = values
      return config
    }
  }
}
