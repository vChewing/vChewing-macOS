// Copyright (c) 2021 and onwards The vChewing Project (MIT-NTL License).
/*
Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

1. The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

2. No trademark license is granted to use the trade names, trademarks, service
marks, or product names of Contributor, except as required to fulfill notice
requirements above.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

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
