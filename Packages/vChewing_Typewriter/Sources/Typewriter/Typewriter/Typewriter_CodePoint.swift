// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

// MARK: - CodePointTypewriter

/// 內碼區位輸入處理 (Handle Code Point Input)
@frozen
public struct CodePointTypewriter<Handler: InputHandlerProtocol>: TypewriterProtocol {
  // MARK: Lifecycle

  public init(_ handler: Handler) {
    self.handler = handler
  }

  // MARK: Public

  public let handler: Handler

  /// 用來處理 InputHandler.HandleInput() 當中的與內碼區位輸入有關的組字行為。
  /// - Parameter input: 輸入訊號。
  /// - Returns: 告知 IMK「該按鍵是否已經被輸入法攔截處理」。
  public func handle(_ input: some InputSignalProtocol) -> Bool? {
    guard !input.isReservedKey else { return nil }
    guard let session = handler.session, input.text.count == 1 else { return nil }
    guard !input.text.compactMap(\.hexDigitValue).isEmpty else {
      errorCallback("05DD692C：輸入的字元並非 ASCII 字元。。")
      return true
    }
    switch handler.strCodePointBuffer.count {
    case 0 ..< 4:
      if handler.strCodePointBuffer.count < 3 {
        handler.strCodePointBuffer.append(input.text)
        var updatedState = handler.generateStateOfInputting(guarded: true)
        updatedState.tooltipDuration = 0
        updatedState.tooltip = TypingMethod.codePoint
          .getTooltip(vertical: session.isVerticalTyping)
        session.switchState(updatedState)
        return true
      }
      let hexSequence = "\(handler.strCodePointBuffer)\(input.text)"
      let parsedChar = CodePointDecoder.decode(
        hexString: hexSequence,
        encodingID: IMEApp.currentInputMode.nonUTFEncoding,
        encodingHint: IMEApp.currentInputMode.nonUTFEncodingInitials
      )?.first?.description
      guard var char = parsedChar else {
        errorCallback("D220B880：輸入的字碼沒有對應的字元。")
        var updatedState = State.ofAbortion()
        updatedState.tooltipDuration = 0
        updatedState.tooltip = "Invalid Code Point.".localized
        session.switchState(updatedState)
        handler.currentTypingMethod = .codePoint
        return true
      }
      // 某些舊版 macOS 會在這裡生成的字元後面插入垃圾字元。這裡只保留起始字元。
      if char.count > 1 { char = char.map(\.description)[0] }
      session.switchState(State.ofCommitting(textToCommit: char))
      var updatedState = handler.generateStateOfInputting(guarded: true)
      updatedState.tooltipDuration = 0
      updatedState.tooltip = TypingMethod.codePoint.getTooltip(
        vertical: session.isVerticalTyping
      )
      session.switchState(updatedState)
      handler.currentTypingMethod = .codePoint
      return true
    default:
      session.switchState(handler.generateStateOfInputting())
      handler.currentTypingMethod = .codePoint
      return true
    }
  }
}
