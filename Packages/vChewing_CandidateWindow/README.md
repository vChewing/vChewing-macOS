# CandidateWindow

用以定義與威注音的選字窗有關的基礎內容。此外，還包含了威注音自家的次世代選字窗「田所(TDK)」。

> 命名緣由：野獸先輩「田所」的姓氏。

TDK 選字窗以純 SwiftUI 構築，用以取代此前自上游繼承來的 Voltaire 選字窗。

然而，TDK 選字窗目前有下述侷限：

- 因 SwiftUI 自身特性所導致的嚴重的效能問題。基本上來講，如果您經常使用全字庫模式的話，請在偏好設定內啟用效能更高的 IMK 選字窗。
- 同樣出於上述原因，為了讓田所選字窗至少處於可在生產力環境下正常使用的狀態，就犧牲了捲動檢視的功能。也就是說，每次只顯示六行，但顯示內容則隨著使用者的游標操作而更新。
- TDK 選字窗目前僅完成了橫版矩陣陳列模式的實作，且尚未引入對縱排選字窗陳列佈局的支援。

因為這些問題恐怕需要很久才能全部解決，所以威注音會在這段時間內推薦使用者們優先使用 IMK 選字窗。

```
// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.
```
