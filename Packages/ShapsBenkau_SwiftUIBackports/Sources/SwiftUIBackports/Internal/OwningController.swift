// (c) 2022 and onwards Shaps Benkau (MIT License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)

#if os(iOS)
  import UIKit

  extension UIView {
    public var parentController: UIViewController? {
      var responder: UIResponder? = self

      while !(responder is UIViewController), superview != nil {
        if let next = responder?.next {
          responder = next
        }
      }

      return responder as? UIViewController
    }
  }
#endif

#if os(macOS)
  import AppKit

  extension NSView {
    public var parentController: NSViewController? {
      var responder: NSResponder? = self

      while !(responder is NSViewController), superview != nil {
        if let next = responder?.nextResponder {
          responder = next
        }
      }

      return responder as? NSViewController
    }
  }
#endif
