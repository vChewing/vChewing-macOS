// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

#if canImport(Darwin)

  import Foundation

  @objcMembers
  public class Broadcaster: NSObject {
    public static var shared = Broadcaster()

    public dynamic var eventForReloadingPhraseEditor = UUID()
    public dynamic var eventForClosingAllPanels = UUID()
  }

#endif
