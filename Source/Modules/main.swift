// Copyright (c) 2011 and onwards The OpenVanilla Project (MIT License).
// All possible vChewing-specific modifications are (c) 2021 and onwards The vChewing Project (MIT-NTL License).
/*
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated
documentation files (the "Software"), to deal in the Software without restriction, including without limitation
the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and
to permit persons to whom the Software is furnished to do so, subject to the following conditions:

1. The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

2. No trademark license is granted to use the trade names, trademarks, service marks, or product names of Contributor,
   except as required to fulfill notice requirements above.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED
TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

import Cocoa
import InputMethodKit

let kConnectionName = "vChewing_1_Connection"

if CommandLine.arguments.count > 1 {
    if CommandLine.arguments[1] == "install" {
        let exitCode = IME.registerInputMethod()
        exit(exitCode)
    }
    if CommandLine.arguments[1] == "uninstall" {
        let exitCode = IME.uninstall(isSudo: IME.isSudoMode)
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
