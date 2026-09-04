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
          + "Every open/close auto-samples anonymous-private + malloc-zone telemetry; log is "
          + "mirrored to ~/Library/Logs/vChewingDebuggable.log."
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
        Button("Snapshot heap") { viewModel.snapshotHeap() }
          .disabled(viewModel.isBusy || viewModel.isHeapBusy)
        Button("Snapshot malloc_history") { viewModel.snapshotMallocHistory() }
          .disabled(viewModel.isBusy || viewModel.isMhBusy)
      }
      HStack(spacing: 12) {
        Button("Reveal log folder") { viewModel.revealLogFolder() }
          .disabled(viewModel.isBusy)
        Button("Clear logs") { viewModel.clearLogs() }
          .disabled(viewModel.isBusy)
      }

      Text(viewModel.statusSummary)
        .font(.system(.callout))
        .fontWidth(.condensed)
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
  private var viewModel = DiagnosticsViewModel.shared
}

// MARK: - DiagnosticsViewModel

@MainActor
@Observable
final class DiagnosticsViewModel {
  // MARK: Lifecycle

  init() {
    // 於 VM 建立當下同步啟用 pendingUnitTests（不等 bootstrap Task），
    // 確保任何設定窗顯示路徑都看到 true——CtlSettingsUI/Cocoa 的
    // 強制置前/層級 bypass 依賴此旗標。
    UserDefaults.pendingUnitTests = true
    bootstrap()
  }

  // MARK: Internal

  static let shared = DiagnosticsViewModel()

  private(set) var isBusy = false
  private(set) var isHeapBusy = false
  private(set) var isMhBusy = false
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
      "pendingUnitTests: \(UserDefaults.pendingUnitTests ? "on" : "off")",
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

  func flipCocoaPage(to pageName: String) {
    guard let tab = PrefUITabs.allCases.first(where: {
      $0.rawValue.caseInsensitiveCompare(pageName) == .orderedSame
        || String(describing: $0).caseInsensitiveCompare(pageName) == .orderedSame
    }) else {
      log("Unknown SettingsCocoa page: \(pageName)")
      return
    }
    if !(CtlSettingsCocoa.shared?.window?.isVisible ?? false) {
      CtlSettingsCocoa.show()
    }
    log("SettingsCocoa page → \(tab.rawValue)…")
    CtlSettingsCocoa.shared?.selectTab(tab)
    scheduleSample(tag: "after page \(tab.rawValue)", delay: 0.8)
  }

  func sampleNow() {
    sampleMemory(tag: "manual sample")
  }

  func handle(url: URL) {
    log("URL command: \(url.absoluteString)")
    switch url.host?.lowercased() {
    case "opensettingsui": openSettingsUI()
    case "closesettingsui": closeSettingsUI()
    case "opensettingscocoa": openSettingsCocoa()
    case "closesettingscocoa": closeSettingsCocoa()
    case "page": flipCocoaPage(to: url.lastPathComponent)
    case "sample":
      sampleMemory(tag: Self.queryItem(url, "tag") ?? "external sample")
    case "heap":
      snapshotHeap(tag: Self.queryItem(url, "tag") ?? "external heap snapshot")
    case "mh":
      snapshotMallocHistory(tag: Self.queryItem(url, "tag") ?? "external malloc_history snapshot")
    case "refresh": refreshState()
    case "reset": resetLogs()
    case "clear": clearLogs()
    case "reveal": revealLogFolder()
    default: log("Unknown URL command: \(url.absoluteString)")
    }
  }

  func resetLogs() {
    consoleText = ""
    try? Data().write(to: Self.logFileURL)
    log("Logs reset.")
  }

  func clearLogs() {
    consoleText = ""
    let fm = FileManager.default
    let dir = Self.logsDirectory
    if let names = try? fm.contentsOfDirectory(atPath: dir.path) {
      for name in names
        where name.hasPrefix("vChewingDebuggable-") && name.hasSuffix(".txt") {
        try? fm.removeItem(at: dir.appendingPathComponent(name))
      }
    }
    try? Data().write(to: Self.logFileURL)
    log("Logs cleared (incl. heap/mh dumps).")
  }

  func revealLogFolder() {
    log("Revealing log folder…")
    NSWorkspace.shared.open(Self.logsDirectory)
  }

  func snapshotHeap(tag: String = "heap snapshot") {
    guard !isHeapBusy else { return }
    isHeapBusy = true
    log("\(tag)… running /usr/bin/heap on self")
    let pid = String(ProcessInfo.processInfo.processIdentifier)
    Task { @MainActor in
      defer { isHeapBusy = false }
      do {
        let capture = try await Self.captureHeap(pid: pid)
        let target = Self.heapOutputURL()
        try capture.text.write(to: target, atomically: true, encoding: .utf8)
        log("heap snapshot → \(target.path) (\(capture.lineCount) lines)")
      } catch {
        log("heap snapshot failed: \(error.localizedDescription)")
      }
    }
  }

  func snapshotMallocHistory(tag: String = "malloc_history snapshot") {
    guard !isMhBusy else { return }
    isMhBusy = true
    log("\(tag)… running /usr/bin/malloc_history -callTree on self")
    let pid = String(ProcessInfo.processInfo.processIdentifier)
    Task { @MainActor in
      defer { isMhBusy = false }
      do {
        let capture = try await Self.captureMallocHistory(pid: pid)
        let target = Self.mallocHistoryOutputURL()
        try capture.text.write(to: target, atomically: true, encoding: .utf8)
        log("malloc_history snapshot → \(target.path) (\(capture.lineCount) lines)")
      } catch {
        log("malloc_history snapshot failed: \(error.localizedDescription)")
      }
    }
  }

  // MARK: Private

  private static var isBootstrapped = false

  nonisolated private static var stampFormatter: DateFormatter {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyyMMdd-HHmmss"
    return formatter
  }

  nonisolated private static var lineFormatter: DateFormatter {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm:ss.SSS"
    return formatter
  }

  // MARK: - File logging

  nonisolated private static var logsDirectory: URL {
    let library = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
    let directory = library.appendingPathComponent("Logs", isDirectory: true)
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
  }

  nonisolated private static var logFileURL: URL {
    logsDirectory.appendingPathComponent("vChewingDebuggable.log")
  }

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

  nonisolated private static func heapOutputURL() -> URL {
    let stamp = stampFormatter.string(from: Date())
    return logsDirectory.appendingPathComponent("vChewingDebuggable-heap-\(stamp).txt")
  }

  nonisolated private static func mallocHistoryOutputURL() -> URL {
    let stamp = stampFormatter.string(from: Date())
    return logsDirectory.appendingPathComponent("vChewingDebuggable-mh-\(stamp).txt")
  }

  nonisolated private static func appendLogFileSync(_ line: String) {
    guard let newData = (line + "\n").data(using: .utf8) else { return }
    var existing = (try? Data(contentsOf: logFileURL)) ?? Data()
    existing.append(newData)
    try? existing.write(to: logFileURL)
  }

  nonisolated private static func queryItem(_ url: URL, _ name: String) -> String? {
    URLComponents(url: url, resolvingAgainstBaseURL: false)?
      .queryItems?.first { $0.name == name }?.value
  }

  nonisolated private static func captureHeap(pid: String) async throws -> (text: String, lineCount: Int) {
    try await Task.detached(priority: .userInitiated) {
      let process = Process()
      process.executableURL = URL(fileURLWithPath: "/usr/bin/heap")
      process.arguments = ["-sortBySize", pid]
      let pipe = Pipe()
      process.standardOutput = pipe
      process.standardError = pipe
      try process.run()
      let data = pipe.fileHandleForReading.readDataToEndOfFile()
      process.waitUntilExit()
      let text = String(decoding: data, as: UTF8.self)
      return (text, text.split(separator: "\n").count)
    }.value
  }

  nonisolated private static func captureMallocHistory(pid: String) async throws -> (text: String, lineCount: Int) {
    try await Task.detached(priority: .userInitiated) {
      let process = Process()
      process.executableURL = URL(fileURLWithPath: "/usr/bin/malloc_history")
      process.arguments = ["-callTree", pid]
      let pipe = Pipe()
      process.standardOutput = pipe
      process.standardError = pipe
      try process.run()
      let data = pipe.fileHandleForReading.readDataToEndOfFile()
      process.waitUntilExit()
      let text = String(decoding: data, as: UTF8.self)
      return (text, text.split(separator: "\n").count)
    }.value
  }

  nonisolated private static func machineName() -> String {
    var info = utsname()
    guard uname(&info) == 0 else { return "unknown" }
    return withUnsafeBytes(of: &info.machine) { raw in
      guard let base = raw.bindMemory(to: CChar.self).baseAddress else { return "unknown" }
      return String(cString: base)
    }
  }

  nonisolated private static func osDescription() -> String {
    let version = ProcessInfo.processInfo.operatingSystemVersion
    var size = 0
    sysctlbyname("kern.osversion", nil, &size, nil, 0)
    var buffer = [CChar](repeating: 0, count: max(size, 1))
    if size > 0 {
      sysctlbyname("kern.osversion", &buffer, &size, nil, 0)
    }
    let build = String(cString: buffer)
    return "macOS \(version.majorVersion).\(version.minorVersion).\(version.patchVersion) (\(build))"
  }

  private func bootstrap() {
    guard !Self.isBootstrapped else { return }
    isBusy = true
    log(
      "Session | OS: \(Self.osDescription()) | machine: "
        + "\(Self.machineName()) | pid: \(ProcessInfo.processInfo.processIdentifier)"
    )
    log("Bootstrapping sandboxed environment…")
    Task { @MainActor in
      defer { isBusy = false }
      do {
        try Self.bootstrapSandbox(suiteName: suiteName)
        Self.isBootstrapped = true
        log("Environment ready (unit-test suite: \(suiteName)). Factory lexicon connected.")
        log("pendingUnitTests=\(UserDefaults.pendingUnitTests) (settings-window front/level bypass active).")
        log("Log file: \(Self.logFileURL.path)")
        log(
          "External control: open vchewingdbg://{openSettingsUI|closeSettingsUI|openSettingsCocoa|closeSettingsCocoa|page/<CocoaTab>|sample|heap|mh|reset|clear|reveal}"
        )
        log("Remote page flip: vchewingdbg://page/<CocoaTab>; telemetry auto-samples on every open/close/page.")
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
    appendLogFile(line)
  }

  private func appendLogFile(_ line: String) {
    Self.appendLogFileSync(Self.lineFormatter.string(from: Date()) + "  " + line)
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
