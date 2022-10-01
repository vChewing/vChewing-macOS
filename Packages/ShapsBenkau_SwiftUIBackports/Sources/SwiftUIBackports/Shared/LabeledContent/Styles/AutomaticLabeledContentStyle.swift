// (c) 2022 and onwards Shaps Benkau (MIT License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)

import SwiftUI

@available(macOS 10.15, *)
extension Backport where Wrapped == Any {
  public struct AutomaticLabeledContentStyle: BackportLabeledContentStyle {
    public func makeBody(configuration: Configuration) -> some View {
      HStack(alignment: .firstTextBaseline) {
        configuration.label
        Spacer()
        configuration.content
          .multilineTextAlignment(.trailing)
      }
    }
  }
}

@available(macOS 10.15, *)
extension BackportLabeledContentStyle where Self == Backport<Any>.AutomaticLabeledContentStyle {
  static var automatic: Self { .init() }
}
