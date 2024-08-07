// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Shared
import SwiftUI

// MARK: - VwrSettingsUI

@available(macOS 13, *)
public struct VwrSettingsUI: View {
  // MARK: Lifecycle

  public init() {}

  // MARK: Public

  /// 雖說從 macOS 13 開始的正確做法是使用 NavigationSplitView，
  /// 但由於這個畫面是藉由 NSHostingView 叫出來的、所以無法正確處理大型標題列。
  /// 目前還是暫時繼續用 NavigationView。
  public var body: some View {
    NavigationView {
      VStack {
        List(PrefUITabs.allCases, selection: $selectedTabID) { neta in
          if neta == PrefUITabs.tabGeneral {
            if let appIcon = NSImage(named: "IconSansMargin") {
              Image(nsImage: appIcon).resizable()
                .frame(width: 86, height: 86)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding([.top, .bottom], NSFont.systemFontSize / 2)
            }
          }
          NavigationLink(destination: neta.suiView) {
            Label {
              Text(verbatim: neta.i18nTitle)
            } icon: {
              Image(nsImage: neta.icon)
            }
          }
        }
        Spacer()
        VStack(alignment: .leading) {
          Text("v" + IMEApp.appMainVersionLabel.joined(separator: " Build "))
          Text(IMEApp.appSignedDateLabel)
        }.settingsDescription().padding()
      }
      .navigationTitle(PrefUITabs.tabGeneral.i18nTitle)
      .frame(minWidth: 128, idealWidth: 128, maxWidth: 128)
      PrefUITabs.tabGeneral.suiView
    }
    .frame(width: CtlSettingsUI.formWidth + 140, height: CtlSettingsUI.contentMaxHeight)
  }

  // MARK: Private

  @State
  private var selectedTabID: PrefUITabs?
}

// MARK: - VwrSettingsUI_Previews

@available(macOS 13, *)
struct VwrSettingsUI_Previews: PreviewProvider {
  static var previews: some View {
    VwrSettingsUI()
  }
}
