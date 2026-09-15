// (c) 2022 and onwards The vChewing Project (MulanPSL-2.0 License).
// ====================
// This code is released under the SPDX-License-Identifier: `MulanPSL-2.0`.

// 本檔為 SwiftUI 專屬，legacy 倉庫（＝本倉的「子集 ＋ Swift 5.10 Dialect」，砍掉了 SwiftUI）無對位模組可繼承；
// 依「SwiftUI 之任何內容不得裸露於 5.10 可編的路徑上」整段圈進 compiler condition，<6.2 分支不提供替代實作。
#if compiler(>=6.2)

  import SwiftUI

  // MARK: - VwrSettingsPaneAbout

  @available(macOS 14, *)
  public struct VwrSettingsPaneAbout: View {
    public static var copyrightLabel: String { SettingsPanesCocoa.About.copyrightLabel }
    public static var eulaContent: String { SettingsPanesCocoa.About.eulaContent }

    // MARK: - Main View

    public var body: some View {
      Form {
        Section {
          HStack(alignment: .top) {
            if let banner = NSImage(named: "AboutBanner") {
              Image(nsImage: banner).resizable().frame(width: 63, height: 310)
            }
            VStack(alignment: .leading) {
              HStack(alignment: .center) {
                VStack(alignment: .leading) {
                  Text("i18n:aboutWindow.APP_NAME").fontWeight(.heavy)
                  Text(
                    "v\(IMEApp.appMainVersionLabel.joined(separator: " Build ")) - \(IMEApp.appSignedDateLabel)"
                  )
                  .font(.system(size: 11))
                  .foregroundStyle(.secondary)
                  .lineLimit(1)
                  Text("i18n:aboutWindow.DONATION_MESSAGE")
                    .font(.system(size: 11))
                    .padding([.vertical], 2)
                  Text(Self.copyrightLabel)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                  Text("i18n:aboutWindow.DEV_CREW")
                    .font(.system(size: 11))
                    .fixedSize()
                    .padding([.vertical], 2)
                    .foregroundStyle(.secondary)
                }
              }
              GroupBox(label: Text("i18n:aboutWindow.LICENSE_TITLE")) {
                ScrollView(.vertical, showsIndicators: true) {
                  HStack {
                    Text(Self.eulaContent).textSelection(.enabled)
                      .frame(maxWidth: 455)
                      .font(.system(size: 11))
                    Spacer()
                  }
                }.padding(4).frame(minHeight: 128, maxHeight: .infinity)
              }
            }
            .frame(maxWidth: .infinity)
          }
          .frame(height: 310)
          .font(.system(size: 12))
          HStack(alignment: .top) {
            Text("i18n:aboutWindow.DISCLAIMER_TEXT")
              .font(.system(size: 11))
              .opacity(0.5)
              .frame(maxWidth: .infinity)
          }
          .font(.system(size: 11))
        } footer: {
          HStack(spacing: 16) {
            if let url = URL(string: "https://vchewing.github.io/") {
              Link("i18n:aboutWindow.WEBSITE_BUTTON".i18n, destination: url)
            }
            if let url = URL(string: "https://vchewing.github.io/BUGREPORT.html") {
              Link("i18n:aboutWindow.BUGREPORT_BUTTON".i18n, destination: url)
            }
          }
          .frame(maxWidth: .infinity, alignment: .trailing)
          .font(.system(size: 11))
        }
      }.formStyled()
        .frame(
          minWidth: CtlSettingsUI.formWidth,
          maxHeight: CtlSettingsUI.contentMaxHeight
        )
    }
  }

  // MARK: - VwrSettingsPaneAbout_Previews

  @available(macOS 14, *)
  struct VwrSettingsPaneAbout_Previews: PreviewProvider {
    static var previews: some View {
      VwrSettingsPaneAbout()
    }
  }

#endif
