// (c) 2022 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import AppKit
import Shared_DarwinImpl
import SwiftUI

#if DEBUG

  @available(macOS 14, *)
  #Preview {
    let testCandidates: [String] = [
      "二十四歲是學生", "二十四歲🐂🍺", "昏睡紅茶", "食雪漢", "意味深", "學生", "便乗",
      "迫真", "驚愕", "論證", "正論", "惱", "悲", "屑", "食", "雪", "漢", "意", "味",
      "深", "二", "十", "四", "歲", "是", "學", "生", "昏", "睡", "紅", "茶", "便", "乗",
      "嗯", "哼", "啊",
    ]

    var testCandidatesConverted: [CandidateInState] {
      testCandidates.map { candidate in
        let firstValue: [String] = .init(repeating: "", count: candidate.count)
        return (firstValue, candidate)
      }
    }

    let poolHorizontal1: TDK4AppKit.CandidatePool4AppKit = {
      let pool = TDK4AppKit.CandidatePool4AppKit(
        candidates: testCandidatesConverted,
        isExpanded: false,
        selectionKeys: "123456",
        layout: .horizontal
      )
      var strOutput = ""
      pool.candidateLines.forEach {
        $0.forEach {
          strOutput += $0.displayedText + ", "
        }
        strOutput += "\n"
      }
      pool.tooltip = "📼"
      pool.reverseLookupResult = ["889", "464"]
      return pool
    }()

    let poolHorizontal2: TDK4AppKit.CandidatePool4AppKit = {
      let pool = TDK4AppKit.CandidatePool4AppKit(
        candidates: testCandidatesConverted,
        lines: 4,
        isExpanded: true,
        selectionKeys: "123456",
        layout: .horizontal
      )
      var strOutput = ""
      pool.candidateLines.forEach {
        $0.forEach {
          strOutput += $0.displayedText + ", "
        }
        strOutput += "\n"
      }
      pool.tooltip = "📼"
      pool.reverseLookupResult = ["889", "464"]
      pool.consecutivelyFlipLines(isBackward: false, count: 1)
      pool.consecutivelyFlipLines(isBackward: true, count: 1)
      return pool
    }()

    let poolVertical1: TDK4AppKit.CandidatePool4AppKit = {
      let pool = TDK4AppKit.CandidatePool4AppKit(
        candidates: testCandidatesConverted,
        isExpanded: false,
        selectionKeys: "123456",
        layout: .vertical
      )
      var strOutput = ""
      pool.candidateLines.forEach {
        $0.forEach {
          strOutput += $0.displayedText + ", "
        }
        strOutput += "\n"
      }
      pool.tooltip = "📼"
      pool.reverseLookupResult = ["889", "464"]
      return pool
    }()

    let poolVertical2: TDK4AppKit.CandidatePool4AppKit = {
      let pool = TDK4AppKit.CandidatePool4AppKit(
        candidates: testCandidatesConverted,
        lines: 4,
        isExpanded: true,
        selectionKeys: "123456",
        layout: .vertical
      )
      var strOutput = ""
      pool.candidateLines.forEach {
        $0.forEach {
          strOutput += $0.displayedText + ", "
        }
        strOutput += "\n"
      }
      pool.tooltip = "📼"
      pool.reverseLookupResult = ["889", "464"]
      pool.consecutivelyFlipLines(isBackward: false, count: 1)
      pool.consecutivelyFlipLines(isBackward: true, count: 1)
      return pool
    }()

    let poolsHorizontal: [TDK4AppKit.CandidatePool4AppKit] = [
      poolHorizontal1, poolHorizontal2,
    ]
    let poolsVertical: [TDK4AppKit.CandidatePool4AppKit] = [
      poolVertical1, poolVertical2,
    ]

    VStack(alignment: .leading) {
      HStack {
        Text(verbatim: "TDKCandidates specimen")
          .bold()
          .frame(maxWidth: .infinity, alignment: .leading)
        Text(verbatim: "bgColor: #114514")
          .bold()
          .frame(maxWidth: .infinity, alignment: .trailing)
      }
      .shadow(radius: 3)
      .shadow(radius: 5)
      VStack(alignment: .leading) {
        ForEach(Array(poolsHorizontal.enumerated()), id: \.offset) { _, pool in
          TDK4AppKit.VwrCandidateTDK4AppKitForSwiftUI(thePool: pool)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .background {
              Color(NSColor.controlBackgroundColor)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .shadow(radius: 4)
            .fixedSize()
        }
      }

      HStack {
        ForEach(Array(poolsVertical.enumerated()), id: \.offset) { _, pool in
          TDK4AppKit.VwrCandidateTDK4AppKitForSwiftUI(thePool: pool)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .background {
              Color(NSColor.controlBackgroundColor)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .shadow(radius: 4)
            .fixedSize()
        }
      }
    }
    .fixedSize()
    .padding()
    .background {
      Color(CGColor(red: 0.07, green: 0.27, blue: 0.08, alpha: 1.00))
        .overlay(alignment: .topTrailing) {
          Text(verbatim: "bgColor: #114514")
            .bold()
            .shadow(radius: 3)
            .padding()
        }
    }
  }

#endif
