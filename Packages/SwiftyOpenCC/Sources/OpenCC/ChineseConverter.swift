//
//  ChineseConverter.swift
//  OpenCC
//
//  Created by ddddxxx on 2017/3/9.
//

import Foundation
import copencc

/// The `ChineseConverter` class is used to represent and apply conversion
/// between Traditional Chinese and Simplified Chinese to Unicode strings.
/// An instance of this class is an immutable representation of a compiled
/// conversion pattern.
///
/// The `ChineseConverter` supporting character-level conversion, phrase-level
/// conversion, variant conversion and regional idioms among Mainland China,
/// Taiwan and HongKong
///
/// `ChineseConverter` is designed to be immutable and threadsafe, so that
/// a single instance can be used in conversion on multiple threads at once.
/// However, the string on which it is operating should not be mutated
/// during the course of a conversion.
public class ChineseConverter {
    
    /// These constants define the ChineseConverter options.
    public struct Options: OptionSet {
        
        public let rawValue: Int
        
        public init(rawValue: Int) {
            self.rawValue = rawValue
        }
        
        /// Convert to Traditional Chinese. (default)
        public static let traditionalize = Options(rawValue: 1 << 0)
        
        /// Convert to Simplified Chinese.
        public static let simplify = Options(rawValue: 1 << 1)
        
        /// Use Taiwan standard.
        public static let twStandard = Options(rawValue: 1 << 5)
        
        /// Use HongKong standard.
        public static let hkStandard = Options(rawValue: 1 << 6)
        
        /// Cancel Taiwan standard.
        public static let twStandardRev = Options(rawValue: 1 << 15)
        
        /// Cancel HongKong standard.
        public static let hkStandardRev = Options(rawValue: 1 << 16)

        /// Taiwanese idiom conversion.
        public static let twIdiom = Options(rawValue: 1 << 10)
    }
    
    private let seg: ConversionDictionary
    private let chain: [ConversionDictionary]
    
    private let converter: CCConverterRef
    
    private init(loader: DictionaryLoader, options: Options) throws {
        seg = try loader.segmentation(options: options)
        chain = try loader.conversionChain(options: options)
        var rawChain = chain.map { $0.dict }
        converter = CCConverterCreate("SwiftyOpenCC", seg.dict, &rawChain, rawChain.count)
    }
    
    /// Returns an initialized `ChineseConverter` instance with the specified
    /// conversion options.
    ///
    /// - Parameter options: The convert’s options.
    /// - Throws: Throws `ConversionError` if failed.
    public convenience init(options: Options) throws {
        let loader = DictionaryLoader(bundle: .module)
        try self.init(loader: loader, options: options)
    }
    
    /// Return a converted string using the convert’s current option.
    ///
    /// - Parameter text: The string to convert.
    /// - Returns: A converted string using the convert’s current option.
    public func convert(_ text: String) -> String {
        let stlStr = CCConverterCreateConvertedStringFromString(converter, text)!
        defer { STLStringDestroy(stlStr) }
        return String(utf8String: STLStringGetUTF8String(stlStr))!
    }
    
}
