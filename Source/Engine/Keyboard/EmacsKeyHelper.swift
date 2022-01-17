/* 
 *  EmacsKeyHelper.swift
 *  
 *  Copyright 2021-2022 vChewing Project (3-Clause BSD License).
 *  Derived from 2011-2022 OpenVanilla Project (MIT License).
 *  Some rights reserved. See "LICENSE.TXT" for details.
 */

import Cocoa

@objc enum vChewingEmacsKey: UInt16 {
    case none = 0
    case forward = 6 // F
    case backward = 2 // B
    case home = 1 // A
    case end = 5 // E
    case delete = 4 // D
    case nextPage = 22 // V
}

class EmacsKeyHelper: NSObject {
    @objc static func detect(charCode: UniChar, flags: NSEvent.ModifierFlags) -> vChewingEmacsKey {
        if flags.contains(.control) {
            return vChewingEmacsKey(rawValue: charCode) ?? .none
        }
        return .none;
    }
}
