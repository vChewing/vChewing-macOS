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
	Function builder for `Preferences` components used in order to restrict types of child views to be of type `Section`.
	*/
	@resultBuilder
	public struct SectionBuilder {
		public static func buildBlock(_ sections: Section...) -> [Section] {
			sections
		}
	}

	/**
	A view which holds `Preferences.Section` views and does all the alignment magic similar to `NSGridView` from AppKit.
	*/
	public struct Container: View {
		private let sectionBuilder: () -> [Section]
		private let contentWidth: Double
		private let minimumLabelWidth: Double
		@State private var maximumLabelWidth = 0.0

		/**
		Creates an instance of container component, which handles layout of stacked `Preferences.Section` views.

		Custom alignment requires content width to be specified beforehand.

		- Parameters:
			- contentWidth: A fixed width of the container's content (excluding paddings).
			- minimumLabelWidth: A minimum width for labels within this container. By default, it will fit to the largest label.
			- builder: A view builder that creates `Preferences.Section`'s of this container.
		*/
		public init(
			contentWidth: Double,
			minimumLabelWidth: Double = 0,
			@SectionBuilder builder: @escaping () -> [Section]
		) {
			sectionBuilder = builder
			self.contentWidth = contentWidth
			self.minimumLabelWidth = minimumLabelWidth
		}

		public var body: some View {
			let sections = sectionBuilder()

			return VStack(alignment: .preferenceSectionLabel) {
				ForEach(0..<sections.count, id: \.self) { index in
					viewForSection(sections, index: index)
				}
			}
			.modifier(Section.LabelWidthModifier(maximumWidth: $maximumLabelWidth))
			.frame(width: CGFloat(contentWidth), alignment: .leading)
			.padding(.vertical, 20)
			.padding(.horizontal, 30)
		}

		@ViewBuilder
		private func viewForSection(_ sections: [Section], index: Int) -> some View {
			sections[index]
			if index != sections.count - 1 && sections[index].bottomDivider {
				Divider()
					// Strangely doesn't work without width being specified. Probably because of custom alignment.
					.frame(width: CGFloat(contentWidth), height: 20)
					.alignmentGuide(.preferenceSectionLabel) {
						$0[.leading] + CGFloat(max(minimumLabelWidth, maximumLabelWidth))
					}
			}
		}
	}
}

/// Extension with custom alignment guide for section title labels.
@available(macOS 10.15, *)
extension HorizontalAlignment {
	private enum PreferenceSectionLabelAlignment: AlignmentID {
		static func defaultValue(in context: ViewDimensions) -> CGFloat {
			context[HorizontalAlignment.leading]
		}
	}

	static let preferenceSectionLabel = HorizontalAlignment(PreferenceSectionLabelAlignment.self)
}
