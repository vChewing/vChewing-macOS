// Copyright (c) 2011 and onwards The OpenVanilla Project (MIT License).
// All possible vChewing-specific modifications are of:
// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
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

protocol ctlNonModalAlertWindowDelegate: AnyObject {
  func ctlNonModalAlertWindowDidConfirm(_ controller: ctlNonModalAlertWindow)
  func ctlNonModalAlertWindowDidCancel(_ controller: ctlNonModalAlertWindow)
}

class ctlNonModalAlertWindow: NSWindowController {
  static let shared = ctlNonModalAlertWindow(windowNibName: "frmNonModalAlertWindow")

  @IBOutlet var titleTextField: NSTextField!
  @IBOutlet var contentTextField: NSTextField!
  @IBOutlet var confirmButton: NSButton!
  @IBOutlet var cancelButton: NSButton!
  weak var delegate: ctlNonModalAlertWindowDelegate?

  func show(
    title: String, content: String, confirmButtonTitle: String, cancelButtonTitle: String?,
    cancelAsDefault: Bool, delegate: ctlNonModalAlertWindowDelegate?
  ) {
    guard let window = window else { return }
    if window.isVisible == true {
      self.delegate?.ctlNonModalAlertWindowDidCancel(self)
    }

    self.delegate = delegate

    var oldFrame = confirmButton.frame
    confirmButton.title = confirmButtonTitle
    confirmButton.sizeToFit()

    var newFrame = confirmButton.frame
    newFrame.size.width = max(90, newFrame.size.width + 10)
    newFrame.origin.x += oldFrame.size.width - newFrame.size.width
    confirmButton.frame = newFrame

    if let cancelButtonTitle = cancelButtonTitle {
      cancelButton.title = cancelButtonTitle
      cancelButton.sizeToFit()
      var adjustFrame = cancelButton.frame
      adjustFrame.size.width = max(90, adjustFrame.size.width + 10)
      adjustFrame.origin.x = newFrame.origin.x - adjustFrame.size.width
      confirmButton.frame = adjustFrame
      cancelButton.isHidden = false
    } else {
      cancelButton.isHidden = true
    }

    cancelButton.nextKeyView = confirmButton
    confirmButton.nextKeyView = cancelButton

    if cancelButtonTitle != nil {
      if cancelAsDefault {
        window.defaultButtonCell = cancelButton.cell as? NSButtonCell
      } else {
        cancelButton.keyEquivalent = " "
        window.defaultButtonCell = confirmButton.cell as? NSButtonCell
      }
    } else {
      window.defaultButtonCell = confirmButton.cell as? NSButtonCell
    }

    titleTextField.stringValue = title

    oldFrame = contentTextField.frame
    contentTextField.stringValue = content

    var infiniteHeightFrame = oldFrame
    infiniteHeightFrame.size.width -= 4.0
    infiniteHeightFrame.size.height = 10240
    newFrame = (content as NSString).boundingRect(
      with: infiniteHeightFrame.size, options: [.usesLineFragmentOrigin],
      attributes: [.font: contentTextField.font!]
    )
    newFrame.size.width = max(newFrame.size.width, oldFrame.size.width)
    newFrame.size.height += 4.0
    newFrame.origin = oldFrame.origin
    newFrame.origin.y -= (newFrame.size.height - oldFrame.size.height)
    contentTextField.frame = newFrame

    var windowFrame = window.frame
    windowFrame.size.height += (newFrame.size.height - oldFrame.size.height)
    window.level = NSWindow.Level(Int(CGShieldingWindowLevel()) + 1)
    window.setFrame(windowFrame, display: true)
    window.center()
    window.makeKeyAndOrderFront(self)
    NSApp.activate(ignoringOtherApps: true)
  }

  @IBAction func confirmButtonAction(_: Any) {
    delegate?.ctlNonModalAlertWindowDidConfirm(self)
    window?.orderOut(self)
  }

  @IBAction func cancelButtonAction(_ sender: Any) {
    cancel(sender)
  }

  func cancel(_: Any) {
    delegate?.ctlNonModalAlertWindowDidCancel(self)
    delegate = nil
    window?.orderOut(self)
  }
}
