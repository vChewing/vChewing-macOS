#!/usr/bin/env swift

// Copyright (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation

let strDataPath = "./"

func handleFiles(_ handler: @escaping ((url: URL, fileName: String)) -> ()) {
  let rawURLs = FileManager.default.enumerator(
    at: URL(fileURLWithPath: strDataPath),
    includingPropertiesForKeys: nil
  )?.compactMap { $0 as? URL }
  rawURLs?.forEach { url in
    let componentsLowercased: Set<String> = Set(url.pathComponents.map { $0.lowercased() })
    let bannedComponents: Set<String> = ["build", ".build"]
    guard componentsLowercased.isDisjoint(with: bannedComponents) else { return }
    guard let fileName = url.pathComponents.last,
          fileName.lowercased() == "localizable.strings" else { return }
    handler((url, fileName))
  }
}

handleFiles { url, fileName in
  guard let rawStr = try? String(contentsOf: url, encoding: .utf8) else { return }
  let locale = Locale(identifier: "zh@collation=stroke")
  do {
    try rawStr.components(separatedBy: .newlines).filter { !$0.isEmpty }.sorted {
      $0.compare($1, locale: locale) == .orderedAscending
    }.joined(separator: "\n").description.appending("\n")
      .write(to: url, atomically: false, encoding: .utf8)
  } catch {
    print("!! Error writing to \(fileName)")
  }
}
