// (c) 2018 and onwards Sindre Sorhus (MIT License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)

import SwiftUI

@available(macOS 10.15, *)
public extension SSPreferences {
  /**
   Represents a section with right-aligned title and optional bottom divider.
   */
  @available(macOS 10.15, *)
  struct Section: View {
    /**
     Preference key holding max width of section labels.
     */
    private struct LabelWidthPreferenceKey: PreferenceKey {
      typealias Value = Double

      static var defaultValue = 0.0

      static func reduce(value: inout Double, nextValue: () -> Double) {
        let next = nextValue()
        value = next > value ? next : value
      }
    }

    /**
     Convenience overlay for finding a label's dimensions using `GeometryReader`.
     */
    private struct LabelOverlay: View {
      var body: some View {
        GeometryReader { geometry in
          Color.clear
            .preference(key: LabelWidthPreferenceKey.self, value: Double(geometry.size.width))
        }
      }
    }

    /**
     Convenience modifier for applying `LabelWidthPreferenceKey`.
     */
    struct LabelWidthModifier: ViewModifier {
      @Binding var maximumWidth: Double

      func body(content: Content) -> some View {
        content
          .onPreferenceChange(LabelWidthPreferenceKey.self) { newMaximumWidth in
            maximumWidth = Double(newMaximumWidth)
          }
      }
    }

    public private(set) var label: AnyView?
    public let content: AnyView
    public let bottomDivider: Bool
    public let verticalAlignment: VerticalAlignment

    /**
     A section is responsible for controlling a single preference without Label.

     - Parameters:
       - bottomDivider: Whether to place a `Divider` after the section content. Default is `false`.
       - verticalAlignement: The vertical alignment of the section content.
       - verticalAlignment:
       - label: A view describing preference handled by this section.
       - content: A content view.
     */
    public init<Content: View>(
      bottomDivider: Bool = false,
      verticalAlignment: VerticalAlignment = .firstTextBaseline,
      @ViewBuilder content: @escaping () -> Content
    ) {
      label = nil
      self.bottomDivider = bottomDivider
      self.verticalAlignment = verticalAlignment
      let stack = VStack(alignment: .leading) { content() }
      self.content = stack.eraseToAnyView()
    }

    /**
     A section is responsible for controlling a single preference.

     - Parameters:
     	- bottomDivider: Whether to place a `Divider` after the section content. Default is `false`.
     	- verticalAlignement: The vertical alignment of the section content.
     	- verticalAlignment:
     	- label: A view describing preference handled by this section.
     	- content: A content view.
     */
    public init<Label: View, Content: View>(
      bottomDivider: Bool = false,
      verticalAlignment: VerticalAlignment = .firstTextBaseline,
      label: @escaping () -> Label,
      @ViewBuilder content: @escaping () -> Content
    ) {
      self.label = label()
        .overlay(LabelOverlay())
        .eraseToAnyView() // TODO: Remove use of `AnyView`.
      self.bottomDivider = bottomDivider
      self.verticalAlignment = verticalAlignment
      let stack = VStack(alignment: .leading) { content() }
      self.content = stack.eraseToAnyView()
    }

    /**
     Creates instance of section, responsible for controling single preference with `Text` as  a `Label`.

     - Parameters:
     	- title: A string describing preference handled by this section.
     	- bottomDivider: Whether to place a `Divider` after the section content. Default is `false`.
     	- verticalAlignement: The vertical alignment of the section content.
     	- verticalAlignment:
     	- content: A content view.
     */
    public init<Content: View>(
      title: String? = nil,
      bottomDivider: Bool = false,
      verticalAlignment: VerticalAlignment = .firstTextBaseline,
      @ViewBuilder content: @escaping () -> Content
    ) {
      if let title = title {
        let textLabel = {
          Text(title)
            .font(.system(size: 13.0))
            .overlay(LabelOverlay())
            .eraseToAnyView()
        }
        self.init(
          bottomDivider: bottomDivider,
          verticalAlignment: verticalAlignment,
          label: textLabel,
          content: content
        )
        return
      }
      self.init(
        bottomDivider: bottomDivider,
        verticalAlignment: verticalAlignment,
        content: content
      )
    }

    public func bodyLimited(rightPaneWidth: CGFloat? = nil) -> some View {
      HStack(alignment: verticalAlignment) {
        if let label = label {
          label.alignmentGuide(.preferenceSectionLabel) { $0[.trailing] }
        }
        HStack {
          content
          Spacer()
        }.frame(maxWidth: rightPaneWidth)
      }
    }

    public var body: some View {
      bodyLimited()
    }
  }
}
