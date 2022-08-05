// Copyright (c) 2021 and onwards Zonble Yang (MIT-NTL License).
// All possible vChewing-specific modifications are of:
// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import XCTest

@testable import vChewing

class VersionUpdateApiTests: XCTestCase {
  func testFetchVersionUpdateInfo() {
    let exp = expectation(description: "wait for 3 seconds")
    _ = VersionUpdateApi.check(forced: true) { result in
      exp.fulfill()
      switch result {
        case .success:
          break
        case .failure(let error):
          XCTFail(error.localizedDescription)
      }
    }
    wait(for: [exp], timeout: 20.0)
  }
}
