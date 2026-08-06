// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import CoreGraphics
import NotifierUI
import Testing

/// 鎖定 `NotifierViewModel` 後台計算數據的單元測試（Swift Testing Macro）。
///
/// 以固定的螢幕矩形（1920×1080）與卡片寬度驅動 viewModel，逐一固定：
/// 卡片堆疊的增刪 / 逐出 / 淡出狀態、視窗框架、每張卡片的框架 / 基礎透明度 / 滑入起點。
/// 重點鎖定「第四則通知逐出最舊卡重用」的幾何——新卡必須落在頂端（而非自底部向上）。
///
/// 註：vChewing-macOS 的 package targets 全面落實 MainActor isolation，而 `XCTestCase`
/// 繼承要求繼承者必須為 nonisolated、與之衝突——故本專案統一使用 Swift Testing
/// （struct 型 suite、無繼承、`@Test` / `#expect`）。本套件釘於 MainActor
/// （target `defaultIsolation` 設為 `@MainActor`），並以 `.serialized` 強制序列執行——
/// 符合 viewModel 的「僅限主執行緒存取」契約；每個測試前於 `init()` 重置共享 singleton。
@Suite(.serialized)
struct NotifierViewModelTests {
  // MARK: Lifecycle

  init() {
    NotifierViewModel.shared.reset()
  }

  // MARK: Internal

  // MARK: - 基礎透明度

  /// 基礎透明度：新 → 舊依序為 100% / 60% / 5%。
  @Test
  func testBaseAlphasAre100_60_5() {
    let vm = NotifierViewModel.shared
    #expect(vm.baseAlphas == [1.0, 0.6, 0.05])
  }

  // MARK: - 幾何基準

  /// 第一則通知：單卡置於頂端（y=152）、全亮（100%）、帶滑入起點。
  @Test
  func testFirstEnqueuePlacesCardAtTopWithFullAlpha() {
    let vm = NotifierViewModel.shared
    let event = vm.enqueue(message: "A", intrinsicWidth: 300)
    #expect(event?.newID == 1)
    #expect(event?.evictedID == nil)

    let layout = vm.layout(in: screen)
    #expect(layout.placements.count == 1)
    let p = layout.placements[0]
    #expect(p.id == 1)
    #expect(
      p.frame
        == CGRect(x: padding, y: windowHeight - padding - cardHeight, width: 300, height: cardHeight)
    )
    #expect(p.alpha == 1.0)
    #expect(p.slideInStart == p.frame.offsetBy(dx: -vm.slideInOffset, dy: 0))
    // 視窗固定高度 = 3 張卡片 + 2 間距 + 2 留白。
    #expect(layout.windowFrame.size == CGSize(width: 300 + padding * 2, height: windowHeight))
    #expect(layout.windowFrame.origin.x == 1_920 - 20 - 300 - padding)
    #expect(layout.windowFrame.origin.y == 1_080 - 100 - windowHeight + padding)
  }

  /// 第二則通知：新卡置頂（100%）、舊卡推下（60%）；兩卡皆依自身內容寬度、尾端對齊。
  @Test
  func testSecondEnqueuePushesOldCardTo60Percent() {
    let vm = NotifierViewModel.shared
    vm.enqueue(message: "A", intrinsicWidth: 300)
    let event = vm.enqueue(message: "B", intrinsicWidth: 200)
    #expect(event?.newID == 2)
    #expect(event?.evictedID == nil)

    let layout = vm.layout(in: screen)
    #expect(layout.placements.count == 2)
    #expect(layout.placements[0].alpha == 1.0)
    #expect(layout.placements[1].alpha == 0.6)
    // 推下不代表立即淡出——由各自的固定時長計時器驅動。
    #expect(!vm.records[1].isFadingOut)
    // 每張卡片依自身內容寬度（B 200 / A 300）、尾端對齊。
    #expect(
      layout.placements[0].frame
        == CGRect(
          x: 300 + padding - 200, y: windowHeight - padding - cardHeight, width: 200,
          height: cardHeight
        )
    )
    #expect(
      layout.placements[1].frame
        == CGRect(
          x: padding, y: windowHeight - padding - cardHeight * 2 - cardGap, width: 300,
          height: cardHeight
        )
    )
    #expect(layout.placements[0].frame.maxX == layout.placements[1].frame.maxX)
  }

  /// 第三則通知：三卡堆疊，基礎透明度依序 100% / 60% / 5%、寬度各自為 200 / 250 / 300。
  @Test
  func testThirdEnqueueStacksThreeCards() {
    let vm = NotifierViewModel.shared
    vm.enqueue(message: "A", intrinsicWidth: 300)
    vm.enqueue(message: "B", intrinsicWidth: 250)
    let event = vm.enqueue(message: "C", intrinsicWidth: 200)
    #expect(event?.newID == 3)
    #expect(event?.evictedID == nil)

    let layout = vm.layout(in: screen)
    #expect(layout.placements.count == 3)
    #expect(layout.placements.map(\.alpha) == [1.0, 0.6, 0.05])
    #expect(layout.placements[2].frame.minY == padding) // 最舊卡貼底。
    // 每張卡片依自身內容寬度（C 200 / B 250 / A 300）、尾端對齊。
    #expect(layout.placements.map(\.frame.width) == [200, 250, 300])
    #expect(layout.placements[0].frame.maxX == layout.placements[2].frame.maxX)
  }

  /// 每張卡片依自身內容寬度（SwiftUI 語義的 fixedSize）、尾端對齊——寬度不會被拉到最寬者。
  @Test
  func testCardWidthsFitOwnContentTrailingAligned() {
    let vm = NotifierViewModel.shared
    vm.enqueue(message: "A", intrinsicWidth: 300)
    vm.enqueue(message: "B", intrinsicWidth: 200)
    vm.enqueue(message: "C", intrinsicWidth: 150)
    let layout = vm.layout(in: screen)
    #expect(layout.placements.map(\.frame.width) == [150, 200, 300])
    // 尾端對齊：所有卡片右緣一致。
    let maxX = layout.placements[0].frame.maxX
    for p in layout.placements {
      #expect(p.frame.maxX == maxX)
    }
    // 視窗寬度仍以最寬者為準（+ 兩側留白）。
    #expect(layout.windowFrame.width == 300 + padding * 2)
    // 最寬卡片左緣貼留白、其餘往右偏移。
    #expect(layout.placements[2].frame.minX == padding)
    #expect(layout.placements[0].frame.minX == 300 + padding - 150)
  }

  // MARK: - 第四則通知（重用/逐出路徑）——「向上」迴歸鎖定

  /// 第四則通知逐出最舊卡重用：新卡必須落在**頂端**（y=152）且全亮、帶滑入起點，
  /// 而非停留在被逐出卡的底部位置——此為「動畫向上」的幾何面迴歸鎖定。
  @Test
  func testFourthEnqueueEvictsOldestAndNewCardLandsAtTop() {
    let vm = NotifierViewModel.shared
    vm.enqueue(message: "A", intrinsicWidth: 300)
    vm.enqueue(message: "B", intrinsicWidth: 250)
    vm.enqueue(message: "C", intrinsicWidth: 200)
    let event = vm.enqueue(message: "D", intrinsicWidth: 180)

    // 逐出最舊（A，id 1）。
    #expect(event?.newID == 4)
    #expect(event?.evictedID == 1)
    #expect(!vm.records.contains { $0.id == 1 })
    #expect(vm.records.map(\.id) == [4, 3, 2])

    let layout = vm.layout(in: screen)
    #expect(layout.placements.count == 3)
    // 堆疊寬 = 剩餘最寬（B 的 250）；各卡依自身寬度、尾端對齊。
    let expected = CGRect(
      x: 250 + padding - 180, y: windowHeight - padding - cardHeight, width: 180, height: cardHeight
    )
    #expect(layout.placements[0].id == 4)
    #expect(layout.placements[0].frame == expected)
    #expect(layout.placements[0].alpha == 1.0)
    // 滑入起點在左側 20pt 外——新卡自左側飄入頂端，而非自底部向上。
    #expect(layout.placements[0].slideInStart == expected.offsetBy(dx: -vm.slideInOffset, dy: 0))
    // 舊卡依序向下、基礎透明度 60% / 5%、寬度各自為 200 / 250。
    #expect(layout.placements[1].frame.minY == layout.placements[0].frame.minY - cardHeight - cardGap)
    #expect(layout.placements[2].frame.minY == padding)
    #expect(layout.placements.map(\.alpha) == [1.0, 0.6, 0.05])
    #expect(layout.placements.map(\.frame.width) == [180, 200, 250])
    // 尾端對齊。
    #expect(layout.placements[0].frame.maxX == layout.placements[2].frame.maxX)
  }

  /// 連續重用多次：每次新卡都落在頂端，堆疊恆為 3 張、最舊者依序被逐出。
  @Test
  func testRepeatedReuseKeepsNewCardAtTop() {
    let vm = NotifierViewModel.shared
    for i in 1 ... 6 {
      vm.enqueue(message: "N\(i)", intrinsicWidth: CGFloat(100 + i))
    }
    #expect(vm.records.count == 3)
    #expect(vm.records.map(\.id) == [6, 5, 4])
    let layout = vm.layout(in: screen)
    #expect(layout.placements[0].id == 6)
    #expect(layout.placements[0].frame.minY == windowHeight - padding - cardHeight)
    #expect(layout.placements.map(\.alpha) == [1.0, 0.6, 0.05])
  }

  // MARK: - 淡出 / 移除 / 時序

  /// 淡出計時器觸發（fadeOut）後，該卡於 layout 中透明度為 0；淡出完成（completeRemoval）後移除。
  @Test
  func testFadeOutMakesAlphaZeroThenRemoval() {
    let vm = NotifierViewModel.shared
    vm.enqueue(message: "A", intrinsicWidth: 300)
    vm.markNotNew(1)
    #expect(vm.layout(in: screen).placements[0].alpha == 1.0)
    #expect(vm.fadeOut(1))
    #expect(vm.layout(in: screen).placements[0].alpha == 0)
    // 已淡出者不可重複淡出。
    #expect(!vm.fadeOut(1))
    #expect(vm.completeRemoval(1))
    #expect(vm.records.isEmpty)
    // 未知 id 一律回 false。
    #expect(!vm.completeRemoval(99))
    #expect(!vm.fadeOut(99))
  }

  /// 任意位置的卡片皆可被 fadeOut（例如被推至 5% 的最舊卡）。
  @Test
  func testFadeOutAppliesToAnyPosition() {
    let vm = NotifierViewModel.shared
    vm.enqueue(message: "A", intrinsicWidth: 300)
    vm.enqueue(message: "B", intrinsicWidth: 250)
    vm.enqueue(message: "C", intrinsicWidth: 200)
    // 最舊卡（id 1）於位置 2（5%）；fadeOut 後透明度為 0。
    #expect(vm.layout(in: screen).placements[2].alpha == 0.05)
    #expect(vm.fadeOut(1))
    #expect(vm.layout(in: screen).placements[2].alpha == 0)
  }

  // MARK: - 去重 / 空訊息

  /// 與最新且仍在新鮮期內者重複 → 略過；新鮮期過後同訊息可再次入列。
  @Test
  func testDedupWithinFreshWindow() {
    let vm = NotifierViewModel.shared
    #expect(vm.enqueue(message: "A", intrinsicWidth: 300) != nil)
    #expect(vm.enqueue(message: "A", intrinsicWidth: 300) == nil) // 仍在新鮮期。
    vm.markNotNew(1)
    #expect(vm.enqueue(message: "A", intrinsicWidth: 300) != nil)
    #expect(vm.records.map(\.id) == [2, 1])
  }

  /// 空訊息（含僅換行）被拒絕。
  @Test
  func testEmptyMessageRejected() {
    let vm = NotifierViewModel.shared
    #expect(vm.enqueue(message: "", intrinsicWidth: 300) == nil)
    #expect(vm.enqueue(message: "\n", intrinsicWidth: 300) == nil)
    #expect(vm.enqueue(message: "\n\n", intrinsicWidth: 300) == nil)
    #expect(vm.records.isEmpty)
  }

  // MARK: - 視窗尺寸 / 滑入旗標

  /// 視窗高度固定（與卡片數量無關）。
  @Test
  func testWindowHeightIsFixedRegardlessOfCardCount() {
    let vm = NotifierViewModel.shared
    vm.enqueue(message: "A", intrinsicWidth: 300)
    #expect(vm.layout(in: screen).windowFrame.height == windowHeight)
    vm.enqueue(message: "B", intrinsicWidth: 250)
    vm.enqueue(message: "C", intrinsicWidth: 200)
    #expect(vm.layout(in: screen).windowFrame.height == windowHeight)
    // 寬度 = 最寬卡片 + 2 × 留白。
    #expect(vm.layout(in: screen).windowFrame.width == 300 + padding * 2)
  }

  /// 滑入旗標於 enqueue 時設定、consumeSlideIn 後清除。
  @Test
  func testSlideInFlagConsumed() {
    let vm = NotifierViewModel.shared
    vm.enqueue(message: "A", intrinsicWidth: 300)
    #expect(vm.layout(in: screen).placements[0].slideInStart != nil)
    vm.consumeSlideIn(for: 1)
    #expect(vm.layout(in: screen).placements[0].slideInStart == nil)
  }

  /// 空堆疊的 layout：無卡片、視窗僅剩留白尺寸。
  @Test
  func testEmptyStackLayout() {
    let vm = NotifierViewModel.shared
    let layout = vm.layout(in: screen)
    #expect(layout.placements.isEmpty)
    #expect(layout.windowFrame.size == CGSize(width: padding * 2, height: windowHeight))
  }

  // MARK: - 代數（id）恆定遞增

  /// 每次成功入列皆獲得全新 id（前端以 id 綁定視圖，永不重用 id）。
  @Test
  func testIDsMonotonicallyIncrease() {
    let vm = NotifierViewModel.shared
    #expect(vm.enqueue(message: "A", intrinsicWidth: 300)?.newID == 1)
    #expect(vm.enqueue(message: "B", intrinsicWidth: 250)?.newID == 2)
    #expect(vm.enqueue(message: "C", intrinsicWidth: 200)?.newID == 3)
    #expect(vm.enqueue(message: "D", intrinsicWidth: 180)?.newID == 4)
  }

  // MARK: Private

  /// 測試用固定螢幕矩形（visibleFrame）。
  private let screen = CGRect(x: 0, y: 0, width: 1_920, height: 1_080)

  /// 依 viewModel 常數推算的期望值（與 viewModel 同源，非魔術數字）。
  private var cardHeight: CGFloat { NotifierViewModel.shared.cardHeight }
  private var cardGap: CGFloat { NotifierViewModel.shared.cardGap }
  private var padding: CGFloat { NotifierViewModel.shared.windowPadding }
  private var windowHeight: CGFloat { NotifierViewModel.shared.windowHeight }
}
