// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.
import Foundation

// MARK: - FuriousTypingConfig

/// 狂拼模式（Furious Typing Mode）專用的執行期狀態容器。
///
/// 將該模式於 `InputHandler` 內散落之執行期狀態收斂成單一值型別，其後由
/// `InputHandlerProtocol` 以單一屬性持有，各欄位再以薄存取器對外（比照
/// `MixedAlnumConfig` 之做法）。
///
/// - Note: 本型別雖由打字機消費，其**持有者恆為 `InputHandlerProtocol`**，故與
///   `MixedAlnumConfig` 一同住在 `InputHandler/`（先前寄居於 `Typewriter/`）。
///
/// - Important: 三個欄位之生命週期不同，不可一概而論：
///   - `trail`：自動 chop 之拼音字母 blob 序列，跨按鍵存在；任何使用者顯式干涉
///     （選字、輪替、游標移動、聲調覆寫）或狀態重置皆使其失效——**唯一出口為
///     `InputHandlerProtocol.invalidateFuriousTrail()`**（即 `resetTrail()`）。
///   - `highlightOverride`：狂拼 copilot 窗之高亮候選，**當拍消費**（讀畢即歸零；
///     不隨 trail 失效而清，但隨狀態重置 `resetAll()` 而清）。
///   - `coSegmentedOffers`：聯合重切（P164）之替代切分 offers，於
///     `furiousTypingFrontCandidates` 生成時**整批刷新**（非累積）。
public struct FuriousTypingConfig: Sendable, Equatable {
  // MARK: Lifecycle

  public init(
    trail: [String] = [],
    highlightOverride: CandidateInState? = nil,
    coSegmentedOffers: [FuriousCoSegmentedOffer] = []
  ) {
    self.trail = trail
    self.highlightOverride = highlightOverride
    self.coSegmentedOffers = coSegmentedOffers
  }

  // MARK: Public

  /// 自動 chop 提交鍵對應的拼音字母 blob 序列（狂拼重切分之依據）。
  public var trail: [String] = []

  /// 狂拼 copilot 窗之高亮候選（**當拍消費**：讀畢即歸零）。
  public var highlightOverride: CandidateInState?

  /// 狂拼 copilot 窗聯合重切（P164）的替代切分 offers（生成時刷新）。
  public var coSegmentedOffers: [FuriousCoSegmentedOffer] = []

  // MARK: Equatable

  /// `CandidateInState` 為 tuple 別名（無從合成 `Equatable`），故逐欄手寫。
  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.trail == rhs.trail
      && lhs.highlightOverride?.keyArray == rhs.highlightOverride?.keyArray
      && lhs.highlightOverride?.value == rhs.highlightOverride?.value
      && lhs.coSegmentedOffers == rhs.coSegmentedOffers
  }

  /// 清空 trail（**使用者顯式干涉**之複位粒度）。
  ///
  /// 唯一呼叫點為 `InputHandlerProtocol.invalidateFuriousTrail()`；
  /// 重切分只認 trail 與組字器尾鍵的對應，故任何使該對應失效的操作都須經此。
  /// **只清 trail**：當拍尚在消費週期內之高亮與重切 offers 不受影響。
  public mutating func resetTrail() {
    trail.removeAll()
  }

  /// 重設整批執行期狀態（**狀態重置**之複位粒度）。
  ///
  /// 唯一呼叫點為 `InputHandlerProtocol.clear()`——該函式即組字／會話狀態之整批
  /// 複位口，故上一輪殘留之高亮與重切 offers 皆不得跨過此邊界
  /// （否則它們會在下一輪被當成當拍狀態消費）。
  public mutating func resetAll() {
    resetTrail()
    highlightOverride = nil
    coSegmentedOffers.removeAll()
  }
}
