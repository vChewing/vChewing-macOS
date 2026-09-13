// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

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
