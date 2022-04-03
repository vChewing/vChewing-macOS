//
//  ConversionError.swift
//  OpenCC
//
//  Created by ddddxxx on 2020/1/3.
//

import Foundation
import copencc

public enum ConversionError: Error {

	case fileNotFound

	case invalidFormat

	case invalidTextDictionary

	case invalidUTF8

	case unknown

	init(_ code: CCErrorCode) {
		switch code {
			case .fileNotFound:
				self = .fileNotFound
			case .invalidFormat:
				self = .invalidFormat
			case .invalidTextDictionary:
				self = .invalidTextDictionary
			case .invalidUTF8:
				self = .invalidUTF8
			case .unknown, _:
				self = .unknown
		}
	}
}
