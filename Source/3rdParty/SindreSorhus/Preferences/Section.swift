// Copyright (c) 2018 and onwards Sindre Sorhus (MIT License).
/*
Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

import SwiftUI

@available(macOS 10.15, *)
extension Preferences {
  /**
	Represents a section with right-aligned title and optional bottom divider.
	*/
  @available(macOS 10.15, *)
  public struct Section: View {
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

    public let label: AnyView
    public let content: AnyView
    public let bottomDivider: Bool
    public let verticalAlignment: VerticalAlignment

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
        .eraseToAnyView()  // TODO: Remove use of `AnyView`.
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
      title: String,
      bottomDivider: Bool = false,
      verticalAlignment: VerticalAlignment = .firstTextBaseline,
      @ViewBuilder content: @escaping () -> Content
    ) {
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
    }

    public var body: some View {
      HStack(alignment: verticalAlignment) {
        label
          .alignmentGuide(.preferenceSectionLabel) { $0[.trailing] }
        content
        Spacer()
      }
    }
  }
}
