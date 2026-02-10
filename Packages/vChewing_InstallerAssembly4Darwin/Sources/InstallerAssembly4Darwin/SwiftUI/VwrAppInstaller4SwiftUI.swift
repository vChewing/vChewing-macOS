// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Combine
import IMKUtils
import InputMethodKit
import OSFrameworkImpl
import SwiftExtension
import SwiftUI

// MARK: - VwrAppInstaller4SwiftUI

@available(macOS 12, *)
struct VwrAppInstaller4SwiftUI: View {
  // MARK: Lifecycle

  init() {}

  // MARK: Internal

  var body: some View {
    GroupBox {
      VStack(alignment: .leading, spacing: 6) {
        VStack(alignment: .leading) {
          HStack(alignment: .center) {
            if let icon = NSImage(named: "AppIcon") {
              Image(nsImage: icon).resizable().frame(width: 120, height: 120)
            }
            VStack(alignment: .leading, spacing: 2) {
              HStack {
                Text("i18n:installer.APP_NAME").fontWeight(.heavy).lineLimit(1)
                Text("v\(versionString) Build \(installingVersion)").lineLimit(1)
              }.fixedSize()
              if let minimumOSSupportedDescriptionString {
                Text(verbatim: minimumOSSupportedDescriptionString)
                  .font(.custom("Tahoma", size: 11))
                  .padding([.vertical], 2)
              }
              Text("i18n:installer.DONATION_MESSAGE").font(.custom("Tahoma", size: 11))
              Text(copyrightLabel).font(.custom("Tahoma", size: 11))
              Text("i18n:installer.DEV_CREW").font(.custom("Tahoma", size: 11))
                .padding([.vertical], 2)
            }
          }
          GroupBox(label: Text("i18n:installer.LICENSE_TITLE")) {
            ScrollView(.vertical, showsIndicators: true) {
              HStack {
                Text(eulaContent + "\n" + eulaContentUpstream).textSelection(.enabled)
                  .frame(maxWidth: .infinity, alignment: .leading)
                  .frame(maxWidth: 455)
                  .font(.custom("Tahoma", size: 11))
                Spacer()
              }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(4)
            .frame(height: 128)
          }
          Text("i18n:installer.EULA_PROMPT_NOTICE").bold().padding(.bottom, 2)
        }
        Divider()
        HStack(alignment: .top) {
          Text("i18n:installer.DISCLAIMER_TEXT")
            .font(.custom("Tahoma", size: 11))
            .opacity(0.5)
            .frame(maxWidth: .infinity, alignment: .leading)
          VStack(spacing: 4) {
            Button { vm.installationButtonClicked() } label: {
              Text(
                vm.config.isUpgrading ? "i18n:installer.DO_APP_UPGRADE" :
                  "i18n:installer.ACCEPT_INSTALLATION"
              )
              .bold().frame(width: 114)
            }
            .keyboardShortcut(.defaultAction)
            .disabled(!vm.config.isCancelButtonEnabled)
            Button(role: .cancel) { NSApp.terminateWithDelay() } label: {
              Text("i18n:installer.CANCEL_INSTALLATION").frame(width: 114)
            }
            .keyboardShortcut(.cancelAction)
            .disabled(!vm.config.isAgreeButtonEnabled)
          }.fixedSize(horizontal: true, vertical: true)
        }
        Spacer()
      }
      .font(.custom("Tahoma", size: 12))
      .padding(4)
    }
    // 警示
    .alert(AlertType.installationFailed.titleLocalized, isPresented: $vm.config.isShowingAlertForFailedInstallation) {
      Button(role: .cancel) { NSApp.terminateWithDelay() } label: { Text("Cancel") }
    } message: {
      Text(AlertType.installationFailed.message)
    }
    .alert(
      AlertType.missingAfterRegistration.titleLocalized,
      isPresented: $vm.config.isShowingAlertForMissingPostInstall
    ) {
      Button(role: .cancel) { NSApp.terminateWithDelay() } label: { Text("Abort") }
    } message: {
      Text(AlertType.missingAfterRegistration.message)
    }
    .alert(vm.config.currentAlertContent.titleLocalized, isPresented: $vm.config.isShowingPostInstallNotification) {
      Button(role: .cancel) { NSApp.terminateWithDelay() } label: {
        Text(vm.config.currentAlertContent == .postInstallWarning ? "Continue" : "OK")
      }
    } message: {
      Text(vm.config.currentAlertContent.message)
    }
    // 停止舊版本的 sheet
    .sheet(isPresented: $vm.config.pendingSheetPresenting) {
      // TODO：在 sheet 被關閉後需執行的工作。
    } content: {
      VStack(spacing: 6) {
        Text("i18n:installer.STOPPING_THE_OLD_VERSION")
        Text("i18n:installer.STOPPING_TIMEOUT_REMAINING" + ": \(vm.config.timeRemaining)s")
          .font(.custom("Tahoma", size: 11))
      }
      .frame(width: 407, height: 144)
    }
    // 其他
    .padding(12)
    .frame(width: 533, alignment: .topLeading)
    .navigationTitle(mainWindowTitle)
    .fixedSize()
    .foregroundStyle(Color(nsColor: NSColor.textColor))
    .background(Color(nsColor: NSColor.windowBackgroundColor))
    .clipShape(RoundedRectangle(cornerRadius: 16))
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

  // MARK: Private

  private typealias AlertType = InstallerUIConfig.AlertType

  @StateObject
  private var vm = InstallerMainViewModel()
}

// MARK: - InstallerMainViewModel

@available(macOS 12, *)
private final class InstallerMainViewModel: ObservableObject, InstallerVMProtocol {
  // MARK: Lifecycle

  init() {
    updateUpgradeableStatus()
  }

  deinit {
    mainSync {
      stopTranslocationTimer()
    }
  }

  // MARK: Internal

  @Published
  var config: InstallerUIConfig = .init()
  let taskQueue: DispatchQueue = .init(label: "vChewingInstaller.Queue.\(UUID().uuidString)")
  var translocationTimer: DispatchSourceTimer?
}

// MARK: - GradientViewWrapper

@available(macOS 12, *)
struct GradientViewWrapper: ViewModifier {
  // MARK: Lifecycle

  init(titleText: LocalizedStringKey) {
    self.titleText = titleText
  }

  // MARK: Internal

  func body(content: Content) -> some View {
    makeGradient()
      .frame(minWidth: 1_000, maxWidth: .infinity, minHeight: 630, maxHeight: .infinity)
      .overlay(alignment: .topLeading) {
        Text(titleText)
          .font(.system(size: 30))
          .italic().bold()
          .padding()
          .foregroundStyle(Color.white)
          .shadow(color: .black, radius: 0, x: 5, y: 5)
      }
      .overlay {
        content
          .shadow(color: .black, radius: 3, x: 0, y: 0)
      }
  }

  // MARK: Private

  private let titleText: LocalizedStringKey

  @ViewBuilder
  private func makeGradient() -> some View {
    if #available(macOS 15.0, *) {
      MeshGradient(
        width: 2,
        height: 2,
        points: [
          [0, 0], [1, 0],
          [0, 1], [1, 1],
        ],
        colors: [
          Color(red: 28 / 255, green: 46 / 255, blue: 61 / 255),
          Color(red: 61 / 255, green: 98 / 255, blue: 126 / 255),
          Color(red: 145 / 255, green: 189 / 255, blue: 224 / 255),
          Color(red: 193 / 255, green: 207 / 255, blue: 217 / 255),
        ]
      )
    } else {
      LinearGradient(
        gradient: Gradient(
          colors: [
            Color(red: 28 / 255, green: 46 / 255, blue: 61 / 255),
            Color(red: 145 / 255, green: 189 / 255, blue: 224 / 255),
          ]
        ),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
    }
  }
}
