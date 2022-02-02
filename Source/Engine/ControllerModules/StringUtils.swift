/*
 *  StringUtils.swift
 *
 *  Copyright 2021-2022 vChewing Project (3-Clause BSD License).
 *  Derived from 2011-2022 OpenVanilla Project (MIT License).
 *  Some rights reserved. See "LICENSE.TXT" for details.
 */

import Foundation

/// Utilities to convert the length of an NSString and a Swift string.
class StringUtils: NSObject {

    /// Converts the index in an NSString to the index in a Swift string.
    ///
    /// An Emoji might be compose by more than one UTF-16 code points, however
    /// the length of an NSString is only the sum of the UTF-16 code points. It
    /// causes that the NSString and Swift string representation of the same
    /// string have different lengths once the string contains such Emoji. The
    /// method helps to find the index in a Swift string by passing the index
    /// in an NSString.
    static func convertToCharIndex(from utf16Index: Int, in string: String) -> Int {
        var length = 0
        for (i, character) in string.enumerated() {
            if length >= utf16Index {
                return i
            }
            length += character.utf16.count
        }
        return string.count
    }

    @objc (nextUtf16PositionForIndex:in:)
    static func nextUtf16Position(for index: Int, in string: String) -> Int {
        var index = convertToCharIndex(from: index, in: string)
        if index < string.count {
            index += 1
        }
        let count = string[..<string.index(string.startIndex, offsetBy: index)].utf16.count
        return count
    }

    @objc (previousUtf16PositionForIndex:in:)
    static func previousUtf16Position(for index: Int, in string: String) -> Int {
        var index = convertToCharIndex(from: index, in: string)
        if index > 0 {
            index -= 1
        }
        let count = string[..<string.index(string.startIndex, offsetBy: index)].utf16.count
        return count
    }
}

extension NSString {
    @objc var count: Int {
        (self as String).count
    }

    @objc var split: [NSString] {
        Array(self as String).map {
            NSString(string: String($0))
        }
    }
}
