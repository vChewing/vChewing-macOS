// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Shared

// MARK: Auto parameter fix procedures, executed everytime on SessionCtl.activateServer().

extension PrefMgr {
  public func fixOddPreferences() {
    // macOS 10.15 開始才能使用 SwiftUI 構建的田所選字窗。
    if #unavailable(macOS 10.15) { useIMKCandidateWindow = true }
    if #unavailable(macOS 10.15) {
      handleDefaultCandidateFontsByLangIdentifier = false
      shiftKeyAccommodationBehavior = 0
      disableShiftTogglingAlphanumericalMode = false
      togglingAlphanumericalModeWithLShift = false
    }
    // 自動糾正選字鍵 (利用其 didSet 特性)
    candidateKeys = candidateKeys
    // 客體黑名單自動排序去重複。
    clientsIMKTextInputIncapable = Array(Set(clientsIMKTextInputIncapable)).sorted()
    // 注拼槽注音排列選項糾錯。
    var isKeyboardParserOptionValid = false
    KeyboardParser.allCases.forEach {
      if $0.rawValue == keyboardParser { isKeyboardParserOptionValid = true }
    }
    if !isKeyboardParserOptionValid {
      keyboardParser = 0
    }
    // 基礎鍵盤排列選項糾錯。
    if TISInputSource.generate(from: basicKeyboardLayout) == nil {
      basicKeyboardLayout = Self.kDefaultBasicKeyboardLayout
    }
    if TISInputSource.generate(from: alphanumericalKeyboardLayout) == nil {
      alphanumericalKeyboardLayout = Self.kDefaultAlphanumericalKeyboardLayout
    }
    // 其它多元選項參數自動糾錯。
    if ![0, 1, 2].contains(specifyIntonationKeyBehavior) {
      specifyIntonationKeyBehavior = 0
    }
    if ![0, 1, 2].contains(specifyShiftBackSpaceKeyBehavior) {
      specifyShiftBackSpaceKeyBehavior = 0
    }
    if ![0, 1, 2].contains(upperCaseLetterKeyBehavior) {
      upperCaseLetterKeyBehavior = 0
    }
    if ![0, 1, 2].contains(shiftKeyAccommodationBehavior) {
      shiftKeyAccommodationBehavior = 0
    }
  }
}
