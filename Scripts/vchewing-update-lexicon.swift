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

let packageSwiftRelPath = "Packages/vChewing_MainAssembly/Package.swift"
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
      print("dry-run: skipping actual update")
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
      } else {
        print("Successfully resolved package.")
      }
    } catch {
      print("Error writing Package.swift: \(error)")
    }
  } else {
    print("No updates needed.")
  }
}

performDictionaryUpdate()
