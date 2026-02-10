// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import AppKit

// MARK: - Tooltip Display and Candidate Display Methods

extension SessionProtocol {
  // 有些 App 會濫用內文組字區的內容來預測使用者的輸入行為。
  // 對此類 App 有疑慮者，可以將這類 App 登記到客體管理員當中。
  // 這樣，不但強制使用（限制讀音 20 個的）浮動組字窗，而且內文組字區只會顯示一個空格。
  public var attributedStringSecured: (value: NSAttributedString, range: NSRange) {
    // 這個針對 Discord 的 特殊相容策略對 Discord 網頁端無效。
    let isDiscordClient = client()?.bundleIdentifier()?.hasSuffix(".Discord") ?? false
    let securedPlaceholder = isDiscordClient
      ? state.data.getAttributedStringPlaceholder("_")
      : state.data.attributedStringPlaceholder
    return clientMitigationLevel >= 2
      ? (securedPlaceholder, NSRange(location: 0, length: 0))
      : (state.attributedString, NSRange(state.u16MarkedRange))
  }

  public var u16Cursor: Int {
    var u16Cursor: Int = state.u16MarkedRange.lowerBound
    if !prefs.useDynamicCandidateWindowOrigin, state.isCandidateContainer {
      u16Cursor = state.u16Cursor
    }
    return max(min(state.displayedTextConverted.utf16.count, u16Cursor), 0)
  }

  public func lineHeightRect(zeroCursor: Bool = false) -> CGRect {
    guard let client = client() else { return .seniorTheBeast }
    return client.lineHeightRect(u16Cursor: zeroCursor ? 0 : u16Cursor)
  }

  public func toggleCandidateUIVisibility(_ newValue: Bool, refresh: Bool) {
    guard isCurrentSession else { return }
    switch (newValue, refresh) {
    case (false, _), (true, false): ui?.candidateUI?.visible = newValue
    case (true, true): showCandidates()
    }
  }

  public func showTooltip(
    _ tooltip: String?,
    colorState: TooltipColorState,
    duration: Double
  ) {
    guard isCurrentSession, client() != nil else { return }
    guard let tooltip, !tooltip.isEmpty else {
      ui?.tooltipUI?.hide()
      return
    }
    let lineHeightRect = updateVerticalTypingStatus()
    var finalOrigin: CGPoint = lineHeightRect.origin
    let delta: Double = lineHeightRect.size.height + 4.0 // bottomOutOfScreenAdjustmentHeight
    if isVerticalTyping {
      finalOrigin = CGPoint(
        x: lineHeightRect.origin.x + lineHeightRect.size.width + 5, y: lineHeightRect.origin.y
      )
    }
    let tooltipContentDirection: UILayoutOrientation = {
      if prefs.alwaysShowTooltipTextsHorizontally { return .horizontal }
      return isVerticalTyping ? .vertical : .horizontal
    }()
    // 先隱藏，因為有顯示滯後性。
    ui?.tooltipUI?.hide()
    ui?.tooltipUI?.setColor(state: colorState)
    // 再設定其文字顯示內容並顯示。
    ui?.tooltipUI?.show(
      tooltip: tooltip, at: finalOrigin, bottomOutOfScreenAdjustmentHeight: delta,
      direction: tooltipContentDirection, duration: duration
    )
  }

  private func showCandidates() {
    guard isCurrentSession, client() != nil else { return }
    updateVerticalTypingStatus()
    let isServiceMenu = state.type == .ofSymbolTable && state.node.containsCandidateServices
    isVerticalCandidateWindow = isVerticalTyping || !prefs.useHorizontalCandidateList
    isVerticalCandidateWindow = isVerticalCandidateWindow || isServiceMenu

    /// 無論是田所選字窗還是 IMK 選字窗，在這裡都有必要重新初期化。
    let candidateLayout: UILayoutOrientation =
      (isVerticalCandidateWindow ? .vertical : .horizontal)

    let isInputtingWithCandidates = state.type == .ofInputting && state.isCandidateContainer
    /// 先取消既有的選字窗的內容顯示。否則可能會重複生成選字窗的 NSWindow()。
    ui?.candidateUI?.visible = false
    ui?.candidateUI?.currentLayout = candidateLayout
    var singleLine = isVerticalTyping || prefs.candidateWindowShowOnlyOneLine
    singleLine = singleLine || isInputtingWithCandidates
    singleLine = singleLine || isServiceMenu

    ui?.candidateUI?.maxLinesPerPage = singleLine ? 1 : 4

    ui?.candidateUI?.assignCandidateFont(
      name: prefs.candidateTextFontName, size: prefs.candidateListTextSize
    )

    ui?.candidateUI?.locale = localeForFontFallbacks
    ui?.candidateUI?.delegate = self // 會自動觸發田所選字窗的資料重載。
    ui?.candidateUI?.visible = true

    resetCandidateWindowOrigin()
  }

  public func resetCandidateWindowOrigin() {
    let lhRect = lineHeightRect()
    var tlPoint = CGPoint(x: lhRect.origin.x, y: lhRect.origin.y - 4.0)
    tlPoint.x += isVerticalTyping ? (lhRect.size.width + 4.0) : 0
    ui?.candidateUI?.set(
      windowTopLeftPoint: tlPoint,
      bottomOutOfScreenAdjustmentHeight: lhRect.size.height + 4.0,
      useGCD: true
    )
  }

  public var localeForFontFallbacks: String {
    switch inputMode {
    case .imeModeCHS: return "zh-Hans"
    case .imeModeCHT:
      if !prefs.shiftJISShinjitaiOutputEnabled, !prefs.chineseConversionEnabled {
        return "zh-Hant"
      }
      return "ja"
    default: return ""
    }
  }
}
