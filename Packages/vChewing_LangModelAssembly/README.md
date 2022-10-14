# LangModelAssembly

威注音輸入法的語言模組總成套裝。

- vChewingLM：總命名空間，也承載一些在套裝內共用的工具函式。
- LMConsolidator：自動格式整理模組。
- LMInstantiator：語言模組副本化模組。另有其日期時間擴充模組可用（對 CIN 磁帶模式無效）。

以下是子模組：

- lmCassette：專門用來處理 CIN 磁帶檔案的模組，命名為「遠野」引擎。
- LMAssociates：聯想詞模組。
- LMCoreEX：可以直接讀取 TXT 格式的帶有權重資料的語彙檔案的模組。
- LMCoreNS：專門用來讀取原廠 plist 檔案的模組。
- lmPlainBopomofo：專門用來讀取使用者自訂ㄅ半候選字順序覆蓋定義檔案（plist）的模組。
- lmReplacements：專門用來讀取使用者語彙置換模式的辭典資料的模組。
- lmUserOverride：半衰記憶模組。

```
// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.
```
