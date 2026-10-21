#!/usr/bin/env swift
import Foundation

// MARK: - Shell

enum Shell {
  // MARK: Internal

  @discardableResult
  static func run(
    _ cmd: String,
    cwd: String? = nil,
    captureOutput: Bool = true,
    trim: Bool = true,
    timeout: TimeInterval? = nil
  )
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
    let timer = startTimeout(task: task, timeout: timeout)
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    task.waitUntilExit()
    timer?.cancel()
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
    let timer = startTimeout(task: task, timeout: timeout)
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    task.waitUntilExit()
    timer?.cancel()
    let str = String(data: data, encoding: .utf8) ?? ""
    if !trim { return (task.terminationStatus, str) }
    return (task.terminationStatus, str.trimmingCharacters(in: .whitespacesAndNewlines))
  }

  // MARK: Private

  private static func startTimeout(task: Process, timeout: TimeInterval?) -> DispatchSourceTimer? {
    guard let timeout = timeout else { return nil }
    let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global())
    timer.schedule(deadline: .now() + timeout)
    timer.setEventHandler {
      if task.isRunning { task.terminate() }
    }
    timer.resume()
    return timer
  }
}

func usage() {
  let name =
    (CommandLine.arguments.first as NSString?)?.lastPathComponent ?? "vchewing-update.swift"
  print("Usage: \(name) [--dry-run] [--path PATH] [--push] [--target-version VERSION]")
}

var dryRun = false
var repoPath = FileManager.default.currentDirectoryPath
var autoPush = false
var targetVersion: String?

var idx = 1
while idx < CommandLine.arguments.count {
  switch CommandLine.arguments[idx] {
  case "--dry-run":
    dryRun = true
    idx += 1
  case "--push":
    autoPush = true
    idx += 1
  case "--path":
    idx += 1
    if idx < CommandLine.arguments.count {
      repoPath = CommandLine.arguments[idx]
      idx += 1
    } else {
      usage()
      exit(1)
    }
  case "--target-version":
    idx += 1
    if idx < CommandLine.arguments.count {
      targetVersion = CommandLine.arguments[idx]
      idx += 1
    } else {
      usage()
      exit(1)
    }
  default:
    usage()
    exit(1)
  }
}

func nowStamp() -> String {
  let df = DateFormatter()
  df.dateFormat = "yyyyMMdd"
  return df.string(from: Date())
}

let commitTime = nowStamp()
let updateCommitMsg = "DictionaryData - \(commitTime)"

// MARK: - LexiconPinSite

/// 語料庫版本在本倉的落地點。路徑全由套件目錄推導，不另存——三個相對路徑本就是同一件事
/// （`<dir>/Package.swift`、`<dir>/Package.resolved`、`<dir>`），分頭寫死只會漂移。
struct LexiconPinSite {
  let packageDirRelPath: String

  var packageSwiftRelPath: String {
    "\(packageDirRelPath)/Package.swift"
  }

  var packageResolvedRelPath: String {
    "\(packageDirRelPath)/Package.resolved"
  }
}

/// 語料庫版本在本倉的全部落地點。新增依賴宣告時必須一併加進來，否則該鏈路會靜默落後。
///
/// 目前只有一筆：兩條建置鏈共用 `LexiconZone/LexiconBuildTrigger` 這一支套件（其 manifest 停在
/// `swift-tools-version: 5.10`，5.10 與 6.4 兩顆工具鏈都讀得懂），差別只在工具鏈與產物目錄，
/// 故依賴宣告也只有一處。
let lexiconPinSites = [
  LexiconPinSite(packageDirRelPath: "LexiconZone/LexiconBuildTrigger"),
]

let vanguardURL = "https://gitee.com/vChewing/vChewing-VanguardLexicon.git"

/// 轉遞給 `swift package resolve` 的額外旗標，來源為環境變數 `SWIFT_EXTRA_FLAGS`（`Makefile` 自
/// `LEGACY_SWIFT_EXTRA_FLAGS` 映射而來）。預設空：正常環境不該削弱 SwiftPM 之 manifest 沙箱。
let swiftExtraFlags =
  ProcessInfo.processInfo.environment["SWIFT_EXTRA_FLAGS"]?
    .split(separator: " ").map(String.init) ?? []

// 1) 檢查並更新 DictionaryData (VanguardLexicon)
// 由於不再使用 submodule，我們直接檢查各 manifest 的 Package.swift 是否需要更新 Dependency。
// 語料庫的依賴宣告只有一處（`LexiconZone/LexiconBuildTrigger`），且兩條建置鏈共用它——現代鏈路以
// 當前工具鏈建置、legacy 鏈路以 5.10 建置，故提升版本時不會出現「一邊升、一邊停在舊版」。

func performDictionaryUpdate() {
  // 尋找目前的 version
  let escapedURL = NSRegularExpression.escapedPattern(for: vanguardURL)
  let pattern = #"\.package\(url:\s*"\#(escapedURL)",\s*exact:\s*"([^"]+)"\),"#

  guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
    print("Error: Invalid regex pattern")
    exit(2)
  }

  // 取得 Remote tags，設定 15 秒 timeout 避免 gitee.com 無回應時無限掛住。
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
      print("dry-run: skipping update")
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
      // 旗標由呼叫端傳入（`make gitrelease LEGACY_SWIFT_EXTRA_FLAGS=--disable-sandbox`），預設不削弱沙箱。
      let resolve = Shell.runExec("/usr/bin/swift", args: ["package", "resolve"] + swiftExtraFlags, cwd: packageDir)
      if resolve.status != 0 {
        print("Warning: swift package resolve failed: \(resolve.output)")
        print("Hint: 失敗訊息若含 sandbox_apply／Invalid manifest，請以 LEGACY_SWIFT_EXTRA_FLAGS=--disable-sandbox 重跑。")
      }
    } catch {
      print("Error writing \(site.packageSwiftRelPath): \(error)")
      exit(2)
    }
  }

  // 2) 檢查檔案變更並 Commit
  let pinnedRelPaths = lexiconPinSites.flatMap { [$0.packageSwiftRelPath, $0.packageResolvedRelPath] }
  let status = Shell.runExec(
    "/usr/bin/git",
    args: ["status", "--porcelain", "--"] + pinnedRelPaths,
    cwd: repoPath
  )
  guard !status.output.isEmpty else {
    print("No DictionaryData changes detected.")
    return
  }

  print("Detected changes in DictionaryData related files.")
  guard !dryRun else {
    print("dry-run: skipping commit")
    return
  }

  let filesToAdd = pinnedRelPaths.filter { FileManager.default.fileExists(atPath: repoPath + "/" + $0) }
  _ = Shell.runExec("/usr/bin/git", args: ["add"] + filesToAdd, cwd: repoPath)
  let commit = Shell.runExec("/usr/bin/git", args: ["commit", "-m", updateCommitMsg], cwd: repoPath)
  if commit.status != 0 {
    print("Failed to commit DictionaryData changes: \(commit.output)")
    // 失敗則退出
    exit(4)
  }
  print("Committed: \(updateCommitMsg)")
}

performDictionaryUpdate()

// 3) 找出最高版本標籤 (highest tag)
let fetchRes = Shell.runExec(
  "/usr/bin/git",
  args: ["-c", "http.lowSpeedLimit=1000", "-c", "http.lowSpeedTime=60", "fetch", "--tags"],
  cwd: repoPath,
  timeout: 60
)
if fetchRes.status != 0 {
  print("Warning: git fetch --tags timed out or failed (status \(fetchRes.status)): \(fetchRes.output)")
}

let tagOut = Shell.runExec(
  "/usr/bin/git",
  args: ["tag", "--list", "--sort=-v:refname"],
  cwd: repoPath
)
let highestTag = tagOut.output.split(separator: "\n").first.map(String.init) ?? ""
print("Highest tag: \(highestTag)")

// --- 新增: 從 Xcode 專案讀取目前的 MARKETING_VERSION 與 CURRENT_PROJECT_VERSION
func locatePbxproj(at repo: String) -> String? {
  let fm = FileManager.default
  let preferred = repo + "/vChewing.xcodeproj/project.pbxproj"
  if fm.fileExists(atPath: preferred) {
    return preferred
  }
  guard let files = try? fm.contentsOfDirectory(atPath: repo) else {
    return nil
  }
  return files
    .filter { $0.hasSuffix(".xcodeproj") }
    .sorted()
    .map { repo + "/" + $0 + "/project.pbxproj" }
    .first(where: { fm.fileExists(atPath: $0) })
}

func parsePbxProjectVersionAndBuild(_ pbxPath: String) -> (String, String)? {
  var content = ""
  do { content = try String(contentsOfFile: pbxPath, encoding: .utf8) } catch {
    return nil
  }
  // 尋找 MARKETING_VERSION 與 CURRENT_PROJECT_VERSION
  let marketingRegex = try? NSRegularExpression(
    pattern: "MARKETING_VERSION = ([0-9]+\\.[0-9]+\\.[0-9]+);",
    options: []
  )
  let buildRegex = try? NSRegularExpression(
    pattern: "CURRENT_PROJECT_VERSION = ([0-9]+);",
    options: []
  )
  guard let mrx = marketingRegex,
        let marketingMatch = mrx.firstMatch(
          in: content,
          options: [],
          range: NSRange(content.startIndex..., in: content)
        ),
        let marketRange = Range(marketingMatch.range(at: 1), in: content),
        let brx = buildRegex,
        let buildMatch = brx.firstMatch(
          in: content,
          options: [],
          range: NSRange(content.startIndex..., in: content)
        ),
        let buildRange = Range(buildMatch.range(at: 1), in: content)
  else {
    return nil
  }
  return (String(content[marketRange]), String(content[buildRange]))
}

func isLegacyByMacOSDeployment(_ pbxPath: String) -> Bool {
  var content = ""
  do { content = try String(contentsOfFile: pbxPath, encoding: .utf8) } catch { return false }
  // 找出所有 MACOSX_DEPLOYMENT_TARGET 的出現，並選擇最小值（最低部署版本）
  let regex = try? NSRegularExpression(
    pattern: "MACOSX_DEPLOYMENT_TARGET = ([0-9]+\\.[0-9]+);",
    options: []
  )
  var minVer: (Int, Int)?
  if let rx = regex {
    let ms = rx.matches(
      in: content,
      options: [],
      range: NSRange(content.startIndex..., in: content)
    )
    for m in ms {
      if let r = Range(m.range(at: 1), in: content) {
        let v = String(content[r])
        let comps = v.split(separator: ".").map { Int($0) ?? 0 }
        if comps.count >= 2 {
          let major = comps[0]
          let minor = comps[1]
          if minVer == nil || (major, minor) < minVer! { minVer = (major, minor) }
        }
      }
    }
  }
  if let m = minVer { return (Double(m.0) + Double(m.1) / 100.0) < 10.15 }
  return false
}

/// 檢查版本資訊是否確實寫入專案檔案（Xcode 專案 + 兩份 plist + 配置助手之 version.txt）。
/// 只要有任何一處與期望值不符（或根本沒寫入），就回傳 false。
func versionStampIsLanded(version: String, build: String) -> Bool {
  guard let pbxPath = locatePbxproj(at: repoPath),
        let pbxContent = try? String(contentsOfFile: pbxPath, encoding: .utf8)
  else { return false }

  let expectations = [
    (#"MARKETING_VERSION = ([0-9]+\.[0-9]+\.[0-9]+);"#, version),
    (#"CURRENT_PROJECT_VERSION = ([0-9]+);"#, build),
  ]
  for (pattern, expected) in expectations {
    guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return false }
    let matches = regex.matches(
      in: pbxContent,
      options: [],
      range: NSRange(pbxContent.startIndex..., in: pbxContent)
    )
    // 專案內的每一處出現都必須符合期望值，有任何一處不符即視為未完成。
    if matches.isEmpty { return false }
    for match in matches {
      guard let range = Range(match.range(at: 1), in: pbxContent),
            String(pbxContent[range]) == expected
      else { return false }
    }
  }

  for plistRelPath in ["Update-Info.plist", "Release-Version.plist"] {
    let plistPath = repoPath + "/" + plistRelPath
    guard FileManager.default.fileExists(atPath: plistPath) else { continue }
    guard let plist = NSDictionary(contentsOfFile: plistPath),
          (plist["CFBundleShortVersionString"] as? String) == version,
          (plist["CFBundleVersion"] as? String) == build
    else { return false }
  }

  // 配置助手側之 version.txt（其所在目錄缺席時略過——該助手不隨發行版出貨）。
  let assistantVersionRelPath = "ValueAdd/WebConfigAssistant/version.txt"
  let assistantVersionPath = repoPath + "/" + assistantVersionRelPath
  if FileManager.default.fileExists(atPath: assistantVersionPath) {
    guard let content = try? String(contentsOfFile: assistantVersionPath, encoding: .utf8)
    else { return false }
    let lines = content.split(separator: "\n").map(String.init)
    guard lines.contains("version=" + version), lines.contains("build=" + build) else {
      return false
    }
  }

  return true
}

var useProjectVersion = false
var currentVer = highestTag
var currentBuild = "0"
var projectIsLegacy = false
if let pbx = locatePbxproj(at: repoPath) {
  if let (market, build) = parsePbxProjectVersionAndBuild(pbx) {
    useProjectVersion = true
    currentVer = market
    currentBuild = build
    print("Using project MARKETING_VERSION=\(market), CURRENT_PROJECT_VERSION=\(build) from \(pbx)")
    projectIsLegacy = isLegacyByMacOSDeployment(pbx)
    if projectIsLegacy { print("Detected legacy project (macOS deployment < 10.15)") }
  } else {
    print("Warning: Failed to parse project version from \(pbx). Falling back to highest tag.")
  }
} else {
  print("Warning: No usable project.pbxproj found. Falling back to highest tag.")
}

func bumpTagFromProject(version: String, useLegacySuffix: Bool) -> (String, Bool) {
  var tag = version
  var isLegacy = useLegacySuffix
  // 若版本字串包含 -legacy 後綴，則移除
  if tag.hasSuffix("-legacy") {
    isLegacy = true
    tag = String(tag.dropLast(7))
  }
  // 解析 semver: major.minor.patch
  let comps = tag.split(separator: ".").map { Int($0) ?? 0 }
  let major = comps.count > 0 ? comps[0] : 0
  let minor = comps.count > 1 ? comps[1] : 0
  var patch = comps.count > 2 ? comps[2] : 0
  patch += 1
  let newTag = "\(major).\(minor).\(patch)" + (isLegacy ? "-legacy" : "")
  return (newTag, isLegacy)
}

let newTag: String
let isLegacy: Bool

if let userVersion = targetVersion {
  // Use the manually specified version; detect legacy suffix from the user input
  newTag = userVersion
  isLegacy = userVersion.hasSuffix("-legacy")
  print("Using manually specified version: \(newTag) (legacy? \(isLegacy))")
} else {
  let (bumpedTag, bumpedLegacy) = bumpTagFromProject(version: currentVer, useLegacySuffix: projectIsLegacy)
  newTag = bumpedTag
  isLegacy = bumpedLegacy
  print("New tag: \(newTag) (legacy? \(isLegacy))")
}

// 4) 計算 build number: major*1000 + minor*100 + patch*10
let base = newTag.components(separatedBy: "-").first ?? newTag
let parts = base.split(separator: ".").map { Int($0) ?? 0 }
let major = parts.count > 0 ? parts[0] : 0
let minor = parts.count > 1 ? parts[1] : 0
let patch = parts.count > 2 ? parts[2] : 0
let buildNum = major * 1_000 + minor * 100 + patch * 10
print("Computed build number: \(buildNum)")

// 5) 執行 BuildVersionSpecifier.swift
// 注意：該腳本不能用 shebang 直接跑（`#!/usr/bin/env swift`）：本腳本自己可能就是由 PATH 上的
// swiftly 代理啟動的，而它會把 `SWIFTLY_PROXY_IN_PROGRESS` 留在環境變數內給子行程。子行程再次
// 命中同一個代理時，代理會直接以「Circular swiftly proxy invocation」中止，版本號於是完全沒被
// 寫入，但後續的 commit 與 tag 仍照做（tag 因而定在舊版本狀態）。故改用 `/usr/bin/swift` 明確
// 指定解譯器，且以下一律檢查每個步驟的執行結果。
if FileManager.default.fileExists(atPath: repoPath + "/BuildVersionSpecifier.swift") {
  print("Running BuildVersionSpecifier.swift \(base) \(buildNum)")
  if dryRun {
    print("dry-run: skipping BuildVersionSpecifier")
  } else {
    let bumpResult = Shell.runExec(
      "/usr/bin/swift",
      args: ["./BuildVersionSpecifier.swift", base, "\(buildNum)"],
      cwd: repoPath
    )
    if bumpResult.status != 0 {
      print(
        "Error: BuildVersionSpecifier.swift exited with status \(bumpResult.status): \(bumpResult.output)"
      )
      exit(6)
    }

    // 版本號沒真的寫進專案檔案的話，之後的 commit 與 tag 只會定在舊版本狀態。
    guard versionStampIsLanded(version: base, build: "\(buildNum)") else {
      print("Error: Version stamp \(base) (build \(buildNum)) did not land; aborting before commit & tag.")
      exit(6)
    }

    // commit 版本變更 - 確保沒有遺留的子模組改動
    let smCheck = Shell.run(
      "git submodule status --recursive | sed -n '1,200p'",
      cwd: repoPath,
      trim: false
    )
    let dirtySm = smCheck.output.split(separator: "\n").map { String($0) }.filter { line in
      line.first != " "
    }
    if !dirtySm.isEmpty {
      print(
        "Error: Submodule changes still present before VersionUp commit: \(dirtySm). Commit or revert these first."
      )
      exit(5)
    }
    let versionUpMsg = "[VersionUp] \(base) GM Build \(buildNum)."
    // 專案內其他未提交的變更都會被 `git add -A` 一起收進版本提交，故先提醒。
    let versionedRelPaths = [
      "vChewing.xcodeproj/project.pbxproj", "Update-Info.plist", "Release-Version.plist",
      "ValueAdd/WebConfigAssistant/version.txt",
    ]
    let otherDirty = Shell.runExec(
      "/usr/bin/git",
      args: ["status", "--porcelain"],
      cwd: repoPath,
      trim: false
    )
    .output.split(separator: "\n")
    .map { String($0.dropFirst(3)) }
    .filter { !$0.isEmpty && !versionedRelPaths.contains($0) }
    if !otherDirty.isEmpty {
      print(
        "Warning: These unrelated uncommitted files will also enter the version commit: \(otherDirty)"
      )
    }
    let addResult = Shell.runExec("/usr/bin/git", args: ["add", "-A"], cwd: repoPath)
    if addResult.status != 0 {
      print("Error: 'git add -A' failed: \(addResult.output)")
      exit(7)
    }
    let commitResult = Shell.runExec(
      "/usr/bin/git",
      args: ["commit", "-m", versionUpMsg],
      cwd: repoPath
    )
    let headSubject = Shell.runExec(
      "/usr/bin/git",
      args: ["log", "-1", "--pretty=format:%s"],
      cwd: repoPath
    ).output
    guard commitResult.status == 0, headSubject == versionUpMsg else {
      let gitSaid = commitResult.output.isEmpty ? "(git reported no output)" : commitResult.output
      print(
        "Error: Failed to create the version commit (git status \(commitResult.status)): \(gitSaid)"
      )
      exit(7)
    }
    print("Committed \(versionUpMsg)")
  }
} else {
  print("BuildVersionSpecifier.swift not found at repo root: skipping version bump.")
  exit(3)
}

// 6) 建立 tag
if dryRun {
  print("dry-run: skipping tag creation for \(newTag)")
} else {
  let tagResult = Shell.runExec("/usr/bin/git", args: ["tag", "-f", newTag], cwd: repoPath)
  if tagResult.status != 0 {
    print("Error: Failed to create tag \(newTag): \(tagResult.output)")
    exit(8)
  }
  print("Tag \(newTag) created/updated.")
}

// 7) 回復 Update-Info.plist 在版本提交時的變更（僅限該檔案）。若可能則使用最後一個 [VersionUp] 提交的 parent commit
let updateInfoPath = "Update-Info.plist"
if FileManager.default.fileExists(atPath: repoPath + "/\(updateInfoPath)") {
  print("Reverting \(updateInfoPath) to previous commit state (only file)")
  if dryRun {
    print("dry-run: skip revert")
  } else {
    let versionUpCommitRes = Shell.run(
      "git log --grep='\\[VersionUp\\]' --pretty=format:%H -n 1",
      cwd: repoPath
    )
    var parentHash = ""
    if versionUpCommitRes.status == 0, !versionUpCommitRes.output.isEmpty {
      let commitHash = versionUpCommitRes.output.split(separator: "\n").first.map(String.init) ?? ""
      if !commitHash.isEmpty {
        parentHash =
          Shell.runExec("/usr/bin/git", args: ["rev-parse", "\(commitHash)^"], cwd: repoPath).output
      }
    }
    if parentHash
      .isEmpty {
      parentHash =
        Shell.runExec("/usr/bin/git", args: ["rev-parse", "HEAD~1"], cwd: repoPath).output
    }
    let revertResult = Shell.runExec(
      "/usr/bin/git",
      args: ["checkout", parentHash, "--", updateInfoPath],
      cwd: repoPath
    )
    let suppressAdd = Shell.runExec("/usr/bin/git", args: ["add", updateInfoPath], cwd: repoPath)
    let suppressCommit = Shell.runExec(
      "/usr/bin/git",
      args: ["commit", "-m", "[SUPPRESSOR]"],
      cwd: repoPath
    )
    if revertResult.status != 0 || suppressAdd.status != 0 || suppressCommit.status != 0 {
      print("Error: Failed to commit [SUPPRESSOR] (tag \(newTag) is already created).")
      print("  Revert: \(revertResult.output)")
      print("  Add: \(suppressAdd.output)")
      print("  Commit: \(suppressCommit.output)")
      exit(9)
    }
    print("Committed [SUPPRESSOR]")
  }
} else {
  print("\(updateInfoPath) not found in repo: skipping revert")
}

print("Done. Dry-run: \(dryRun). Remember scripts will not push to remote by default.")

// 腳本結束
