/* 
 *  NonModalAlertWindowController.swift
 *  
 *  Copyright 2021-2022 vChewing Project (3-Clause BSD License).
 *  Derived from 2011-2022 OpenVanilla Project (MIT License).
 *  Some rights reserved. See "LICENSE.TXT" for details.
 */

import Cocoa

@objc protocol NonModalAlertWindowControllerDelegate: AnyObject {
    func nonModalAlertWindowControllerDidConfirm(_ controller: NonModalAlertWindowController)
    func nonModalAlertWindowControllerDidCancel(_ controller: NonModalAlertWindowController)
}

class NonModalAlertWindowController: NSWindowController {
    @objc (sharedInstance)
    
    static let shared = NonModalAlertWindowController(windowNibName: "NonModalAlertWindowController")
    
    @IBOutlet weak var titleTextField: NSTextField!
    @IBOutlet weak var contentTextField: NSTextField!
    @IBOutlet weak var confirmButton: NSButton!
    @IBOutlet weak var cancelButton: NSButton!
    weak var delegate: NonModalAlertWindowControllerDelegate?
    
    @objc func show(title: String, content: String, confirmButtonTitle: String, cancelButtonTitle: String?, cancelAsDefault: Bool, delegate: NonModalAlertWindowControllerDelegate?) {
        if window?.isVisible == true {
            self.delegate?.nonModalAlertWindowControllerDidCancel(self)
        }
        
        self.delegate = delegate
        
        var oldFrame = confirmButton.frame
        confirmButton.title = confirmButtonTitle
        confirmButton.sizeToFit()
        
        var newFrame = confirmButton.frame
        newFrame.size.width = max(90, newFrame.size.width + 10)
        newFrame.origin.x += oldFrame.size.width - newFrame.size.width
        self.confirmButton.frame = newFrame
        
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
                window?.defaultButtonCell = cancelButton.cell as? NSButtonCell
            } else {
                cancelButton.keyEquivalent = " "
                window?.defaultButtonCell = confirmButton.cell as? NSButtonCell
            }
        } else {
            window?.defaultButtonCell = confirmButton.cell as? NSButtonCell
        }
        
        titleTextField.stringValue = title
        
        oldFrame = contentTextField.frame
        contentTextField.stringValue = content
        
        var infiniteHeightFrame = oldFrame
        infiniteHeightFrame.size.width -= 4.0
        infiniteHeightFrame.size.height = 10240
        newFrame = (content as NSString).boundingRect(with: infiniteHeightFrame.size, options: [.usesLineFragmentOrigin], attributes: [.font: contentTextField.font!])
        newFrame.size.width = max(newFrame.size.width, oldFrame.size.width)
        newFrame.size.height += 4.0
        newFrame.origin = oldFrame.origin
        newFrame.origin.y -= (newFrame.size.height - oldFrame.size.height)
        contentTextField.frame = newFrame
        
        var windowFrame = window?.frame ?? NSRect.zero
        windowFrame.size.height += (newFrame.size.height - oldFrame.size.height)
        window?.level = NSWindow.Level(Int(CGShieldingWindowLevel()) + 1)
        window?.setFrame(windowFrame, display: true)
        window?.center()
        window?.makeKeyAndOrderFront(self)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @IBAction func confirmButtonAction(_ sender: Any) {
        delegate?.nonModalAlertWindowControllerDidConfirm(self)
        window?.orderOut(self)
    }
    
    @IBAction func cancelButtonAction(_ sender: Any) {
        cancel(sender)
    }
    
    func cancel(_ sender: Any) {
        delegate?.nonModalAlertWindowControllerDidCancel(self)
        delegate = nil
        window?.orderOut(self)
    }
    
}
