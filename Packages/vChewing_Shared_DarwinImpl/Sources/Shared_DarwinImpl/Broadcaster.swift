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
  // MARK: Public

  public static var shared = Broadcaster()

  public private(set) dynamic var eventForReloadingPhraseEditor = UUID()
  public private(set) dynamic var eventForClosingAllPanels = UUID()
  public private(set) dynamic var lmMgrDataFolderPathInvalidityConfirmed: String?
  public private(set) dynamic var lmMgrCassettePathInvalidityConfirmed: String?

  public func confirmLmMgrDataFolderPathInvalidity(
    _ path: String?
  ) {
    queue.sync {
      self.lmMgrDataFolderPathInvalidityConfirmed = path
    }
  }

  public func confirmLmMgrCassettePathInvalidity(
    _ path: String?
  ) {
    queue.sync {
      self.lmMgrCassettePathInvalidityConfirmed = path
    }
  }

  public func clearLmMgrDataFolderPathInvalidity() {
    queue.sync { self.lmMgrDataFolderPathInvalidityConfirmed = nil }
  }

  public func clearLmMgrCassettePathInvalidity() {
    queue.sync { self.lmMgrCassettePathInvalidityConfirmed = nil }
  }

  public func postEventForReloadingPhraseEditor() {
    queue.sync {
      self.eventForReloadingPhraseEditor = UUID()
    }
  }

  public func postEventForClosingAllPanels() {
    queue.sync {
      self.eventForClosingAllPanels = UUID()
    }
  }

  // MARK: Private

  private let queue = DispatchQueue(
    label: "org.vchewing.vChewing_Shared_DarwinImpl.Broadcaster"
  )
}
