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

/// Shiki's Notes: The cursor index in the IMK inline composition buffer
/// still uses UTF16 index measurements. This means that any attempt of
/// using Swift native UTF8 handlings to replace Zonble's NSString (or
/// .utf16) handlings below will still result in unavoidable necessities
/// of solving the UTF16->UTF8 conversions in another approach. Therefore,
/// I strongly advise against any attempt of such until the day that IMK is
/// capable of handling the cursor index in its inline composition buffer using
/// UTF8 measurements.

extension String {
  /// Converts the index in an NSString or .utf16 to the index in a Swift string.
  ///
  /// An Emoji might be compose by more than one UTF-16 code points. However,
  /// the length of an NSString is only the sum of the UTF-16 code points. It
  /// causes that the NSString and Swift string representation of the same
  /// string have different lengths once the string contains such Emoji. The
  /// method helps to find the index in a Swift string by passing the index
  /// in an NSString (or .utf16).
  public func utf16CharIndex(from utf16Index: Int) -> Int {
    var length = 0
    for (i, character) in self.enumerated() {
      length += character.utf16.count
      if length > utf16Index {
        return (i)
      }
    }
    return count
  }

  public func utf16NextPosition(for index: Int) -> Int {
    let fixedIndex = min(utf16CharIndex(from: index) + 1, count)
    return self[..<self.index(startIndex, offsetBy: fixedIndex)].utf16.count
  }

  public func utf16PreviousPosition(for index: Int) -> Int {
    let fixedIndex = max(utf16CharIndex(from: index) - 1, 0)
    return self[..<self.index(startIndex, offsetBy: fixedIndex)].utf16.count
  }

  func utf16SubString(with r: Range<Int>) -> String {
    let arr = Array(self.utf16)[r].map { $0 }
    return String(utf16CodeUnits: arr, count: arr.count)
  }
}
