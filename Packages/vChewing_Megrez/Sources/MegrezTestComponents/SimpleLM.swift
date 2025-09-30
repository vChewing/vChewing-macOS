// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Megrez

// MARK: - SimpleLM

extension MegrezTestComponents {
  public class SimpleLM: LangModelProtocol {
    // MARK: Lifecycle

    public init(input: String, swapKeyValue: Bool = false, separator: String = "-") {
      self.separator = separator
      reinit(input: input, swapKeyValue: swapKeyValue, separator: separator)
    }

    // MARK: Public

    public var mutDatabase: [String: [Megrez.Unigram]] = [:]
    public var separator: String = ""

    public func unigramsFor(keyArray: [String]) -> [Megrez.Unigram] {
      if let f = mutDatabase[keyArray.joined(separator: separator)] {
        return f
      } else {
        return [Megrez.Unigram]().sorted { $0.score > $1.score }
      }
    }

    public func hasUnigramsFor(keyArray: [String]) -> Bool {
      mutDatabase.keys.contains(keyArray.joined(separator: separator))
    }

    public func trim(key: String, value: String) {
      guard var arr = mutDatabase[key] else { return }
      arr = arr.compactMap { $0.value == value ? nil : $0 }
      guard !arr.isEmpty else {
        mutDatabase[key] = nil
        return
      }
      mutDatabase[key] = arr
    }

    public func reinit(input: String, swapKeyValue: Bool = false, separator: String? = nil) {
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
        let key = swapKeyValue ? col1 : col0
        let value = swapKeyValue ? col0 : col1
        let keyArray = separatorComponents(from: key)
        let u = Megrez.Unigram(keyArray: keyArray, value: value, score: col2)
        mutDatabase[key, default: []].append(u)
      }
    }

    // MARK: Private

    private func separatorComponents(from key: String) -> [String] {
      if separator.isEmpty {
        return key.map(\.description)
      }
      return key
        .components(separatedBy: separator)
        .filter { !$0.isEmpty }
    }
  }

  // MARK: - MockLM

  public class MockLM: LangModelProtocol {
    // MARK: Lifecycle

    public init() {}

    // MARK: Public

    public func unigramsFor(keyArray: [String]) -> [Megrez.Unigram] {
      [Megrez.Unigram(keyArray: keyArray, value: keyArray.joined(), score: -1)]
    }

    public func hasUnigramsFor(keyArray: [String]) -> Bool {
      !keyArray.isEmpty
    }
  }
}
