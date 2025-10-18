// (c) 2022 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation

// MARK: - IMKHelper Extension

extension IMKHelper {
  public static var currentBasicKeyboardLayout: String {
    UserDefaults.current.string(forKey: "BasicKeyboardLayout") ?? ""
  }

  public static var isDynamicBasicKeyboardLayoutEnabled: Bool {
    Self.arrDynamicBasicKeyLayouts
      .contains(currentBasicKeyboardLayout) || !currentBasicKeyboardLayout.isEmpty
  }
}
