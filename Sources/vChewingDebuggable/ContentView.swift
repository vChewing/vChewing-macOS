// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import AppKit
import Darwin
import MainAssembly4Darwin
import SwiftUI

// MARK: - ContentView

struct ContentView: View {
  // MARK: Internal

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("SettingsUI / SettingsCocoa Diagnostics Host")
        .font(.title2)
        .fontWeight(.semibold)

      Text(
        "Opens the two preference-window flavors inside this process for memory analysis. "
          + "Flip pages manually inside the settings windows; every open/close auto-samples "
          + "anonymous-private + malloc-zone telemetry (same purge-first semantics as the IME menu meter)."
      )
      .foregroundStyle(.secondary)

      HStack(spacing: 12) {
        Button("Open SettingsUI (SwiftUI)") { viewModel.openSettingsUI() }
          .disabled(viewModel.isBusy || viewModel.isSettingsUIVisible)
        Button("Close SettingsUI") { viewModel.closeSettingsUI() }
          .disabled(viewModel.isBusy || !viewModel.isSettingsUIVisible)
      }
      HStack(spacing: 12) {
        Button("Open SettingsCocoa (AppKit)") { viewModel.openSettingsCocoa() }
          .disabled(viewModel.isBusy || viewModel.isSettingsCocoaVisible)
        Button("Close SettingsCocoa") { viewModel.closeSettingsCocoa() }
          .disabled(viewModel.isBusy || !viewModel.isSettingsCocoaVisible)
      }
      HStack(spacing: 12) {
        Button("Sample now") { viewModel.sampleNow() }
          .disabled(viewModel.isBusy)
      }

      Text(viewModel.statusSummary)
        .font(.system(.callout, design: .monospaced))
        .foregroundStyle(.secondary)

      ScrollView {
        Text(viewModel.consoleText)
          .font(.system(.body, design: .monospaced))
          .frame(maxWidth: .infinity, alignment: .leading)
          .textSelection(.enabled)
      }
      .defaultScrollAnchor(.bottom)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .padding(12)
      .background(Color(nsColor: .textBackgroundColor))
      .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
    .padding(20)
    .frame(minWidth: 720, minHeight: 420)
    .onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { _ in
      viewModel.refreshState()
    }
  }

  // MARK: Private

  @State
  private var viewModel = DiagnosticsViewModel()
}

// MARK: - DiagnosticsViewModel

@MainActor
@Observable
final class DiagnosticsViewModel {
  // MARK: Lifecycle

  init() {
    bootstrap()
  }

  // MARK: Internal

  private(set) var isBusy = false
  private(set) var consoleText = ""
  private(set) var windowStateRevision = 0

  var isSettingsUIVisible: Bool {
    CtlSettingsUI.shared?.window?.isVisible ?? false
  }

  var isSettingsCocoaVisible: Bool {
    CtlSettingsCocoa.shared?.window?.isVisible ?? false
  }

  var statusSummary: String {
    [
      "SettingsUI (SwiftUI): \(isSettingsUIVisible ? "open" : "closed")",
      "SettingsCocoa (AppKit): \(isSettingsCocoaVisible ? "open" : "closed")",
      "Environment: \(Self.isBootstrapped ? "ready" : "not ready")",
    ].joined(separator: "   |   ")
  }

  func refreshState() {
    windowStateRevision += 1
  }

  func openSettingsUI() {
    log("Open SettingsUI (SwiftUI)…")
    CtlSettingsUI.show()
    scheduleSample(tag: "after open SettingsUI", delay: 0.6)
  }

  func closeSettingsUI() {
    log("Close SettingsUI…")
    CtlSettingsUI.shared?.close()
    scheduleSample(tag: "after close SettingsUI", delay: 0.8)
  }

  func openSettingsCocoa() {
    log("Open SettingsCocoa (AppKit)…")
    CtlSettingsCocoa.show()
    scheduleSample(tag: "after open SettingsCocoa", delay: 0.6)
  }

  func closeSettingsCocoa() {
    log("Close SettingsCocoa…")
    CtlSettingsCocoa.shared?.close()
    scheduleSample(tag: "after close SettingsCocoa", delay: 0.8)
  }

  func sampleNow() {
    sampleMemory(tag: "manual sample")
  }

  // MARK: Private

  private static var isBootstrapped = false

  private let suiteName = "org.atelierInmu.vChewing.vChewingDebuggable.Diagnostics"

  private static func bootstrapSandbox(suiteName: String) throws {
    UserDefaults.unitTests = .init(suiteName: suiteName)
    UserDefaults.pendingUnitTests = true
    UserDef.resetAll()
    LMMgr.prepareForUnitTests()
    LMAssembly.LMInstantiator.asyncLoadingUserData = false
    SettingsUIHost.wireUp()
    SessionHost.wireUp()
    guard let factoryPath = LMMgr.getCoreDictionaryDBPath(factory: true) else {
      throw DiagnosticsError.factoryLexiconNotFound
    }
    LMMgr.connectCoreDB(dbPath: factoryPath)
  }

  nonisolated private static func privateAnonymousMB() -> Double {
    var info = task_vm_info_data_t()
    var count = mach_msg_type_number_t(
      MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size
    )
    let kr = withUnsafeMutablePointer(to: &info) {
      $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
        task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
      }
    }
    guard kr == KERN_SUCCESS else { return -1 }
    return Double(info.internal) / 1_048_576
  }

  private func bootstrap() {
    guard !Self.isBootstrapped else { return }
    isBusy = true
    log("Bootstrapping sandboxed environment…")
    Task { @MainActor in
      defer { isBusy = false }
      do {
        try Self.bootstrapSandbox(suiteName: suiteName)
        Self.isBootstrapped = true
        log("Environment ready (unit-test suite: \(suiteName)). Factory lexicon connected.")
        log("Flip pages manually inside the settings windows; telemetry auto-samples on every open/close.")
        sampleMemory(tag: "baseline (after env ready)")
      } catch {
        log("Bootstrap failed: \(error.localizedDescription)")
      }
    }
  }

  private func scheduleSample(tag: String, delay: Double) {
    Task { @MainActor in
      try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
      sampleMemory(tag: tag)
    }
  }

  private func sampleMemory(tag: String) {
    // 與輸入法選單讀數同語義：先請 malloc 歸還空閒頁，再取匿名私有頁與預設 zone 統計。
    malloc_zone_pressure_relief(nil, 0)
    var stats = malloc_statistics_t()
    malloc_zone_statistics(malloc_default_zone(), &stats)
    let line = tag
      + String(
        format: " | internal=%.1fMB | malloc inUse=%.1fMB / allocated=%.1fMB",
        Self.privateAnonymousMB(),
        Double(stats.size_in_use) / 1_048_576,
        Double(stats.size_allocated) / 1_048_576
      )
    log(line)
  }

  private func log(_ line: String) {
    if consoleText.isEmpty {
      consoleText = line
    } else {
      consoleText += "\n" + line
    }
  }
}

// MARK: - DiagnosticsError

private enum DiagnosticsError: LocalizedError {
  case factoryLexiconNotFound

  // MARK: Internal

  var errorDescription: String? {
    switch self {
    case .factoryLexiconNotFound:
      return "Bundled factory lexicon was not found in MainAssembly4Darwin resources."
    }
  }
}

// MARK: - ContentView_Previews

#Preview {
  ContentView()
}
