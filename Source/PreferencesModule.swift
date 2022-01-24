/* 
 *  PreferencesModule.swift
 *  
 *  Copyright 2021-2022 vChewing Project (3-Clause BSD License).
 *  Derived from 2011-2022 OpenVanilla Project (MIT License).
 *  Some rights reserved. See "LICENSE.TXT" for details.
 */

import Cocoa

private let kKeyboardLayoutPreferenceKey = "KeyboardLayout"
private let kBasisKeyboardLayoutPreferenceKey = "BasisKeyboardLayout"  // alphanumeric ("ASCII") input basi
private let kFunctionKeyKeyboardLayoutPreferenceKey = "FunctionKeyKeyboardLayout"  // alphanumeric ("ASCII") input basi
private let kFunctionKeyKeyboardLayoutOverrideIncludeShiftKey = "FunctionKeyKeyboardLayoutOverrideIncludeShift" // whether include shif
private let kCandidateListTextSizeKey = "CandidateListTextSize"
private let kSelectPhraseAfterCursorAsCandidatePreferenceKey = "SelectPhraseAfterCursorAsCandidate"
private let kUseHorizontalCandidateListPreferenceKey = "UseHorizontalCandidateList"
private let kComposingBufferSizePreferenceKey = "ComposingBufferSize"
private let kChooseCandidateUsingSpaceKey = "ChooseCandidateUsingSpaceKey"
private let kCNS11643EnabledKey = "CNS11643Enabled"
private let kChineseConversionEnabledKey = "ChineseConversionEnabled"
private let kHalfWidthPunctuationEnabledKey = "HalfWidthPunctuationEnable"
private let kEscToCleanInputBufferKey = "EscToCleanInputBuffer"
private let kUseWinNT351BPMF = "UseWinNT351BPMF"
private let kMaxCandidateLength = "MaxCandidateLength"
private let kShouldNotFartInLieuOfBeep = "ShouldNotFartInLieuOfBeep"

private let kCandidateTextFontName = "CandidateTextFontName"
private let kCandidateKeyLabelFontName = "CandidateKeyLabelFontName"
private let kCandidateKeys = "CandidateKeys"
private let kChineseConversionEngineKey = "ChineseConversionEngine"
private let kPhraseReplacementEnabledKey = "PhraseReplacementEnabled"

private let kDefaultCandidateListTextSize: CGFloat = 18
private let kMinKeyLabelSize: CGFloat = 10
private let kMinCandidateListTextSize: CGFloat = 12
private let kMaxCandidateListTextSize: CGFloat = 196

// default, min and max composing buffer size (in codepoints)
// modern Macs can usually work up to 16 codepoints when the builder still
// walks the grid with good performance slower Macs (like old PowerBooks)
// will start to sputter beyond 12 such is the algorithmatic complexity
// of the Viterbi algorithm used in the builder library (at O(N^2))
private let kDefaultComposingBufferSize = 20
private let kMinComposingBufferSize = 4
private let kMaxComposingBufferSize = 30

private let kDefaultKeys = "123456789"

// MARK: Property wrappers
@propertyWrapper
struct UserDefault<Value> {
    let key: String
    let defaultValue: Value
    var container: UserDefaults = .standard

    var wrappedValue: Value {
        get {
            return container.object(forKey: key) as? Value ?? defaultValue
        }
        set {
            container.set(newValue, forKey: key)
        }
    }
}

@propertyWrapper
struct CandidateListTextSize {
    let key: String
    let defaultValue: CGFloat = kDefaultCandidateListTextSize
    lazy var container: UserDefault = {
        UserDefault(key: key, defaultValue: defaultValue) }()

    var wrappedValue: CGFloat {
        mutating get {
            var value = container.wrappedValue
            if value < kMinCandidateListTextSize {
                value = kMinCandidateListTextSize
            } else if value > kMaxCandidateListTextSize {
                value = kMaxCandidateListTextSize
            }
            return value
        }
        set {
            var value = newValue
            if value < kMinCandidateListTextSize {
                value = kMinCandidateListTextSize
            } else if value > kMaxCandidateListTextSize {
                value = kMaxCandidateListTextSize
            }
            container.wrappedValue = value
        }
    }
}

@propertyWrapper
struct ComposingBufferSize {
    let key: String
    let defaultValue: Int = kDefaultComposingBufferSize
    lazy var container: UserDefault = {
        UserDefault(key: key, defaultValue: defaultValue) }()

    var wrappedValue: Int {
        mutating get {
            let currentValue = container.wrappedValue
            if currentValue < kMinComposingBufferSize {
                return kMinComposingBufferSize
            } else if currentValue > kMaxComposingBufferSize {
                return kMaxComposingBufferSize
            }
            return currentValue
        }
        set {
            var value = newValue
            if value < kMinComposingBufferSize {
                value = kMinComposingBufferSize
            } else if value > kMaxComposingBufferSize {
                value = kMaxComposingBufferSize
            }
            container.wrappedValue = value
        }
    }
}

// MARK: -
@objc enum KeyboardLayout: Int {
    case standard = 0
    case eten = 1
    case hsu = 2
    case eten26 = 3
    case hanyuPinyin = 4
    case IBM = 5

    var name: String {
        switch (self) {
        case .standard:
            return "Standard"
        case .eten:
            return "ETen"
        case .hsu:
            return "Hsu"
        case .eten26:
            return "ETen26"
        case .hanyuPinyin:
            return "HanyuPinyin"
        case .IBM:
            return "IBM"
        }
    }
}

@objc enum ChineseConversionEngine: Int {
    case openCC
    case vxHanConvert

    var name: String {
        switch (self) {
        case .openCC:
            return "OpenCC"
        case .vxHanConvert:
            return "VXHanConvert"
        }
    }
}

// MARK: -
@objc public class Preferences: NSObject {
    static func reset() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: kKeyboardLayoutPreferenceKey)
        defaults.removeObject(forKey: kBasisKeyboardLayoutPreferenceKey)
        defaults.removeObject(forKey: kFunctionKeyKeyboardLayoutPreferenceKey)
        defaults.removeObject(forKey: kFunctionKeyKeyboardLayoutOverrideIncludeShiftKey)
        defaults.removeObject(forKey: kCandidateListTextSizeKey)
        defaults.removeObject(forKey: kSelectPhraseAfterCursorAsCandidatePreferenceKey)
        defaults.removeObject(forKey: kUseHorizontalCandidateListPreferenceKey)
        defaults.removeObject(forKey: kComposingBufferSizePreferenceKey)
        defaults.removeObject(forKey: kChooseCandidateUsingSpaceKey)
        defaults.removeObject(forKey: kCNS11643EnabledKey)
        defaults.removeObject(forKey: kChineseConversionEnabledKey)
        defaults.removeObject(forKey: kHalfWidthPunctuationEnabledKey)
        defaults.removeObject(forKey: kEscToCleanInputBufferKey)
        defaults.removeObject(forKey: kCandidateTextFontName)
        defaults.removeObject(forKey: kCandidateKeyLabelFontName)
        defaults.removeObject(forKey: kCandidateKeys)
        defaults.removeObject(forKey: kPhraseReplacementEnabledKey)
        defaults.removeObject(forKey: kChineseConversionEngineKey)
        defaults.removeObject(forKey: kUseWinNT351BPMF)
        defaults.removeObject(forKey: kMaxCandidateLength)
        defaults.removeObject(forKey: kShouldNotFartInLieuOfBeep)
    }

    @UserDefault(key: kKeyboardLayoutPreferenceKey, defaultValue: 0)
    @objc static var keyboardLayout: Int

    @objc static var keyboardLayoutName: String {
        (KeyboardLayout(rawValue: self.keyboardLayout) ?? KeyboardLayout.standard).name
    }

    @UserDefault(key: kBasisKeyboardLayoutPreferenceKey, defaultValue: "com.apple.keylayout.US")
    @objc static var basisKeyboardLayout: String

    @UserDefault(key: kFunctionKeyKeyboardLayoutPreferenceKey, defaultValue: "com.apple.keylayout.US")
    @objc static var functionKeyboardLayout: String

    @UserDefault(key: kFunctionKeyKeyboardLayoutOverrideIncludeShiftKey, defaultValue: false)
    @objc static var functionKeyKeyboardLayoutOverrideIncludeShiftKey: Bool

    @CandidateListTextSize(key: kCandidateListTextSizeKey)
    @objc static var candidateListTextSize: CGFloat

    @UserDefault(key: kSelectPhraseAfterCursorAsCandidatePreferenceKey, defaultValue: false)
    @objc static var selectPhraseAfterCursorAsCandidate: Bool

    @UserDefault(key: kUseHorizontalCandidateListPreferenceKey, defaultValue: true)
    @objc static var useHorizontalCandidateList: Bool

    @ComposingBufferSize(key: kComposingBufferSizePreferenceKey)
    @objc static var composingBufferSize: Int

    @UserDefault(key: kChooseCandidateUsingSpaceKey, defaultValue: true)
    @objc static var chooseCandidateUsingSpace: Bool
    
    @UserDefault(key: kUseWinNT351BPMF, defaultValue: false)
    @objc static var useWinNT351BPMF: Bool
    
    @objc static func toggleWinNT351BPMFEnabled() -> Bool {
        useWinNT351BPMF = !useWinNT351BPMF
        UserDefaults.standard.set(useWinNT351BPMF, forKey: kUseWinNT351BPMF)
        return useWinNT351BPMF
    }
    
    @UserDefault(key: kMaxCandidateLength, defaultValue: 10)
    @objc static var maxCandidateLength: Int
    
    @UserDefault(key: kShouldNotFartInLieuOfBeep, defaultValue: true)
    @objc static var shouldNotFartInLieuOfBeep: Bool
    
    @objc static func toggleShouldNotFartInLieuOfBeep() -> Bool {
        shouldNotFartInLieuOfBeep = !shouldNotFartInLieuOfBeep
        UserDefaults.standard.set(shouldNotFartInLieuOfBeep, forKey: kShouldNotFartInLieuOfBeep)
        return shouldNotFartInLieuOfBeep
    }

    @UserDefault(key: kCNS11643EnabledKey, defaultValue: false)
    @objc static var cns11643Enabled: Bool

    @objc static func toggleCNS11643Enabled() -> Bool {
        cns11643Enabled = !cns11643Enabled
        UserDefaults.standard.set(cns11643Enabled, forKey: kCNS11643EnabledKey)
        return cns11643Enabled
    }

    @UserDefault(key: kChineseConversionEnabledKey, defaultValue: false)
    @objc static var chineseConversionEnabled: Bool

    @objc static func toggleChineseConversionEnabled() -> Bool {
        chineseConversionEnabled = !chineseConversionEnabled
        UserDefaults.standard.set(chineseConversionEnabled, forKey: kChineseConversionEnabledKey)
        return chineseConversionEnabled
    }

    @UserDefault(key: kHalfWidthPunctuationEnabledKey, defaultValue: false)
    @objc static var halfWidthPunctuationEnabled: Bool

    @objc static func toggleHalfWidthPunctuationEnabled() -> Bool {
        halfWidthPunctuationEnabled = !halfWidthPunctuationEnabled
        return halfWidthPunctuationEnabled
    }

    @UserDefault(key: kEscToCleanInputBufferKey, defaultValue: true)
    @objc static var escToCleanInputBuffer: Bool

    // MARK: Optional settings
    @UserDefault(key: kCandidateTextFontName, defaultValue: nil)
    @objc static var candidateTextFontName: String?

    @UserDefault(key: kCandidateKeyLabelFontName, defaultValue: nil)
    @objc static var candidateKeyLabelFontName: String?

    @UserDefault(key: kCandidateKeys, defaultValue: kDefaultKeys)
    @objc static var candidateKeys: String

    @objc static var defaultCandidateKeys: String {
        kDefaultKeys
    }
    @objc static var suggestedCandidateKeys: [String] {
        [kDefaultKeys, "234567890", "QWERTYUIO", "QWERTASDF", "ASDFGHJKL", "ASDFZXCVB"]
    }

    @objc static func validate(candidateKeys: String) throws {
        let trimmed = candidateKeys.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            throw CandidateKeyError.empty
        }
        if !trimmed.canBeConverted(to: .ascii) {
            throw CandidateKeyError.invalidCharacters
        }
        if trimmed.contains(" ") {
            throw CandidateKeyError.containSpace
        }
        if trimmed.count < 4 {
            throw CandidateKeyError.tooShort
        }
        if trimmed.count > 15 {
            throw CandidateKeyError.tooLong
        }
        let set = Set(Array(trimmed))
        if set.count != trimmed.count {
            throw CandidateKeyError.duplicatedCharacters
        }
    }

    enum CandidateKeyError: Error, LocalizedError {
        case empty
        case invalidCharacters
        case containSpace
        case duplicatedCharacters
        case tooShort
        case tooLong

        var errorDescription: String? {
            switch self {
            case .empty:
                return NSLocalizedString("Candidates keys cannot be empty.", comment: "")
            case .invalidCharacters:
                return NSLocalizedString("Candidate keys can only contain ASCII characters like alphanumerals.", comment: "")
            case .containSpace:
                return NSLocalizedString("Candidate keys cannot contain space.", comment: "")
            case .duplicatedCharacters:
                return NSLocalizedString("There should not be duplicated keys.", comment: "")
            case .tooShort:
                return NSLocalizedString("Please specify at least 4 candidate keys.", comment: "")
            case .tooLong:
                return NSLocalizedString("Maximum 15 candidate keys allowed.", comment: "")
            }
        }

    }

    @UserDefault(key: kChineseConversionEngineKey, defaultValue: 0)
    @objc static var chineseConversionEngine: Int

    @objc static var chineseConversionEngineName: String? {
        return ChineseConversionEngine(rawValue: chineseConversionEngine)?.name
    }

    @UserDefault(key: kPhraseReplacementEnabledKey, defaultValue: false)
    @objc static var phraseReplacementEnabled: Bool

    @objc static func togglePhraseReplacementEnabled() -> Bool {
        phraseReplacementEnabled = !phraseReplacementEnabled
        UserDefaults.standard.set(phraseReplacementEnabled, forKey: kPhraseReplacementEnabledKey)
        return phraseReplacementEnabled
    }
}
