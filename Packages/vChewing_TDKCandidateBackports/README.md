# TDKCandidateBackports

田所選字窗的分支版本，僅對 macOS 10.15 與 macOS 11 提供、且有下述特性折扣：

- 所有的與介面配色有關的內容設定都是手動重新指定的，所以介面調色盤會與 macOS 12 開始的系統專用的田所選字窗完整版相比有出入。
- 無法支援「根據不同的選字窗內容文本語言區域，使用對應區域的系統介面字型來顯示」的特性。
  - 原因：與該特性有關的幾個關鍵 API 都是 macOS 12 開始才有的 API。

詳情請參考 `vChewing_CandidateWindow` 這個 Swift Package。

```
// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.
```
