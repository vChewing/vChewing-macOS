// (c) 2022 and onwards Shaps Benkau (MIT License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)

#if os(iOS)
  import UIKit

  extension UIApplication {
    static var activeScene: UIWindowScene? {
      shared.connectedScenes
        .first { $0.activationState == .foregroundActive }
        as? UIWindowScene
    }
  }
#endif
