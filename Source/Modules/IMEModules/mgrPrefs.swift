// Copyright (c) 2011 and onwards The OpenVanilla Project (MIT License).
// All possible vChewing-specific modifications are of:
// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
/*
Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

1. The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

2. No trademark license is granted to use the trade names, trademarks, service
marks, or product names of Contributor, except as required to fulfill notice
requirements above.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

import Cocoa

struct UserDef {
	static let kIsDebugModeEnabled = "_DebugMode"
	static let kUserDataFolderSpecified = "UserDataFolderSpecified"
	static let kCheckUpdateAutomatically = "CheckUpdateAutomatically"
	static let kKeyboardLayout = "KeyboardLayout"
	static let kBasisKeyboardLayout = "BasisKeyboardLayout"
	static let kShowPageButtonsInCandidateWindow = "ShowPageButtonsInCandidateWindow"
	static let kCandidateListTextSize = "CandidateListTextSize"
	static let kAppleLanguages = "AppleLanguages"
	static let kShouldAutoReloadUserDataFiles = "ShouldAutoReloadUserDataFiles"
	static let kSelectPhraseAfterCursorAsCandidate = "SelectPhraseAfterCursorAsCandidate"
	static let kUseHorizontalCandidateList = "UseHorizontalCandidateList"
	static let kComposingBufferSize = "ComposingBufferSize"
	static let kChooseCandidateUsingSpace = "ChooseCandidateUsingSpace"
	static let kCNS11643Enabled = "CNS11643Enabled"
	static let kSymbolInputEnabled = "SymbolInputEnabled"
	static let kChineseConversionEnabled = "ChineseConversionEnabled"
	static let kShiftJISShinjitaiOutputEnabled = "ShiftJISShinjitaiOutputEnabled"
	static let kHalfWidthPunctuationEnabled = "HalfWidthPunctuationEnable"
	static let kMoveCursorAfterSelectingCandidate = "MoveCursorAfterSelectingCandidate"
	static let kEscToCleanInputBuffer = "EscToCleanInputBuffer"
	static let kSpecifyShiftTabKeyBehavior = "SpecifyShiftTabKeyBehavior"
	static let kSpecifyShiftSpaceKeyBehavior = "SpecifyShiftSpaceKeyBehavior"
	static let kUseSCPCTypingMode = "UseSCPCTypingMode"
	static let kMaxCandidateLength = "MaxCandidateLength"
	static let kShouldNotFartInLieuOfBeep = "ShouldNotFartInLieuOfBeep"

	static let kCandidateTextFontName = "CandidateTextFontName"
	static let kCandidateKeyLabelFontName = "CandidateKeyLabelFontName"
	static let kCandidateKeys = "CandidateKeys"

	static let kAssociatedPhrasesEnabled = "AssociatedPhrasesEnabled"
	static let kPhraseReplacementEnabled = "PhraseReplacementEnabled"
}

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
			container.object(forKey: key) as? Value ?? defaultValue
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
		UserDefault(key: key, defaultValue: defaultValue)
	}()

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
		UserDefault(key: key, defaultValue: defaultValue)
	}()

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
	case ofStandard = 0
	case ofEten = 1
	case ofHsu = 2
	case ofEen26 = 3
	case ofIBM = 4
	case ofMiTAC = 5
	case ofFakeSeigyou = 6
	case ofHanyuPinyin = 10

	var name: String {
		switch self {
			case .ofStandard:
				return "Standard"
			case .ofEten:
				return "ETen"
			case .ofHsu:
				return "Hsu"
			case .ofEen26:
				return "ETen26"
			case .ofIBM:
				return "IBM"
			case .ofMiTAC:
				return "MiTAC"
			case .ofFakeSeigyou:
				return "FakeSeigyou"
			case .ofHanyuPinyin:
				return "HanyuPinyin"
		}
	}
}

// MARK: -
@objc public class mgrPrefs: NSObject {
	static var allKeys: [String] {
		[
			UserDef.kIsDebugModeEnabled,
			UserDef.kUserDataFolderSpecified,
			UserDef.kKeyboardLayout,
			UserDef.kBasisKeyboardLayout,
			UserDef.kShowPageButtonsInCandidateWindow,
			UserDef.kCandidateListTextSize,
			UserDef.kAppleLanguages,
			UserDef.kShouldAutoReloadUserDataFiles,
			UserDef.kSelectPhraseAfterCursorAsCandidate,
			UserDef.kUseHorizontalCandidateList,
			UserDef.kComposingBufferSize,
			UserDef.kChooseCandidateUsingSpace,
			UserDef.kCNS11643Enabled,
			UserDef.kSymbolInputEnabled,
			UserDef.kChineseConversionEnabled,
			UserDef.kShiftJISShinjitaiOutputEnabled,
			UserDef.kHalfWidthPunctuationEnabled,
			UserDef.kSpecifyShiftTabKeyBehavior,
			UserDef.kSpecifyShiftSpaceKeyBehavior,
			UserDef.kEscToCleanInputBuffer,
			UserDef.kCandidateTextFontName,
			UserDef.kCandidateKeyLabelFontName,
			UserDef.kCandidateKeys,
			UserDef.kMoveCursorAfterSelectingCandidate,
			UserDef.kPhraseReplacementEnabled,
			UserDef.kUseSCPCTypingMode,
			UserDef.kMaxCandidateLength,
			UserDef.kShouldNotFartInLieuOfBeep,
			UserDef.kAssociatedPhrasesEnabled,
		]
	}

	@objc public static func setMissingDefaults() {
		// 既然 Preferences Module 的預設屬性不自動寫入 plist、而且還是 private，那這邊就先寫入了。

		// 首次啟用輸入法時不要啟用偵錯模式。
		if UserDefaults.standard.object(forKey: UserDef.kIsDebugModeEnabled) == nil {
			UserDefaults.standard.set(mgrPrefs.isDebugModeEnabled, forKey: UserDef.kIsDebugModeEnabled)
		}

		// 首次啟用輸入法時設定不要自動更新，免得在某些要隔絕外部網路連線的保密機構內觸犯資安規則。
		if UserDefaults.standard.object(forKey: UserDef.kCheckUpdateAutomatically) == nil {
			UserDefaults.standard.set(false, forKey: UserDef.kCheckUpdateAutomatically)
		}

		// 預設顯示選字窗翻頁按鈕
		if UserDefaults.standard.object(forKey: UserDef.kShowPageButtonsInCandidateWindow) == nil {
			UserDefaults.standard.set(
				mgrPrefs.showPageButtonsInCandidateWindow, forKey: UserDef.kShowPageButtonsInCandidateWindow
			)
		}

		// 預設啟用繪文字與符號輸入
		if UserDefaults.standard.object(forKey: UserDef.kSymbolInputEnabled) == nil {
			UserDefaults.standard.set(mgrPrefs.symbolInputEnabled, forKey: UserDef.kSymbolInputEnabled)
		}

		// 預設選字窗字詞文字尺寸，設成 18 剛剛好
		if UserDefaults.standard.object(forKey: UserDef.kCandidateListTextSize) == nil {
			UserDefaults.standard.set(
				mgrPrefs.candidateListTextSize, forKey: UserDef.kCandidateListTextSize)
		}

		// 預設摁空格鍵來選字，所以設成 true
		if UserDefaults.standard.object(forKey: UserDef.kChooseCandidateUsingSpace) == nil {
			UserDefaults.standard.set(
				mgrPrefs.chooseCandidateUsingSpace, forKey: UserDef.kChooseCandidateUsingSpace)
		}

		// 自動檢測使用者自訂語彙數據的變動並載入。
		if UserDefaults.standard.object(forKey: UserDef.kShouldAutoReloadUserDataFiles) == nil {
			UserDefaults.standard.set(
				mgrPrefs.shouldAutoReloadUserDataFiles, forKey: UserDef.kShouldAutoReloadUserDataFiles)
		}

		// 預設情況下讓 Tab 鍵在選字窗內切換候選字、而不是用來換頁。
		if UserDefaults.standard.object(forKey: UserDef.kSpecifyShiftTabKeyBehavior) == nil {
			UserDefaults.standard.set(
				mgrPrefs.specifyShiftTabKeyBehavior, forKey: UserDef.kSpecifyShiftTabKeyBehavior)
		}

		// 預設情況下讓 Space 鍵在選字窗內切換候選字、而不是用來換頁。
		if UserDefaults.standard.object(forKey: UserDef.kSpecifyShiftSpaceKeyBehavior) == nil {
			UserDefaults.standard.set(
				mgrPrefs.specifyShiftSpaceKeyBehavior, forKey: UserDef.kSpecifyShiftSpaceKeyBehavior)
		}

		// 預設禁用逐字選字模式（就是每個字都要選的那種），所以設成 false
		if UserDefaults.standard.object(forKey: UserDef.kUseSCPCTypingMode) == nil {
			UserDefaults.standard.set(mgrPrefs.useSCPCTypingMode, forKey: UserDef.kUseSCPCTypingMode)
		}

		// 預設禁用逐字選字模式時的聯想詞功能，所以設成 false
		if UserDefaults.standard.object(forKey: UserDef.kAssociatedPhrasesEnabled) == nil {
			UserDefaults.standard.set(
				mgrPrefs.associatedPhrasesEnabled, forKey: UserDef.kAssociatedPhrasesEnabled)
		}

		// 預設漢音風格選字，所以要設成 0
		if UserDefaults.standard.object(forKey: UserDef.kSelectPhraseAfterCursorAsCandidate)
			== nil
		{
			UserDefaults.standard.set(
				mgrPrefs.selectPhraseAfterCursorAsCandidate,
				forKey: UserDef.kSelectPhraseAfterCursorAsCandidate)
		}

		// 預設在選字後自動移動游標
		if UserDefaults.standard.object(forKey: UserDef.kMoveCursorAfterSelectingCandidate) == nil {
			UserDefaults.standard.set(
				mgrPrefs.moveCursorAfterSelectingCandidate,
				forKey: UserDef.kMoveCursorAfterSelectingCandidate)
		}

		// 預設橫向選字窗，不爽請自行改成縱向選字窗
		if UserDefaults.standard.object(forKey: UserDef.kUseHorizontalCandidateList) == nil {
			UserDefaults.standard.set(
				mgrPrefs.useHorizontalCandidateList, forKey: UserDef.kUseHorizontalCandidateList)
		}

		// 預設停用全字庫支援
		if UserDefaults.standard.object(forKey: UserDef.kCNS11643Enabled) == nil {
			UserDefaults.standard.set(mgrPrefs.cns11643Enabled, forKey: UserDef.kCNS11643Enabled)
		}

		// 預設停用繁體轉康熙模組
		if UserDefaults.standard.object(forKey: UserDef.kChineseConversionEnabled) == nil {
			UserDefaults.standard.set(
				mgrPrefs.chineseConversionEnabled, forKey: UserDef.kChineseConversionEnabled)
		}

		// 預設停用繁體轉 JIS 當用新字體模組
		if UserDefaults.standard.object(forKey: UserDef.kShiftJISShinjitaiOutputEnabled) == nil {
			UserDefaults.standard.set(
				mgrPrefs.shiftJISShinjitaiOutputEnabled, forKey: UserDef.kShiftJISShinjitaiOutputEnabled)
		}

		// 預設停用自訂語彙置換
		if UserDefaults.standard.object(forKey: UserDef.kPhraseReplacementEnabled) == nil {
			UserDefaults.standard.set(
				mgrPrefs.phraseReplacementEnabled, forKey: UserDef.kPhraseReplacementEnabled)
		}

		// 預設沒事不要在那裡放屁
		if UserDefaults.standard.object(forKey: UserDef.kShouldNotFartInLieuOfBeep) == nil {
			UserDefaults.standard.set(
				mgrPrefs.shouldNotFartInLieuOfBeep, forKey: UserDef.kShouldNotFartInLieuOfBeep)
		}

		UserDefaults.standard.synchronize()
	}

	@UserDefault(key: UserDef.kIsDebugModeEnabled, defaultValue: false)
	@objc static var isDebugModeEnabled: Bool

	@UserDefault(key: UserDef.kCheckUpdateAutomatically, defaultValue: false)
	@objc static var checkUpdateAutomatically: Bool

	@UserDefault(key: UserDef.kUserDataFolderSpecified, defaultValue: "")
	@objc static var userDataFolderSpecified: String

	@objc static func ifSpecifiedUserDataPathExistsInPlist() -> Bool {
		UserDefaults.standard.object(forKey: UserDef.kUserDataFolderSpecified) != nil
	}

	@UserDefault(key: UserDef.kAppleLanguages, defaultValue: [])
	@objc static var appleLanguages: [String]

	@UserDefault(key: UserDef.kKeyboardLayout, defaultValue: 0)
	@objc static var keyboardLayout: Int

	@objc static var keyboardLayoutName: String {
		(KeyboardLayout(rawValue: self.keyboardLayout) ?? KeyboardLayout.ofStandard).name
	}

	@UserDefault(
		key: UserDef.kBasisKeyboardLayout, defaultValue: "com.apple.keylayout.ZhuyinBopomofo")
	@objc static var basisKeyboardLayout: String

	@UserDefault(key: UserDef.kShowPageButtonsInCandidateWindow, defaultValue: true)
	@objc static var showPageButtonsInCandidateWindow: Bool

	@CandidateListTextSize(key: UserDef.kCandidateListTextSize)
	@objc static var candidateListTextSize: CGFloat

	@UserDefault(key: UserDef.kShouldAutoReloadUserDataFiles, defaultValue: true)
	@objc static var shouldAutoReloadUserDataFiles: Bool

	@UserDefault(key: UserDef.kSelectPhraseAfterCursorAsCandidate, defaultValue: false)
	@objc static var selectPhraseAfterCursorAsCandidate: Bool

	@UserDefault(key: UserDef.kMoveCursorAfterSelectingCandidate, defaultValue: true)
	@objc static var moveCursorAfterSelectingCandidate: Bool

	@UserDefault(key: UserDef.kUseHorizontalCandidateList, defaultValue: true)
	@objc static var useHorizontalCandidateList: Bool

	@ComposingBufferSize(key: UserDef.kComposingBufferSize)
	@objc static var composingBufferSize: Int

	@UserDefault(key: UserDef.kChooseCandidateUsingSpace, defaultValue: true)
	@objc static var chooseCandidateUsingSpace: Bool

	@UserDefault(key: UserDef.kUseSCPCTypingMode, defaultValue: false)
	@objc static var useSCPCTypingMode: Bool

	@objc static func toggleSCPCTypingModeEnabled() -> Bool {
		useSCPCTypingMode = !useSCPCTypingMode
		UserDefaults.standard.set(useSCPCTypingMode, forKey: UserDef.kUseSCPCTypingMode)
		return useSCPCTypingMode
	}

	@UserDefault(key: UserDef.kMaxCandidateLength, defaultValue: kDefaultComposingBufferSize * 2)
	@objc static var maxCandidateLength: Int

	@UserDefault(key: UserDef.kShouldNotFartInLieuOfBeep, defaultValue: true)
	@objc static var shouldNotFartInLieuOfBeep: Bool

	@objc static func toggleShouldNotFartInLieuOfBeep() -> Bool {
		shouldNotFartInLieuOfBeep = !shouldNotFartInLieuOfBeep
		UserDefaults.standard.set(shouldNotFartInLieuOfBeep, forKey: UserDef.kShouldNotFartInLieuOfBeep)
		return shouldNotFartInLieuOfBeep
	}

	@UserDefault(key: UserDef.kCNS11643Enabled, defaultValue: false)
	@objc static var cns11643Enabled: Bool

	@objc static func toggleCNS11643Enabled() -> Bool {
		cns11643Enabled = !cns11643Enabled
		mgrLangModel.setCNSEnabled(cns11643Enabled)  // 很重要
		UserDefaults.standard.set(cns11643Enabled, forKey: UserDef.kCNS11643Enabled)
		return cns11643Enabled
	}

	@UserDefault(key: UserDef.kSymbolInputEnabled, defaultValue: true)
	@objc static var symbolInputEnabled: Bool

	@objc static func toggleSymbolInputEnabled() -> Bool {
		symbolInputEnabled = !symbolInputEnabled
		mgrLangModel.setSymbolEnabled(symbolInputEnabled)  // 很重要
		UserDefaults.standard.set(symbolInputEnabled, forKey: UserDef.kSymbolInputEnabled)
		return symbolInputEnabled
	}

	@UserDefault(key: UserDef.kChineseConversionEnabled, defaultValue: false)
	@objc static var chineseConversionEnabled: Bool

	@objc @discardableResult static func toggleChineseConversionEnabled() -> Bool {
		chineseConversionEnabled = !chineseConversionEnabled
		// 康熙轉換與 JIS 轉換不能同時開啟，否則會出現某些奇奇怪怪的情況
		if chineseConversionEnabled && shiftJISShinjitaiOutputEnabled {
			self.toggleShiftJISShinjitaiOutputEnabled()
			UserDefaults.standard.set(
				shiftJISShinjitaiOutputEnabled, forKey: UserDef.kShiftJISShinjitaiOutputEnabled)
		}
		UserDefaults.standard.set(chineseConversionEnabled, forKey: UserDef.kChineseConversionEnabled)
		return chineseConversionEnabled
	}

	@UserDefault(key: UserDef.kShiftJISShinjitaiOutputEnabled, defaultValue: false)
	@objc static var shiftJISShinjitaiOutputEnabled: Bool

	@objc @discardableResult static func toggleShiftJISShinjitaiOutputEnabled() -> Bool {
		shiftJISShinjitaiOutputEnabled = !shiftJISShinjitaiOutputEnabled
		// 康熙轉換與 JIS 轉換不能同時開啟，否則會出現某些奇奇怪怪的情況
		if shiftJISShinjitaiOutputEnabled && chineseConversionEnabled {
			self.toggleChineseConversionEnabled()
		}
		UserDefaults.standard.set(
			shiftJISShinjitaiOutputEnabled, forKey: UserDef.kShiftJISShinjitaiOutputEnabled)
		return shiftJISShinjitaiOutputEnabled
	}

	@UserDefault(key: UserDef.kHalfWidthPunctuationEnabled, defaultValue: false)
	@objc static var halfWidthPunctuationEnabled: Bool

	@objc static func toggleHalfWidthPunctuationEnabled() -> Bool {
		halfWidthPunctuationEnabled = !halfWidthPunctuationEnabled
		return halfWidthPunctuationEnabled
	}

	@UserDefault(key: UserDef.kEscToCleanInputBuffer, defaultValue: true)
	@objc static var escToCleanInputBuffer: Bool

	@UserDefault(key: UserDef.kSpecifyShiftTabKeyBehavior, defaultValue: false)
	@objc static var specifyShiftTabKeyBehavior: Bool

	@UserDefault(key: UserDef.kSpecifyShiftSpaceKeyBehavior, defaultValue: false)
	@objc static var specifyShiftSpaceKeyBehavior: Bool

	// MARK: - Optional settings
	@UserDefault(key: UserDef.kCandidateTextFontName, defaultValue: nil)
	@objc static var candidateTextFontName: String?

	@UserDefault(key: UserDef.kCandidateKeyLabelFontName, defaultValue: nil)
	@objc static var candidateKeyLabelFontName: String?

	@UserDefault(key: UserDef.kCandidateKeys, defaultValue: kDefaultKeys)
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
					return NSLocalizedString(
						"Candidate keys can only contain ASCII characters like alphanumericals.",
						comment: "")
				case .containSpace:
					return NSLocalizedString("Candidate keys cannot contain space.", comment: "")
				case .duplicatedCharacters:
					return NSLocalizedString("There should not be duplicated keys.", comment: "")
				case .tooShort:
					return NSLocalizedString(
						"Please specify at least 4 candidate keys.", comment: "")
				case .tooLong:
					return NSLocalizedString("Maximum 15 candidate keys allowed.", comment: "")
			}
		}

	}

	@UserDefault(key: UserDef.kPhraseReplacementEnabled, defaultValue: false)
	@objc static var phraseReplacementEnabled: Bool

	@objc static func togglePhraseReplacementEnabled() -> Bool {
		phraseReplacementEnabled = !phraseReplacementEnabled
		mgrLangModel.setPhraseReplacementEnabled(phraseReplacementEnabled)
		UserDefaults.standard.set(phraseReplacementEnabled, forKey: UserDef.kPhraseReplacementEnabled)
		return phraseReplacementEnabled
	}

	@UserDefault(key: UserDef.kAssociatedPhrasesEnabled, defaultValue: false)
	@objc static var associatedPhrasesEnabled: Bool

	@objc static func toggleAssociatedPhrasesEnabled() -> Bool {
		associatedPhrasesEnabled = !associatedPhrasesEnabled
		UserDefaults.standard.set(associatedPhrasesEnabled, forKey: UserDef.kAssociatedPhrasesEnabled)
		return associatedPhrasesEnabled
	}

}
