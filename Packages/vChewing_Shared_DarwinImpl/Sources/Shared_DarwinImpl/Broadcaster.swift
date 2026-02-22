// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation

@objcMembers
public final class Broadcaster: NSObject {
  public static var shared = Broadcaster()

  public private(set) dynamic var eventForReloadingPhraseEditor = UUID()
  public private(set) dynamic var eventForClosingAllPanels = UUID()
  public private(set) dynamic var lmMgrDataFolderPathInvalidityConfirmed: String?
  public private(set) dynamic var lmMgrCassettePathInvalidityConfirmed: String?

  public func confirmLmMgrDataFolderPathInvalidity(
    _ path: String?
  ) {
    mainSync {
      self.lmMgrDataFolderPathInvalidityConfirmed = path
    }
  }

  public func confirmLmMgrCassettePathInvalidity(
    _ path: String?
  ) {
    mainSync {
      self.lmMgrCassettePathInvalidityConfirmed = path
    }
  }

  public func clearLmMgrDataFolderPathInvalidity() {
    mainSync { self.lmMgrDataFolderPathInvalidityConfirmed = nil }
  }

  public func clearLmMgrCassettePathInvalidity() {
    mainSync { self.lmMgrCassettePathInvalidityConfirmed = nil }
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
