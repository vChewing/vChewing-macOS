//
//  ConversionDictionary.swift
//  OpenCC
//
//  Created by ddddxxx on 2020/1/3.
//

import Foundation
import copencc

class ConversionDictionary {
    
    let group: [ConversionDictionary]
    
    let dict: CCDictRef
    
    init(path: String) throws {
        guard let dict = CCDictCreateMarisaWithPath(path) else {
            throw ConversionError(ccErrorno)
        }
        self.group = []
        self.dict = dict
    }
    
    init(group: [ConversionDictionary]) {
        var rawGroup = group.map { $0.dict }
        self.group = group
        self.dict = CCDictCreateWithGroup(&rawGroup, rawGroup.count)
    }
}
