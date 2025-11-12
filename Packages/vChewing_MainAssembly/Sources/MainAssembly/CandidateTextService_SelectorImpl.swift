// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation

extension CandidateTextService {
  // MARK: - Final Sanity Check Implementation.

  public static func enableFinalSanityCheck() {
    finalSanityCheck = finalSanityCheckImplemented
  }

  private static func finalSanityCheckImplemented(_ target: CandidateTextService) -> Bool {
    switch target.value {
    case .url: return true
    case let .selector(strSelector):
      guard target.candidateText != "%s" else { return true } // 防止誤傷到編輯器。
      switch strSelector {
      case "copyUnicodeMetadata:": return true
      case _ where strSelector.hasPrefix("copyRuby"),
           _ where strSelector.hasPrefix("copyBraille"),
           _ where strSelector.hasPrefix("copyInline"):
        return !target.reading.joined().isEmpty // 以便應對 [""] 的情況。
      default: return true
      }
    }
  }

  // MARK: - Selector Methods, CandidatePairServicable, and the Coordinator.

  public var responseFromSelector: String? {
    switch value {
    case .url: return nil
    case let .selector(string):
      let passable = CandidatePairServicable(value: candidateText, reading: reading)
      return Coordinator().runTask(selectorName: string, candidate: passable)
    }
  }

  @objcMembers
  public final class CandidatePairServicable: NSObject {
    // MARK: Lifecycle

    public init(value: String, reading: [String] = []) {
      self.value = value
      self.reading = reading
    }

    // MARK: Public

    public typealias SubPair = (key: String, value: String)

    public var value: String
    public var reading: [String]

    // MARK: Internal

    @nonobjc
    var smashed: [SubPair] {
      var pairs = [SubPair]()
      if value.count != reading.count {
        pairs.append((reading.joined(separator: " "), value))
      } else {
        value.enumerated().forEach { i, valChar in
          pairs.append((reading[i], valChar.description))
        }
      }
      return pairs
    }
  }

  @objc
  public final class Coordinator: NSObject {
    // MARK: Public

    public func runTask(selectorName: String, candidate param: CandidatePairServicable) -> String? {
      guard !selectorName.isEmpty, !param.value.isEmpty else { return nil }
      guard responds(to: Selector(selectorName)) else { return nil }
      performSelector(onMainThread: Selector(selectorName), with: param, waitUntilDone: true)
      defer { result = nil }
      return result
    }

    // MARK: Internal

    /// 生成 Unicode 統一碼碼位中繼資料。
    /// - Parameter param: 要處理的詞音配對物件。
    @objc
    func copyUnicodeMetadata(_ param: CandidatePairServicable) {
      var resultArray = [String]()
      param.value.forEach { char in
        resultArray.append("\(char) \(char.description.charDescriptions.first ?? "NULL")")
      }
      result = resultArray.joined(separator: "\n")
    }

    /// 生成 HTML Ruby (教科書注音)。
    /// - Parameter param: 要處理的詞音配對物件。
    @objc
    func copyRubyHTMLZhuyinTextbookStyle(_ param: CandidatePairServicable) {
      prepareTextBookZhuyinReadings(param)
      copyRubyHTMLCommon(param)
    }

    /// 生成 HTML Ruby (教科書漢語拼音注音)。
    /// - Parameter param: 要處理的詞音配對物件。
    @objc
    func copyRubyHTMLHanyuPinyinTextbookStyle(_ param: CandidatePairServicable) {
      prepareTextBookPinyinReadings(param)
      copyRubyHTMLCommon(param)
    }

    /// 生成內文讀音標注 (教科書注音)。
    /// - Parameter param: 要處理的詞音配對物件。
    @objc
    func copyInlineZhuyinAnnotationTextbookStyle(_ param: CandidatePairServicable) {
      prepareTextBookZhuyinReadings(param)
      copyInlineAnnotationCommon(param)
    }

    /// 生成內文讀音標注 (教科書漢語拼音注音)。
    /// - Parameter param: 要處理的詞音配對物件。
    @objc
    func copyInlineHanyuPinyinAnnotationTextbookStyle(_ param: CandidatePairServicable) {
      prepareTextBookPinyinReadings(param)
      copyInlineAnnotationCommon(param)
    }

    @objc
    func copyBraille1947(_ param: CandidatePairServicable) {
      result = BrailleSputnik(standard: .of1947).convertToBraille(smashedPairs: param.smashed)
    }

    @objc
    func copyBraille2018(_ param: CandidatePairServicable) {
      result = BrailleSputnik(standard: .of2018).convertToBraille(smashedPairs: param.smashed)
    }

    // MARK: Private

    private var result: String?
  }
}

extension CandidateTextService.Coordinator {
  fileprivate func copyInlineAnnotationCommon(
    _ param: CandidateTextService
      .CandidatePairServicable
  ) {
    var composed = ""
    param.smashed.forEach { subPair in
      let subKey = subPair.key
      let subValue = subPair.value
      composed += subKey.contains("_") ? subValue : "\(subValue)(\(subKey))"
    }
    result = composed
  }

  fileprivate func copyRubyHTMLCommon(_ param: CandidateTextService.CandidatePairServicable) {
    var composed = ""
    param.smashed.forEach { subPair in
      let subKey = subPair.key
      let subValue = subPair.value
      composed += subKey
        .contains("_") ? subValue : "<ruby>\(subValue)<rp>(</rp><rt>\(subKey)</rt><rp>)</rp></ruby>"
    }
    result = composed
  }

  fileprivate func prepareTextBookZhuyinReadings(
    _ param: CandidateTextService
      .CandidatePairServicable
  ) {
    let newReadings = param.reading.map { currentReading in
      if currentReading.contains("_") { return "_??" }
      return Tekkon.cnvPhonaToTextbookStyle(target: currentReading)
    }
    param.reading = newReadings
  }

  fileprivate func prepareTextBookPinyinReadings(
    _ param: CandidateTextService
      .CandidatePairServicable
  ) {
    let newReadings = param.reading.map { currentReading in
      if currentReading.contains("_") { return "_??" }
      return Tekkon.cnvHanyuPinyinToTextbookStyle(
        targetJoined: Tekkon.cnvPhonaToHanyuPinyin(targetJoined: currentReading)
      )
    }
    param.reading = newReadings
  }
}
