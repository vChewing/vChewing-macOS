// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import SwiftUI

// MARK: - VwrSettingsUI

@available(macOS 14, *)
public struct VwrSettingsUI: View {
  // MARK: Lifecycle

  public init() {}

  // MARK: Public

  public var body: some View {
    @Bindable
    var viewModel = viewModel
    NavigationSplitView(columnVisibility: $columnVisibility) {
      sidebar
        .navigationSplitViewColumnWidth(173)
    } detail: {
      detailView
        .frame(maxHeight: .infinity)
        .onAppear {
          if viewModel.selectedTabID == nil {
            viewModel.selectedTabID = .tabGeneral
          }
        }
    }
    .frame(maxHeight: .infinity)
    // ⌘F 叫出搜尋 Sheet（作用於本視窗而非輸入法選單）。
    .overlay {
      Button("") { viewModel.isShowingSearch = true }
        .keyboardShortcut("f", modifiers: .command)
        .opacity(0).frame(width: 0, height: 0)
      // Esc 關閉搜尋 Sheet（僅 Sheet 打開時生效）。
      Button("") { viewModel.isShowingSearch = false }
        .keyboardShortcut(.escape, modifiers: [])
        .opacity(0).frame(width: 0, height: 0)
        .disabled(!viewModel.isShowingSearch)
    }
    // 使用者手動切換分頁時清空搜尋文字；從 Sheet 跳轉則保留。
    .onChange(of: viewModel.selectedTabID) { _, _ in
      if viewModel.suppressSearchableClear {
        viewModel.suppressSearchableClear = false
      } else {
        viewModel.searchableText = ""
      }
    }
    .sheet(isPresented: $viewModel.isShowingSearch) {
      searchSheet
    }
  }

  // MARK: Private

  @Environment(SettingsUIViewModel.self)
  private var viewModel

  @State
  private var columnVisibility: NavigationSplitViewVisibility = .doubleColumn

  @Environment(\.colorScheme)
  private var colorScheme

  // MARK: - Sidebar

  @ViewBuilder
  private var sidebar: some View {
    @Bindable
    var viewModel = viewModel
    List(PrefUITabs.allCases, selection: $viewModel.selectedTabID) { neta in
      NavigationLink(value: neta) {
        Label {
          Text(verbatim: neta.i18nTitle)
        } icon: {
          Image(nsImage: neta.icon)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 16, height: 16)
        }
      }
    }
    // 搜尋按鈕放在 Logo 下方、頁面清單上方。
    .safeAreaInset(edge: .top) {
      VStack(spacing: 4) {
        Group {
          if let appIcon = NSImage(named: "PrefBanner") {
            Image(nsImage: appIcon)
              .resizable()
              .aspectRatio(contentMode: .fit)
              .frame(width: 144, height: 49)
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding([.top, .bottom], 6)
              .id(colorScheme)
          } else {
            Color.secondary
          }
        }
        .frame(width: 144, height: 49)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding([.top, .bottom], 6)
        .id(colorScheme)
        // 搜尋按鈕。
        Button {
          viewModel.isShowingSearch = true
        } label: {
          Label("i18n:Menu.SearchPreferences", systemImage: "magnifyingglass")
        }
        .buttonStyle(.borderless)
        .frame(maxWidth: .infinity, alignment: .leading)
        Divider()
          .overlay {
            LinearGradient(
              colors: [
                Color.primary.opacity(0),
                Color.primary.opacity(1),
                Color.primary.opacity(0.5),
                Color.primary.opacity(0.3),
                Color.primary.opacity(0),
              ],
              startPoint: .leading,
              endPoint: .trailing
            )
            .frame(height: 1)
          }
      }.padding([.horizontal])
    }
    .safeAreaInset(edge: .bottom) {
      VStack(alignment: .leading) {
        Text("v" + IMEApp.appMainVersionLabel.joined(separator: " Build "))
          .settingsDescription()
        Text(IMEApp.appSignedDateLabel)
          .settingsDescription()
        if let hpURL = URL(string: "https://vchewing.github.io") {
          Link("i18n:settings.button.hpAndDonation", destination: hpURL)
            .controlSize(.small)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
      }.padding([.horizontal, .bottom])
    }
  }

  // MARK: - Detail View

  /// 以 ZStack 預渲染全部 page，令所有 UserDefRendered 的 onAppear 觸發，
  /// 從而事前完整收集 UserDef→Tab 映射。僅當前選中的 page 設為可見與可互動。
  @ViewBuilder
  private var detailView: some View {
    ZStack {
      ForEach(PrefUITabs.allCases) { tab in
        let isCurrentTab = viewModel.selectedTabID == tab
        let currentTabView = tab.suiView
          .environment(\.currentSettingsTab, tab)
          .opacity(viewModel.selectedTabID == tab ? 1 : 0)
          .allowsHitTesting(isCurrentTab)
        if viewModel.tabPagesNotSearchable.contains(tab) || !isCurrentTab {
          currentTabView
        } else {
          // 內建搜尋欄（右上角），Phrases/Clients/Services 不顯示。
          currentTabView
            .searchable(
              text: Bindable(viewModel).searchableText,
              prompt: Text(verbatim: "i18n:Settings.SearchCurrentPage".i18n)
            )
        }
      }
    }
  }

  // MARK: - Search Sheet

  @ViewBuilder
  private var searchSheet: some View {
    @Bindable
    var viewModel = viewModel
    VStack(spacing: 0) {
      // Search field.
      HStack {
        TextField("i18n:Menu.SearchPreferences", text: $viewModel.searchText)
          .textFieldStyle(.roundedBorder)
          .onSubmit {
            if let firstResult = viewModel.searchResults.first,
               let firstTab = firstResult.tabs.first {
              viewModel.navigateToTab(firstTab)
            }
          }
        Button("i18n:Common.Cancel") {
          viewModel.isShowingSearch = false
          viewModel.searchText = ""
        }
      }
      .padding()

      Divider()

      // Results.
      if viewModel.searchText.isEmpty {
        Spacer()
        Text("i18n:Settings.SearchPrompt")
          .foregroundColor(.secondary)
        Spacer()
      } else if viewModel.searchResults.isEmpty {
        Spacer()
        Text("i18n:Settings.NoSearchResults")
          .foregroundColor(.secondary)
        Spacer()
      } else {
        List(viewModel.searchResults) { result in
          Button {
            if let firstTab = result.tabs.first {
              viewModel.navigateToTab(firstTab)
            }
          } label: {
            VStack(alignment: .leading, spacing: 2) {
              Text(result.title)
                .font(.body)
              HStack(spacing: 4) {
                if !result.description.isEmpty {
                  Text(result.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                }
                if let tab = result.tabs.first {
                  Text("→ \(tab.i18nTitle)")
                    .font(.caption)
                    .foregroundColor(.accentColor)
                }
              }
            }
            .padding(.vertical, 2)
          }
          .buttonStyle(.plain)
        }
      }
    }
    .frame(width: 480, height: 400)
  }
}

// MARK: - VwrSettingsUI_Previews

@available(macOS 14, *)
struct VwrSettingsUI_Previews: PreviewProvider {
  static var previews: some View {
    VwrSettingsUI()
      .environment(SettingsUIViewModel())
  }
}
