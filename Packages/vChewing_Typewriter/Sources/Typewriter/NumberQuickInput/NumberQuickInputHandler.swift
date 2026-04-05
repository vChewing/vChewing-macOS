// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation

// MARK: - NumberQuickInputHandler

/// 數字快打模式的狀態機。管理漂鍵雙擊偵測、輸入緩衝、格式分類，以及候選清單產生。
@MainActor
public final class NumberQuickInputHandler {

  // MARK: - 狀態

  /// 是否正在數字快打模式中。
  public private(set) var isActive: Bool = false

  /// 數字快打前方的已組中文（或任何已輸入文字），可為空字串。
  public private(set) var precedingText: String = ""

  /// 使用者在數字快打模式中已輸入的字串（數字/算式/日期/時間）。
  public private(set) var numberBuffer: String = ""

  // MARK: - 漂鍵雙擊偵測

  /// 記錄第一下漂鍵的時間戳記。nil 表示尚無等待中的第一下。
  private var firstBacktickTimestamp: TimeInterval?

  /// 用於逾時後自動送出漂鍵字元的 DispatchWorkItem。
  private var pendingTimeoutWorkItem: DispatchWorkItem?

  /// 雙擊判定的時間窗口（秒）。
  private let doubleTapInterval: TimeInterval = 0.3

  /// 第一下漂鍵逾時後的回呼。由 InputHandler 設定，執行時應呼叫
  /// `session?.switchState(State.ofCommitting(textToCommit: "`"))` 並清理狀態。
  public var onBacktickTimeout: (() -> Void)?

  // MARK: - Lifecycle

  public init() {}

  // MARK: - 漂鍵雙擊偵測

  /// 記錄第一下漂鍵，並啟動 300ms 逾時計時器。
  /// 若逾時後仍未收到第二下，觸發 `onBacktickTimeout`。
  public func recordFirstBacktick() {
    firstBacktickTimestamp = Date().timeIntervalSince1970
    let workItem = DispatchWorkItem { [weak self] in
      guard let self else { return }
      guard firstBacktickTimestamp != nil else { return }
      firstBacktickTimestamp = nil
      pendingTimeoutWorkItem = nil
      onBacktickTimeout?()
    }
    pendingTimeoutWorkItem = workItem
    DispatchQueue.main.asyncAfter(deadline: .now() + doubleTapInterval, execute: workItem)
  }

  /// 嘗試確認雙擊。
  /// - Parameter precedingText: 雙擊成立時，組字區前方的已有文字。
  /// - Returns: 若在時間窗口內確認雙擊，啟動模式並回傳 `true`；否則回傳 `false`。
  public func tryConfirmDoubleTap(precedingText: String) -> Bool {
    guard let first = firstBacktickTimestamp else { return false }
    let elapsed = Date().timeIntervalSince1970 - first
    guard elapsed <= doubleTapInterval else {
      firstBacktickTimestamp = nil
      pendingTimeoutWorkItem?.cancel()
      pendingTimeoutWorkItem = nil
      return false
    }
    pendingTimeoutWorkItem?.cancel()
    pendingTimeoutWorkItem = nil
    firstBacktickTimestamp = nil
    activate(precedingText: precedingText)
    return true
  }

  // MARK: - 模式進入/離開

  /// 進入數字快打模式。
  /// - Parameter precedingText: 組字區前方的已有文字（可為空字串）。
  public func activate(precedingText: String) {
    isActive = true
    self.precedingText = precedingText
    numberBuffer = ""
  }

  /// 離開數字快打模式，重置所有狀態。
  public func deactivate() {
    isActive = false
    precedingText = ""
    numberBuffer = ""
    firstBacktickTimestamp = nil
    pendingTimeoutWorkItem?.cancel()
    pendingTimeoutWorkItem = nil
  }

  // MARK: - 緩衝管理

  /// 在緩衝區末尾追加一個字元。
  public func appendChar(_ char: Character) {
    numberBuffer.append(char)
  }

  /// 刪除緩衝區最後一個字元。若緩衝區已空則不做任何事。
  public func deleteLastChar() {
    guard !numberBuffer.isEmpty else { return }
    numberBuffer.removeLast()
  }

  // MARK: - 輸入分類

  /// 數字快打的輸入模式分類。
  public enum InputMode: Equatable {
    case empty
    case number
    case expression
    case date
    case time
  }

  /// 根據目前的 `numberBuffer` 內容自動判斷輸入模式。
  public var currentMode: InputMode {
    if numberBuffer.isEmpty { return .empty }
    if numberBuffer.contains(":") { return .time }
    // 含 .、/、- 且所有分段均為純數字 → 日期
    if looksLikeDate(numberBuffer) { return .date }
    // 含運算子 → 算術表達式
    let expressionOps: Set<Character> = ["+", "-", "*", "/", "(", ")"]
    if numberBuffer.contains(where: { expressionOps.contains($0) }) { return .expression }
    return .number
  }

  private func looksLikeDate(_ s: String) -> Bool {
    let separators = CharacterSet(charactersIn: "./")
    let parts = s.components(separatedBy: separators)
    guard parts.count >= 2 else { return false }
    return parts.allSatisfy { !$0.isEmpty && $0.allSatisfy(\.isNumber) }
  }

  // MARK: - 候選產生（委派給轉換器）

  /// 根據目前的 `numberBuffer` 產生候選清單。
  public func generateCandidates() -> [CandidateInState] {
    switch currentMode {
    case .empty: return []
    case .number: return NumberConverter.candidates(for: numberBuffer)
    case .expression: return ExpressionEvaluator.candidates(for: numberBuffer)
    case .date: return DateTimeConverter.dateCandidates(for: numberBuffer)
    case .time: return DateTimeConverter.timeCandidates(for: numberBuffer)
    }
  }

  /// 產生即時顯示的提示字串（如計算機模式的 "= 6000"）。
  /// 返回 nil 表示無提示。
  public func generateDisplayHint() -> String? {
    ExpressionEvaluator.displayHint(for: numberBuffer)
  }
}
