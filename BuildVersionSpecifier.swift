#!/usr/bin/env swift

// Copyright (c) 2021 and onwards The vChewing Project (MIT-NTL License).
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

extension String {
  fileprivate mutating func regReplace(pattern: String, replaceWith: String = "") {
    // Ref: https://stackoverflow.com/a/40993403/4162914 && https://stackoverflow.com/a/71291137/4162914
    do {
      let regex = try NSRegularExpression(
        pattern: pattern, options: [.caseInsensitive, .anchorsMatchLines]
      )
      let range = NSRange(startIndex..., in: self)
      self = regex.stringByReplacingMatches(
        in: self, options: [], range: range, withTemplate: replaceWith
      )
    } catch { return }
  }
}

var verMarket: String = "1.0.0"
var verBuild: String = "1000"
var strXcodeProjContent: String = ""
var dirXcodeProjectFile = "./vChewing.xcodeproj/project.pbxproj"
var dirPackageProjectFile = "./vChewing.pkgproj"
var dirUpdateInfoPlist = "./Update-Info.plist"
var theDictionary: NSDictionary?

if CommandLine.arguments.count == 3 {
  verMarket = CommandLine.arguments[1]
  verBuild = CommandLine.arguments[2]

  // Xcode project file version update.
  do {
    strXcodeProjContent += try String(contentsOfFile: dirXcodeProjectFile, encoding: .utf8)
  } catch {
    NSLog(" - Exception happened when reading raw phrases data.")
  }

  strXcodeProjContent.regReplace(
    pattern: #"CURRENT_PROJECT_VERSION = .*$"#, replaceWith: "CURRENT_PROJECT_VERSION = " + verBuild + ";"
  )
  strXcodeProjContent.regReplace(
    pattern: #"MARKETING_VERSION = .*$"#, replaceWith: "MARKETING_VERSION = " + verMarket + ";"
  )
  do {
    try strXcodeProjContent.write(to: URL(fileURLWithPath: dirXcodeProjectFile), atomically: false, encoding: .utf8)
  } catch {
    NSLog(" -: Error on writing strings to file: \(error)")
  }
  NSLog(" - Xcode 專案版本資訊更新完成：\(verMarket) \(verBuild)。")

  // Packages project file version update.
  theDictionary = NSDictionary(contentsOfFile: dirPackageProjectFile)
  theDictionary?.setValue(verMarket, forKeyPath: "PACKAGES.PACKAGE_SETTINGS.VERSION")
  theDictionary?.write(toFile: dirPackageProjectFile, atomically: true)
  NSLog(" - Packages 專案版本資訊更新完成：\(verMarket) \(verBuild)。")

  // Update notification project file version update.
  theDictionary = NSDictionary(contentsOfFile: dirUpdateInfoPlist)
  theDictionary?.setValue(verBuild, forKeyPath: "CFBundleVersion")
  theDictionary?.setValue(verMarket, forKeyPath: "CFBundleShortVersionString")
  theDictionary?.write(toFile: dirUpdateInfoPlist, atomically: true)
  NSLog(" - 更新用通知 plist 版本資訊更新完成：\(verMarket) \(verBuild)。")
}
