// Copyright (c) 2021 and onwards The vChewing Project (MIT-NTL License).
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

import Foundation

extension String {
    mutating func removingRegexMatches(pattern: String, replaceWith: String = "") {
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
            let range = NSRange(location: 0, length: count)
            self = regex.stringByReplacingMatches(in: self, options: [], range: range, withTemplate: replaceWith)
        } catch { return }
    }
    mutating func formatConsolidate() {
        // Step 1: Consolidating formats per line.
        var arrData = self.components(separatedBy: "\n")
        var varLineData = ""
        var strProcessed = ""
        for lineData in arrData {
            varLineData = lineData
            varLineData.removingRegexMatches(pattern: "　", replaceWith: " ") // CJKWhiteSpace to ASCIISpace
            varLineData.removingRegexMatches(pattern: " ", replaceWith: " ") // NonBreakWhiteSpace to ASCIISpace
            varLineData.removingRegexMatches(pattern: "\\s+", replaceWith: " ") // Consolidating Consecutive Spaves
            varLineData.removingRegexMatches(pattern: "^\\s", replaceWith: "") // Trim Leading Space
            varLineData.removingRegexMatches(pattern: "\\s$", replaceWith: "") // Trim Trailing Space
            strProcessed += varLineData
            strProcessed += "\n"
        }
        
        // Step 2: Deduplication.
        arrData = strProcessed.components(separatedBy: "\n")
        strProcessed = "" // Reset its value
        let arrDataDeduplicated = Array(NSOrderedSet(array: arrData).array as! [String])
        for lineData in arrDataDeduplicated {
            strProcessed += lineData
            strProcessed += "\n"
        }
        
        // Step 3: Remove duplicated newlines at the end of the file.
        strProcessed.removingRegexMatches(pattern: "\\n\\n", replaceWith: "\n")
        self = strProcessed
    }
}
