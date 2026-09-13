// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

// MARK: - TypewriterProtocol

public protocol TypewriterProtocol {
  associatedtype Handler: InputHandlerProtocol
  typealias State = Handler.State
  typealias Session = Handler.Session
  var handler: Handler { get }
  init(_ handler: Handler)
  func handle(_ input: some InputSignalProtocol) -> Bool?
}

extension TypewriterProtocol {
  public func errorCallback(_ msg: String) {
    handler.errorCallback?(msg)
  }
}
