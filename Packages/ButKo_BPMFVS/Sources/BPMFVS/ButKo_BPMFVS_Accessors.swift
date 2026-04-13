// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

// 該檔案不包括 ButKo BPMFVS 原始資料實作。BPMFVS 原始資料著作權資訊詳見：
// http://github.com/ButTaiwan/bpmfvs/raw/refs/heads/master/NOTICE.txt

import Foundation

public enum BPMFVS {
  public static func getBPMFVSDataURL() -> URL? {
    // Bundle.module is MainActor-isolated in this context.
    Bundle.module.url(forResource: "phonic_table_Z", withExtension: "txt")
  }
}
