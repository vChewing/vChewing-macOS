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
    trim: Bool = true
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
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    task.waitUntilExit()
    let str = String(data: data, encoding: .utf8) ?? ""
    if !trim { return (task.terminationStatus, str) }
    return (task.terminationStatus, str.trimmingCharacters(in: .whitespacesAndNewlines))
  }
}

func usage() {
  let name =
    (CommandLine.arguments.first as NSString?)?.lastPathComponent ?? "vchewing-update.swift"
  print("Usage: \(name) [--dry-run] [--path PATH] [--push]")
}

var dryRun = false
var repoPath = FileManager.default.currentDirectoryPath
var autoPush = false

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

// 1) 檢查並更新 DictionaryData (VanguardLexicon)
// 由於不再使用 submodule，我們直接檢查 MainAssembly 的 Package.swift 是否需要更新 Dependency。

let packageSwiftRelPath = "Packages/vChewing_MainAssembly/Package.swift"
let packageResolvedRelPath = "Packages/vChewing_MainAssembly/Package.resolved"
let packageDirRelPath = "Packages/vChewing_MainAssembly"
let vanguardURL = "https://atomgit.com/vChewing/vChewing-VanguardLexicon.git"

print("Checking VanguardLexicon version in \(packageSwiftRelPath)...")

func performDictionaryUpdate() {
  let packageSwiftPath = repoPath + "/" + packageSwiftRelPath
  let packageDir = repoPath + "/" + packageDirRelPath

  guard let content = try? String(contentsOfFile: packageSwiftPath, encoding: .utf8) else {
    print("Error: Could not read \(packageSwiftPath)")
    return
  }

  // 尋找目前的 version
  let escapedURL = NSRegularExpression.escapedPattern(for: vanguardURL)
  let pattern = #"\.package\(url:\s*"\#(escapedURL)",\s*exact:\s*"([^"]+)"\),"#

  guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
    print("Error: Invalid regex pattern")
    return
  }

  var currentVer: String?
  var existingRange: Range<String.Index>?

  if let match = regex.firstMatch(in: content, options: [], range: NSRange(content.startIndex..., in: content)) {
    if let verRange = Range(match.range(at: 1), in: content) {
      currentVer = String(content[verRange])
      existingRange = verRange
    }
  }

  // 取得 Remote tags
  var remoteVer = currentVer
  let lsRemote = Shell.runExec(
    "/usr/bin/git",
    args: ["ls-remote", "--tags", "--sort=-v:refname", vanguardURL],
    trim: true
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
    print("Warning: Failed to query remote tags: \(lsRemote.output)")
  }

  var newContent = content
  var pendingUpdate = false

  if let current = currentVer, let remote = remoteVer, current != remote, let range = existingRange {
    print("Update available: \(current) -> \(remote)")
    if !dryRun {
      newContent.replaceSubrange(range, with: remote)
      pendingUpdate = true
    } else {
      print("dry-run: skipping update")
    }
  } else {
    var msg = "VanguardLexicon is up to date or cannot be determined (Current: \(currentVer ?? "?")"
    if let r = remoteVer, r != currentVer {
      msg += ", Remote: \(r)"
    }
    msg += ")"
    print(msg)
  }

  if pendingUpdate {
    do {
      try newContent.write(toFile: packageSwiftPath, atomically: true, encoding: .utf8)
      print("Updated Package.swift to version \(remoteVer!)")

      print("Running 'swift package resolve' in \(packageDir)...")
      let resolve = Shell.runExec("/usr/bin/swift", args: ["package", "resolve"], cwd: packageDir)
      if resolve.status != 0 {
        print("Warning: swift package resolve failed: \(resolve.output)")
      }
    } catch {
      print("Error writing Package.swift: \(error)")
    }
  }

  // 2) 檢查檔案變更並 Commit
  let status = Shell.runExec("/usr/bin/git", args: ["status", "--porcelain", packageDirRelPath], cwd: repoPath)
  // Check if Package.swift or Package.resolved inside that folder are changed
  if !status.output.isEmpty {
    // Determine if relevant files changed
    let lines = status.output.split(separator: "\n")
    let relevantChanges = lines.contains { line in
      line.contains("Package.swift") || line.contains("Package.resolved")
    }

    if relevantChanges {
      print("Detected changes in DictionaryData related files.")
      if dryRun {
        print("dry-run: skipping commit")
      } else {
        var filesToAdd = [packageSwiftRelPath]
        if FileManager.default.fileExists(atPath: repoPath + "/" + packageResolvedRelPath) {
          filesToAdd.append(packageResolvedRelPath)
        }
        _ = Shell.runExec("/usr/bin/git", args: ["add"] + filesToAdd, cwd: repoPath)
        let commit = Shell.runExec("/usr/bin/git", args: ["commit", "-m", updateCommitMsg], cwd: repoPath)
        if commit.status != 0 {
          print("Failed to commit DictionaryData changes: \(commit.output)")
          // 失敗則退出
          exit(4)
        }
        print("Committed: \(updateCommitMsg)")
      }
    } else {
      print("Changes detected in MainAssembly but not Package.swift/resolved. Ignoring for DictionaryData update.")
    }
  } else {
    print("No DictionaryData changes detected.")
  }
}

performDictionaryUpdate()

// 3) 找出最高版本標籤 (highest tag)
let tagOut = Shell.run(
  "git fetch --tags && git tag --list --sort=-v:refname | head -n 1",
  cwd: repoPath
)
let highestTag = tagOut.output.trimmingCharacters(in: .whitespacesAndNewlines)
print("Highest tag: \(highestTag)")

// --- 新增: 從 Xcode 專案讀取目前的 MARKETING_VERSION 與 CURRENT_PROJECT_VERSION
func locatePbxproj(at repo: String) -> String? {
  let fm = FileManager.default
  if let files = try? fm.contentsOfDirectory(atPath: repo) {
    if let proj = files.first(where: { $0.hasSuffix(".xcodeproj") }) {
      return repo + "/" + proj + "/project.pbxproj"
    }
  }
  return nil
}

func parsePbxProjectVersionAndBuild(_ pbxPath: String) -> (String, String) {
  var content = ""
  do { content = try String(contentsOfFile: pbxPath, encoding: .utf8) } catch {
    return ("0.0.0", "0")
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
  var market = "0.0.0"
  var build = "0"
  if let mrx = marketingRegex,
     let match = mrx.firstMatch(
       in: content,
       options: [],
       range: NSRange(content.startIndex..., in: content)
     ) {
    if let range = Range(match.range(at: 1), in: content) { market = String(content[range]) }
  }
  if let brx = buildRegex,
     let match = brx.firstMatch(
       in: content,
       options: [],
       range: NSRange(content.startIndex..., in: content)
     ) {
    if let range = Range(match.range(at: 1), in: content) { build = String(content[range]) }
  }
  return (market, build)
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

var useProjectVersion = false
var currentVer = highestTag
var currentBuild = "0"
var projectIsLegacy = false
if let pbx = locatePbxproj(at: repoPath) {
  useProjectVersion = true
  let (market, build) = parsePbxProjectVersionAndBuild(pbx)
  currentVer = market
  currentBuild = build
  print("Using project MARKETING_VERSION=\(market), CURRENT_PROJECT_VERSION=\(build) from \(pbx)")
  projectIsLegacy = isLegacyByMacOSDeployment(pbx)
  if projectIsLegacy { print("Detected legacy project (macOS deployment < 10.15)") }
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

let (newTag, isLegacy) = bumpTagFromProject(version: currentVer, useLegacySuffix: projectIsLegacy)
print("New tag: \(newTag) (legacy? \(isLegacy))")

// 4) 計算 build number: major*1000 + minor*100 + patch*10
let base = newTag.components(separatedBy: "-").first ?? newTag
let parts = base.split(separator: ".").map { Int($0) ?? 0 }
let major = parts.count > 0 ? parts[0] : 0
let minor = parts.count > 1 ? parts[1] : 0
let patch = parts.count > 2 ? parts[2] : 0
let buildNum = major * 1_000 + minor * 100 + patch * 10
print("Computed build number: \(buildNum)")

// 5) 執行 BuildVersionSpecifier.swift
if FileManager.default.fileExists(atPath: repoPath + "/BuildVersionSpecifier.swift") {
  print("Running BuildVersionSpecifier.swift \(base) \(buildNum)")
  if dryRun {
    print("dry-run: skipping BuildVersionSpecifier")
  } else {
    _ = Shell.run(
      "chmod +x ./BuildVersionSpecifier.swift && ./BuildVersionSpecifier.swift \(base) \(buildNum)",
      cwd: repoPath
    )
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
    _ = Shell.run(
      "git add -A && git commit -m \"[VersionUp] \(base) GM Build \(buildNum).\"",
      cwd: repoPath
    )
    print("Committed [VersionUp] \(base) GM Build \(buildNum).")
  }
} else {
  print("BuildVersionSpecifier.swift not found at repo root: skipping version bump.")
  exit(3)
}

// 6) 建立 tag
if dryRun {
  print("dry-run: skipping tag creation for \(newTag)")
} else {
  _ = Shell.runExec("/usr/bin/git", args: ["tag", "-f", newTag], cwd: repoPath)
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
    _ = Shell.runExec(
      "/usr/bin/git",
      args: ["checkout", parentHash, "--", updateInfoPath],
      cwd: repoPath
    )
    _ = Shell.runExec("/usr/bin/git", args: ["add", updateInfoPath], cwd: repoPath)
    _ = Shell.runExec("/usr/bin/git", args: ["commit", "-m", "[SUPPRESSOR]"], cwd: repoPath)
    print("Committed [SUPPRESSOR]")
  }
} else {
  print("\(updateInfoPath) not found in repo: skipping revert")
}

print("Done. Dry-run: \(dryRun). Remember scripts will not push to remote by default.")

// 腳本結束
