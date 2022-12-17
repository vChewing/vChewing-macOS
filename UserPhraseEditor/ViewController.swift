// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Cocoa

class ViewController: NSViewController, NSTextViewDelegate {
  @IBOutlet var edtDocument: NSTextView!
  /// - Tag: setRepresentedObjectExample
  override var representedObject: Any? {
    didSet {
      // Pass down the represented object to all of the child view controllers.
      for child in children {
        child.representedObject = representedObject
      }
    }
  }

  weak var document: Document? {
    if let docRepresentedObject = representedObject as? Document {
      return docRepresentedObject
    }
    return nil
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    // Do any additional setup after loading the view.
    edtDocument.font = NSFont(name: "Monaco", size: 16)
  }

  override func viewDidAppear() {
    super.viewDidAppear()
  }

  // MARK: - NSTextViewDelegate

  func textDidBeginEditing(_: Notification) {
    document?.objectDidBeginEditing(self)
  }

  func textDidEndEditing(_: Notification) {
    document?.objectDidEndEditing(self)
  }
}
