// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation
import Homa
import LexiconAssembly
import Shared
import SwiftExtension

// MARK: - PhraseOperationPostCheckRequest

/// 使用者片語控頻（升權／降權）之延後查核請求。
///
/// 本結構只承載**可跨執行緒傳遞**之資料：查核所需之語言模組、偏好與宿主服務，一律於
/// 主執行緒上以 ``SessionProtocol/host`` 就地取得。之所以要這樣切：控頻之落盤已在
/// `LXAssembly.userDataWriteQueue` 上完成，查核必須排在該筆工作**之後**，而該巷不得
/// 回頭觸碰主執行緒持有之語言模組。
struct PhraseOperationPostCheckRequest: Sendable {
  let keyArray: [String]
  let value: String
  let inputMode: Shared.InputMode
  let action: CandidateContextMenuAction
  /// 本次控頻所寫入之權重（升權為 `nil`、降權為極低值）。
  let weight: Double?
  /// 0＝操作之後的首次查核（可修復）；1＝修復之後的覆核（只記錄、不再修復）。
  let attempt: Int

  var keyChain: String { keyArray.joined(separator: "-") }
}

// MARK: - PhraseOperationPostCheckCause

/// 控頻未能生效之真因（可多項並存）。
enum PhraseOperationPostCheckCause: Equatable {
  /// 使用者片語檔內查無該列——落盤失敗、或該列已被清詞。
  case targetRowMissing
  /// 目標仍在濾除清單內：升權之後仍不會出現。
  case targetFilteredButBoosted
  /// 目標與競品同分，而競品之列較新（同分時由列序決勝）。
  case tiedWithNewerCompetitor(competitor: String)
  /// 競品分數嚴格高於目標。
  case outrankedByCompetitor(competitor: String, score: Double)
  /// 降權之後目標仍居首（權重未被套用）。
  case targetStillRankedFirst(score: Double)
  /// 漸退記憶（POM）會把選字拉回競品（升權）或拉回目標本身（降權）。
  case pomOverride(headValue: String, candidate: String)

  // MARK: Internal

  var logDescription: String {
    switch self {
    case .targetRowMissing:
      return "target row missing from the user phrase store"
    case .targetFilteredButBoosted:
      return "target still listed in the exclusion list"
    case let .tiedWithNewerCompetitor(competitor):
      return "tied with a newer competitor '\(competitor)'"
    case let .outrankedByCompetitor(competitor, score):
      return "outranked by '\(competitor)' at \(score)"
    case let .targetStillRankedFirst(score):
      return "still ranked first at \(score)"
    case let .pomOverride(headValue, candidate):
      return "gradual memory would pull '\(headValue)' to '\(candidate)'"
    }
  }

  /// 是否應以「重寫該列」處置。漸退記憶另有清詞路徑。
  var isRepairedByRewriting: Bool {
    switch self {
    case .pomOverride: return false
    default: return true
    }
  }
}

// MARK: - SessionProtocol + Phrase Operation Post Check

extension SessionProtocol {
  /// 排定一次控頻查核：於使用者資料寫入巷上排隊，故必然在其落盤工作之後執行；
  /// 巷上只做「排到主執行緒」這一件小事，查核本身一律回主執行緒（語言模組之持有者）。
  ///
  /// - Note: 本函式只認升權與降權；加詞與濾除另有其語義（前者本就以「出現與否」自證、
  ///   後者之成效由「該詞是否消失」自證），不在此列。
  func schedulePhraseOperationPostCheck(
    for phrase: UserPhraseInsertable,
    action: CandidateContextMenuAction,
    attempt: Int = 0
  ) {
    guard action == .toBoost || action == .toNerf else { return }
    guard phrase.isValid else { return }
    let request = PhraseOperationPostCheckRequest(
      keyArray: phrase.keyArray,
      value: phrase.value,
      inputMode: phrase.inputMode,
      action: action,
      weight: phrase.weight,
      attempt: attempt
    )
    // 主執行緒上成形之閉包：只捕獲 `self`（會話）與請求本體。`@MainActor` 標註使該捕獲
    // 留在主執行緒之隔離域內，故得安全穿過寫入巷再回到主執行緒。
    let recheck: @MainActor @Sendable @convention(block) () -> () = { [weak self] in
      self?.runPhraseOperationPostCheck(request)
    }
    LXAssembly.withUserDataWriteQueueAsync {
      asyncOnMain(execute: recheck)
    }
  }

  /// 同步執行一次控頻查核（不經寫入巷）。供排程路徑、覆核與單元測試共用。
  func runPhraseOperationPostCheck(
    for phrase: UserPhraseInsertable,
    action: CandidateContextMenuAction,
    attempt: Int = 0
  ) {
    guard action == .toBoost || action == .toNerf, phrase.isValid else { return }
    runPhraseOperationPostCheck(
      PhraseOperationPostCheckRequest(
        keyArray: phrase.keyArray,
        value: phrase.value,
        inputMode: phrase.inputMode,
        action: action,
        weight: phrase.weight,
        attempt: attempt
      )
    )
  }

  /// 執行一次控頻查核；失效時嘗試修復一次，並排定覆核。
  func runPhraseOperationPostCheck(_ request: PhraseOperationPostCheckRequest) {
    // 生產環境下 `currentLM` 即宿主所持之該模式辭典副本；測試則另注入等價實例
    // （`host.lexicon(for:)` 會再建一份、其使用者資料為空）。故以會話現用之副本為優先，
    // 僅當其語言側與請求不符時才回問宿主。
    let expectedCHS = request.inputMode == .imeModeCHS
    let lexicon: LXAssembly.LXFacade = if let current = inputHandler?.currentLM,
                                          current.isCHS == expectedCHS {
      current
    } else {
      host.lexicon(for: request.inputMode)
    }
    let timestamp = Date().timeIntervalSince1970
    // 只看單元圖：帶前文之 n-gram 條目是語境偏好，不是「該讀音底下誰居首」之判準。
    let ranked = lexicon.lxQuerier.grams(for: request.keyArray).filter(\.isUnigram)
    let target = ranked.first { $0.current == request.value }
    let top = ranked.first

    // 名次之判準：升權者須居首；降權者須不居首（只有單一候選時，降權無從改變名次，
    // 而目標缺席於清單＝已沉底，兩者皆算達標）。
    let isRankSatisfied: Bool = switch request.action {
    case .toNerf:
      top?.current != request.value || ranked.count <= 1
    default:
      top?.current == request.value
    }
    // 漸退記憶：升權者怕「head 詞值已是目標、候選卻另有其詞」之記憶（該記憶會在升權之後
    // 回過頭把選字拉走）；降權者怕目標自身仍被記憶反覆拉回。**此項獨立於名次**——
    // 語言模組之名次已達標、卻被記憶綁架，正是最常見的「升權無效」形態。
    // 主開關關閉時漸退記憶根本不參與選字，故不得以「查核」為名清掉它（那是無謂的資料損失）。
    let conflicts: [LXAssembly.POMMemory] = if prefs.fetchSuggestionsFromPerceptionOverrideModel {
      lexicon.pomMemories(headReading: request.keyChain, timestamp: timestamp).filter {
        switch request.action {
        case .toBoost: return $0.headValue == request.value && $0.candidate != request.value
        case .toNerf: return $0.candidate == request.value && $0.headValue != request.value
        default: return false
        }
      }
    } else {
      []
    }
    if isRankSatisfied, conflicts.isEmpty {
      // 成功路徑亦記身分：否則日誌上「查核通過」與「查核從未執行」同形。
      vCLog(
        "UserPhrasePostCheck: \(request.action) '\(request.value)' @ '\(request.keyChain)'"
          + " is effective (top: '\(top?.current ?? "-")')."
      )
      return
    }

    var causes = [PhraseOperationPostCheckCause]()
    if !isRankSatisfied {
      if request.action == .toBoost {
        if target == nil {
          causes.append(.targetRowMissing)
        }
        let pair = Homa.CandidatePair(keyArray: request.keyArray, value: request.value)
        if lexicon.lxQuerier.isPairFiltered(pair: pair) {
          causes.append(.targetFilteredButBoosted)
        }
        if let top, let target, top.current != request.value {
          if top.probability > target.probability {
            causes.append(.outrankedByCompetitor(competitor: top.current, score: top.probability))
          } else {
            causes.append(.tiedWithNewerCompetitor(competitor: top.current))
          }
        }
      } else if let top, top.current == request.value {
        causes.append(.targetStillRankedFirst(score: top.probability))
      }
    }
    causes.append(contentsOf: conflicts.map {
      .pomOverride(headValue: $0.headValue, candidate: $0.candidate)
    })

    let summary = causes.map(\.logDescription).joined(separator: "; ")
    vCLog(
      "UserPhrasePostCheck: \(request.action) '\(request.value)' @ '\(request.keyChain)'"
        + " is ineffective (top: '\(top?.current ?? "-")'). Causes: \(summary.isEmpty ? "unknown" : summary)"
    )

    guard request.attempt == 0 else { return }

    var didRepair = false
    if !conflicts.isEmpty {
      // 使用者既已顯式重排該讀音之先後，同一讀音底下之舊記憶即屬過期資料。
      // 落盤一律交宿主之 debounce 協調器（`savePerceptionOverrideModelData`）：本查核雖已
      // 離開 IMK 之事件鏈路，仍不應在主執行緒上做 JSON 編碼與磁碟寫入（分卷 29 之紀律）。
      lexicon.bleachSpecifiedPOMSuggestions(
        headReadings: [request.keyChain],
        saveCallback: { self.host.savePerceptionOverrideModelData() }
      )
      didRepair = true
      vCLog("UserPhrasePostCheck: purged gradual memories under '\(request.keyChain)'.")
    }
    if causes.contains(where: \.isRepairedByRewriting) {
      // 重寫一列：列序即同分時之決勝依據，故「重寫」等同「把本次意圖提為最新」。
      // 權重一律就地重算（經宿主之 `updateUserPhraseWeight`）——單讀音單漢字之升權係相對
      // 權重，重算才會把分數抬到「此刻最強競品」之上。目標若仍在濾除清單內，宿主之落盤
      // 計畫會把它解讀為「自濾除清單移出」——這正是升權所須之前置步驟。
      let phrase = host.updateUserPhraseWeight(
        UserPhraseInsertable(
          keyArray: request.keyArray,
          value: request.value,
          inputMode: request.inputMode,
          weight: request.weight
        ),
        request.action
      )
      if host.writeUserPhrasesAtOnce(phrase, false) {
        didRepair = true
        vCLog("UserPhrasePostCheck: re-appended the row for '\(request.value)'.")
      } else {
        vCLog("UserPhrasePostCheck: failed to re-append the row for '\(request.value)'.")
      }
    }
    guard didRepair else { return }
    schedulePhraseOperationPostCheck(
      for: UserPhraseInsertable(
        keyArray: request.keyArray,
        value: request.value,
        inputMode: request.inputMode,
        weight: request.weight
      ),
      action: request.action,
      attempt: request.attempt + 1
    )
  }
}
