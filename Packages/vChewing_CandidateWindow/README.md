# CandidateWindow

用以定義與唯音的選字窗有關的基礎內容。此外，還包含了唯音自家的次世代選字窗「田所(TDK)」。

> 命名緣由：野獸先輩「田所」的姓氏。

TDK 選字窗以純 SwiftUI 構築，用以取代此前自上游繼承來的 Voltaire 選字窗。

TDK 選字窗同時支援橫排矩陣佈局與縱排矩陣佈局。然而，目前有下述侷限：

- 因 SwiftUI 自身特性所導致的嚴重的效能問題（可能只會在幾年前的老電腦上出現）。基本上來講，如果您經常使用全字庫模式的話，請在偏好設定內啟用效能更高的 IMK 選字窗。
- 同樣出於上述原因，為了讓田所選字窗至少處於可在生產力環境下正常使用的狀態，就犧牲了捲動檢視的功能。也就是說，每次只顯示三行/三列，但顯示內容則隨著使用者的游標操作而更新。

TDK 選字窗會在 macOS 10.15 與 macOS 11 系統下有下述特性折扣：

- 所有的與介面配色有關的內容設定都是手動重新指定的，所以介面調色盤會與 macOS 12 開始的系統專用的田所選字窗完整版相比有出入。
- 無法支援「根據不同的選字窗內容文本語言區域，使用對應區域的系統介面字型來顯示」的特性。
  - 原因：與該特性有關的幾個關鍵 API 都是 macOS 12 開始才有的 API。

```
// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.
```
