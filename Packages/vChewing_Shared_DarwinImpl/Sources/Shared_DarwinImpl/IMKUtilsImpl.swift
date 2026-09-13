// (c) 2022 and onwards The vChewing Project (MulanPSL-2.0 License).
// ====================
// This code is released under the SPDX-License-Identifier: `MulanPSL-2.0`.

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
