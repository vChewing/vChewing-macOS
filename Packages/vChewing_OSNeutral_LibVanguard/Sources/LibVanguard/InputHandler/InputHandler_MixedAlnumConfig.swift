// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.
import Foundation

// MARK: - MixedAlnumConfig

/// 中英混打（MixedAlnum）模式專用的執行期狀態容器。
///
/// 將該模式所需的暫存狀態收斂成單一值型別，其後由 `InputHandlerProtocol` 以單一屬性持有，
/// 各欄位再以薄存取器對外（比照 `Homa.Assembler.config` 之做法）。
///
/// - Important: **本型別提供兩個復位粒度，不可混用**：
///   - `resetContent()`：僅重設「內容」類狀態。**每次遞交都會經過此路徑**
///     （`switchState(.ofCommitting)` 會連帶呼叫 `InputHandlerProtocol.clear()`），
///     故**不得**在該處清除閂滯旗標，否則「每鍵即刻遞交」會在第一顆鍵就自我解除。
///   - `resetAll()`：連同閂滯旗標一併重設。**由 `InputHandlerProtocol.releaseLatchedAlnumState(announce:)`
///     呼叫**——該函式即「閂滯之解除」之唯一出口：使用者之明確解除鍵與會話邊界
///     （`resetInputHandler()`、`performServerActivation()`）皆經此。
public struct MixedAlnumConfig: Sendable, Equatable {
  // MARK: Lifecycle

  public init(buffer: String = "", isLatchedToAlnum: Bool = false) {
    self.buffer = buffer
    self.isLatchedToAlnum = isLatchedToAlnum
  }

  // MARK: Public

  /// 混輸暫存 ASCII 緩衝區（尚待辨識為英文抑或注音之內容）。
  public var buffer: String = ""

  /// 是否已「閂滯於英打」。
  ///
  /// 為真時，該模式下每一顆可列印 ASCII 按鍵皆即刻遞交、不進緩衝區。
  /// 僅在中英混打模式與英數閂滯開關皆啟用時才可能為真。
  public var isLatchedToAlnum: Bool = false

  /// 僅重設內容類狀態（緩衝區）。**不觸碰閂滯旗標。**
  public mutating func resetContent() {
    buffer.removeAll()
  }

  /// 重設全部狀態（含閂滯旗標）。
  /// 唯一呼叫點為 `InputHandlerProtocol.releaseLatchedAlnumState(announce:)`。
  public mutating func resetAll() {
    resetContent()
    isLatchedToAlnum = false
  }
}
