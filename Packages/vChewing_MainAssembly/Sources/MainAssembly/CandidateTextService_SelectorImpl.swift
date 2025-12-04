// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation

extension CandidateTextService {
  // 白名單：以 enum 型別列出所有允許的 selector；使用 enum 以利在編譯期檢查與方法映射。
  public enum AllowedSelector: String, CaseIterable {
    case copyUnicodeMetadata = "copyUnicodeMetadata:"
    case copyRubyHTMLZhuyinTextbookStyle = "copyRubyHTMLZhuyinTextbookStyle:"
    case copyRubyHTMLHanyuPinyinTextbookStyle = "copyRubyHTMLHanyuPinyinTextbookStyle:"
    case copyInlineZhuyinAnnotationTextbookStyle = "copyInlineZhuyinAnnotationTextbookStyle:"
    case copyInlineHanyuPinyinAnnotationTextbookStyle = "copyInlineHanyuPinyinAnnotationTextbookStyle:"
    case copyBraille1947 = "copyBraille1947:"
    case copyBraille2018 = "copyBraille2018:"

    // MARK: Internal

    var selectorName: String { rawValue }
  }

  // MARK: - Final Sanity Check Registration.

  // Register the default allowed selector set into the shared CandidateTextService
  // module. This runs on module initialization and ensures the Shared module's
  // final sanity check has a concrete whitelist to validate against.
  public static let registerAllowedSelectors: () = {
    CandidateTextService.allowedSelectorSet = Set(Self.AllowedSelector.allCases.map { $0.rawValue })
  }()

  // (The default FinalSanityCheck implementation now lives in `Shared/CandidateTextService`.
  // The registration above ensures Shared has the allowed selector whitelist.)

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
      // older runtime checks removed in favor of strongly-typed mapping
      // 在執行前再檢查是否在白名單中，並改以 enum/action 映射執行，避免使用 performSelector。
      guard let action = AllowedSelector(rawValue: selectorName) else { return nil }
      switch action {
      case .copyUnicodeMetadata:
        copyUnicodeMetadata(param)
      case .copyRubyHTMLZhuyinTextbookStyle:
        copyRubyHTMLZhuyinTextbookStyle(param)
      case .copyRubyHTMLHanyuPinyinTextbookStyle:
        copyRubyHTMLHanyuPinyinTextbookStyle(param)
      case .copyInlineZhuyinAnnotationTextbookStyle:
        copyInlineZhuyinAnnotationTextbookStyle(param)
      case .copyInlineHanyuPinyinAnnotationTextbookStyle:
        copyInlineHanyuPinyinAnnotationTextbookStyle(param)
      case .copyBraille1947:
        copyBraille1947(param)
      case .copyBraille2018:
        copyBraille2018(param)
      }
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

// 確保模組載入時即註冊允許的 selector 集合。
private let _ignoredRegisterAllowedSelectors: () = CandidateTextService.registerAllowedSelectors

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
