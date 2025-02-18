// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Megrez

// MARK: - SimpleLM

class SimpleLM: LangModelProtocol {
  // MARK: Lifecycle

  init(input: String, swapKeyValue: Bool = false, separator: String = "-") {
    self.separator = separator
    reinit(input: input, swapKeyValue: swapKeyValue, separator: separator)
  }

  // MARK: Internal

  var mutDatabase: [String: [Megrez.Unigram]] = [:]
  var separator: String = ""

  func unigramsFor(keyArray: [String]) -> [Megrez.Unigram] {
    if let f = mutDatabase[keyArray.joined(separator: separator)] {
      return f
    } else {
      return [Megrez.Unigram]().sorted { $0.score > $1.score }
    }
  }

  func hasUnigramsFor(keyArray: [String]) -> Bool {
    mutDatabase.keys.contains(keyArray.joined(separator: separator))
  }

  func trim(key: String, value: String) {
    guard var arr = mutDatabase[key] else { return }
    arr = arr.compactMap { $0.value == value ? nil : $0 }
    guard !arr.isEmpty else {
      mutDatabase[key] = nil
      return
    }
    mutDatabase[key] = arr
  }

  func reinit(input: String, swapKeyValue: Bool = false, separator: String? = nil) {
    self.separator = separator ?? self.separator
    mutDatabase.removeAll()
    let sstream = input.components(separatedBy: "\n")
    sstream.forEach { line in
      if line.isEmpty || line.hasPrefix("#") {
        return
      }
      let linestream = line.split(separator: " ")
      guard linestream.count == 3 else { return } // Megrez 不支援 Bigram。
      let col0 = String(linestream[0])
      let col1 = String(linestream[1])
      let col2 = Double(linestream[2]) ?? 0.0
      let u = Megrez.Unigram(value: swapKeyValue ? col0 : col1, score: col2)
      mutDatabase[swapKeyValue ? col1 : col0, default: []].append(u)
    }
  }
}

// MARK: - MockLM

class MockLM: LangModelProtocol {
  func unigramsFor(keyArray: [String]) -> [Megrez.Unigram] {
    [Megrez.Unigram(value: keyArray.joined(), score: -1)]
  }

  func hasUnigramsFor(keyArray: [String]) -> Bool {
    !keyArray.isEmpty
  }
}
