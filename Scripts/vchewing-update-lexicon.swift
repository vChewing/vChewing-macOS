#!/usr/bin/env swift
import Foundation

// MARK: - Shell

enum Shell {
  @discardableResult
  static func run(_ cmd: String, cwd: String? = nil, captureOutput: Bool = true, trim: Bool = true)
    -> (status: Int32, output: String) {
    let task = Process()
    task.launchPath = "/bin/bash"
    task.arguments = ["-lc", cmd]
    if let cwd = cwd {
      task.currentDirectoryPath = cwd
    }
    let pipe = Pipe()
    task.standardOutput = pipe
    task.standardError = pipe
    do { try task.run() } catch {
      return (-1, "Error: \(error)")
    }
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    task.waitUntilExit()
    let str = String(data: data, encoding: .utf8) ?? ""
    if trim {
      return (task.terminationStatus, str.trimmingCharacters(in: .whitespacesAndNewlines))
    } else {
      return (task.terminationStatus, str)
    }
  }

  @discardableResult
  static func runExec(
    _ executable: String,
    args: [String] = [],
    cwd: String? = nil,
    captureOutput: Bool = true,
    trim: Bool = true,
    timeout: TimeInterval? = nil
  )
    -> (status: Int32, output: String) {
    let task = Process()
    let pipe = Pipe()
    task.executableURL = URL(fileURLWithPath: executable)
    task.arguments = args
    if let cwd = cwd { task.currentDirectoryPath = cwd }
    task.standardOutput = pipe
    task.standardError = pipe
    do { try task.run() } catch { return (-1, "Error: \(error)") }
    // 只有真的要計時才建立 dispatch source：suspended 狀態下被釋放的 source 會讓 libdispatch
    // 直接 SIGTRAP（`Release of a suspended object`），故 timeout 為 nil 時不得先把 source 造出來。
    var timer: DispatchSourceTimer?
    if let timeout = timeout {
      let source = DispatchSource.makeTimerSource(queue: DispatchQueue.global())
      source.schedule(deadline: .now() + timeout)
      source.setEventHandler {
        if task.isRunning { task.terminate() }
      }
      source.resume()
      timer = source
    }
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    task.waitUntilExit()
    timer?.cancel()
    let str = String(data: data, encoding: .utf8) ?? ""
    if !trim { return (task.terminationStatus, str) }
    return (task.terminationStatus, str.trimmingCharacters(in: .whitespacesAndNewlines))
  }
}

var repoPath = FileManager.default.currentDirectoryPath
var dryRun = false

// Parse arguments if path is provided
var idx = 1
while idx < CommandLine.arguments.count {
  switch CommandLine.arguments[idx] {
  case "--dry-run":
    dryRun = true
    idx += 1
  case "--path":
    idx += 1
    if idx < CommandLine.arguments.count {
      repoPath = CommandLine.arguments[idx]
      idx += 1
    }
  default:
    idx += 1
  }
}

// MARK: - LexiconPinSite

struct LexiconPinSite {
  let packageSwiftRelPath: String
  let packageResolvedRelPath: String
  let packageDirRelPath: String
}

/// 語料庫版本在本倉的全部落地點。新增依賴宣告時必須一併加進來，否則該鏈路會靜默落後。
let lexiconPinSites = [
  LexiconPinSite(
    packageSwiftRelPath: "Packages/vChewing_MainAssembly4Darwin/Package.swift",
    packageResolvedRelPath: "Packages/vChewing_MainAssembly4Darwin/Package.resolved",
    packageDirRelPath: "Packages/vChewing_MainAssembly4Darwin"
  ),
  LexiconPinSite(
    packageSwiftRelPath: "LegacyZone/LexiconBuildTrigger/Package.swift",
    packageResolvedRelPath: "LegacyZone/LexiconBuildTrigger/Package.resolved",
    packageDirRelPath: "LegacyZone/LexiconBuildTrigger"
  ),
]

let vanguardURL = "https://atomgit.com/vChewing/vChewing-VanguardLexicon.git"

/// 轉遞給 `swift package resolve` 的額外旗標，來源為環境變數 `SWIFT_EXTRA_FLAGS`（`Makefile` 自
/// `LEGACY_SWIFT_EXTRA_FLAGS` 映射而來）。預設空：正常環境不該削弱 SwiftPM 之 manifest 沙箱。
let swiftExtraFlags =
  ProcessInfo.processInfo.environment["SWIFT_EXTRA_FLAGS"]?
    .split(separator: " ").map(String.init) ?? []

func performDictionaryUpdate() {
  // 尋找目前的 version
  let escapedURL = NSRegularExpression.escapedPattern(for: vanguardURL)
  let pattern = #"\.package\(url:\s*"\#(escapedURL)",\s*exact:\s*"([^"]+)"\),"#

  guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
    print("Error: Invalid regex pattern")
    exit(2)
  }

  // 取得 Remote tags，設定 15 秒 timeout 避免 atomgit.com 無回應時無限掛住。
  var remoteVer: String?
  let lsRemote = Shell.runExec(
    "/usr/bin/git",
    args: [
      "-c", "http.lowSpeedLimit=1000", "-c", "http.lowSpeedTime=15",
      "ls-remote", "--tags", "--sort=-v:refname", vanguardURL,
    ],
    trim: true,
    timeout: 15
  )
  if lsRemote.status == 0 {
    // output line format: <hash>\trefs/tags/<tag>
    if let firstLine = lsRemote.output.split(separator: "\n").first {
      let parts = firstLine.split(separator: "\t")
      if parts.count >= 2 {
        let ref = String(parts[1])
        remoteVer = ref.replacingOccurrences(of: "refs/tags/", with: "")
      }
    }
  } else {
    print("Warning: Failed to query remote tags (status \(lsRemote.status)): \(lsRemote.output)")
  }

  for site in lexiconPinSites {
    print("Checking VanguardLexicon version in \(site.packageSwiftRelPath)...")
    let packageSwiftPath = repoPath + "/" + site.packageSwiftRelPath
    let packageDir = repoPath + "/" + site.packageDirRelPath

    // 讀不到 manifest 即中止：靜默略過任何一個落地點，正是本 Phase 要根除的失效模式。
    guard let content = try? String(contentsOfFile: packageSwiftPath, encoding: .utf8) else {
      print("Error: Could not read \(packageSwiftPath)")
      exit(2)
    }

    guard let match = regex.firstMatch(
      in: content,
      options: [],
      range: NSRange(content.startIndex..., in: content)
    ),
      let existingRange = Range(match.range(at: 1), in: content)
    else {
      print("Error: No VanguardLexicon version pin found in \(site.packageSwiftRelPath)")
      exit(2)
    }

    let currentVer = String(content[existingRange])
    guard let remote = remoteVer else {
      print("VanguardLexicon version cannot be determined (Current: \(currentVer)). Skipping.")
      continue
    }
    guard currentVer != remote else {
      print("VanguardLexicon is up to date (Current: \(currentVer)).")
      continue
    }

    print("Update available: \(currentVer) -> \(remote)")
    guard !dryRun else {
      print("dry-run: skipping actual update")
      continue
    }

    var newContent = content
    newContent.replaceSubrange(existingRange, with: remote)
    do {
      try newContent.write(toFile: packageSwiftPath, atomically: true, encoding: .utf8)
      print("Updated \(site.packageSwiftRelPath) to version \(remote)")

      print("Running 'swift package resolve' in \(packageDir)...")
      // 外層已受沙箱拘束者（AI harness 等）會在 manifest 編譯那關失敗（`sandbox-exec: sandbox_apply:
      // Operation not permitted` ⇒ `error: Invalid manifest`）。與 `LEGACY_SWIFT_EXTRA_FLAGS` 同一慣例：
      // 旗標由呼叫端傳入（`make update LEGACY_SWIFT_EXTRA_FLAGS=--disable-sandbox`），預設不削弱沙箱。
      let resolve = Shell.runExec("/usr/bin/swift", args: ["package", "resolve"] + swiftExtraFlags, cwd: packageDir)
      if resolve.status != 0 {
        print("Warning: swift package resolve failed: \(resolve.output)")
        print("Hint: 失敗訊息若含 sandbox_apply／Invalid manifest，請以 LEGACY_SWIFT_EXTRA_FLAGS=--disable-sandbox 重跑。")
      } else {
        print("Successfully resolved package.")
      }
    } catch {
      print("Error writing \(site.packageSwiftRelPath): \(error)")
      exit(2)
    }
  }
}

performDictionaryUpdate()
