// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import CoreGraphics
import Foundation

// MARK: - NotifierViewModel

/// Notifier 的後台計算單元（singleton）——負責一切「幾何與序列」的計算：
/// 卡片堆疊的增刪 / 逐出 / 淡出狀態、視窗框架、每張卡片的框架與透明度、滑入起點等。
/// 前端（`Notifier` / `NotifierCard`）僅依此處計算出的數據做呈現，不自行推導任何幾何。
///
/// 全部計算皆為純函式（僅依賴傳入的螢幕矩形與卡片寬度），可在單元測試中以固定的
/// 螢幕矩形與寬度鎖定所有輸出；時間軸則以「明確方法呼叫」驅動（`markNotNew` /
/// `fadeOut` / `completeRemoval`），由前端依此類別的時序常數排程實際計時器。
///
/// 執行緒模型：僅允許在主執行緒上存取（前端經 `mainSync` / `asyncOnMain` 驅動；
/// 單元測試以 Swift Testing `.serialized` + `@MainActor` 序列執行、於 suite `init()` 重置），
/// 故以 `@unchecked Sendable` 標記 singleton。
public final class NotifierViewModel: @unchecked Sendable {
  // MARK: Lifecycle

  public init() {
    self.windowHeight = CGFloat(maxCardCount) * cardHeight
      + CGFloat(maxCardCount - 1) * cardGap + windowPadding * 2
  }

  // MARK: Public

  /// 單張卡片的最新狀態（邏輯記錄；前端以 `id` 綁定視圖實例）。
  public struct CardRecord: Equatable {
    public let id: Int
    public let message: String
    public let intrinsicWidth: CGFloat
    public internal(set) var isNew: Bool
    public internal(set) var isFadingOut: Bool
    public internal(set) var needsSlideIn: Bool
  }

  /// `enqueue` 的結果：本次事件的影響範圍。
  public struct EnqueueEvent: Equatable {
    public let newID: Int
    public let evictedID: Int?
  }

  /// 一次渲染所需的全部幾何數據。
  public struct Layout: Equatable {
    public struct Placement: Equatable {
      public let id: Int
      public let frame: CGRect
      public let alpha: CGFloat
      /// 滑入起點（自左側偏移處）；無滑入需求時為 nil。
      public let slideInStart: CGRect?
    }

    public let windowFrame: CGRect
    public let placements: [Placement]
  }

  public static let shared = NotifierViewModel()

  // 幾何常數（單一事實來源）。
  public let cardHeight: CGFloat = 60
  public let cardGap: CGFloat = 10
  public let windowPadding: CGFloat = 32 // 需要設得大一些，不然橫向動畫時視窗邊緣會切到陰影。
  public let slideInOffset: CGFloat = 20
  public let maxCardCount = 3

  /// 各堆疊位置的基礎透明度（索引 0 = 最新）：100% / 60% / 5%。
  public let baseAlphas: [CGFloat] = [1.0, 0.6, 0.05]

  // 時序常數（前端據以排程計時器與動畫時長）。
  public let dedupWindow: TimeInterval = 0.3
  /// 每則通知停留在螢幕上、直至淡出觸發的固定時長——對所有通知皆相同，
  /// 不因被推下（基礎透明度改變）而重置。
  public let displayLifetime: TimeInterval = 1.3
  public let slideInDuration: TimeInterval = 0.1
  public let relayoutDuration: TimeInterval = 0.1
  public let fadeOutDuration: TimeInterval = 0.15

  /// 視窗固定高度：容納最多三張卡片 + 內側留白（陰影繪製區）。
  public let windowHeight: CGFloat

  /// 卡片堆疊（索引 0 = 最新）。
  public private(set) var records: [CardRecord] = []

  // MARK: 動作

  /// 重置全部狀態（供單元測試隔離）。
  public func reset() {
    records = []
    nextID = 1
  }

  /// 入列一則通知。回傳本次事件；被去重（與最新且仍在新鮮期內者重複）或訊息為空時回傳 nil。
  @discardableResult
  public func enqueue(message: String, intrinsicWidth: CGFloat) -> EnqueueEvent? {
    if let newest = records.first, newest.isNew, newest.message == message { return nil }
    let rawMessage = message.replacingOccurrences(of: "\n", with: "")
    guard !rawMessage.isEmpty else { return nil }

    // 堆疊已滿時逐出最舊者。
    var evictedID: Int?
    if records.count >= maxCardCount, let oldest = records.last {
      evictedID = oldest.id
      records.removeLast()
    }

    let record = CardRecord(
      id: nextID, message: message, intrinsicWidth: intrinsicWidth,
      isNew: true, isFadingOut: false, needsSlideIn: true
    )
    nextID += 1
    records.insert(record, at: 0)

    return EnqueueEvent(newID: record.id, evictedID: evictedID)
  }

  /// 標記某卡不再是「新」通知（由前端於新鮮期滿時呼叫）。
  public func markNotNew(_ id: Int) {
    guard let index = records.firstIndex(where: { $0.id == id }) else { return }
    records[index].isNew = false
  }

  /// 使某卡開始淡出（前端於其仍未被推下時呼叫）。回傳是否真的開始。
  @discardableResult
  public func fadeOut(_ id: Int) -> Bool {
    guard let index = records.firstIndex(where: { $0.id == id }), !records[index].isFadingOut
    else { return false }
    records[index].isFadingOut = true
    return true
  }

  /// 淡出完成後移除某卡（前端於淡出動畫結束時呼叫）。回傳是否真的移除。
  @discardableResult
  public func completeRemoval(_ id: Int) -> Bool {
    guard let index = records.firstIndex(where: { $0.id == id }) else { return false }
    records.remove(at: index)
    return true
  }

  /// 消費某卡的滑入旗標（前端於套用滑入起點後呼叫）。
  public func consumeSlideIn(for id: Int) {
    guard let index = records.firstIndex(where: { $0.id == id }) else { return }
    records[index].needsSlideIn = false
  }

  // MARK: 計算

  /// 依目前堆疊與螢幕矩形計算全部幾何。
  public func layout(in screenRect: CGRect) -> Layout {
    // 視窗寬度以「最寬卡片」為準；每張卡片本身則依自身內容寬度
    // （SwiftUI 語義上的 fixedSize），並以尾端（右緣）對齊於同一螢幕位置。
    let maxWidth = records.map { $0.intrinsicWidth }.max() ?? 0
    let windowWidth = maxWidth + windowPadding * 2
    var windowFrame = CGRect(x: 0, y: 0, width: windowWidth, height: windowHeight)
    // 卡片堆疊的螢幕位置與舊版一致：頂端於 maxY − 100、右緣於 maxX − 20。
    let stackTopInset = ceil(2.5 * cardHeight) - cardHeight + 10
    windowFrame.origin.x = screenRect.maxX - 20 - maxWidth - windowPadding
    windowFrame.origin.y = screenRect.maxY - stackTopInset - windowHeight + windowPadding

    let placements: [Layout.Placement] = records.enumerated().map { index, record in
      let y = windowHeight - windowPadding - CGFloat(index + 1) * cardHeight
        - CGFloat(index) * cardGap
      // 每張卡片以自身內容寬度排版、右緣對齊（x = 視窗右緣 − 留白 − 自身寬度）。
      let width = record.intrinsicWidth
      let frame = CGRect(
        x: windowWidth - windowPadding - width, y: y, width: width, height: cardHeight
      )
      let alpha: CGFloat =
        record.isFadingOut ? 0 : baseAlphas[min(index, baseAlphas.count - 1)]
      let slideInStart: CGRect? = record.needsSlideIn
        ? frame.offsetBy(dx: -slideInOffset, dy: 0) : nil
      return Layout.Placement(id: record.id, frame: frame, alpha: alpha, slideInStart: slideInStart)
    }
    return Layout(windowFrame: windowFrame, placements: placements)
  }

  // MARK: Private

  private var nextID = 1
}
