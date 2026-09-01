// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import SwiftUI

// MARK: - SettingsUIViewModel

/// 所有 SettingsUI page 共用的 ViewModel。
/// 管理搜尋狀態、導航狀態、以及 UserDef→Tab 映射的自動收集。
@available(macOS 14, *)
@Observable
public final class SettingsUIViewModel {
  // MARK: Lifecycle

  public init() {}

  // MARK: Public

  // -- 搜尋結果 --

  public struct SearchResult: Identifiable, Hashable {
    public let userDef: UserDef
    public let tabs: [PrefUITabs]
    public let title: String
    public let description: String

    public var id: String { userDef.rawValue }
  }

  // -- 導航狀態 --

  public var selectedTabID: PrefUITabs?

  // -- Sheet 搜尋狀態 --

  public var searchText: String = ""
  public var isShowingSearch: Bool = false

  // -- 內建 Searchable 搜尋狀態（方案一：頁面內過濾） --

  public var searchableText: String = ""

  /// 由 VwrSettingsUI 在 user-initiated tab switch 時讀取／重設，
  /// 用於區分「使用者點 sidebar 切頁」與「搜尋 Sheet 跳轉導航」。
  public var suppressSearchableClear = false

  // -- UserDef→Tab 映射（由 page 渲染時的 onAppear 自動填充） --

  public private(set) var userDefToTabs: [UserDef: Set<PrefUITabs>] = [:]

  public var tabPagesNotSearchable: Set<PrefUITabs> {
    [.tabAbout, .tabPhrases, .tabClients, .tabServices]
  }

  /// 目前的 Sheet 搜尋結果（根據 searchText 即時更新）。
  public var searchResults: [SearchResult] {
    guard !searchText.isEmpty else { return [] }
    let query = searchText
    var results: [SearchResult] = []
    for userDef in UserDef.allCases {
      guard let meta = userDef.metaData else { continue }
      let title = meta.shortTitle?.i18n ?? ""
      let desc = meta.description?.i18n ?? ""
      guard title.localizedStandardContains(query) || desc.localizedStandardContains(query)
      else { continue }
      let tabs = userDefToTabs[userDef].map(Array.init) ?? []
      results.append(
        SearchResult(
          userDef: userDef,
          tabs: tabs,
          title: title,
          description: desc
        )
      )
    }
    results.sort { lhs, rhs in
      let lhsTitle = lhs.title.localizedStandardContains(query)
      let rhsTitle = rhs.title.localizedStandardContains(query)
      if lhsTitle != rhsTitle { return lhsTitle && !rhsTitle }
      return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
    }
    return results
  }

  /// 判斷某個 UserDef 是否符合當前 searchableText（方案一頁面內過濾）。
  public func matchesSearchable(_ userDef: UserDef) -> Bool {
    let query = searchableText
    guard !query.isEmpty else { return true }
    guard let meta = userDef.metaData else { return false }
    let title = meta.shortTitle?.i18n ?? ""
    let desc = meta.description?.i18n ?? ""
    return title.localizedStandardContains(query) || desc.localizedStandardContains(query)
  }

  /// 由 UserDefRendered.onAppear 呼叫，登記某個 UserDef 出現在某個 Tab。
  public func register(_ userDef: UserDef, in tab: PrefUITabs) {
    userDefToTabs[userDef, default: []].insert(tab)
  }

  /// 從搜尋 Sheet 跳轉到指定分頁，同時將搜尋關鍵字帶入 searchableText，
  /// 讓使用者無需再次輸入。
  public func navigateToTab(_ tab: PrefUITabs) {
    searchableText = searchText
    suppressSearchableClear = true
    selectedTabID = tab
    isShowingSearch = false
    searchText = ""
  }
}

// MARK: - CurrentSettingsTabKey

@available(macOS 14, *)
struct CurrentSettingsTabKey: EnvironmentKey {
  static let defaultValue: PrefUITabs? = nil
}

@available(macOS 14, *)
extension EnvironmentValues {
  public var currentSettingsTab: PrefUITabs? {
    get { self[CurrentSettingsTabKey.self] }
    set { self[CurrentSettingsTabKey.self] = newValue }
  }
}
