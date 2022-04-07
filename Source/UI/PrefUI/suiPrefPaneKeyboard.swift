// Copyright (c) 2021 and onwards The vChewing Project (MIT-NTL License).
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

import SwiftUI

@available(macOS 11.0, *)
struct suiPrefPaneKeyboard: View {
	@State private var selMandarinParser = UserDefaults.standard.integer(forKey: UserDef.kMandarinParser)
	@State private var selBasicKeyboardLayout: String =
		UserDefaults.standard.string(forKey: UserDef.kBasicKeyboardLayout) ?? mgrPrefs.basicKeyboardLayout
	private let contentWidth: Double = 560.0

	var body: some View {
		Preferences.Container(contentWidth: contentWidth) {
			Preferences.Section(label: { Text(LocalizedStringKey("Phonetic Parser:")) }) {
				Picker("", selection: $selMandarinParser) {
					Text(LocalizedStringKey("Dachen (Microsoft Standard / Wang / 01, etc.)")).tag(0)
					Text(LocalizedStringKey("Eten Traditional")).tag(1)
					Text(LocalizedStringKey("Eten 26")).tag(3)
					Text(LocalizedStringKey("IBM")).tag(4)
					Text(LocalizedStringKey("Hsu")).tag(2)
					Text(LocalizedStringKey("MiTAC")).tag(5)
					Text(LocalizedStringKey("Fake Seigyou")).tag(6)
					Text(LocalizedStringKey("Hanyu Pinyin with Numeral Intonation")).tag(10)
				}.onChange(of: selMandarinParser) { (value) in
					mgrPrefs.mandarinParser = value
				}
				.labelsHidden()
				.frame(width: 320.0)
				Text(LocalizedStringKey("Choose the phonetic layout for Mandarin parser."))
					.preferenceDescription()
			}
			Preferences.Section(bottomDivider: true, label: { Text(LocalizedStringKey("Basic Keyboard Layout:")) }) {
				HStack {
					Picker("", selection: $selBasicKeyboardLayout) {
						ForEach(0...(IME.arrEnumerateSystemKeyboardLayouts.count - 1), id: \.self) { id in
							Text(IME.arrEnumerateSystemKeyboardLayouts[id].strName).tag(
								IME.arrEnumerateSystemKeyboardLayouts[id].strValue)
						}.id(UUID())
					}.onChange(of: selBasicKeyboardLayout) { (value) in
						mgrPrefs.basicKeyboardLayout = value
					}
					.labelsHidden()
					.frame(width: 240.0)
				}
				Text(LocalizedStringKey("Choose the macOS-level basic keyboard layout."))
					.preferenceDescription()
			}
		}
		Divider()
		Preferences.Container(contentWidth: contentWidth) {
			Preferences.Section(title: "") {
				VStack(alignment: .leading, spacing: 10) {
					Text(
						LocalizedStringKey(
							"Non-QWERTY alphanumeral keyboard layouts are for Hanyu Pinyin parser only."
						)
					)
					.preferenceDescription()
					Text(
						LocalizedStringKey(
							"Apple Dynamic Bopomofo Basic Keyboard Layouts (Dachen & Eten Traditional) must match the Dachen parser in order to be functional."
						)
					)
					.preferenceDescription()
				}
			}
		}
	}
}

@available(macOS 11.0, *)
struct suiPrefPaneKeyboard_Previews: PreviewProvider {
	static var previews: some View {
		suiPrefPaneKeyboard()
	}
}
