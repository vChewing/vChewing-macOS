// Copyright (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// Refactored from the ObjCpp-version of this class by:
// (c) 2011 and onwards The OpenVanilla Project (MIT License).
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

// MARK: - § Misc functions.

extension KeyHandler {
  func getCurrentMandarinParser() -> String {
    mgrPrefs.mandarinParserName + "_"
  }

  func getActualCandidateCursorIndex() -> Int {
    var cursorIndex = getBuilderCursorIndex()
    // Windows Yahoo Kimo IME style, phrase is *at the rear of* the cursor.
    // (i.e. the cursor is always *before* the phrase.)
    // This is different from MS Phonetics IME style ...
    // ... since Windows Yahoo Kimo allows "node crossing".
    if (mgrPrefs.setRearCursorMode
      && (cursorIndex < getBuilderLength()))
      || cursorIndex == 0
    {
      if cursorIndex == 0, !mgrPrefs.setRearCursorMode {
        cursorIndex += getKeyLengthAtIndexZero()
      } else {
        cursorIndex += 1
      }
    }
    return cursorIndex
  }

  // 用於網頁 Ruby 的注音需要按照教科書印刷的方式來顯示輕聲，所以這裡處理一下。
  func cnvZhuyinKeyToTextbookReading(target: String, newSeparator: String = "-") -> String {
    var arrReturn: [String] = []
    for neta in target.split(separator: "-") {
      var newString = String(neta)
      if String(neta.reversed()[0]) == "˙" {
        newString = String(neta.dropLast())
        newString.insert("˙", at: newString.startIndex)
      }
      arrReturn.append(newString)
    }
    return arrReturn.joined(separator: newSeparator)
  }

  // 用於網頁 Ruby 的拼音的陰平必須顯示，這裡處理一下。
  func restoreToneOneInZhuyinKey(target: String, newSeparator: String = "-") -> String {
    var arrReturn: [String] = []
    for neta in target.split(separator: "-") {
      var newNeta = String(neta)
      if !"ˊˇˋ˙".contains(String(neta.reversed()[0])), !neta.contains("_") {
        newNeta += "1"
      }
      arrReturn.append(newNeta)
    }
    return arrReturn.joined(separator: newSeparator)
  }
}
