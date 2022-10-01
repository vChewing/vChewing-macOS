// (c) 2022 and onwards Shaps Benkau (MIT License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)

import SwiftUI

@available(iOS, deprecated: 14)
@available(watchOS, deprecated: 7)
@available(tvOS, deprecated: 14)
extension Backport where Wrapped: View {
  @ViewBuilder
  public func navigationTitle<S: StringProtocol>(_ title: S) -> some View {
    #if os(macOS)
      if #available(macOS 11, *) {
        content.navigationTitle(title)
      } else {
        content
      }
    #else
      content.navigationBarTitle(title)
    #endif
  }

  @ViewBuilder
  public func navigationTitle(_ titleKey: LocalizedStringKey) -> some View {
    #if os(macOS)
      if #available(macOS 11, *) {
        content.navigationTitle(titleKey)
      } else {
        content
      }
    #else
      content.navigationBarTitle(titleKey)
    #endif
  }
}
