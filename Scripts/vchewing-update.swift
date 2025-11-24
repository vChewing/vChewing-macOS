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
let updateCommitMsg = "Update Data - \(commitTime)"

// 1) run make update
print("Running 'make update' in \(repoPath) ...")
if dryRun {
  print("dry-run enabled: skipping 'make update'")
} else {
  let res = Shell.run("make update", cwd: repoPath)
  print(res.output)
  if res.status != 0 {
    print("make update failed (status \(res.status))")
    // Continue? exit for now
    exit(2)
  }
}

// 2) detect submodule changes using git submodule status for robust detection
let smStatus = Shell.run("git submodule status --recursive", cwd: repoPath, trim: false)
let smLines = smStatus.output.split(separator: "\n").map { String($0) }
let changedSmLines = smLines.filter { line in
  // lines start with ' ' for up-to-date; '+' or '-' or 'U' indicate changed/uncommitted
  guard let firstChar = line.first else { return false }
  return firstChar != " "
}

let submodulePaths = changedSmLines.map { line -> String in
  // line format: "<status> <sha> <path> (details)" -> we want the path (comps[1])
  let comps = line.split(separator: " ")
  return comps.count >= 2 ? String(comps[1]) : line
}

if !submodulePaths.isEmpty {
  print("Detected submodule changes in: \(submodulePaths)")
  if dryRun {
    print("dry-run: skipping commit of submodules")
  } else {
    // Add and commit submodule pointer updates explicitly
    for sm in submodulePaths {
      _ = Shell.run("git add \(sm)", cwd: repoPath)
    }
    let commitRes = Shell.run("git commit -m \"\(updateCommitMsg)\"", cwd: repoPath)
    if commitRes.status != 0 {
      print("Failed to commit submodule changes: \(commitRes.output)")
      // Don't continue version bump if submodule commit failed
      exit(4)
    }
    print("Committed: \(updateCommitMsg)")
  }
} else {
  print("No submodule changes detected via 'git submodule status'.")
}

// 3) find highest tag
let tagOut = Shell.run(
  "git fetch --tags && git tag --list --sort=-v:refname | head -n 1",
  cwd: repoPath
)
let highestTag = tagOut.output.trimmingCharacters(in: .whitespacesAndNewlines)
print("Highest tag: \(highestTag)")

// --- New: read current MARKETING_VERSION & CURRENT_PROJECT_VERSION from Xcode project
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
  do { content = try String(contentsOfFile: pbxPath, encoding: .utf8) } catch { return ("0.0.0", "0") }
  // Find MARKETING_VERSION and CURRENT_PROJECT_VERSION
  let marketingRegex = try? NSRegularExpression(pattern: "MARKETING_VERSION = ([0-9]+\\.[0-9]+\\.[0-9]+);", options: [])
  let buildRegex = try? NSRegularExpression(pattern: "CURRENT_PROJECT_VERSION = ([0-9]+);", options: [])
  var market = "0.0.0"
  var build = "0"
  if let mrx = marketingRegex, let match = mrx.firstMatch(
    in: content,
    options: [],
    range: NSRange(content.startIndex..., in: content)
  ) {
    if let range = Range(match.range(at: 1), in: content) { market = String(content[range]) }
  }
  if let brx = buildRegex, let match = brx.firstMatch(
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
  // find all MACOSX_DEPLOYMENT_TARGET occurrences and choose minimal
  let regex = try? NSRegularExpression(pattern: "MACOSX_DEPLOYMENT_TARGET = ([0-9]+\\.[0-9]+);", options: [])
  var minVer: (Int, Int)?
  if let rx = regex {
    let ms = rx.matches(in: content, options: [], range: NSRange(content.startIndex..., in: content))
    for m in ms {
      if let r = Range(m.range(at: 1), in: content) {
        let v = String(content[r])
        let comps = v.split(separator: ".").map { Int($0) ?? 0 }
        if comps.count >= 2 {
          let major = comps[0], minor = comps[1]
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
  // If version string contains -legacy suffix, remove it
  if tag.hasSuffix("-legacy") { isLegacy = true; tag = String(tag.dropLast(7)) }
  // parse semver: major.minor.patch
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

// 4) compute build number: major*1000 + minor*100 + patch*10
let base = newTag.components(separatedBy: "-").first ?? newTag
let parts = base.split(separator: ".").map { Int($0) ?? 0 }
let major = parts.count > 0 ? parts[0] : 0
let minor = parts.count > 1 ? parts[1] : 0
let patch = parts.count > 2 ? parts[2] : 0
let buildNum = major * 1_000 + minor * 100 + patch * 10
print("Computed build number: \(buildNum)")

// 5) run BuildVersionSpecifier.swift
if FileManager.default.fileExists(atPath: repoPath + "/BuildVersionSpecifier.swift") {
  print("Running BuildVersionSpecifier.swift \(base) \(buildNum)")
  if dryRun {
    print("dry-run: skipping BuildVersionSpecifier")
  } else {
    _ = Shell.run(
      "chmod +x ./BuildVersionSpecifier.swift && ./BuildVersionSpecifier.swift \(base) \(buildNum)",
      cwd: repoPath
    )
    // commit version changes - ensure no submodule changes remain
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

// 6) create tag
if dryRun {
  print("dry-run: skipping tag creation for \(newTag)")
} else {
  _ = Shell.run("git tag -f \"\(newTag)\"", cwd: repoPath)
  print("Tag \(newTag) created/updated.")
}

// 7) revert Update-Info.plist changes from version commit (only the file). Use the parent of the last [VersionUp] commit when possible.
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
        parentHash = Shell.run("git rev-parse \(commitHash)^", cwd: repoPath).output
      }
    }
    if parentHash.isEmpty { parentHash = Shell.run("git rev-parse HEAD~1", cwd: repoPath).output }
    _ = Shell.run("git checkout \(parentHash) -- \(updateInfoPath)", cwd: repoPath)
    _ = Shell.run("git add \(updateInfoPath)", cwd: repoPath)
    _ = Shell.run("git commit -m \"[SUPPRESSOR]\"", cwd: repoPath)
    print("Committed [SUPPRESSOR]")
  }
} else {
  print("\(updateInfoPath) not found in repo: skipping revert")
}

print("Done. Dry-run: \(dryRun). Remember scripts will not push to remote by default.")

// End of script
