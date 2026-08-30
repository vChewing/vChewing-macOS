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

            Button {
              if let url = URL(string: "https://vchewing.github.io/") {
                NSWorkspace.shared.open(url)
              }
            } label: {
              // 按鈕寬度有限：優先使用 Arial Narrow Bold，不可用時回退至系統預設粗體。
              Text("i18n:installer.HP_AND_DONATION")
                .frame(width: 114)
                .font(Font(
                  NSFont(name: "ArialNarrow-Bold", size: NSFont.systemFontSize)
                    ?? NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)
                ))
            }
          }.fixedSize(horizontal: true, vertical: true)
        }
        Spacer()
      }
      .font(.custom("Tahoma", size: 12))
      .padding(4)
    }
    // 警示：SwiftUI 將多個 alert 串接在同一個 view 上時只會有最後一個生效，
    // 因此使用單一 alert 並透過 alertItem 驅動內容切換。
    .onChange(of: vm.config.currentAlertContent) { _ in
      vm.updateAlertItemFromConfig()
    }
    .onChange(of: vm.config.adminRenameFailureAlertPaths) { _ in
      vm.updateAlertItemFromConfig()
    }
    .alert(item: $vm.config.alertItem) { item in
      Alert(
        title: Text(item.title),
        message: Text(item.message),
        dismissButton: .cancel(Text(item.buttonTitle), action: {
          NSApp.terminateWithDelay()
        })
      )
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

  /// 將 `currentAlertContent` 與 `adminRenameFailureAlertPaths` 同步成單一 `alertItem`，
  /// 供 SwiftUI 的 `alert(item:)` 使用。
  func updateAlertItemFromConfig() {
    guard config.currentAlertContent != .nothing else { return }
    config.alertItem = config.currentAlertContent.makeAlertItem(paths: config.adminRenameFailureAlertPaths)
  }
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
          Color(red: 0.93, green: 0.49, blue: 0.21),
          Color(red: 0.31, green: 0.73, blue: 0.30),
          Color(red: 0.38, green: 0.58, blue: 0.81),
          Color(red: 0.97, green: 0.84, blue: 0.02),
        ]
      )
    } else {
      Canvas { context, size in
        // 角落顏色（sRGB 分量）
        let c00: SIMD3<Double> = [0.93, 0.49, 0.21] // top-left
        let c10: SIMD3<Double> = [0.31, 0.73, 0.30] // top-right
        let c01: SIMD3<Double> = [0.38, 0.58, 0.81] // bottom-left
        let c11: SIMD3<Double> = [0.97, 0.84, 0.02] // bottom-right

        let steps = 64
        let cellW = size.width / CGFloat(steps)
        let cellH = size.height / CGFloat(steps)

        for y in 0 ..< steps {
          for x in 0 ..< steps {
            let u = (Double(x) + 0.5) / Double(steps)
            let v = (Double(y) + 0.5) / Double(steps)

            // linear space bilinear
            let top = context.lerp(context.srgbToLinear(c00), context.srgbToLinear(c10), t: u)
            let bottom = context.lerp(context.srgbToLinear(c01), context.srgbToLinear(c11), t: u)
            let linear = context.lerp(top, bottom, t: v)
            let srgb = context.linearToSrgb(linear)

            let color = Color(red: srgb.x, green: srgb.y, blue: srgb.z)

            let rect = CGRect(
              x: CGFloat(x) * cellW,
              y: CGFloat(y) * cellH,
              width: cellW + 0.5,
              height: cellH + 0.5
            )
            context.fill(Path(rect), with: .color(color))
          }
        }
      }
    }
  }
}

// MARK: - Helpers

extension GraphicsContext {
  fileprivate func lerp(_ a: SIMD3<Double>, _ b: SIMD3<Double>, t: Double) -> SIMD3<Double> {
    a + (b - a) * t
  }

  fileprivate func srgbToLinear(_ c: SIMD3<Double>) -> SIMD3<Double> {
    SIMD3(
      srgbChannelToLinear(c.x),
      srgbChannelToLinear(c.y),
      srgbChannelToLinear(c.z)
    )
  }

  fileprivate func linearToSrgb(_ c: SIMD3<Double>) -> SIMD3<Double> {
    SIMD3(
      linearChannelToSrgb(c.x),
      linearChannelToSrgb(c.y),
      linearChannelToSrgb(c.z)
    )
  }

  fileprivate func srgbChannelToLinear(_ channel: Double) -> Double {
    if channel <= 0.04045 {
      return channel / 12.92
    } else {
      return pow((channel + 0.055) / 1.055, 2.4)
    }
  }

  fileprivate func linearChannelToSrgb(_ channel: Double) -> Double {
    if channel <= 0.0031308 {
      return channel * 12.92
    } else {
      return 1.055 * pow(channel, 1.0 / 2.4) - 0.055
    }
  }
}
