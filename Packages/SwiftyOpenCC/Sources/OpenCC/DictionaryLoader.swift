//
//  DictionaryLoader.swift
//  OpenCC
//
//  Created by ddddxxx on 2018/5/5.
//

import Foundation
import copencc

extension ChineseConverter {
  struct DictionaryLoader {
    private static let subdirectory = "Dictionary"
    private static let dictCache = WeakValueCache<String, ConversionDictionary>()

    private let bundle: Bundle

    init(bundle: Bundle) {
      self.bundle = bundle
    }

    func dict(_ name: ChineseConverter.DictionaryName) throws -> ConversionDictionary {
      guard
        let path = bundle.path(
          forResource: name.description, ofType: "ocd2",
          inDirectory: DictionaryLoader.subdirectory
        )
      else {
        throw ConversionError.fileNotFound
      }
      return try DictionaryLoader.dictCache.value(for: path) {
        try ConversionDictionary(path: path)
      }
    }
  }
}

extension ChineseConverter.DictionaryLoader {
  func segmentation(options: ChineseConverter.Options) throws -> ConversionDictionary {
    let dictName = options.segmentationDictName
    return try dict(dictName)
  }

  func conversionChain(options: ChineseConverter.Options) throws -> [ConversionDictionary] {
    try options.conversionChain.compactMap { names in
      switch names.count {
        case 0:
          return nil
        case 1:
          return try dict(names.first!)
        case _:
          let dicts = try names.map(dict)
          return ConversionDictionary(group: dicts)
      }
    }
  }
}
