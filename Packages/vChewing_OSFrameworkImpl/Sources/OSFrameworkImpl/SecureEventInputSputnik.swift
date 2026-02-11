// (c) 2023 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

/// A Swift script to check whether a non-system process is abusing the SecureEventInput.
/// ---------
/// This file is only imported by SecurityAgentHelper. No need to compile on Linux.

#if canImport(AppKit) && canImport(IOKit)
  import AppKit
  import Combine
  import IOKit

  // MARK: - SecureEventInputSputnik

  public final class SecureEventInputSputnik {
    // MARK: Lifecycle

    public init() {
      oobe()
    }

    // MARK: Public

    public let shared = SecureEventInputSputnik()

    public static func getIORegListResults() -> String? {
      // Don't generate results under any of the following situations:
      // - Hibernation / LoggedOut / SwitchedOut / ScreenSaver situations.
      guard NSWorkspace.activationFlags.isEmpty else { return nil }
      var resultDictionaryCF: Unmanaged<CFMutableDictionary>?
      defer { resultDictionaryCF = nil }
      /// Regarding the parameter in IORegistryGetRootEntry:
      /// Both kIOMasterPortDefault and kIOMainPortDefault are 0.
      /// The latter one is similar to what `git` had done: changing "Master" to "Main".
      let statusSucceeded = IORegistryEntryCreateCFProperties(
        IORegistryGetRootEntry(0), &resultDictionaryCF, kCFAllocatorDefault, IOOptionBits(0)
      )
      let dict: CFMutableDictionary? = resultDictionaryCF?.takeRetainedValue()
      guard statusSucceeded == KERN_SUCCESS else { return nil }
      guard let dict: [CFString: Any] = dict as? [CFString: Any] else { return nil }
      return dict.description
    }

    /// Find all non-system processes using the SecureEventInput.
    /// - Parameter abusersOnly: List only non-frontmost processes.
    /// - **Reason to Use**: Non-frontmost processes of such are considered abusers of SecureEventInput,
    /// hindering 3rd-party input methods from being switched to by the user.
    /// They are also hindering users from accessing the menu of all 3rd-party input methods.
    /// There are Apple's internal business reasons why macOS always has lack of certain crucial input methods,
    /// plus that some some IMEs in macOS have certain bugs / defects for decades and are unlikely to be solved,
    /// making the sense that why there are needs of 3rd-party input methods.
    /// - **How to Use**: For example, one can use an NSTimer to run this function
    /// with `abusersOnly: true` every 15~60 seconds. Once the result dictionary is not empty,
    /// you may either warn the users to restart the matched process or directly terminate it.
    /// Note that you cannot terminate a process if your app is Sandboxed.
    /// - Returns: Matched results as a dictionary in `[Int32: NSRunningApplication]` format. The keys are PIDs.
    /// - Remark: The`"com.apple.SecurityAgent"` won't be included in the result since it is a system process.
    /// Also, "com.apple.loginwindow" should be excluded as long as the system screen saver engine is running.
    public static func getRunningSecureInputApps(abusersOnly: Bool = false)
      -> [Int32: NSRunningApplication] {
      var result = [Int32: NSRunningApplication]()
      guard let rawData = getIORegListResults() else { return result }
      rawData.enumerateLines { currentLine, _ in
        guard currentLine.contains("kCGSSessionSecureInputPID") else { return }
        guard let filteredNumStr = Int32(currentLine.filter("0123456789".contains)) else { return }
        guard let matchedApp = NSRunningApplication(processIdentifier: filteredNumStr)
        else { return }
        guard matchedApp.bundleIdentifier != "com.apple.SecurityAgent" else { return }
        guard !(matchedApp.isLoginWindowWithLockedScreenOrScreenSaver) else { return }
        if abusersOnly {
          guard !matchedApp.isActive else { return }
        }
        result[filteredNumStr] = matchedApp
      }
      return result
    }
  }

  extension NSWorkspace {
    nonisolated public struct ActivationFlags: OptionSet, Sendable {
      // MARK: Lifecycle

      public init(rawValue: Int) {
        self.rawValue = rawValue
      }

      // MARK: Public

      public static let hibernating = Self(rawValue: 1 << 0)
      public static let desktopLocked = Self(rawValue: 1 << 1)
      public static let sessionSwitchedOut = Self(rawValue: 1 << 2)
      public static let screenSaverRunning = Self(rawValue: 1 << 3)

      public let rawValue: Int
    }

    nonisolated public static var activationFlags: ActivationFlags {
      get { mtxActivationFlags.value }
      set { mtxActivationFlags.value = newValue }
    }

    nonisolated private static let mtxActivationFlags: NSMutex<ActivationFlags> = .init([])
  }

  extension NSRunningApplication {
    public var isLoginWindowWithLockedScreenOrScreenSaver: Bool {
      guard bundleIdentifier == "com.apple.loginwindow" else { return false }
      return !NSWorkspace.activationFlags.isEmpty
    }
  }

  extension SecureEventInputSputnik {
    nonisolated(unsafe) private static var combinePoolCocoa = [any NSObjectProtocol]()

    @available(macOS 10.15, *)
    nonisolated(unsafe) private static var combinePool = Set<AnyCancellable>()

    func oobe() {
      if #available(macOS 10.15, *) {
        DistributedNotificationCenter.default()
          .publisher(for: .init(rawValue: "com.apple.screenIsLocked"))
          .sink { _ in NSWorkspace.activationFlags.insert(.desktopLocked) }
          .store(in: &Self.combinePool)
        DistributedNotificationCenter.default()
          .publisher(for: .init(rawValue: "com.apple.screenIsUnlocked"))
          .sink { _ in NSWorkspace.activationFlags.remove(.desktopLocked) }
          .store(in: &Self.combinePool)
        DistributedNotificationCenter.default()
          .publisher(for: .init(rawValue: "com.apple.screensaver.didstart"))
          .sink { _ in NSWorkspace.activationFlags.insert(.screenSaverRunning) }
          .store(in: &Self.combinePool)
        DistributedNotificationCenter.default()
          .publisher(for: .init(rawValue: "com.apple.screensaver.didstop"))
          .sink { _ in NSWorkspace.activationFlags.remove(.screenSaverRunning) }
          .store(in: &Self.combinePool)
        NSWorkspace.shared.notificationCenter
          .publisher(for: NSWorkspace.willSleepNotification)
          .sink { _ in NSWorkspace.activationFlags.insert(.hibernating) }
          .store(in: &Self.combinePool)
        NSWorkspace.shared.notificationCenter
          .publisher(for: NSWorkspace.didWakeNotification)
          .sink { _ in NSWorkspace.activationFlags.remove(.hibernating) }
          .store(in: &Self.combinePool)
        NSWorkspace.shared.notificationCenter
          .publisher(for: NSWorkspace.sessionDidResignActiveNotification)
          .sink { _ in NSWorkspace.activationFlags.insert(.sessionSwitchedOut) }
          .store(in: &Self.combinePool)
        NSWorkspace.shared.notificationCenter
          .publisher(for: NSWorkspace.sessionDidBecomeActiveNotification)
          .sink { _ in NSWorkspace.activationFlags.remove(.sessionSwitchedOut) }
          .store(in: &Self.combinePool)
      } else {
        Self.combinePoolCocoa.append(
          DistributedNotificationCenter.default()
            .addObserver(
              forName: .init("com.apple.screenIsLocked"),
              object: nil,
              queue: .main
            ) { _ in
              NSWorkspace.activationFlags.insert(.desktopLocked)
            }
        )
        Self.combinePoolCocoa.append(
          DistributedNotificationCenter.default()
            .addObserver(
              forName: .init("com.apple.screenIsUnlocked"),
              object: nil,
              queue: .main
            ) { _ in
              NSWorkspace.activationFlags.remove(.desktopLocked)
            }
        )
        Self.combinePoolCocoa.append(
          DistributedNotificationCenter.default()
            .addObserver(
              forName: .init("com.apple.screensaver.didstart"),
              object: nil,
              queue: .main
            ) { _ in
              NSWorkspace.activationFlags.insert(.screenSaverRunning)
            }
        )
        Self.combinePoolCocoa.append(
          DistributedNotificationCenter.default()
            .addObserver(
              forName: .init("com.apple.screensaver.didstop"),
              object: nil,
              queue: .main
            ) { _ in
              NSWorkspace.activationFlags.remove(.screenSaverRunning)
            }
        )
        Self.combinePoolCocoa.append(
          NSWorkspace.shared.notificationCenter
            .addObserver(
              forName: NSWorkspace.willSleepNotification,
              object: nil,
              queue: .main
            ) { _ in
              NSWorkspace.activationFlags.insert(.hibernating)
            }
        )
        Self.combinePoolCocoa.append(
          NSWorkspace.shared.notificationCenter
            .addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { _ in
              NSWorkspace.activationFlags.remove(.hibernating)
            }
        )
        Self.combinePoolCocoa.append(
          NSWorkspace.shared.notificationCenter
            .addObserver(
              forName: NSWorkspace.sessionDidResignActiveNotification,
              object: nil,
              queue: .main
            ) { _ in
              NSWorkspace.activationFlags.insert(.sessionSwitchedOut)
            }
        )
        Self.combinePoolCocoa.append(
          NSWorkspace.shared.notificationCenter
            .addObserver(
              forName: NSWorkspace.sessionDidBecomeActiveNotification,
              object: nil,
              queue: .main
            ) { _ in
              NSWorkspace.activationFlags.remove(.sessionSwitchedOut)
            }
        )
      }
    }
  }
#endif
