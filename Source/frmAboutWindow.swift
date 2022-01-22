/*
 *  frmAboutWindow.swift
 *
 *  Copyright 2021-2022 vChewing Project (3-Clause BSD License).
 *  Derived from 2011-2022 OpenVanilla Project (MIT License).
 *  Some rights reserved. See "LICENSE.TXT" for details.
 */

import Cocoa

@objc(frmAboutWindow) class frmAboutWindow: NSWindowController {
    @IBOutlet weak var appVersionLabel: NSTextField!
    @IBOutlet weak var appCopyrightLabel: NSTextField!
    @IBOutlet var appEULAContent: NSTextView!

    override func windowDidLoad() {
        super.windowDidLoad()
        
        window?.standardWindowButton(.closeButton)?.isHidden = true
        window?.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window?.standardWindowButton(.zoomButton)?.isHidden = true
        guard let installingVersion = Bundle.main.infoDictionary?[kCFBundleVersionKey as String] as? String,
              let versionString = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else {
            return
        }
        if let copyrightLabel = Bundle.main.localizedInfoDictionary?["NSHumanReadableCopyright"] as? String {
            appCopyrightLabel.stringValue = copyrightLabel
        }
        if let eulaContent = Bundle.main.localizedInfoDictionary?["CFEULAContent"] as? String {
            appEULAContent.string = eulaContent
        }
        appVersionLabel.stringValue = String(format: "%@ Build %@", versionString, installingVersion)
    }
    
}
