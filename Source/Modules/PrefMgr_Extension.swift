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
    // 防呆。macOS 10.11 用 IMK 選字窗會崩潰，macOS 10.13 的 IMK 選字窗仍有問題。
    // 一般人想用的 IMK 選字窗基於 macOS 10.09 系統內建的注音輸入法的那種矩陣選字窗。
    // 然而，該選字窗的體驗直到 macOS 10.14 開始才在 IMKCandidates 當中正式提供。
    if #unavailable(macOS 12) { useIMKCandidateWindow = true }
    if #unavailable(macOS 10.15) {
      handleDefaultCandidateFontsByLangIdentifier = false
      shiftKeyAccommodationBehavior = 0
      disableShiftTogglingAlphanumericalMode = false
      togglingAlphanumericalModeWithLShift = false
    }
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
