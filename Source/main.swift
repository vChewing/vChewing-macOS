/* 
 *  main.m
 *  
 *  Copyright 2021-2022 vChewing Project (3-Clause BSD License).
 *  Derived from 2011-2022 OpenVanilla Project (MIT License).
 *  Some rights reserved. See "LICENSE.TXT" for details.
 */

import Cocoa
import InputMethodKit

private func install() -> Int32 {
    guard let bundleID = Bundle.main.bundleIdentifier else {
        return -1
    }
    let bundleUrl = Bundle.main.bundleURL
    var inputSource = InputSourceHelper.inputSource(for: bundleID)

    if inputSource == nil {
        NSLog("Registering input source \(bundleID) at \(bundleUrl.absoluteString)");
        // then register
        let status = InputSourceHelper.registerTnputSource(at: bundleUrl)

        if !status {
            NSLog("Fatal error: Cannot register input source \(bundleID) at \(bundleUrl.absoluteString).")
            return -1
        }

        inputSource = InputSourceHelper.inputSource(for: bundleID)
    }

    guard let inputSource = inputSource else {
        NSLog("Fatal error: Cannot find input source \(bundleID) after registration.")
        return -1
    }

    if !InputSourceHelper.inputSourceEnabled(for: inputSource) {
        NSLog("Enabling input source \(bundleID) at \(bundleUrl.absoluteString).")
        let status = InputSourceHelper.enable(inputSource: inputSource)
        if !status {
            NSLog("Fatal error: Cannot enable input source \(bundleID).")
            return -1
        }
        if !InputSourceHelper.inputSourceEnabled(for: inputSource) {
            NSLog("Fatal error: Cannot enable input source \(bundleID).")
            return -1
        }
    }

    if CommandLine.arguments.count > 2 && CommandLine.arguments[2] == "--all" {
        let enabled = InputSourceHelper.enableAllInputMode(for: bundleID)
        NSLog(enabled ? "All input sources enabled for \(bundleID)" : "Cannot enable all input sources for \(bundleID), but this is ignored")
    }
    return 0
}

let kConnectionName = "vChewing_1_Connection"

if CommandLine.arguments.count > 1 {
    if CommandLine.arguments[1] == "install" {
        let exitCode = install()
        exit(exitCode)
    }
}

guard let mainNibName = Bundle.main.infoDictionary?["NSMainNibFile"] as? String else {
    NSLog("Fatal error: NSMainNibFile key not defined in Info.plist.");
    exit(-1)
}

let loaded = Bundle.main.loadNibNamed(mainNibName, owner: NSApp, topLevelObjects: nil)
if !loaded {
    NSLog("Fatal error: Cannot load \(mainNibName).")
    exit(-1)
}

guard let bundleID = Bundle.main.bundleIdentifier, let server = IMKServer(name: kConnectionName, bundleIdentifier: bundleID) else {
    NSLog("Fatal error: Cannot initialize input method server with connection \(kConnectionName).")
    exit(-1)
}

NSApp.run()
