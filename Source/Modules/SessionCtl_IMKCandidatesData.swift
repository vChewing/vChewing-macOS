// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation
import Shared
import Tekkon

// MARK: - IMKCandidates 功能擴充

extension SessionCtl {
  /// 生成 IMK 選字窗專用的候選字串陣列。
  /// - Parameter sender: 呼叫了該函式的客體（無須使用）。
  /// - Returns: IMK 選字窗專用的候選字串陣列。
  public override func candidates(_ sender: Any!) -> [Any]! {
    _ = sender  // 防止格式整理工具毀掉與此對應的參數。
    var arrResult = [String]()

    // 注意：下文中的不可列印字元是用來方便在 IMEState 當中用來分割資料的。
    func handleIMKCandidatesPrepared(_ candidates: [(String, String)], prefix: String = "") {
      for theCandidate in candidates {
        let theConverted = ChineseConverter.kanjiConversionIfRequired(theCandidate.1)
        var result = (theCandidate.1 == theConverted) ? theCandidate.1 : "\(theConverted)\u{1A}(\(theCandidate.1))"
        if arrResult.contains(result) {
          let reading: String =
            PrefMgr.shared.showHanyuPinyinInCompositionBuffer
            ? Tekkon.cnvPhonaToHanyuPinyin(target: Tekkon.restoreToneOneInZhuyinKey(target: theCandidate.0))
            : theCandidate.0
          result = "\(result)\u{17}(\(reading))"
        }
        arrResult.append(prefix + result)
      }
    }

    if state.type == .ofAssociates {
      handleIMKCandidatesPrepared(state.candidates, prefix: "⇧")
    } else if state.type == .ofSymbolTable {
      // 分類符號選單不會出現同符異音項、不需要康熙 / JIS 轉換，所以使用簡化過的處理方式。
      arrResult = state.candidates.map(\.1)
    } else if state.type == .ofCandidates {
      guard !state.candidates.isEmpty else { return .init() }
      if state.candidates[0].0.contains("_punctuation") {
        arrResult = state.candidates.map(\.1)  // 標點符號選單處理。
      } else {
        handleIMKCandidatesPrepared(state.candidates)
      }
    }

    return arrResult
  }

  /// IMK 選字窗限定函式，只要選字窗內的高亮內容選擇出現變化了、就會呼叫這個函式。
  /// - Parameter currentSelection: 已經高亮選中的候選字詞內容。
  public override func candidateSelectionChanged(_ currentSelection: NSAttributedString!) {
    guard let currentCandidate = currentSelection?.string, !currentCandidate.isEmpty else { return }
    let annotation = reverseLookup(for: currentCandidate).joined(separator: "\n")
    guard !annotation.isEmpty else { return }
    vCLog("Current Annotation: \(annotation)")
    DispatchQueue.main.async {
      guard let imkCandidates = self.ctlCandidateCurrent as? CtlCandidateIMK else { return }
      imkCandidates.showAnnotation(.init(string: annotation))
    }
  }

  /// IMK 選字窗限定函式，只要選字窗確認了某個候選字詞的選擇、就會呼叫這個函式。
  /// - Parameter candidateString: 已經確認的候選字詞內容。
  public override func candidateSelected(_ candidateString: NSAttributedString!) {
    let candidateString: String = candidateString?.string ?? ""
    if state.type == .ofAssociates {
      if !PrefMgr.shared.alsoConfirmAssociatedCandidatesByEnter {
        switchState(IMEState.ofAbortion())
        return
      }
    }

    var indexDeducted = 0

    // 注意：下文中的不可列印字元是用來方便在 IMEState 當中用來分割資料的。
    func handleIMKCandidatesSelected(_ candidates: [(String, String)], prefix: String = "") {
      for (i, neta) in candidates.enumerated() {
        let theConverted = ChineseConverter.kanjiConversionIfRequired(neta.1)
        let netaShown = (neta.1 == theConverted) ? neta.1 : "\(theConverted)\u{1A}(\(neta.1))"
        let reading: String =
          PrefMgr.shared.showHanyuPinyinInCompositionBuffer
          ? Tekkon.cnvPhonaToHanyuPinyin(target: Tekkon.restoreToneOneInZhuyinKey(target: neta.0)) : neta.0
        let netaShownWithPronunciation = "\(netaShown)\u{17}(\(reading))"
        if candidateString == prefix + netaShownWithPronunciation {
          indexDeducted = i
          break
        }
        if candidateString == prefix + netaShown {
          indexDeducted = i
          break
        }
      }
    }

    // 分類符號選單不會出現同符異音項、不需要康熙 / JIS 轉換，所以使用簡化過的處理方式。
    func handleSymbolCandidatesSelected(_ candidates: [(String, String)]) {
      for (i, neta) in candidates.enumerated() {
        if candidateString == neta.1 {
          indexDeducted = i
          break
        }
      }
    }

    if state.type == .ofAssociates {
      handleIMKCandidatesSelected(state.candidates, prefix: "⇧")
    } else if state.type == .ofSymbolTable {
      handleSymbolCandidatesSelected(state.candidates)
    } else if state.type == .ofCandidates {
      guard !state.candidates.isEmpty else { return }
      if state.candidates[0].0.contains("_punctuation") {
        handleSymbolCandidatesSelected(state.candidates)  // 標點符號選單處理。
      } else {
        handleIMKCandidatesSelected(state.candidates)
      }
    }
    candidatePairSelected(at: indexDeducted)
  }
}
