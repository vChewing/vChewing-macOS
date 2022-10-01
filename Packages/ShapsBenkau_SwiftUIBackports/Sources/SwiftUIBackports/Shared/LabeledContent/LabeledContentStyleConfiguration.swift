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
  /// The properties of a labeled content instance.
  public struct LabeledContentStyleConfiguration {
    /// A type-erased label of a labeled content instance.
    public struct Label: View {
      @EnvironmentContains(key: "LabelsHiddenKey") private var isHidden
      let view: AnyView
      public var body: some View {
        if isHidden {
          EmptyView()
        } else {
          view
        }
      }

      @available(macOS 10.15, *)
      init<V: View>(_ view: V) {
        self.view = .init(view)
      }
    }

    @available(macOS 10.15, *)
    /// A type-erased content of a labeled content instance.
    public struct Content: View {
      @EnvironmentContains(key: "LabelsHiddenKey") private var isHidden
      let view: AnyView
      public var body: some View {
        view
          .foregroundColor(isHidden ? .primary : .secondary)
          .frame(maxWidth: .infinity, alignment: isHidden ? .leading : .trailing)
      }

      @available(macOS 10.15, *)
      init<V: View>(_ view: V) {
        self.view = .init(view)
      }
    }

    @available(macOS 10.15, *)
    /// The label of the labeled content instance.
    public let label: Label

    @available(macOS 10.15, *)
    /// The content of the labeled content instance.
    public let content: Content

    @available(macOS 10.15, *)
    internal init<L: View, C: View>(label: L, content: C) {
      self.label = .init(label)
      self.content = .init(content)
    }

    @available(macOS 10.15, *)
    internal init<L: View, C: View>(@ViewBuilder content: () -> C, @ViewBuilder label: () -> L) {
      self.content = .init(content())
      self.label = .init(label())
    }
  }
}
