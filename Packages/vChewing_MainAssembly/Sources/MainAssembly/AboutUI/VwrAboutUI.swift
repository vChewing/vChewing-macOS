// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import AppKit
import SwiftUI

// MARK: - VwrAboutUI

public struct VwrAboutUI {
  // MARK: Public

  public static var copyrightLabel: String { VwrAboutCocoa.copyrightLabel }
  public static var eulaContent: String { VwrAboutCocoa.eulaContent }
  public static var eulaContentUpstream: String { VwrAboutCocoa.eulaContentUpstream }

  // MARK: Internal

  let foobar = "FOO_BAR"
}

// MARK: View

@available(macOS 12, *)
extension VwrAboutUI: View {
  public var body: some View {
    GroupBox {
      VStack(alignment: .leading, spacing: 6) {
        VStack(alignment: .leading) {
          HStack(alignment: .center) {
            if let icon = NSImage(named: "IconSansMargin") {
              Image(nsImage: icon).resizable().frame(width: 90, height: 90)
            }
            VStack(alignment: .leading) {
              HStack {
                Text("i18n:AboutWindow.APP_NAME").fontWeight(.heavy).lineLimit(1)
                Text(
                  "v\(IMEApp.appMainVersionLabel.joined(separator: " Build ")) - \(IMEApp.appSignedDateLabel)"
                )
                .lineLimit(1)
              }.fixedSize()
              Text("i18n:AboutWindow.DONATION_MESSAGE").font(.custom("Tahoma", size: 11))
              Text(Self.copyrightLabel).font(.custom("Tahoma", size: 11))
              Text("i18n:AboutWindow.DEV_CREW").font(.custom("Tahoma", size: 11))
                .padding([.vertical], 2)
            }
          }
          GroupBox(label: Text("i18n:AboutWindow.LICENSE_TITLE")) {
            ScrollView(.vertical, showsIndicators: true) {
              HStack {
                Text(Self.eulaContent + "\n" + Self.eulaContentUpstream).textSelection(.enabled)
                  .frame(maxWidth: 455)
                  .font(.custom("Tahoma", size: 11))
                Spacer()
              }
            }.padding(4).frame(height: 128)
          }
        }
        Divider()
        HStack(alignment: .top) {
          Text("i18n:AboutWindow.DISCLAIMER_TEXT")
            .font(.custom("Tahoma", size: 11))
            .opacity(0.5)
            .frame(maxWidth: .infinity)
          VStack(spacing: 4) {
            Button {
              CtlAboutUI.shared?.window?.close()
            } label: {
              Text("i18n:AboutWindow.OK_BUTTON").frame(width: 114)
            }
            .keyboardShortcut(.defaultAction)
            Button {
              if let url = URL(string: "https://vchewing.github.io/") {
                NSWorkspace.shared.open(url)
              }
            } label: {
              Text("i18n:AboutWindow.WEBSITE_BUTTON").frame(width: 114)
            }
            Button {
              if let url = URL(string: "https://vchewing.github.io/BUGREPORT.html") {
                NSWorkspace.shared.open(url)
              }
            } label: {
              Text("i18n:AboutWindow.BUGREPORT_BUTTON").frame(width: 114)
            }
          }.fixedSize(horizontal: true, vertical: true)
        }
        Spacer()
      }
      .font(.custom("Tahoma", size: 12))
      .padding(4)
    }
    // OTHER
    .padding([.horizontal, .bottom], 12)
    .frame(width: 533, alignment: .topLeading)
    .fixedSize()
    .frame(
      minWidth: 533,
      idealWidth: 533,
      maxWidth: 533,
      minHeight: 386,
      idealHeight: 386,
      maxHeight: 386,
      alignment: .top
    )
  }
}
