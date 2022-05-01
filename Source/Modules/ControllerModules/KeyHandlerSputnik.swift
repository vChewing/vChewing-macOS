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

// MARK: - KeyHandler Sputnik.

// Swift Extension 不允許直接存放這些變數，所以就寫了這個衛星型別。
// 一旦 Mandarin 模組被 Swift 化，整個 KeyHandler 就可以都用 Swift。
// 屆時會考慮將該衛星型別內的變數與常數都挪回 KeyHandler_Kernel 內。

class KeyHandlerSputnik: NSObject {
	static let kEpsilon: Double = 0.000001
	static var inputMode: String = ""
	static var languageModel: vChewing.LMInstantiator = .init()
	static var userOverrideModel: vChewing.LMUserOverride = .init()
	static var builder: Megrez.BlockReadingBuilder = .init(lm: languageModel)
	static var walkedNodes: [Megrez.NodeAnchor] = []
}
