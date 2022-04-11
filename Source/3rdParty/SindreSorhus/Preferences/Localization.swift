// Copyright (c) 2018 and onwards Sindre Sorhus (MIT License).
/*
Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

import Foundation

struct Localization {
	enum Identifier {
		case preferences
		case preferencesEllipsized
	}

	private static let localizedStrings: [Identifier: [String: String]] = [
		.preferences: [
			"ar": "تفضيلات",
			"ca": "Preferències",
			"cs": "Předvolby",
			"da": "Indstillinger",
			"de": "Einstellungen",
			"el": "Προτιμήσεις",
			"en": "Preferences",
			"en-AU": "Preferences",
			"en-GB": "Preferences",
			"es": "Preferencias",
			"es-419": "Preferencias",
			"fi": "Asetukset",
			"fr": "Préférences",
			"fr-CA": "Préférences",
			"he": "העדפות",
			"hi": "प्राथमिकता",
			"hr": "Postavke",
			"hu": "Beállítások",
			"id": "Preferensi",
			"it": "Preferenze",
			"ja": "環境設定",
			"ko": "환경설정",
			"ms": "Keutamaan",
			"nl": "Voorkeuren",
			"no": "Valg",
			"pl": "Preferencje",
			"pt": "Preferências",
			"pt-PT": "Preferências",
			"ro": "Preferințe",
			"ru": "Настройки",
			"sk": "Nastavenia",
			"sv": "Inställningar",
			"th": "การตั้งค่า",
			"tr": "Tercihler",
			"uk": "Параметри",
			"vi": "Tùy chọn",
			"zh-CN": "偏好设置",
			"zh-HK": "偏好設定",
			"zh-TW": "偏好設定",
		],
		.preferencesEllipsized: [
			"ar": "تفضيلات…",
			"ca": "Preferències…",
			"cs": "Předvolby…",
			"da": "Indstillinger…",
			"de": "Einstellungen…",
			"el": "Προτιμήσεις…",
			"en": "Preferences…",
			"en-AU": "Preferences…",
			"en-GB": "Preferences…",
			"es": "Preferencias…",
			"es-419": "Preferencias…",
			"fi": "Asetukset…",
			"fr": "Préférences…",
			"fr-CA": "Préférences…",
			"he": "העדפות…",
			"hi": "प्राथमिकता…",
			"hr": "Postavke…",
			"hu": "Beállítások…",
			"id": "Preferensi…",
			"it": "Preferenze…",
			"ja": "環境設定…",
			"ko": "환경설정...",
			"ms": "Keutamaan…",
			"nl": "Voorkeuren…",
			"no": "Valg…",
			"pl": "Preferencje…",
			"pt": "Preferências…",
			"pt-PT": "Preferências…",
			"ro": "Preferințe…",
			"ru": "Настройки…",
			"sk": "Nastavenia…",
			"sv": "Inställningar…",
			"th": "การตั้งค่า…",
			"tr": "Tercihler…",
			"uk": "Параметри…",
			"vi": "Tùy chọn…",
			"zh-CN": "偏好设置…",
			"zh-HK": "偏好設定⋯",
			"zh-TW": "偏好設定⋯",
		],
	]

	/**
	Returns the localized version of the given string.

	- Parameter identifier: Identifier of the string to localize.

	- Note: If the system's locale can't be determined, the English localization of the string will be returned.
	*/
	static subscript(identifier: Identifier) -> String {
		// Force-unwrapped since all of the involved code is under our control.
		let localizedDict = Localization.localizedStrings[identifier]!
		let defaultLocalizedString = localizedDict["en"]!

		// Iterate through all user-preferred languages until we find one that has a valid language code.
		let preferredLocale =
			Locale.preferredLanguages
			.lazy
			.map { Locale(identifier: $0) }
			.first { $0.languageCode != nil }
			?? .current

		guard let languageCode = preferredLocale.languageCode else {
			return defaultLocalizedString
		}

		// Chinese is the only language where different region codes result in different translations.
		if languageCode == "zh" {
			let regionCode = preferredLocale.regionCode ?? ""
			if regionCode == "HK" || regionCode == "TW" {
				return localizedDict["\(languageCode)-\(regionCode)"]!
			} else {
				// Fall back to "regular" zh-CN if neither the HK or TW region codes are found.
				return localizedDict["\(languageCode)-CN"]!
			}
		} else {
			if let localizedString = localizedDict[languageCode] {
				return localizedString
			}
		}

		return defaultLocalizedString
	}
}
