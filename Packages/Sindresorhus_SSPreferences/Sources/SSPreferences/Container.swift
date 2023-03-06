// (c) 2018 and onwards Sindre Sorhus (MIT License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)

import SwiftUI

@available(macOS 10.15, *)
public extension Settings {
  /**
   Function builder for `Settings` components used in order to restrict types of child views to be of type `Section`.
   */
  @resultBuilder
  enum SectionBuilder {
    public static func buildBlock(_ sections: Section...) -> [Section] {
      sections
    }
  }

  /**
   A view which holds `Settings.Section` views and does all the alignment magic similar to `NSGridView` from AppKit.
   */
  struct Container: View {
    private let sectionBuilder: () -> [Section]
    private let contentWidth: Double
    private let minimumLabelWidth: Double
    @State private var maximumLabelWidth = 0.0

    /**
     Creates an instance of container component, which handles layout of stacked `Settings.Section` views.

     Custom alignment requires content width to be specified beforehand.

     - Parameters:
     	- contentWidth: A fixed width of the container's content (excluding paddings).
     	- minimumLabelWidth: A minimum width for labels within this container. By default, it will fit to the largest label.
     	- builder: A view builder that creates `Settings.Section`'s of this container.
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

      return VStack(alignment: .settingsSectionLabel) {
        ForEach(0 ..< sections.count, id: \.self) { index in
          let labelWidth = max(minimumLabelWidth, maximumLabelWidth)
          if sections[index].label != nil {
            sections[index]
              .frame(width: contentWidth, alignment: .leading)
          } else {
            sections[index].content
              .alignmentGuide(.settingsSectionLabel) { $0[.leading] + labelWidth }
              .frame(width: contentWidth, alignment: .leading)
          }
          if sections[index].bottomDivider, index < sections.count - 1 {
            Divider()
              .frame(height: 10)
              .alignmentGuide(.settingsSectionLabel) { $0[.leading] + labelWidth }
          }
        }
      }
      .modifier(Section.LabelWidthModifier(maximumWidth: $maximumLabelWidth))
      .frame(width: contentWidth, alignment: .leading)
      .padding(.vertical, 20)
      .padding(.horizontal, 30)
    }
  }
}

/**
 Extension with custom alignment guide for section title labels.
 */
@available(macOS 10.15, *)
extension HorizontalAlignment {
  private enum SettingsSectionLabelAlignment: AlignmentID {
    // swiftlint:disable:next no_cgfloat
    static func defaultValue(in context: ViewDimensions) -> CGFloat {
      context[HorizontalAlignment.leading]
    }
  }

  static let settingsSectionLabel = HorizontalAlignment(SettingsSectionLabelAlignment.self)
}
