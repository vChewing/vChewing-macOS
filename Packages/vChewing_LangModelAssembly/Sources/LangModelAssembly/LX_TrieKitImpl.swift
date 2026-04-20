// (c) 2025 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import TrieKit

extension VanguardTrie.Trie.EntryType {
  public static let cinCassette = Self(rawValue: 100 << 0) // 這一條不用記錄到先鋒語料庫內。
  public static let meta = Self(rawValue: 2 << 0)
  public static let revLookup = Self(rawValue: 3 << 0)
  public static let letterPunctuations = Self(rawValue: 4 << 0)
  public static let chs = Self(rawValue: 5 << 0) // 0x0804
  public static let cht = Self(rawValue: 6 << 0) // 0x0404
  public static let cns = Self(rawValue: 7 << 0)
  public static let nonKanji = Self(rawValue: 8 << 0)
  public static let symbolPhrases = Self(rawValue: 9 << 0)
  public static let zhuyinwen = Self(rawValue: 10 << 0)
}
