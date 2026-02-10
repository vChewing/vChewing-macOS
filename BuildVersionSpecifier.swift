#!/usr/bin/env swift

// Copyright (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

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
var dirUpdateInfoPlist4SPM = "./Release-Version.plist"
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
    pattern: #"CURRENT_PROJECT_VERSION = .*$"#,
    replaceWith: "CURRENT_PROJECT_VERSION = " + verBuild + ";"
  )
  strXcodeProjContent.regReplace(
    pattern: #"MARKETING_VERSION = .*$"#, replaceWith: "MARKETING_VERSION = " + verMarket + ";"
  )
  do {
    try strXcodeProjContent.write(
      to: URL(fileURLWithPath: dirXcodeProjectFile),
      atomically: false,
      encoding: .utf8
    )
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

  // Update SPM Compiled Bundles version update.
  theDictionary = NSDictionary(contentsOfFile: dirUpdateInfoPlist4SPM)
  theDictionary?.setValue(verBuild, forKeyPath: "CFBundleVersion")
  theDictionary?.setValue(verMarket, forKeyPath: "CFBundleShortVersionString")
  theDictionary?.write(toFile: dirUpdateInfoPlist4SPM, atomically: true)
  NSLog(" - SPM 專案版本資訊更新完成：\(verMarket) \(verBuild)。")
}
