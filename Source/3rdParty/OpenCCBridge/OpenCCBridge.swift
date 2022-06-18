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

import Foundation
import OpenCC

/// A bridge to let Objctive-C code to access SwiftyOpenCC.
///
/// Since SwiftyOpenCC only provide Swift classes, we create an NSObject subclass
/// in Swift in order to bridge the Swift classes into our Objective-C++ project.
public class OpenCCBridge: NSObject {
  private static let shared = OpenCCBridge()
  private var simplify: ChineseConverter?
  private var traditionalize: ChineseConverter?

  override private init() {
    try? simplify = ChineseConverter(options: .simplify)
    try? traditionalize = ChineseConverter(options: [.traditionalize, .twStandard])
    super.init()
  }

  /// CrossConvert.
  ///
  /// - Parameter string: Text in Original Script.
  /// - Returns: Text converted to Different Script.
  public static func crossConvert(_ string: String) -> String? {
    switch IME.currentInputMode {
      case InputMode.imeModeCHS:
        return shared.traditionalize?.convert(string)
      case InputMode.imeModeCHT:
        return shared.simplify?.convert(string)
      default:
        return string
    }
  }
}
