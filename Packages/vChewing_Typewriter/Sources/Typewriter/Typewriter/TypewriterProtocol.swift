// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

// MARK: - TypewriterProtocol

public protocol TypewriterProtocol {
  associatedtype InputHandler: InputHandlerProtocol
  typealias State = InputHandler.State
  typealias Session = InputHandler.Session
  var handler: InputHandler { get }
  init(_ handler: InputHandler)
  func handle(_ input: InputSignalProtocol) -> Bool?
}

extension TypewriterProtocol {
  public func errorCallback(_ msg: String) {
    handler.errorCallback?(msg)
  }
}
