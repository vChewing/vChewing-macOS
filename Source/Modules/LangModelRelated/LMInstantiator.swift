// Copyright (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// Refactored from the ObjCpp-version of this class by:
// (c) 2011 and onwards The OpenVanilla Project (MIT License).
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

// NOTE: We still keep some of the comments left by Zonble,
// regardless that he is not in charge of this Swift module。

import Foundation

extension vChewing {
	/// LMInstantiator is a facade for managing a set of models including
	/// the input method language model, user phrases and excluded phrases.
	///
	/// It is the primary model class that the input controller and grammar builder
	/// of vChewing talks to. When the grammar builder starts to build a sentence
	/// from a series of BPMF readings, it passes the readings to the model to see
	/// if there are valid unigrams, and use returned unigrams to produce the final
	/// results.
	///
	/// LMInstantiator combine and transform the unigrams from the primary language
	/// model and user phrases. The process is
	///
	/// 1) Get the original unigrams.
	/// 2) Drop the unigrams whose value is contained in the exclusion map.
	/// 3) Replace the values of the unigrams using the phrase replacement map.
	/// 4) Replace the values of the unigrams using an external converter lambda.
	/// 5) Drop the duplicated phrases.
	///
	/// The controller can ask the model to load the primary input method language
	/// model while launching and to load the user phrases anytime if the custom
	/// files are modified. It does not keep the reference of the data pathes but
	/// you have to pass the paths when you ask it to do loading.
	public class LMInstantiator: Megrez.LanguageModel {
		// 在函數內部用以記錄狀態的開關。
		public var isPhraseReplacementEnabled = false
		public var isCNSEnabled = false
		public var isSymbolEnabled = false

		// 聲明原廠語言模組
		/// Reverse 的話，第一欄是注音，第二欄是對應的漢字，第三欄是可能的權重。
		/// 不 Reverse 的話，第一欄是漢字，第二欄是對應的注音，第三欄是可能的權重。
		let lmCore = LMCore(reverse: false, consolidate: false, defaultScore: -9.5, forceDefaultScore: false)
		let lmMisc = LMCore(reverse: true, consolidate: false, defaultScore: -1, forceDefaultScore: false)
		let lmSymbols = LMLite(defaultScore: -13.0, consolidate: true)
		let lmCNS = LMLite(defaultScore: -11.0, consolidate: true)

		// 聲明使用者語言模組
		let lmUserPhrases = LMLite(defaultScore: 0.0, consolidate: true)
		let lmFiltered = LMLite(defaultScore: 0.0, consolidate: true)
		let lmUserSymbols = LMLite(defaultScore: -12.0, consolidate: true)
		let lmReplacements = LMReplacments()
		let lmAssociates = LMAssociates()

		// 初期化的函數先保留
		override init() {}

		// 自我析構前要關掉全部的語言模組
		deinit {
			lmCore.close()
			lmMisc.close()
			lmSymbols.close()
			lmCNS.close()
			lmUserPhrases.close()
			lmFiltered.close()
			lmUserSymbols.close()
			lmReplacements.close()
			lmAssociates.close()
		}

		// 以下這些函數命名暫時保持原樣，等弒神行動徹底結束了再調整。

		public func isDataModelLoaded() -> Bool { lmCore.isLoaded() }
		public func loadLanguageModel(path: String) {
			if FileManager.default.isReadableFile(atPath: path) {
				lmCore.close()
				lmCore.open(path)
			}
		}

		public func isCNSDataLoaded() -> Bool { lmCNS.isLoaded() }
		public func loadCNSData(path: String) {
			if FileManager.default.isReadableFile(atPath: path) {
				lmCNS.close()
				lmCNS.open(path)
			}
		}

		public func isMiscDataLoaded() -> Bool { lmMisc.isLoaded() }
		public func loadMiscData(path: String) {
			if FileManager.default.isReadableFile(atPath: path) {
				lmMisc.close()
				lmMisc.open(path)
			}
		}

		public func isSymbolDataLoaded() -> Bool { lmSymbols.isLoaded() }
		public func loadSymbolData(path: String) {
			if FileManager.default.isReadableFile(atPath: path) {
				lmSymbols.close()
				lmSymbols.open(path)
			}
		}

		public func loadUserPhrases(path: String, filterPath: String) {
			if FileManager.default.isReadableFile(atPath: path) {
				lmUserPhrases.close()
				lmUserPhrases.open(path)
			}
			if FileManager.default.isReadableFile(atPath: filterPath) {
				lmFiltered.close()
				lmFiltered.open(filterPath)
			}
		}

		public func loadUserSymbolData(path: String) {
			if FileManager.default.isReadableFile(atPath: path) {
				lmUserSymbols.close()
				lmUserSymbols.open(path)
			}
		}

		public func loadUserAssociatedPhrases(path: String) {
			if FileManager.default.isReadableFile(atPath: path) {
				lmAssociates.close()
				lmAssociates.open(path)
			}
		}

		public func loadPhraseReplacementMap(path: String) {
			if FileManager.default.isReadableFile(atPath: path) {
				lmReplacements.close()
				lmReplacements.open(path)
			}
		}

		// MARK: - Core Functions (Public)

		/// Not implemented since we do not have data to provide bigram function.
		// public func bigramsForKeys(preceedingKey: String, key: String) -> [Megrez.Bigram] { }

		/// Returns a list of available unigram for the given key.
		/// @param key:String represents the BPMF reading or a symbol key.
		/// For instance, it you pass "ㄉㄨㄟˇ", it returns "㨃" and other possible candidates.
		override open func unigramsFor(key: String) -> [Megrez.Unigram] {
			if key == " " {
				/// 給空格鍵指定輸出值。
				let spaceUnigram = Megrez.Unigram(
					keyValue: Megrez.KeyValuePair(key: " ", value: " "),
					score: 0
				)
				return [spaceUnigram]
			}

			/// 準備不同的語言模組容器。
			var coreUnigrams: [Megrez.Unigram] = []
			var miscUnigrams: [Megrez.Unigram] = []
			var symbolUnigrams: [Megrez.Unigram] = []
			var userUnigrams: [Megrez.Unigram] = []
			var userSymbolUnigrams: [Megrez.Unigram] = []
			var cnsUnigrams: [Megrez.Unigram] = []

			var insertedPairs: Set<Megrez.KeyValuePair> = []  // 具體用途有待商榷
			var filteredPairs: Set<Megrez.KeyValuePair> = []

			// 開始逐漸往容器陣列內塞入資料
			let filteredUnigrams: [Megrez.Unigram] =
				lmFiltered.hasUnigramsFor(key: key) ? lmFiltered.unigramsFor(key: key) : []
			for unigram in filteredUnigrams {
				filteredPairs.insert(unigram.keyValue)
			}

			if lmUserPhrases.hasUnigramsFor(key: key) {
				var rawUserUnigrams: [Megrez.Unigram] = []
				// 用 reversed 指令讓使用者語彙檔案內的詞條優先順序隨著行數增加而逐漸增高。
				// 這樣一來就可以在就地新增語彙時徹底複寫優先權。
				// 將兩句差分也是為了讓 rawUserUnigrams 的類型不受可能的影響。
				rawUserUnigrams.append(contentsOf: lmUserPhrases.unigramsFor(key: key).reversed())
				userUnigrams = filterAndTransform(
					unigrams: rawUserUnigrams, filter: filteredPairs, inserted: &insertedPairs
				)
			}

			if lmUserPhrases.hasUnigramsFor(key: key) {
				let rawUserUnigrams: [Megrez.Unigram] = lmUserPhrases.unigramsFor(key: key)
				userUnigrams = filterAndTransform(
					unigrams: rawUserUnigrams, filter: filteredPairs, inserted: &insertedPairs
				)
			}

			if lmMisc.hasUnigramsFor(key: key) {
				let rawMiscUnigrams: [Megrez.Unigram] = lmMisc.unigramsFor(key: key)
				miscUnigrams = filterAndTransform(
					unigrams: rawMiscUnigrams, filter: filteredPairs, inserted: &insertedPairs
				)
			}

			if lmCore.hasUnigramsFor(key: key) {
				let rawCoreUnigrams: [Megrez.Unigram] = lmCore.unigramsFor(key: key)
				coreUnigrams = filterAndTransform(
					unigrams: rawCoreUnigrams, filter: filteredPairs, inserted: &insertedPairs
				)
			}

			if isSymbolEnabled {
				if lmUserSymbols.hasUnigramsFor(key: key) {
					let rawUserSymbolUnigrams: [Megrez.Unigram] = lmUserSymbols.unigramsFor(key: key)
					userSymbolUnigrams = filterAndTransform(
						unigrams: rawUserSymbolUnigrams, filter: filteredPairs, inserted: &insertedPairs
					)
				} else {
					IME.prtDebugIntel("Not found in UserSymbolUnigram: \(key)")
				}

				if lmSymbols.hasUnigramsFor(key: key) {
					let rawSymbolUnigrams: [Megrez.Unigram] = lmSymbols.unigramsFor(key: key)
					symbolUnigrams = filterAndTransform(
						unigrams: rawSymbolUnigrams, filter: filteredPairs, inserted: &insertedPairs
					)
				} else {
					IME.prtDebugIntel("Not found in UserUnigram: \(key)")
				}
			}

			if lmCNS.hasUnigramsFor(key: key), isCNSEnabled {
				let rawCNSUnigrams: [Megrez.Unigram] = lmCNS.unigramsFor(key: key)
				cnsUnigrams = filterAndTransform(
					unigrams: rawCNSUnigrams, filter: filteredPairs, inserted: &insertedPairs
				)
			}

			let allUnigrams: [Megrez.Unigram] =
				userUnigrams + miscUnigrams + coreUnigrams + cnsUnigrams + userSymbolUnigrams + symbolUnigrams

			return allUnigrams
		}

		/// If the model has unigrams for the given key.
		/// @param key The key.
		override open func hasUnigramsFor(key: String) -> Bool {
			if key == " " { return true }

			if !lmFiltered.hasUnigramsFor(key: key) {
				return lmUserPhrases.hasUnigramsFor(key: key) || lmCore.hasUnigramsFor(key: key)
			}

			return !unigramsFor(key: key).isEmpty
		}

		public func associatedPhrasesForKey(_ key: String) -> [String] {
			lmAssociates.valuesFor(key: key) ?? []
		}

		public func hasAssociatedPhrasesForKey(_ key: String) -> Bool {
			lmAssociates.hasValuesFor(key: key)
		}

		// MARK: - Core Functions (Private)

		func filterAndTransform(
			unigrams: [Megrez.Unigram],
			filter filteredPairs: Set<Megrez.KeyValuePair>,
			inserted insertedPairs: inout Set<Megrez.KeyValuePair>
		) -> [Megrez.Unigram] {
			var results: [Megrez.Unigram] = []

			for unigram in unigrams {
				let pairToDealWith: Megrez.KeyValuePair = unigram.keyValue
				if filteredPairs.contains(pairToDealWith) {
					continue
				}

				var pair: Megrez.KeyValuePair = pairToDealWith
				if isPhraseReplacementEnabled {
					let replacement = lmReplacements.valuesFor(key: pair.key)
					if !replacement.isEmpty {
						IME.prtDebugIntel(replacement)
						pair.value = replacement
					}
				}

				if !insertedPairs.contains(pair) {
					results.append(Megrez.Unigram(keyValue: pair, score: unigram.score))
					insertedPairs.insert(pair)
				}
			}
			return results
		}
	}
}
