// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import AppKit
import Foundation
import Shared
import Tekkon

// MARK: - IMKCandidates 功能擴充

public extension SessionCtl {
  /// 生成 IMK 選字窗專用的候選字串陣列。
  /// - Parameter sender: 呼叫了該函式的客體（無須使用）。
  /// - Returns: IMK 選字窗專用的候選字串陣列。
  override func candidates(_ sender: Any!) -> [Any]! {
    _ = sender // 防止格式整理工具毀掉與此對應的參數。
    var arrResult = [String]()

    // 注意：下文中的不可列印字元是用來方便在 IMEState 當中用來分割資料的。
    func handleIMKCandidatesPrepared(
      _ candidates: [(keyArray: [String], value: String)], prefix: String = ""
    ) {
      guard let separator = inputHandler?.keySeparator else { return }
      for theCandidate in candidates {
        let theConverted = ChineseConverter.kanjiConversionIfRequired(theCandidate.value)
        var result = (theCandidate.value == theConverted) ? theCandidate.value : "\(theConverted)\u{1A}(\(theCandidate.value))"
        if arrResult.contains(result) {
          let reading: String =
            PrefMgr.shared.cassetteEnabled
              ? theCandidate.keyArray.joined(separator: separator)
              : (PrefMgr.shared.showHanyuPinyinInCompositionBuffer
                ? Tekkon.cnvPhonaToHanyuPinyin(
                  targetJoined: {
                    var arr = [String]()
                    theCandidate.keyArray.forEach { key in
                      arr.append(Tekkon.restoreToneOneInPhona(target: key))
                    }
                    return arr.joined(separator: "-")
                  }()
                )
                : theCandidate.keyArray.joined(separator: separator))
          result = "\(result)\u{17}(\(reading))"
        }
        arrResult.append(prefix + result)
      }
    }

    switch state.type {
    case .ofDeactivated, .ofEmpty, .ofAbortion, .ofCommitting, .ofMarking: break
    case .ofAssociates:
      handleIMKCandidatesPrepared(state.candidates, prefix: "⇧")
    case .ofInputting where state.isCandidateContainer:
      handleIMKCandidatesPrepared(state.candidates)
    case .ofCandidates:
      guard !state.candidates.isEmpty else { return .init() }
      if state.candidates[0].keyArray.joined(separator: "-").contains("_punctuation") {
        arrResult = state.candidates.map(\.value) // 標點符號選單處理。
      } else {
        handleIMKCandidatesPrepared(state.candidates)
      }
    case .ofSymbolTable:
      // 分類符號選單不會出現同符異音項、不需要康熙 / JIS 轉換，所以使用簡化過的處理方式。
      arrResult = state.candidates.map(\.value)
    default: break
    }

    return arrResult
  }

  /// IMK 選字窗限定函式，只要選字窗內的高亮內容選擇出現變化了、就會呼叫這個函式。
  /// - Parameter currentSelection: 已經高亮選中的候選字詞內容。
  override func candidateSelectionChanged(_ currentSelection: NSAttributedString!) {
    guard state.isCandidateContainer else { return }
    guard let candidateString = currentSelection?.string, !candidateString.isEmpty else { return }
    // Handle candidatePairHighlightChanged().
    let indexDeducted = deductCandidateIndex(from: candidateString)
    candidatePairHighlightChanged(at: indexDeducted)
    let realCandidateString = state.candidates[indexDeducted].value
    // Handle IMK Annotation... We just use this to tell Apple that this never works in IMKCandidates.
    DispatchQueue.main.async { [self] in
      let annotation = reverseLookup(for: candidateString).joined(separator: "\n")
      guard !annotation.isEmpty else { return }
      vCLog("Current Annotation: \(annotation)")
      guard let imkCandidates = candidateUI as? CtlCandidateIMK else { return }
      annotationSelected(.init(string: annotation), forCandidate: .init(string: realCandidateString))
      imkCandidates.showAnnotation(.init(string: annotation))
    }
  }

  /// IMK 選字窗限定函式，只要選字窗確認了某個候選字詞的選擇、就會呼叫這個函式。
  /// - Remark: 不要被 IMK 的 API 命名方式困惑到。這其實是 Confirm Selection 確認選字。
  /// - Parameter candidateString: 已經確認的候選字詞內容。
  override func candidateSelected(_ candidateString: NSAttributedString!) {
    guard state.isCandidateContainer else { return }
    let candidateString: String = candidateString?.string ?? ""
    if state.type == .ofAssociates {
      // 聯想詞的 Shift+選字鍵的處理已經在其它位置實作完成。
      let isShiftHold = NSEvent.modifierFlags.contains(.shift)
      if !(isShiftHold || PrefMgr.shared.alsoConfirmAssociatedCandidatesByEnter) {
        switchState(IMEState.ofAbortion())
        return
      }
    }

    let indexDeducted = deductCandidateIndex(from: candidateString)
    candidatePairSelectionConfirmed(at: indexDeducted)
  }

  func deductCandidateIndex(from candidateString: String) -> Int {
    var indexDeducted = 0

    // 分類符號選單不會出現同符異音項、不需要康熙 / JIS 轉換，所以使用簡化過的處理方式。
    func fixSymbolIndexForIMKCandidates() {
      for (i, neta) in state.candidates.enumerated() {
        if candidateString == neta.value {
          indexDeducted = min(i, state.candidates.count - 1)
          break
        }
      }
    }

    switch state.type {
    case .ofAssociates:
      fixIndexForIMKCandidates(&indexDeducted, prefix: "⇧", source: candidateString)
    case .ofInputting where state.isCandidateContainer:
      fixIndexForIMKCandidates(&indexDeducted, source: candidateString)
    case .ofSymbolTable:
      fixSymbolIndexForIMKCandidates()
    case .ofCandidates:
      guard !state.candidates.isEmpty else { break }
      if state.candidates[0].keyArray.description.contains("_punctuation") {
        fixSymbolIndexForIMKCandidates() // 標點符號選單處理。
      } else {
        fixIndexForIMKCandidates(&indexDeducted, source: candidateString)
      }
    default: break
    }
    return indexDeducted
  }

  /// 解析 IMKCandidates 給出的資料參數，據此推算正確的被確認的候選字詞配對的編號。
  /// - Remark: 該函式當中的不可列印字元`\u{1A}`是用來方便在 IMEState 當中用來分割資料的。
  /// - Parameters:
  ///   - prefix: 前綴（僅限於聯想詞模式）。
  ///   - indexToFix: 要糾正的編號變數。
  ///   - candidateString: IMKCandidates 給出的原始資料。
  private func fixIndexForIMKCandidates(
    _ indexDeducted: inout Int, prefix: String = "", source candidateString: String
  ) {
    guard state.isCandidateContainer else { return }
    guard let separator = inputHandler?.keySeparator else { return }
    let candidates = state.candidates
    let maxIndex = candidates.count - 1
    for (i, neta) in candidates.enumerated() {
      let theConverted = ChineseConverter.kanjiConversionIfRequired(neta.value)
      let netaShown = (neta.value == theConverted)
        ? neta.value
        : "\(theConverted)\u{1A}(\(neta.value))"
      let reading: String =
        PrefMgr.shared.cassetteEnabled
          ? neta.keyArray.joined(separator: separator)
          : (PrefMgr.shared.showHanyuPinyinInCompositionBuffer
            ? Tekkon.cnvPhonaToHanyuPinyin(
              targetJoined: {
                var arr = [String]()
                neta.keyArray.forEach { key in
                  arr.append(Tekkon.restoreToneOneInPhona(target: key))
                }
                return arr.joined(separator: "-")
              }()
            )
            : neta.keyArray.joined(separator: separator))
      let netaShownWithPronunciation = "\(netaShown)\u{17}(\(reading))"
      if candidateString == prefix + netaShownWithPronunciation {
        indexDeducted = min(i, maxIndex)
        break
      }
      if candidateString == prefix + netaShown {
        indexDeducted = min(i, maxIndex)
        break
      }
    }
  }

  /// 特殊處理：deactivateServer() 可能會遲於另一個客體會話的 activateServer() 執行。
  /// 雖然所有在這個函式內影響到的變數都改為動態變數了（不會出現跨副本波及的情況），
  /// 但 IMKCandidates 是有內部共用副本的、會被波及。所以在這裡糾偏一下。
  internal func keepIMKCandidatesShownUp() {
    guard PrefMgr.shared.useIMKCandidateWindow, isBootingUp else { return }
    guard let imkC = candidateUI as? CtlCandidateIMK else { return }
    var i: Double = 0
    while i < 1 {
      DispatchQueue.main.asyncAfter(deadline: .now() + i) { [self] in
        if state.isCandidateContainer, !imkC.visible {
          imkC.visible = true
        }
      }
      i += 0.3
    }
  }
}
