// (c) 2022 and onwards The vChewing Project (MulanPSL-2.0 License).
// ====================
// This code is released under the SPDX-License-Identifier: `MulanPSL-2.0`.

import Foundation

@objcMembers
public final class Broadcaster: NSObject {
  public static var shared = Broadcaster()

  public private(set) dynamic var eventForReloadingPhraseEditor = UUID()
  public private(set) dynamic var eventForClosingAllPanels = UUID()
  public private(set) dynamic var lxMgrDataFolderPathInvalidityConfirmed: String?
  public private(set) dynamic var lxMgrCassettePathInvalidityConfirmed: String?

  public func confirmLmMgrDataFolderPathInvalidity(
    _ path: String?
  ) {
    mainSync {
      self.lxMgrDataFolderPathInvalidityConfirmed = path
    }
  }

  public func confirmLmMgrCassettePathInvalidity(
    _ path: String?
  ) {
    mainSync {
      self.lxMgrCassettePathInvalidityConfirmed = path
    }
  }

  public func clearLmMgrDataFolderPathInvalidity() {
    mainSync { self.lxMgrDataFolderPathInvalidityConfirmed = nil }
  }

  public func clearLmMgrCassettePathInvalidity() {
    mainSync { self.lxMgrCassettePathInvalidityConfirmed = nil }
  }

  public func postEventForReloadingPhraseEditor() {
    // 該操作得異步進行，避免阻塞 MainActor。
    asyncOnMain {
      self.eventForReloadingPhraseEditor = UUID()
    }
  }

  public func postEventForClosingAllPanels() {
    mainSync {
      self.eventForClosingAllPanels = UUID()
    }
  }
}
