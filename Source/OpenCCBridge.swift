//
// PreferencesWindowController.swift
//
// Copyright (c) 2011-2022 The OpenVanilla Project.
//
// Contributors:
//     Weizhong Yang (@zonble) @ OpenVanilla
//
// Based on the Syrup Project and the Formosana Library
// by Lukhnos Liu (@lukhnos).
//
// Permission is hereby granted, free of charge, to any person
// obtaining a copy of this software and associated documentation
// files (the "Software"), to deal in the Software without
// restriction, including without limitation the rights to use,
// copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the
// Software is furnished to do so, subject to the following
// conditions:
//
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
// OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
// HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
// WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
// OTHER DEALINGS IN THE SOFTWARE.
//

import Foundation
import OpenCC

// Since SwiftyLibreCC only provide Swift classes, we create an NSObject subclass
// in Swift in order to bridge the Swift classes into our Objective-C++ project.
class OpenCCBridge : NSObject {
    private static let shared = OpenCCBridge()
    private var converter: ChineseConverter?

    private override init() {
        try? converter = ChineseConverter(options: .twStandardRev)
        super.init()
    }

    @objc static func convert(_ string: String) -> String? {
        shared.converter?.convert(string)
    }

    private func convert(_ string: String) -> String? {
        converter?.convert(string)
    }
}
